import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/capture/capture_image_picker.dart';
import 'package:kashakeibo/features/manual_entry/manual_entry_sheet.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:mocktail/mocktail.dart';

/// Analyticsを必要としないウィジェットテスト用の記録処理。
Future<void> discardAnalyticsEvent({
  required String name,
  Map<String, Object>? parameters,
}) async {}

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
    sourceImageObjectKey: null,
  );
}

/// テスト用 Firebase ユーザーモック。
class MockFirebaseUser extends Mock implements User {}

/// 何もしないアカウント削除機能。設定画面の表示テストで Firebase への接続を避ける。
class NoopDeleteAccount implements DeleteAccount {
  @override
  Future<void> call() async {}
}

/// 設定画面が依存する Firebase Auth の Provider を匿名ユーザー相当へ差し替える。
List<Override> anonymousUserOverrides() {
  final firebaseUser = MockFirebaseUser();
  when(() => firebaseUser.uid).thenReturn('user-id');
  when(() => firebaseUser.isAnonymous).thenReturn(true);
  when(() => firebaseUser.providerData).thenReturn(const []);
  return [
    firebaseUserChangesProvider.overrideWith(
      (ref) => Stream.value(firebaseUser),
    ),
    linkOrSignInWithAppleProvider.overrideWithValue(
      () async => AccountActionResult.linked,
    ),
    linkOrSignInWithGoogleProvider.overrideWithValue(
      () async => AccountActionResult.linked,
    ),
    hasCurrentUserDataProvider.overrideWithValue(() async => false),
    deleteAccountProvider.overrideWithValue(NoopDeleteAccount()),
  ];
}

/// スキャン残量チップ・ペイウォールが依存する課金 Provider を、無料プラン (今月 [monthlyScanCount] 回消費) に差し替える。
List<Override> freePlanOverrides({required int monthlyScanCount}) => [
  fetchScanQuotaProvider.overrideWithValue(
    () async =>
        ScanQuota(monthlyScanCount: monthlyScanCount, monthlyFreeScanLimit: 50),
  ),
  isPremiumProvider.overrideWithValue(false),
  premiumOfferingProvider.overrideWith((ref) async => null),
  purchasePremiumPackageProvider.overrideWithValue(
    ({required package}) async => false,
  ),
  restorePurchasesProvider.overrideWithValue(() async => false),
];

