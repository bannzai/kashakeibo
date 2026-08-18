// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction.g.dart';

/// `/users/{userID}/transactions` への参照 (Entity コンバータ適用済み)。
CollectionReference<Transaction> transactionsReference({
  required String userID,
}) => FirebaseFirestore.instance
    .collection('users')
    .doc(userID)
    .collection('transactions')
    .withConverter(
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

/// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
///
/// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
@riverpod
List<DuplicateCandidate> monthlyDuplicateCandidates(
  Ref ref, {
  required String yearMonth,
}) {
  final monthStart = DateTime.parse('$yearMonth-01');
  final transactions = <Transaction>[];
  for (final monthOffset in const [-1, 0, 1]) {
    final queryMonth = DateTime(
      monthStart.year,
      monthStart.month + monthOffset,
    );
    transactions.addAll(
      ref
              .watch(
                monthlyTransactionsProvider(
                  yearMonth: yearMonthFrom(dateTime: queryMonth),
                ),
              )
              .value ??
          const [],
    );
  }

  return duplicateCandidates(transactions: transactions)
      .where(
        (candidate) =>
            candidate.primaryTransaction.yearMonth == yearMonth ||
            candidate.duplicateTransaction.yearMonth == yearMonth,
      )
      .toList();
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

/// 重複候補 2 件を 1 件へ統合する機能 Provider。
@riverpod
MergeDuplicateTransactions mergeDuplicateTransactions(Ref ref) =>
    const MergeDuplicateTransactions();

/// 重複候補 2 件を Firestore トランザクションで 1 件へ統合する。
class MergeDuplicateTransactions {
  const MergeDuplicateTransactions();

  /// [primaryTransaction] を残し、[duplicateTransaction] を削除する。
  ///
  /// 同じ操作が再実行され、削除対象が存在しない場合は成功済みとして終了するため冪等。
  /// 逆向きのマージや「別物として残す」が別端末から同時実行された場合も、
  /// Firestore の競合検知後に最新状態で再試行され、両方を削除しない。
  Future<void> call({
    required Transaction primaryTransaction,
    required Transaction duplicateTransaction,
  }) async {
    _validateDifferentTransactions(
      firstTransaction: primaryTransaction,
      secondTransaction: duplicateTransaction,
    );
    final primaryReference = transactionsReference(
      userID: primaryTransaction.userID,
    ).doc(primaryTransaction.id);
    final duplicateReference = transactionsReference(
      userID: duplicateTransaction.userID,
    ).doc(duplicateTransaction.id);

    await FirebaseFirestore.instance.runTransaction((
      firestoreTransaction,
    ) async {
      final primarySnapshot = await firestoreTransaction.get(primaryReference);
      final duplicateSnapshot = await firestoreTransaction.get(
        duplicateReference,
      );
      final latestPrimaryTransaction = primarySnapshot.data();
      final latestDuplicateTransaction = duplicateSnapshot.data();

      // 同じ向きの再実行、または逆向きのマージが先に完了した状態。
      if (latestPrimaryTransaction == null ||
          latestDuplicateTransaction == null) {
        return;
      }
      if (!isDuplicateCandidate(
        firstTransaction: latestPrimaryTransaction,
        secondTransaction: latestDuplicateTransaction,
      )) {
        throw StateError('明細が更新されたため、重複候補ではなくなりました');
      }

      final confirmedDistinctTransactionIDs =
          <String>{
              ...latestPrimaryTransaction.confirmedDistinctTransactionIDs,
              ...latestDuplicateTransaction.confirmedDistinctTransactionIDs,
            }
            ..remove(latestPrimaryTransaction.id)
            ..remove(latestDuplicateTransaction.id);
      firestoreTransaction.set(
        primaryReference,
        latestPrimaryTransaction.copyWith(
          confirmedDistinctTransactionIDs:
              confirmedDistinctTransactionIDs.toList()..sort(),
        ),
        SetOptions(merge: true),
      );
      firestoreTransaction.delete(duplicateReference);
    });
  }
}

/// 重複候補 2 件を別々の明細として残す機能 Provider。
@riverpod
KeepBothTransactions keepBothTransactions(Ref ref) =>
    const KeepBothTransactions();

/// 重複候補 2 件へ相互の ID を記録し、同じ候補を再提示しないようにする。
class KeepBothTransactions {
  const KeepBothTransactions();

  /// 2 件を「別物として残す」と Firestore トランザクションで確定する。
  ///
  /// 相互の ID が既に記録されていれば書き込まず終了するため冪等。
  Future<void> call({
    required Transaction firstTransaction,
    required Transaction secondTransaction,
  }) async {
    _validateDifferentTransactions(
      firstTransaction: firstTransaction,
      secondTransaction: secondTransaction,
    );
    final firstReference = transactionsReference(
      userID: firstTransaction.userID,
    ).doc(firstTransaction.id);
    final secondReference = transactionsReference(
      userID: secondTransaction.userID,
    ).doc(secondTransaction.id);

    await FirebaseFirestore.instance.runTransaction((
      firestoreTransaction,
    ) async {
      final firstSnapshot = await firestoreTransaction.get(firstReference);
      final secondSnapshot = await firestoreTransaction.get(secondReference);
      final latestFirstTransaction = firstSnapshot.data();
      final latestSecondTransaction = secondSnapshot.data();

      // マージが先に完了した場合は、残った 1 件をそのまま正とする。
      if (latestFirstTransaction == null || latestSecondTransaction == null) {
        return;
      }
      final firstAlreadyConfirmed = latestFirstTransaction
          .confirmedDistinctTransactionIDs
          .contains(latestSecondTransaction.id);
      final secondAlreadyConfirmed = latestSecondTransaction
          .confirmedDistinctTransactionIDs
          .contains(latestFirstTransaction.id);
      if (firstAlreadyConfirmed && secondAlreadyConfirmed) {
        return;
      }
      if (!isDuplicateCandidate(
        firstTransaction: latestFirstTransaction,
        secondTransaction: latestSecondTransaction,
      )) {
        throw StateError('明細が更新されたため、重複候補ではなくなりました');
      }

      firestoreTransaction.set(
        firstReference,
        latestFirstTransaction.copyWith(
          confirmedDistinctTransactionIDs: <String>{
            ...latestFirstTransaction.confirmedDistinctTransactionIDs,
            latestSecondTransaction.id,
          }.toList()..sort(),
        ),
        SetOptions(merge: true),
      );
      firestoreTransaction.set(
        secondReference,
        latestSecondTransaction.copyWith(
          confirmedDistinctTransactionIDs: <String>{
            ...latestSecondTransaction.confirmedDistinctTransactionIDs,
            latestFirstTransaction.id,
          }.toList()..sort(),
        ),
        SetOptions(merge: true),
      );
    });
  }
}

void _validateDifferentTransactions({
  required Transaction firstTransaction,
  required Transaction secondTransaction,
}) {
  if (firstTransaction.id == secondTransaction.id) {
    throw ArgumentError('同じ明細同士は重複候補として操作できません');
  }
  if (firstTransaction.userID != secondTransaction.userID) {
    throw ArgumentError('異なるユーザーの明細同士は操作できません');
  }
}
