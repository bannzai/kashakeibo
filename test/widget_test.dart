import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
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
    final analyticsEvents = <String>[];
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(
            logAnalyticsEvent: ({required name, parameters}) async {
              analyticsEvents.add(name);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().monthlyTransactionsEmpty),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(AppLocalizationsEn().openSettings));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings), findsOneWidget);
    expect(find.text(AppLocalizationsEn().termsOfService), findsOneWidget);
    expect(analyticsEvents, ['settings_open']);
  });

  testWidgets('設定画面: 3つの法務ドキュメントを開ける', (tester) async {
    final openedUris = <Uri>[];
    final analyticsEvents = <({String name, String document})>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(
          openExternalUri: ({required uri}) async {
            openedUris.add(uri);
          },
          logAnalyticsEvent: ({required name, parameters}) async {
            analyticsEvents.add((
              name: name,
              document: parameters!['document']! as String,
            ));
          },
        ),
      ),
    );

    await tester.tap(find.text(AppLocalizationsEn().termsOfService));
    await tester.pump();
    await tester.tap(find.text(AppLocalizationsEn().privacyPolicy));
    await tester.pump();
    await tester.tap(
      find.text(AppLocalizationsEn().specifiedCommercialTransactionAct),
    );
    await tester.pump();

    expect(openedUris, [
      Uri.parse('https://bannzai.github.io/kashakeibo/Terms'),
      Uri.parse('https://bannzai.github.io/kashakeibo/PrivacyPolicy-en'),
      Uri.parse(
        'https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja',
      ),
    ]);
    expect(analyticsEvents, [
      (name: 'legal_document_open', document: 'terms'),
      (name: 'legal_document_open', document: 'privacy_policy'),
      (
        name: 'legal_document_open',
        document: 'specified_commercial_transaction_act',
      ),
    ]);
  });
}
