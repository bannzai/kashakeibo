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
  source: TransactionSource.manual,
  amount: amount,
  category: category,
  title: 'タイトル',
  transactionDate: DateTime(2026, 8, 16, 12),
  transactionDateTimeZoneOffsetMinutes: null,
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
        'source': 'manual',
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
      expect(transaction.source, TransactionSource.manual);
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
        'source': 'manual',
        'amount': 1200,
        'category': 'newCategoryAddedInFuture',
        'title': 'タイトル',
        'transactionDate': Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
        'yearMonth': '2026-08',
        'excludedFromAggregation': false,
      });
      expect(transaction.category, TransactionCategory.other);
    });

    test('出所が無い旧データは unknown として読む', () {
      final transaction = Transaction.fromJson({
        'id': 'transaction-id',
        'userID': 'user-id',
        'type': 'expense',
        'amount': 1200,
        'category': 'food',
        'title': 'タイトル',
        'transactionDate': Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
        'yearMonth': '2026-08',
        'excludedFromAggregation': false,
      });
      expect(transaction.source, TransactionSource.unknown);
    });
  });

  group('transactionLocalDate', () {
    test('登録時のオフセット基準の日時を返し、端末タイムゾーンに依存しない', () {
      // JST (UTC+9, 540分) の 2026-09-01 08:30 に登録された取引。
      // UTC では 2026-08-31 23:30 だが、表示は登録時のカレンダー日 9/1 になる。
      final transaction =
          buildTransaction(
            type: TransactionType.expense,
            amount: 1200,
            category: TransactionCategory.food,
            excludedFromAggregation: false,
          ).copyWith(
            transactionDate: DateTime.utc(2026, 8, 31, 23, 30),
            transactionDateTimeZoneOffsetMinutes: 540,
            yearMonth: '2026-09',
          );
      expect(transaction.transactionLocalDate.year, 2026);
      expect(transaction.transactionLocalDate.month, 9);
      expect(transaction.transactionLocalDate.day, 1);
      expect(transaction.transactionLocalDate.hour, 8);
      expect(transaction.transactionLocalDate.minute, 30);
    });

    test('オフセット未保存の旧データは端末ローカルで表示する (従来挙動)', () {
      final transaction = buildTransaction(
        type: TransactionType.expense,
        amount: 1200,
        category: TransactionCategory.food,
        excludedFromAggregation: false,
      );
      expect(
        transaction.transactionLocalDate,
        transaction.transactionDate.toLocal(),
      );
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
      expect(json['source'], 'manual');
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
        category: TransactionCategory.subscription,
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
          category: TransactionCategory.eatingOut,
          excludedFromAggregation: false,
        ),
        buildTransaction(
          type: TransactionType.expense,
          amount: 100000,
          category: TransactionCategory.subscription,
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
        TransactionCategory.eatingOut,
        TransactionCategory.food,
      ]);
      expect(totals[TransactionCategory.eatingOut], 9800);
      expect(totals[TransactionCategory.food], 4200);
    });
  });
}