void main() {
  testWidgets('月次一覧: 残量チップに今月のスキャン残りを表示し、タップでペイウォールを開く', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(const [])),
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => const []),
          ...anonymousUserOverrides(),
          ...freePlanOverrides(monthlyScanCount: 43),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().capturesSection), findsOneWidget);
    expect(
      find.text(AppLocalizationsEn().scanQuotaRemaining(7)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppLocalizationsEn().scanQuotaRemaining(7)));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);
  });

  testWidgets('月次一覧: 無料枠を使い切っていると「カメラで撮影」はカメラを開かずペイウォールを開く', (tester) async {
    var cameraOpenCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(const [])),
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => const []),
          captureReceiptImageProvider.overrideWithValue(() async {
            cameraOpenCount++;
            return null;
          }),
          ...anonymousUserOverrides(),
          ...freePlanOverrides(monthlyScanCount: 50),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().scanQuotaRemaining(0)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppLocalizationsEn().addRecordOpen));
    await tester.pumpAndSettle();
    // 「記録する」シートの下部にも残量を出す
    expect(
      find.text(AppLocalizationsEn().scanQuotaRemaining(0)),
      findsNWidgets(2),
    );

    await tester.tap(find.text(AppLocalizationsEn().captureReceiptWithCamera));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);
    expect(cameraOpenCount, 0);
  });

  testWidgets('月次一覧: 無料プランは直近3ヶ月より前へ月送りするとペイウォールを開き、月は変わらない', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 当月から直近3ヶ月 (無料の範囲) ぶんの購読を空で差し替える
          for (var monthOffset = 0; monthOffset < 3; monthOffset++) ...[
            monthlyTransactionsProvider(
              yearMonth: yearMonthFrom(
                dateTime: DateTime(now.year, now.month - monthOffset),
              ),
            ).overrideWith((ref) => Stream.value(const [])),
            monthlyDuplicateCandidatesProvider(
              yearMonth: yearMonthFrom(
                dateTime: DateTime(now.year, now.month - monthOffset),
              ),
            ).overrideWith((ref) => const []),
          ],
          ...anonymousUserOverrides(),
          ...freePlanOverrides(monthlyScanCount: 0),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 当月 → 2ヶ月前までは無料で月送りできる
    await tester.tap(find.byTooltip(AppLocalizationsEn().previousMonth));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppLocalizationsEn().previousMonth));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsNothing);

    // 3ヶ月より前 (無料範囲外) への月送りはペイウォールになり、閉じると月は変わらない
    await tester.tap(find.byTooltip(AppLocalizationsEn().previousMonth));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);

    await tester.tap(
      find.byTooltip(const DefaultMaterialLocalizations().closeButtonTooltip),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsNothing);
    // 2ヶ月前の月ラベルのまま (英語表記の副題で判定)
    final twoMonthsAgo = DateTime(now.year, now.month - 2);
    expect(
      find.textContaining(
        DateFormat('MMMM yyyy', 'en_US').format(twoMonthsAgo).toUpperCase(),
      ),
      findsOneWidget,
    );
  });

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
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => const []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
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
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => const []),
          ...anonymousUserOverrides(),
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
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.only(bottom: 104),
    );

    await tester.tap(find.byTooltip(AppLocalizationsEn().openSettings));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings), findsOneWidget);
    expect(find.text(AppLocalizationsEn().termsOfService), findsOneWidget);
    expect(analyticsEvents, ['settings_open']);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings), findsNothing);
    expect(analyticsEvents, ['settings_open', 'settings_close']);
  });

  testWidgets('手動入力: 必須項目を登録すると出所 manual で保存する', (tester) async {
    final addTransaction = _RecordingAddTransaction();
    final analyticsEvents = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [addTransactionProvider.overrideWithValue(addTransaction)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ManualEntrySheet(
              logAnalyticsEvent: ({required name, parameters}) async {
                analyticsEvents.add(name);
              },
            ),
          ),
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
    expect(addTransaction.sourceImageObjectKey, isNull);
    expect(addTransaction.analysisAdjustedByUser, false);
    expect(analyticsEvents, ['manual_entry_register']);
  });

  testWidgets('手動入力: 金額だけで食費の現金支出として保存する', (tester) async {
    final addTransaction = _RecordingAddTransaction();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [addTransactionProvider.overrideWithValue(addTransaction)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ManualEntrySheet(logAnalyticsEvent: discardAnalyticsEvent),
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '500');
    await tester.ensureVisible(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pumpAndSettle();

    expect(addTransaction.category, TransactionCategory.food);
    expect(addTransaction.title, AppLocalizationsEn().manualEntryDefaultTitle);
  });

  testWidgets('手動入力: 登録処理中は戻る操作でシートを閉じない', (tester) async {
    final addTransaction = _PendingAddTransaction();
    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [addTransactionProvider.overrideWithValue(addTransaction)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showManualEntrySheet(
                    context: context,
                    logAnalyticsEvent: discardAnalyticsEvent,
                  );
                },
                child: const Text('Open manual entry'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open manual entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '500');
    await tester.ensureVisible(find.text('Add transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add transaction'));
    await tester.pump();

    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ManualEntrySheet), findsOneWidget);

    addTransaction.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ManualEntrySheet), findsNothing);
    expect(result, true);
  });

  testWidgets('手動入力: 閉じるボタン・背景タップのどちらでも manual_entry_cancel を1回だけ記録する', (
    tester,
  ) async {
    final analyticsEvents = <String>[];
    Future<void> pumpAndOpenSheet() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addTransactionProvider.overrideWithValue(
              _RecordingAddTransaction(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await showManualEntrySheet(
                      context: context,
                      logAnalyticsEvent: ({required name, parameters}) async {
                        analyticsEvents.add(name);
                      },
                    );
                  },
                  child: const Text('Open manual entry'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open manual entry'));
      await tester.pumpAndSettle();
    }

    await pumpAndOpenSheet();
    await tester.tap(
      find.byTooltip(const DefaultMaterialLocalizations().closeButtonTooltip),
    );
    await tester.pumpAndSettle();
    expect(analyticsEvents, ['manual_entry_cancel']);

    // 背景タップ (barrier) の dismiss でも同じく1回だけ記録されることを確認する。
    await pumpAndOpenSheet();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(analyticsEvents, ['manual_entry_cancel', 'manual_entry_cancel']);
  });

  testWidgets('設定画面: 3つの法務ドキュメントを開ける', (tester) async {
    final openedUris = <Uri>[];
    final analyticsEvents = <({String name, String document})>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: anonymousUserOverrides(),
        child: MaterialApp(
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
      ),
    );
    // Firebase ユーザーの Stream が流れてから設定画面本体が描画される。
    await tester.pumpAndSettle();

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

  testWidgets('月次一覧: 重複候補バナーから2件を比較する確認シートを開き、マージを記録する', (tester) async {
    final mergeDuplicateTransactions = _RecordingMergeDuplicateTransactions();
    final analyticsEvents =
        <({String name, Map<String, Object>? parameters})>[];
    final transactions = [
      buildTransaction(
        id: 'receipt-transaction',
        type: TransactionType.expense,
        amount: 4230,
        category: TransactionCategory.eatingOut,
        title: '鳥貴族 三軒茶屋店',
        excludedFromAggregation: false,
      ),
      buildTransaction(
        id: 'card-transaction',
        type: TransactionType.expense,
        amount: 4230,
        category: TransactionCategory.eatingOut,
        title: '鳥貴族　三軒茶屋店',
        excludedFromAggregation: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(transactions)),
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith(
            (ref) => duplicateCandidates(transactions: transactions),
          ),
          mergeDuplicateTransactionsProvider.overrideWithValue(
            mergeDuplicateTransactions,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(
            logAnalyticsEvent: ({required name, parameters}) async {
              analyticsEvents.add((name: name, parameters: parameters));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().duplicateCandidateCount(1)),
      findsOneWidget,
    );
    await tester.tap(
      find.text(AppLocalizationsEn().duplicateCandidateReviewHint),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().duplicateCandidateTitle),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().mergeDuplicateCandidate),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().keepBothDuplicateCandidates),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().duplicateCandidateKeep),
      findsOneWidget,
    );
    expect(
      analyticsEvents.map((event) => event.name),
      contains('duplicate_candidate_open'),
    );

    await tester.tap(find.text(AppLocalizationsEn().mergeDuplicateCandidate));
    await tester.pumpAndSettle();

    expect(
      mergeDuplicateTransactions.primaryTransaction?.id,
      'receipt-transaction',
    );
    expect(
      mergeDuplicateTransactions.duplicateTransaction?.id,
      'card-transaction',
    );
    expect(analyticsEvents.last.name, 'duplicate_merge');
    expect(analyticsEvents.last.parameters, {
      'primaryTransactionID': 'receipt-transaction',
      'duplicateTransactionID': 'card-transaction',
    });
  });

  testWidgets('月次一覧: 下側の候補を選んでマージすると残す側・削除する側が入れ替わる', (tester) async {
    final mergeDuplicateTransactions = _RecordingMergeDuplicateTransactions();
    final analyticsEvents =
        <({String name, Map<String, Object>? parameters})>[];
    final transactions = [
      buildTransaction(
        id: 'receipt-transaction',
        type: TransactionType.expense,
        amount: 4230,
        category: TransactionCategory.eatingOut,
        title: '鳥貴族 三軒茶屋店',
        excludedFromAggregation: false,
      ),
      buildTransaction(
        id: 'card-transaction',
        type: TransactionType.expense,
        amount: 4230,
        category: TransactionCategory.eatingOut,
        title: '鳥貴族　三軒茶屋店',
        excludedFromAggregation: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(transactions)),
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith(
            (ref) => duplicateCandidates(transactions: transactions),
          ),
          mergeDuplicateTransactionsProvider.overrideWithValue(
            mergeDuplicateTransactions,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(
            logAnalyticsEvent: ({required name, parameters}) async {
              analyticsEvents.add((name: name, parameters: parameters));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(AppLocalizationsEn().duplicateCandidateReviewHint),
    );
    await tester.pumpAndSettle();

    // 明細リストにも同じ店名が並ぶため、確認シート内のカードに絞ってタップする。
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('鳥貴族　三軒茶屋店'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().mergeDuplicateCandidate));
    await tester.pumpAndSettle();

    expect(
      mergeDuplicateTransactions.primaryTransaction?.id,
      'card-transaction',
    );
    expect(
      mergeDuplicateTransactions.duplicateTransaction?.id,
      'receipt-transaction',
    );
    expect(analyticsEvents.last.name, 'duplicate_merge');
    expect(analyticsEvents.last.parameters, {
      'primaryTransactionID': 'card-transaction',
      'duplicateTransactionID': 'receipt-transaction',
    });
  });

  testWidgets('月次一覧: 前月末と当月初の明細も重複候補として表示する', (tester) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    final nextMonth = DateTime(now.year, now.month + 1);
    final currentYearMonth = yearMonthFrom(dateTime: currentMonth);
    final previousYearMonth = yearMonthFrom(dateTime: previousMonth);
    final nextYearMonth = yearMonthFrom(dateTime: nextMonth);
    final previousMonthTransaction =
        buildTransaction(
          id: 'previous-month-transaction',
          type: TransactionType.expense,
          amount: 1200,
          category: TransactionCategory.food,
          title: 'スーパーマーケット',
          excludedFromAggregation: false,
        ).copyWith(
          transactionDate: DateTime(now.year, now.month, 0, 12),
          yearMonth: previousYearMonth,
        );
    final currentMonthTransaction =
        buildTransaction(
          id: 'current-month-transaction',
          type: TransactionType.expense,
          amount: 1200,
          category: TransactionCategory.food,
          title: 'スーパーマーケット',
          excludedFromAggregation: false,
        ).copyWith(
          transactionDate: DateTime(now.year, now.month, 1, 12),
          yearMonth: currentYearMonth,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: previousYearMonth,
          ).overrideWith((ref) => Stream.value([previousMonthTransaction])),
          monthlyTransactionsProvider(
            yearMonth: currentYearMonth,
          ).overrideWith((ref) => Stream.value([currentMonthTransaction])),
          monthlyTransactionsProvider(
            yearMonth: nextYearMonth,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().duplicateCandidateCount(1)),
      findsOneWidget,
    );
  });

  testWidgets('テーマ: ダークテーマでも月次一覧・設定画面が描画される', (tester) async {
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
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyTransactionsProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => Stream.value(transactions)),
          monthlyDuplicateCandidatesProvider(
            yearMonth: yearMonthFrom(dateTime: DateTime.now()),
          ).overrideWith((ref) => const []),
          ...anonymousUserOverrides(),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MonthlyPage(logAnalyticsEvent: discardAnalyticsEvent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final monthlyContext = tester.element(find.byType(MonthlyPage));
    expect(
      Theme.of(monthlyContext).extension<AppColorScheme>(),
      AppColorScheme.dark,
    );
    expect(
      Theme.of(monthlyContext).scaffoldBackgroundColor,
      AppColorScheme.dark.background,
    );

    await tester.tap(find.byTooltip(AppLocalizationsEn().openSettings));
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().settings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('テーマ: ライトテーマの ColorScheme と TextTheme にデザイントークンが載る', () {
    final theme = buildAppTheme(brightness: Brightness.light);

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.surface, AppColors.neutral100);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.textTheme.titleLarge!.fontSize, 19);
    expect(theme.textTheme.titleLarge!.fontWeight, FontWeight.w800);
    expect(theme.textTheme.titleLarge!.fontFamily, 'Figtree');
    expect(theme.extension<AppColorScheme>(), AppColorScheme.light);

    final darkTheme = buildAppTheme(brightness: Brightness.dark);

    expect(darkTheme.colorScheme.brightness, Brightness.dark);
    expect(darkTheme.scaffoldBackgroundColor, AppColors.onSurface);
    expect(darkTheme.extension<AppColorScheme>(), AppColorScheme.dark);
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

  /// 登録された元画像のオブジェクトキー。
  String? sourceImageObjectKey;

  /// 登録された AI 解析結果の修正有無。
  bool? analysisAdjustedByUser;

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
    required String? sourceImageObjectKey,
    required bool analysisAdjustedByUser,
  }) async {
    this.type = type;
    this.source = source;
    this.amount = amount;
    this.category = category;
    this.title = title;
    this.transactionDate = transactionDate;
    this.excludedFromAggregation = excludedFromAggregation;
    this.sourceImageObjectKey = sourceImageObjectKey;
    this.analysisAdjustedByUser = analysisAdjustedByUser;
  }
}

