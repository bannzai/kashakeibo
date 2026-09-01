import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/onboarding/onboarding_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/app_theme.dart';

Future<void> pumpOnboardingResolver(
  WidgetTester tester, {
  required Future<bool> Function() loadOnboardingCompletion,
  required Future<void> Function() saveOnboardingCompletion,
  required Future<void> Function({required BuildContext context})
  openOnboardingPaywall,
  required Future<void> Function({
    required String name,
    Map<String, Object>? parameters,
  })
  logAnalyticsEvent,
  required Locale locale,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: buildAppTheme(brightness: Brightness.light),
    home: OnboardingResolver(
      logAnalyticsEvent: logAnalyticsEvent,
      loadOnboardingCompletion: loadOnboardingCompletion,
      saveOnboardingCompletion: saveOnboardingCompletion,
      openOnboardingPaywall: openOnboardingPaywall,
      child: const Scaffold(body: Text('月次画面')),
    ),
  ),
);

Future<void> tapVisibleText(WidgetTester tester, {required String text}) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> completeJapaneseOnboarding(WidgetTester tester) async {
  await tapVisibleText(tester, text: '次へ');
  await tapVisibleText(tester, text: '毎回の入力が面倒で続かない');
  await tapVisibleText(tester, text: '次へ');
  await tapVisibleText(tester, text: 'レシートもWeb明細も両方');
  await tapVisibleText(tester, text: '次へ');
  await tapVisibleText(tester, text: '家計簿にかける時間を減らしたい');
  await tapVisibleText(tester, text: '次へ');
  await tapVisibleText(tester, text: '次へ');
  await tapVisibleText(tester, text: '次へ');
}

void main() {
  testWidgets('初回起動は短尺ファネルを表示し、回答を結果へ反映してペイウォールへ進む', (tester) async {
    final actions = <String>[];
    final loggedEvents = <({String name, Map<String, Object>? parameters})>[];
    await pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => false,
      saveOnboardingCompletion: () async {
        actions.add('save');
      },
      openOnboardingPaywall: ({required context}) async {
        actions.add('paywall');
      },
      logAnalyticsEvent: ({required name, parameters}) async {
        loggedEvents.add((name: name, parameters: parameters));
        if (name == 'onboarding_complete') {
          actions.add(name);
        }
      },
      locale: const Locale('ja'),
    );
    await tester.pumpAndSettle();

    expect(find.text('家計の記録をもっと手軽に'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);

    await completeJapaneseOnboarding(tester);

    expect(find.text('入力の手間を減らして続けやすく'), findsOneWidget);
    final titleBottom = tester.getBottomLeft(find.text('入力の手間を減らして続けやすく')).dy;
    final descriptionTop = tester
        .getTopLeft(find.text('撮った明細を月ごとに整理して家計をひと目で振り返れます'))
        .dy;
    expect(titleBottom, lessThan(descriptionTop));
    expect(
      find.text('レシートもWeb明細も撮って支出を1か所にまとめます\n\n繰り返し入力する代わりに写真とスクショで記録します'),
      findsOneWidget,
    );
    await tapVisibleText(tester, text: 'プレミアムプランを見る');

    expect(actions, ['save', 'onboarding_complete', 'paywall']);
    expect(find.text('月次画面'), findsOneWidget);
    expect(
      loggedEvents.where((event) => event.name == 'onboarding_step_view'),
      hasLength(7),
    );
    expect(
      loggedEvents,
      contains(
        isA<({String name, Map<String, Object>? parameters})>()
            .having((event) => event.name, 'name', 'onboarding_answer')
            .having((event) => event.parameters, 'parameters', <String, Object>{
              'step': 'pain',
              'answer': 'recordingEffort',
              'funnel_variant': 'short',
            }),
      ),
    );
  });

  testWidgets('完了済みならオンボーディングを表示しない', (tester) async {
    await pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => true,
      saveOnboardingCompletion: () async {},
      openOnboardingPaywall: ({required context}) async {},
      logAnalyticsEvent: ({required name, parameters}) async {},
      locale: const Locale('ja'),
    );
    await tester.pumpAndSettle();

    expect(find.text('月次画面'), findsOneWidget);
    expect(find.text('家計の記録をもっと手軽に'), findsNothing);
  });

  testWidgets('完了状態の保存に失敗したらエラーを表示しペイウォールを開かない', (tester) async {
    var paywallOpened = false;
    await pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => false,
      saveOnboardingCompletion: () async {
        throw StateError('保存できませんでした');
      },
      openOnboardingPaywall: ({required context}) async {
        paywallOpened = true;
      },
      logAnalyticsEvent: ({required name, parameters}) async {},
      locale: const Locale('ja'),
    );
    await tester.pumpAndSettle();
    await completeJapaneseOnboarding(tester);
    await tapVisibleText(tester, text: 'プレミアムプランを見る');

    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    expect(paywallOpened, isFalse);
    expect(find.text('月次画面'), findsNothing);
  });

  testWidgets('完了イベントの記録に失敗してもペイウォールを開く', (tester) async {
    var paywallOpened = false;
    await pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => false,
      saveOnboardingCompletion: () async {},
      openOnboardingPaywall: ({required context}) async {
        paywallOpened = true;
      },
      logAnalyticsEvent: ({required name, parameters}) async {
        if (name == 'onboarding_complete') {
          throw StateError('計測できませんでした');
        }
      },
      locale: const Locale('ja'),
    );
    await tester.pumpAndSettle();
    await completeJapaneseOnboarding(tester);
    await tapVisibleText(tester, text: 'プレミアムプランを見る');

    expect(paywallOpened, isTrue);
    expect(find.text('月次画面'), findsOneWidget);
    expect(find.textContaining('計測できませんでした'), findsNothing);
  });

  testWidgets('英語ロケールでは価値説明を含む10画面の長尺ファネルを表示する', (tester) async {
    await pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => false,
      saveOnboardingCompletion: () async {},
      openOnboardingPaywall: ({required context}) async {},
      logAnalyticsEvent: ({required name, parameters}) async {},
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/10'), findsOneWidget);
    await tapVisibleText(tester, text: 'Continue');
    expect(find.text('Capture it now and review it later'), findsOneWidget);
    expect(find.text('2/10'), findsOneWidget);
  });

  testWidgets('表示中に英語から日本語へ変更しても開始時の10画面構成を維持する', (tester) async {
    Future<void> pumpWithLocale(Locale locale) => pumpOnboardingResolver(
      tester,
      loadOnboardingCompletion: () async => false,
      saveOnboardingCompletion: () async {},
      openOnboardingPaywall: ({required context}) async {},
      logAnalyticsEvent: ({required name, parameters}) async {},
      locale: locale,
    );

    await pumpWithLocale(const Locale('en'));
    await tester.pumpAndSettle();
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(
      tester,
      text: 'Entering every purchase takes too much work',
    );
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(tester, text: 'Both receipts and online statements');
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(tester, text: 'Almost every day');
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(tester, text: 'Reduce unnecessary spending');
    await tapVisibleText(tester, text: 'Continue');
    await tapVisibleText(tester, text: 'Continue');
    expect(find.text('8/10'), findsOneWidget);

    await pumpWithLocale(const Locale('ja'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('手軽な記録を始めませんか？'), findsOneWidget);
  });
}
