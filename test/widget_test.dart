import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/manual_entry/manual_entry_sheet.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/transaction.dart';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required String id,
  required TransactionType type,
  required int amount,
  required TransactionCategory category,
  required String title,
  required bool excludedFromAggregation,
}) {
  // MonthlyPage は現在月を初期表示するため、現在月の明細としてデータを作る。
  final now = DateTime.now();
  return Transaction(
    id: id,
    userID: 'user-id',
    type: type,
    source: TransactionSource.manual,
    amount: amount,
    category: category,
    title: title,
    transactionDate: DateTime(now.year, now.month, 1, 12),
    transactionDateTimeZoneOffsetMinutes: DateTime(
      now.year,
      now.month,
      1,
      12,
    ).timeZoneOffset.inMinutes,
    yearMonth: yearMonthFrom(dateTime: now),
    excludedFromAggregation: excludedFromAggregation,
  );
}

void main() {
  testWidgets('月次一覧: サマリー・カテゴリ内訳・明細リストがクライアント集計で表示される', (tester) async {
    final transactions = [
      buildTransaction(
        id: 'income-1',
        type: TransactionType.income,
        amount: 280000,
        category: TransactionCategory.salary,
        title: '給与',
        excludedFromAggregation: false,
      ),
      buildTransaction(
        id: 'expense-1',
        type: TransactionType.expense,
        amount: 1200,
        category: TransactionCategory.food,
        title: 'スーパーマーケット',
        excludedFromAggregation: false,
      ),
      buildTransaction(
        id: 'expense-2',
        type: TransactionType.expense,
        amount: 5000,
        category: TransactionCategory.eatingOut,
        title: '計算対象外の明細',
        excludedFromAggregation: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(transactions)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(),
        ),
      ),
    );
    // Stream の初回イベントが AsyncValue.data に反映されるまで進める。
    await tester.pumpAndSettle();

    // サマリー: 収入 280,000 / 支出 1,200 (計算対象外の 5,000 は含めない) / 残り 278,800
    expect(find.text('¥280,000'), findsOneWidget);
    expect(find.text('¥278,800'), findsOneWidget);
    expect(find.text('¥1,200'), findsWidgets);

    // 明細リスト: 3 件の明細が表示され、行の金額は +/- 付き。
    // 計算対象外の明細にはサブ行に注記が付く
    expect(find.text('給与'), findsOneWidget);
    expect(find.text('+¥280,000'), findsOneWidget);
    expect(find.text('スーパーマーケット'), findsOneWidget);
    expect(find.text('-¥1,200'), findsOneWidget);
    expect(find.text('計算対象外の明細'), findsOneWidget);
    expect(
      find.textContaining(AppLocalizationsEn().excludedFromAggregation),
      findsWidgets,
    );
  });

  testWidgets('月次一覧: 明細が無い月は空メッセージを表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().monthlyTransactionsEmpty),
      findsOneWidget,
    );
  });

  testWidgets('手動入力: 必須項目を登録すると出所 manual で保存する', (tester) async {
    final addTransaction = _RecordingAddTransaction();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [addTransactionProvider.overrideWithValue(addTransaction)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ManualEntrySheet()),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '1280',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store or note'),
      'Neighborhood store',
    );
    await tester.tap(find.text('Food'));
    await tester.ensureVisible(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();

    expect(addTransaction.type, TransactionType.expense);
    expect(addTransaction.source, TransactionSource.manual);
    expect(addTransaction.amount, 1280);
    expect(addTransaction.category, TransactionCategory.food);
    expect(addTransaction.title, 'Neighborhood store');
    expect(addTransaction.transactionDate, DateUtils.dateOnly(DateTime.now()));
    expect(addTransaction.excludedFromAggregation, false);
  });
}

/// 手動入力 Widget テストで登録内容を記録する AddTransaction。
class _RecordingAddTransaction extends AddTransaction {
  _RecordingAddTransaction() : super(userID: 'user-id');

  /// 登録された収支種別。
  TransactionType? type;

  /// 登録された出所。
  TransactionSource? source;

  /// 登録された金額。
  int? amount;

  /// 登録されたカテゴリ。
  TransactionCategory? category;

  /// 登録された店名・メモ。
  String? title;

  /// 登録された取引日。
  DateTime? transactionDate;

  /// 登録された集計除外フラグ。
  bool? excludedFromAggregation;

  /// Firestore へ書き込まず、手動入力画面から渡された値を記録する。
  @override
  Future<void> call({
    required TransactionType type,
    required TransactionSource source,
    required int amount,
    required TransactionCategory category,
    required String title,
    required DateTime transactionDate,
    required bool excludedFromAggregation,
  }) async {
    this.type = type;
    this.source = source;
    this.amount = amount;
    this.category = category;
    this.title = title;
    this.transactionDate = transactionDate;
    this.excludedFromAggregation = excludedFromAggregation;
  }
}