/// 完了タイミングをテスト側で制御する AddTransaction。
class _PendingAddTransaction extends _RecordingAddTransaction {
  final Completer<void> _completer = Completer<void>();

  /// 保留中の登録処理を完了する。
  void complete() => _completer.complete();

  @override
  Future<void> call({
    required TransactionType type,
    required TransactionSource source,
    required int amount,
    required TransactionCategory category,
    required String title,
    required DateTime transactionDate,
    required bool excludedFromAggregation,
    required String? sourceImageObjectKey,
    required bool analysisAdjustedByUser,
  }) {
    this.type = type;
    this.source = source;
    this.amount = amount;
    this.category = category;
    this.title = title;
    this.transactionDate = transactionDate;
    this.excludedFromAggregation = excludedFromAggregation;
    this.sourceImageObjectKey = sourceImageObjectKey;
    this.analysisAdjustedByUser = analysisAdjustedByUser;
    return _completer.future;
  }
}

/// Firestore へ書き込まず、マージに渡された 2 件を記録する MergeDuplicateTransactions。
class _RecordingMergeDuplicateTransactions extends MergeDuplicateTransactions {
  _RecordingMergeDuplicateTransactions()
    : super(deleteStoredImage: ({required imageObjectKey}) async {});

  /// マージ後に残す明細として渡された明細。
  Transaction? primaryTransaction;

  /// マージで削除する明細として渡された明細。
  Transaction? duplicateTransaction;

  @override
  Future<void> call({
    required Transaction primaryTransaction,
    required Transaction duplicateTransaction,
  }) async {
    this.primaryTransaction = primaryTransaction;
    this.duplicateTransaction = duplicateTransaction;
  }
}
