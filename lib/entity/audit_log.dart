import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kashakeibo/entity/timestamp.dart';

part 'audit_log.g.dart';
part 'audit_log.freezed.dart';

/// 監査ログが記録する操作の種別。
///
/// Firestore には enum 名の文字列で保存される。将来種別を追加した時に旧バージョンの
/// クライアントがデコードに失敗しないよう、欠損値と未知の値は
/// [AuditLogOperation.unknown] として読む (AuditLog.operation の unknownEnumValue)。
enum AuditLogOperation {
  /// 明細を新規作成した。
  transactionCreated,

  /// 明細の内容を訂正した。
  transactionUpdated,

  /// 明細を削除した。
  transactionDeleted,

  /// 明細の元画像 (R2) を削除した。
  transactionImageDeleted,

  /// 種別フィールド追加前のログ、または将来追加された未知の種別。
  unknown,
}

/// 明細と元画像に対する訂正・削除の履歴 1 件
/// (documents/adr/0003-denshi-choubo-hozon-hou-youken-jissou.md の訂正削除履歴)。
///
/// 「いつ・どの操作が・何に対して行われたか」を後から確認するための記録で、明細の
/// 現在の状態からは復元できない情報を持つ (削除された明細の店名・金額など)。
/// Firestore 上では `/users/{userID}/auditLogs/{id}` に保存される。
/// id は Firestore の自動生成 ID。アカウント削除時は明細と同様に全削除する
/// (lib/provider/account.dart)。
@freezed
abstract class AuditLog with _$AuditLog {
  const AuditLog._();

  @JsonSerializable(explicitToJson: true)
  const factory AuditLog({
    /// ドキュメント ID (Firestore の自動生成 ID)。
    required String id,

    /// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
    /// `.claude/rules/entity-parent-id-rules.md` 参照)。
    required String userID,

    /// 記録した操作の種別。
    @JsonKey(
      defaultValue: AuditLogOperation.unknown,
      unknownEnumValue: AuditLogOperation.unknown,
    )
    required AuditLogOperation operation,

    /// 操作の対象になった明細の ID。明細に紐づかない操作では null。
    required String? transactionID,

    /// 削除した元画像の R2 オブジェクトキー。画像を伴わない操作では null。
    required String? imageObjectKey,

    /// 操作時点の明細の表示名 (店名・摘要)。削除済みの明細を履歴だけで識別できるよう保持する。
    required String? transactionTitle,

    /// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
    required int? transactionAmount,

    /// 訂正で値が変わった Transaction のフィールド名
    /// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。
    /// 訂正以外の操作では空。フィールドが無い旧データも空として読む。
    @Default(<String>[]) List<String> changedFieldNames,

    /// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
    @ServerCreatedTimestamp() DateTime? serverCreatedDateTime,
  }) = _AuditLog;

  factory AuditLog.fromJson(Map<String, dynamic> json) =>
      _$AuditLogFromJson(json);

  /// Firestore からの読み込み用コンバータ。
  static AuditLog fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) => AuditLog.fromJson(snapshot.data()!..['id'] = snapshot.id);

  /// Firestore への書き込み用コンバータ。
  static Map<String, dynamic> toFirestore(
    AuditLog auditLog,
    SetOptions? options,
  ) => auditLog.toJson();
}

/// AuditLog の Firestore フィールド名。クエリ・インデックス定義
/// (firebase/firestore.indexes.json) と一致させる。
abstract class AuditLogFirestoreKeys {
  static const String serverCreatedDateTime = 'serverCreatedDateTime';
}
