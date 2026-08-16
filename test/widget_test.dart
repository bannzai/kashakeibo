import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
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
    amount: amount,
    category: category,
    title: title,
    transactionDate: DateTime(now.year, now.month, 1, 12),
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
}
