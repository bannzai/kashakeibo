// cloud_firestore も Transaction クラスを公開しており本 Entity と衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kashakeibo/entity/timestamp.dart';

part 'transaction.g.dart';
part 'transaction.freezed.dart';

/// 明細の種別 (収入 / 支出)。
enum TransactionType {
  /// 収入。
  income,

  /// 支出。
  expense,
}

/// 明細のカテゴリ。
///
/// 支出カテゴリの体系はデザイン (design_handoff_kashakeibo/README.md の
/// 読み取り確認画面: 食費・外食・日用品・交通・サブスク・その他) に合わせる。
/// 収入側はデザインに定義が無いため給与のみ定義する。
/// Firestore には enum 名の文字列で保存される。将来カテゴリを追加した時に
/// 旧バージョンのクライアントがデコードに失敗しないよう、未知の値は
/// [TransactionCategory.other] として読む (Transaction.category の unknownEnumValue)。
enum TransactionCategory {
  /// 食費。
  food,

  /// 外食。
  eatingOut,

  /// 日用品。
  dailyGoods,

  /// 交通。
  transportation,

  /// サブスク。
  subscription,

  /// 給与 (収入)。
  salary,

  /// その他。
  other,
}

/// 家計簿の明細。レシート・スクショの AI 解析結果や手動入力から作られる、
/// 本アプリで唯一の真実となるデータ (集計はサマリーを持たず本 Entity から都度計算する。
/// `.claude/rules/firestore-aggregation-rules.md` 参照)。
///
/// Firestore 上では `/users/{userID}/transactions/{id}` に保存される。
/// id は Firestore の自動生成 ID。
@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  @JsonSerializable(explicitToJson: true)
  const factory Transaction({
    /// ドキュメント ID (Firestore の自動生成 ID)。
    required String id,

    /// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
    /// `.claude/rules/entity-parent-id-rules.md` 参照)。
    required String userID,

    /// 明細の種別 (収入 / 支出)。月次集計・複合インデックスの絞り込みに使う。
    required TransactionType type,

    /// 金額 (日本円、整数)。
    required int amount,

    /// カテゴリ。未知の値は other として読む (enum 定義のコメント参照)。
    @JsonKey(unknownEnumValue: TransactionCategory.other)
    required TransactionCategory category,

    /// 明細の表示名 (店名・摘要)。
    required String title,

    /// 取引日時。
    @TimestampConverter() required DateTime transactionDate,

    /// 取引月 ("2026-08" 形式)。月次一覧のクエリ用フィールド。
    /// [transactionDate] のローカルタイムから [yearMonthFrom] で導出し、両者は常に一致させる。
    required String yearMonth,

    /// 集計の計算対象から除外するかどうか。重複明細の片方を残したまま
    /// 集計に含めない、などの用途 (documents/PROJECT.md の MVP スコープ)。
    required bool excludedFromAggregation,
    @ServerCreatedTimestamp() DateTime? serverCreatedDateTime,
    @ServerUpdatedTimestamp() DateTime? serverUpdatedDateTime,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  /// Firestore からの読み込み用コンバータ。
  static Transaction fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) => Transaction.fromJson(snapshot.data()!..['id'] = snapshot.id);

  /// Firestore への書き込み用コンバータ。
  static Map<String, dynamic> toFirestore(
    Transaction transaction,
    SetOptions? options,
  ) => transaction.toJson();
}

/// Transaction の Firestore フィールド名。クエリ・インデックス定義
/// (firebase/firestore.indexes.json) と一致させる。
abstract class TransactionFirestoreKeys {
  static const String yearMonth = 'yearMonth';
  static const String type = 'type';
  static const String transactionDate = 'transactionDate';
  static const String excludedFromAggregation = 'excludedFromAggregation';
}

/// 指定日時をローカルタイム基準の "yyyy-MM" 形式へ変換する。
///
/// UTC ではなくローカルタイム基準にするのは、家計簿ではユーザーの生活時間で
/// 月を区切るのが自然なため (例: JST 2026-09-01 08:00 の買い物は UTC では
/// 2026-08-31 23:00 だが、9月の明細として扱う)。
String yearMonthFrom({required DateTime dateTime}) {
  final local = dateTime.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}';
}

/// 指定種別の明細の合計金額を返す。計算対象外 (excludedFromAggregation) の明細は含めない。
int totalAmount({
  required List<Transaction> transactions,
  required TransactionType type,
}) => transactions
    .where(
      (transaction) =>
          !transaction.excludedFromAggregation && transaction.type == type,
    )
    .fold(0, (total, transaction) => total + transaction.amount);

/// 指定種別の明細のカテゴリ別合計金額を、金額の大きい順で返す。
/// 計算対象外 (excludedFromAggregation) の明細は含めない。
Map<TransactionCategory, int> categoryTotals({
  required List<Transaction> transactions,
  required TransactionType type,
}) {
  final totals = <TransactionCategory, int>{};
  for (final transaction in transactions) {
    if (transaction.excludedFromAggregation || transaction.type != type) {
      continue;
    }
    totals[transaction.category] =
        (totals[transaction.category] ?? 0) + transaction.amount;
  }
  return Map.fromEntries(
    totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );
}
