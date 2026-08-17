// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction.g.dart';

/// `/users/{userID}/transactions` への未変換の参照。
CollectionReference<Map<String, dynamic>> transactionDocumentsReference({
  required String userID,
  FirebaseFirestore? firebaseFirestore,
}) => (firebaseFirestore ?? FirebaseFirestore.instance)
    .collection('users')
    .doc(userID)
    .collection('transactions');

/// `/users/{userID}/transactions` への参照 (Entity コンバータ適用済み)。
CollectionReference<Transaction> transactionsReference({
  required String userID,
}) => transactionDocumentsReference(userID: userID).withConverter(
  fromFirestore: Transaction.fromFirestore,
  toFirestore: Transaction.toFirestore,
);

/// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
///
/// snapshot listener なので編集・追加はリアルタイムに反映され、
/// Firestore のオフラインキャッシュがあればオフラインでも動作する。
@riverpod
Stream<List<Transaction>> monthlyTransactions(
  Ref ref, {
  required String yearMonth,
}) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    return Stream.value(const []);
  }
  return transactionsReference(userID: userID)
      .where(TransactionFirestoreKeys.yearMonth, isEqualTo: yearMonth)
      .orderBy(TransactionFirestoreKeys.transactionDate, descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}

/// 明細を新規作成する機能 Provider。
@riverpod
AddTransaction addTransaction(Ref ref) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    // サインイン完了 (SignInResolver) 後の画面からのみ利用される前提。
    throw StateError('サインイン前に AddTransaction は利用できない');
  }
  return AddTransaction(userID: userID);
}

/// 明細の新規作成 (`.claude/rules/coding-conventions.md` の call クラス)。
class AddTransaction {
  /// 明細の所有ユーザー ID。
  final String userID;

  AddTransaction({required this.userID});

  /// 明細を 1 件作成する。
  ///
  /// 冪等ではない: 明細の追加はユーザー操作 1 回 = 1 件の意味を持ち、
  /// Firestore の自動生成 ID で毎回新しいドキュメントを作るため。
  ///
  /// yearMonth はここで [transactionDate] から導出し、呼び出し側に渡させない。
  /// 両フィールドの食い違いを構造的に防ぐため。
  Future<void> call({
    required TransactionType type,
    required int amount,
    required TransactionCategory category,
    required String title,
    required DateTime transactionDate,
    required bool excludedFromAggregation,
  }) async {
    final documentReference = transactionsReference(userID: userID).doc();
    await documentReference.set(
      Transaction(
        id: documentReference.id,
        userID: userID,
        type: type,
        amount: amount,
        category: category,
        title: title,
        transactionDate: transactionDate,
        // yearMonth の導出 (ローカルタイム基準) と後からの表示・グループ化を
        // 同じカレンダー日に揃えるため、登録時のオフセットを保存する。
        transactionDateTimeZoneOffsetMinutes: transactionDate
            .toLocal()
            .timeZoneOffset
            .inMinutes,
        yearMonth: yearMonthFrom(dateTime: transactionDate),
        excludedFromAggregation: excludedFromAggregation,
      ),
    );
  }
}
