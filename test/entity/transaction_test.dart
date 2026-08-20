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
  sourceImageObjectKey: null,
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
      expect(transaction.confirmedDistinctTransactionIDs, isEmpty);
      // 元画像・出所記録のフィールドが無い旧データは、画像なし・未修正として読む
      expect(transaction.sourceImageObjectKey, isNull);
      expect(transaction.analysisAdjustedByUser, false);
    });

    test('元画像のオブジェクトキーと AI 解析結果の修正有無を復元できる', () {
      final transaction = Transaction.fromJson({
        'id': 'transaction-id',
        'userID': 'user-id',
        'type': 'expense',
        'source': 'receipt',
        'amount': 872,
        'category': 'food',
        'title': 'コンビニ',
        'transactionDate': Timestamp.fromDate(DateTime(2026, 8, 16, 12)),
        'yearMonth': '2026-08',
        'excludedFromAggregation': false,
        'sourceImageObjectKey': 'users/user-id/image-id.jpg',
        'analysisAdjustedByUser': true,
      });
      expect(transaction.sourceImageObjectKey, 'users/user-id/image-id.jpg');
      expect(transaction.analysisAdjustedByUser, true);
      expect(
        transaction.toJson()['sourceImageObjectKey'],
        'users/user-id/image-id.jpg',
      );
      expect(transaction.toJson()['analysisAdjustedByUser'], true);
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
      expect(json['confirmedDistinctTransactionIDs'], isEmpty);
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

  group('duplicateCandidates', () {
    final receiptTransaction =
        buildTransaction(
          type: TransactionType.expense,
          amount: 4230,
          category: TransactionCategory.eatingOut,
          excludedFromAggregation: false,
        ).copyWith(
          id: 'receipt-transaction',
          title: '鳥貴族 三軒茶屋店',
          transactionDate: DateTime(2026, 8, 10, 12),
        );
    final cardTransaction =
        buildTransaction(
          type: TransactionType.expense,
          amount: 4230,
          category: TransactionCategory.eatingOut,
          excludedFromAggregation: false,
        ).copyWith(
          id: 'card-transaction',
          title: '鳥貴族　三軒茶屋店',
          transactionDate: DateTime(2026, 8, 13, 12),
        );

    test('金額が同じ・取引日が前後3日以内・正規化した店名が一致する支出を検出する', () {
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction,
        ),
        isTrue,
      );
      final candidates = duplicateCandidates(
        transactions: [receiptTransaction, cardTransaction],
      );
      expect(candidates, hasLength(1));
      expect(candidates.single.primaryTransaction.id, 'receipt-transaction');
      expect(candidates.single.duplicateTransaction.id, 'card-transaction');
    });

    test('金額・日付・店名のいずれかが基準外なら検出しない', () {
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction.copyWith(amount: 4229),
        ),
        isFalse,
      );
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction.copyWith(
            transactionDate: DateTime(2026, 8, 14, 12),
          ),
        ),
        isFalse,
      );
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction.copyWith(title: '別の店舗'),
        ),
        isFalse,
      );
    });

    test('計算対象外・収入・別物として確定済みの組み合わせは検出しない', () {
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction.copyWith(
            excludedFromAggregation: true,
          ),
        ),
        isFalse,
      );
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction,
          secondTransaction: cardTransaction.copyWith(
            type: TransactionType.income,
          ),
        ),
        isFalse,
      );
      expect(
        isDuplicateCandidate(
          firstTransaction: receiptTransaction.copyWith(
            confirmedDistinctTransactionIDs: ['card-transaction'],
          ),
          secondTransaction: cardTransaction,
        ),
        isFalse,
      );
    });
  });
}
