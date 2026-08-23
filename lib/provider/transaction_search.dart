// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_search.g.dart';

/// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
///
/// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
/// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
/// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
/// 月をまたいだ・課金状態が変わった時に再検索されない)。
/// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
@riverpod
Stream<List<Transaction>> searchedTransactions(
  Ref ref, {
  required DateTime? transactionDateFrom,
  required DateTime? transactionDateTo,
  required int? minimumAmount,
  required int? maximumAmount,
  required String? titleKeyword,
  required DateTime? oldestSearchableTransactionDate,
}) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    return Stream.value(const []);
  }
  return searchTransactions(
    firebaseFirestore: FirebaseFirestore.instance,
    userID: userID,
    transactionDateFrom: transactionDateFrom,
    transactionDateTo: transactionDateTo,
    minimumAmount: minimumAmount,
    maximumAmount: maximumAmount,
    titleKeyword: titleKeyword,
    oldestSearchableTransactionDate: oldestSearchableTransactionDate,
  );
}

/// 検索条件に一致する明細を取引日の新しい順で購読する。
///
/// 取引日 ([transactionDateFrom] / [transactionDateTo]) と金額
/// ([minimumAmount] / [maximumAmount]) はいずれも両端を含む範囲で、Firestore の
/// where で絞り込む。店名 ([titleKeyword]) は Firestore が部分一致検索を持たないため、
/// 取得した結果に対してクライアント側で大文字小文字を無視した部分一致で絞り込む。
///
/// [oldestSearchableTransactionDate] は無料プランで検索できる最古の取引日
/// (プレミアムは制限なしのため null)。非 null の場合は検索条件によらず必ず適用し、
/// [transactionDateFrom] がそれより古ければ下限の方を採用する。UI ガードだけで守る方針は
/// features/paywall/free_plan_history_limit.dart を参照。
///
/// 条件がすべて未指定の場合は、全明細の読み取りになるためクエリを発行せず空を返す。
Stream<List<Transaction>> searchTransactions({
  required FirebaseFirestore firebaseFirestore,
  required String userID,
  required DateTime? transactionDateFrom,
  required DateTime? transactionDateTo,
  required int? minimumAmount,
  required int? maximumAmount,
  required String? titleKeyword,
  required DateTime? oldestSearchableTransactionDate,
}) {
  final searchedTitleKeyword = titleKeyword?.trim().toLowerCase();
  if (transactionDateFrom == null &&
      transactionDateTo == null &&
      minimumAmount == null &&
      maximumAmount == null &&
      (searchedTitleKeyword == null || searchedTitleKeyword.isEmpty)) {
    return Stream.value(const []);
  }
  final searchedTransactionDateFrom =
      oldestSearchableTransactionDate != null &&
          (transactionDateFrom == null ||
              transactionDateFrom.isBefore(oldestSearchableTransactionDate))
      ? oldestSearchableTransactionDate
      : transactionDateFrom;

  Query<Transaction> query = transactionsReference(
    userID: userID,
    firebaseFirestore: firebaseFirestore,
  );
  if (searchedTransactionDateFrom != null) {
    query = query.where(
      TransactionFirestoreKeys.transactionDate,
      isGreaterThanOrEqualTo: Timestamp.fromDate(searchedTransactionDateFrom),
    );
  }
  if (transactionDateTo != null) {
    query = query.where(
      TransactionFirestoreKeys.transactionDate,
      isLessThanOrEqualTo: Timestamp.fromDate(transactionDateTo),
    );
  }
  if (minimumAmount != null) {
    query = query.where(
      TransactionFirestoreKeys.amount,
      isGreaterThanOrEqualTo: minimumAmount,
    );
  }
  if (maximumAmount != null) {
    query = query.where(
      TransactionFirestoreKeys.amount,
      isLessThanOrEqualTo: maximumAmount,
    );
  }
  // 範囲フィルタを掛けたフィールドは orderBy に含める必要があり、Firestore は
  // orderBy の並びと同じフィールド順の複合インデックスでクエリを解決する
  // (firebase/firestore.indexes.json の amount ASC + transactionDate DESC)。
  // そのため金額の範囲を指定した時は amount → transactionDate の順で並べ、
  // 表示順 (取引日の新しい順) は取得後にクライアント側で整える。
  final orderedQuery = minimumAmount != null || maximumAmount != null
      ? query
            .orderBy(TransactionFirestoreKeys.amount)
            .orderBy(TransactionFirestoreKeys.transactionDate, descending: true)
      : query.orderBy(
          TransactionFirestoreKeys.transactionDate,
          descending: true,
        );

  return orderedQuery.snapshots().map(
    (snapshot) =>
        snapshot.docs
            .map((doc) => doc.data())
            .where(
              (transaction) =>
                  searchedTitleKeyword == null ||
                  searchedTitleKeyword.isEmpty ||
                  transaction.title.toLowerCase().contains(
                    searchedTitleKeyword,
                  ),
            )
            .toList()
          ..sort(
            (firstTransaction, secondTransaction) => secondTransaction
                .transactionDate
                .compareTo(firstTransaction.transactionDate),
          ),
  );
}
