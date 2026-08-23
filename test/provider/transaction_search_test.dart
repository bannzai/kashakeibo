// 明細検索の絞り込みのテスト。
// Firestore への読み取りは FakeFirebaseFirestore に対して行い、取引日・金額の範囲
// (サーバー側の where) と店名の部分一致 (クライアント側の絞り込み) を検証する。
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/provider/transaction_search.dart';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required String id,
  required int amount,
  required String title,
  required DateTime transactionDate,
}) => Transaction(
  id: id,
  userID: 'user-id',
  type: TransactionType.expense,
  source: TransactionSource.manual,
  amount: amount,
  category: TransactionCategory.food,
  title: title,
  transactionDate: transactionDate,
  transactionDateTimeZoneOffsetMinutes: 540,
  yearMonth: yearMonthFrom(dateTime: transactionDate),
  excludedFromAggregation: false,
  sourceImageObjectKey: null,
);

/// 検索対象の明細一式を fake の Firestore に保存する。
Future<void> saveSearchedTransactions({
  required FakeFirebaseFirestore firebaseFirestore,
}) async {
  for (final transaction in [
    buildTransaction(
      id: 'supermarket',
      amount: 1280,
      title: 'スーパーマーケット中目黒店',
      transactionDate: DateTime(2026, 8, 10, 12),
    ),
    buildTransaction(
      id: 'convenience-store',
      amount: 480,
      title: 'コンビニ',
      transactionDate: DateTime(2026, 8, 20, 9),
    ),
    buildTransaction(
      id: 'electronics',
      amount: 32800,
      title: 'Yodobashi Camera',
      transactionDate: DateTime(2026, 9, 2, 18),
    ),
  ]) {
    await transactionsReference(
      userID: 'user-id',
      firebaseFirestore: firebaseFirestore,
    ).doc(transaction.id).set(transaction);
  }
}

/// 検索を 1 回実行し、一致した明細の ID を返す。
Future<List<String>> searchTransactionIDs({
  required FakeFirebaseFirestore firebaseFirestore,
  DateTime? transactionDateFrom,
  DateTime? transactionDateTo,
  int? minimumAmount,
  int? maximumAmount,
  String? titleKeyword,
}) async => (await searchTransactions(
  firebaseFirestore: firebaseFirestore,
  userID: 'user-id',
  transactionDateFrom: transactionDateFrom,
  transactionDateTo: transactionDateTo,
  minimumAmount: minimumAmount,
  maximumAmount: maximumAmount,
  titleKeyword: titleKeyword,
).first).map((transaction) => transaction.id).toList();

void main() {
  group('searchTransactions', () {
    test('取引日の範囲で絞り込み、取引日の新しい順で返す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          transactionDateFrom: DateTime(2026, 8, 1),
          transactionDateTo: DateTime(2026, 8, 31, 23, 59, 59, 999),
        ),
        ['convenience-store', 'supermarket'],
      );
    });

    test('金額の範囲で絞り込む', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          minimumAmount: 500,
          maximumAmount: 2000,
        ),
        ['supermarket'],
      );
      // 範囲の両端を含む。
      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          minimumAmount: 480,
          maximumAmount: 1280,
        ),
        ['convenience-store', 'supermarket'],
      );
    });

    test('店名は大文字小文字を無視した部分一致で絞り込む', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          titleKeyword: 'スーパー',
        ),
        ['supermarket'],
      );
      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          titleKeyword: 'yodobashi',
        ),
        ['electronics'],
      );
    });

    test('取引日・金額・店名を同時に指定すると全条件を満たす明細だけを返す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          transactionDateFrom: DateTime(2026, 8, 1),
          transactionDateTo: DateTime(2026, 8, 31, 23, 59, 59, 999),
          minimumAmount: 1000,
          titleKeyword: 'マーケット',
        ),
        ['supermarket'],
      );
      // 金額の条件だけを外れる明細は返さない。
      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          transactionDateFrom: DateTime(2026, 8, 1),
          minimumAmount: 100000,
        ),
        isEmpty,
      );
    });

    test('条件に一致する明細が無ければ空を返す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          titleKeyword: 'ドラッグストア',
        ),
        isEmpty,
      );
    });

    test('条件が未指定なら検索を実行せず空を返す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      await saveSearchedTransactions(firebaseFirestore: firebaseFirestore);

      expect(
        await searchTransactionIDs(firebaseFirestore: firebaseFirestore),
        isEmpty,
      );
      // 空白だけの店名も条件なしとして扱う。
      expect(
        await searchTransactionIDs(
          firebaseFirestore: firebaseFirestore,
          titleKeyword: '   ',
        ),
        isEmpty,
      );
    });
  });
}
