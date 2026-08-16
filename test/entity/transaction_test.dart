import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/transaction.dart';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required TransactionType type,
  required int amount,
  required TransactionCategory category,
  required bool excludedFromAggregation,
}) => Transaction(
  id: 'transaction-id',
  userID: 'user-id',
  type: type,
  amount: amount,
  category: category,
  title: 'タイトル',
  transactionDate: DateTime(2026, 8, 16, 12),
  yearMonth: '2026-08',
  excludedFromAggregation: excludedFromAggregation,
);

void main() {
  group('yearMonthFrom', () {
    test('月は 2 桁ゼロ埋めで yyyy-MM 形式になる', () {
      expect(yearMonthFrom(dateTime: DateTime(2026, 8, 5)), '2026-08');
      expect(yearMonthFrom(dateTime: DateTime(2026, 12, 31)), '2026-12');
      expect(yearMonthFrom(dateTime: DateTime(2027, 1, 1)), '2027-01');
    });
  });

  group('Transaction.fromJson', () {
    test('Firestore のフィールドから復元できる', () {
      final transaction = Transaction.fromJson({
        'id': 'transaction-id',
        'userID': 'user-id',
        'type': 'expense',
        'amount': 1200,
        'category': 'food',
        'title': 'スーパーマーケット',
        'transactionDate': Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
        'yearMonth': '2026-08',
        'excludedFromAggregation': false,
        'serverCreatedDateTime': null,
        'serverUpdatedDateTime': null,
      });
      expect(transaction.type, TransactionType.expense);
      expect(transaction.amount, 1200);
      expect(transaction.category, TransactionCategory.food);
      expect(transaction.transactionDate, DateTime(2026, 8, 16, 12));
      expect(transaction.yearMonth, '2026-08');
      expect(transaction.excludedFromAggregation, false);
    });

    test('未知のカテゴリは other として読む (旧クライアントの後方互換)', () {
      final transaction = Transaction.fromJson({
        'id': 'transaction-id',
        'userID': 'user-id',
        'type': 'expense',
        'amount': 1200,
        'category': 'newCategoryAddedInFuture',
        'title': 'タイトル',
        'transactionDate': Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
        'yearMonth': '2026-08',
        'excludedFromAggregation': false,
      });
      expect(transaction.category, TransactionCategory.other);
    });
  });

  group('Transaction.toJson', () {
    test('enum は名前の文字列、日時は Timestamp で書き込まれる', () {
      final json = buildTransaction(
        type: TransactionType.income,
        amount: 280000,
        category: TransactionCategory.salary,
        excludedFromAggregation: false,
      ).toJson();
      expect(json['type'], 'income');
      expect(json['category'], 'salary');
      expect(
        json['transactionDate'],
        Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
      );
      expect(json['yearMonth'], '2026-08');
      // サーバータイムスタンプは書き込みのたびに FieldValue で付与される
      // (.claude/rules/firestore-timestamp-rules.md)。
      expect(json['serverCreatedDateTime'], isA<FieldValue>());
      expect(json['serverUpdatedDateTime'], isA<FieldValue>());
    });
  });

  group('totalAmount', () {
    final transactions = [
      buildTransaction(
        type: TransactionType.income,
        amount: 280000,
        category: TransactionCategory.salary,
        excludedFromAggregation: false,
      ),
      buildTransaction(
        type: TransactionType.expense,
        amount: 1200,
        category: TransactionCategory.food,
        excludedFromAggregation: false,
      ),
      buildTransaction(
        type: TransactionType.expense,
        amount: 800,
        category: TransactionCategory.dailyGoods,
        excludedFromAggregation: false,
      ),
      buildTransaction(
        type: TransactionType.expense,
        amount: 5000,
        category: TransactionCategory.entertainment,
        excludedFromAggregation: true,
      ),
    ];

    test('種別ごとに合計し、計算対象外の明細は含めない', () {
      expect(
        totalAmount(transactions: transactions, type: TransactionType.income),
        280000,
      );
      expect(
        totalAmount(transactions: transactions, type: TransactionType.expense),
        2000,
      );
    });
  });

  group('categoryTotals', () {
    test('カテゴリ別に合計し、金額の大きい順で返す。計算対象外は含めない', () {
      final transactions = [
        buildTransaction(
          type: TransactionType.expense,
          amount: 1200,
          category: TransactionCategory.food,
          excludedFromAggregation: false,
        ),
        buildTransaction(
          type: TransactionType.expense,
          amount: 3000,
          category: TransactionCategory.food,
          excludedFromAggregation: false,
        ),
        buildTransaction(
          type: TransactionType.expense,
          amount: 9800,
          category: TransactionCategory.housing,
          excludedFromAggregation: false,
        ),
        buildTransaction(
          type: TransactionType.expense,
          amount: 100000,
          category: TransactionCategory.entertainment,
          excludedFromAggregation: true,
        ),
        buildTransaction(
          type: TransactionType.income,
          amount: 280000,
          category: TransactionCategory.salary,
          excludedFromAggregation: false,
        ),
      ];
      final totals = categoryTotals(
        transactions: transactions,
        type: TransactionType.expense,
      );
      expect(totals.keys.toList(), [
        TransactionCategory.housing,
        TransactionCategory.food,
      ]);
      expect(totals[TransactionCategory.housing], 9800);
      expect(totals[TransactionCategory.food], 4200);
    });
  });
}
