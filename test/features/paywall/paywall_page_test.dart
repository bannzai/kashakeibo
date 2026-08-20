// ペイウォール (features/paywall) の表示と購入・復元の操作のテスト。
// RevenueCat SDK は Provider (Offering・購入・復元・プレミアム判定) を差し替えて呼ばない。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/paywall/paywall_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Analytics を必要としないテスト用の記録処理。
Future<void> discardAnalyticsEvent({
  required String name,
  Map<String, Object>? parameters,
}) async {}

/// テスト用の RevenueCat パッケージ (ストアが解決した価格付き)。
Package buildPackage({
  required PackageType packageType,
  required String productIdentifier,
  required double price,
  required String priceString,
}) => Package(
  packageType == PackageType.annual ? r'$rc_annual' : r'$rc_monthly',
  packageType,
  StoreProduct(
    productIdentifier,
    'カシャケイボ プレミアム',
    'プレミアム',
    price,
    priceString,
    'JPY',
  ),
  const PresentedOfferingContext('default', null, null),
);

final monthlyPackage = buildPackage(
  packageType: PackageType.monthly,
  productIdentifier: 'kashakeibo_premium_monthly_480yen',
  price: 480,
  priceString: '¥480',
);

final annualPackage = buildPackage(
  packageType: PackageType.annual,
  productIdentifier: 'kashakeibo_premium_annual_3800yen',
  price: 3800,
  priceString: '¥3,800',
);

final premiumOffering = Offering(
  'default',
  'プレミアム',
  const {},
  [monthlyPackage, annualPackage],
  monthly: monthlyPackage,
  annual: annualPackage,
);

/// ペイウォールを開くボタンだけを持つホーム画面 (pop の戻り値を確認するため)。
class _PaywallLauncher extends StatelessWidget {
  final ValueChanged<bool?> onPaywallClosed;

  const _PaywallLauncher({required this.onPaywallClosed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            onPaywallClosed(
              await showPaywall(
                context: context,
                trigger: 'test',
                openExternalUri: ({required uri}) async {},
                logAnalyticsEvent: discardAnalyticsEvent,
              ),
            );
          },
          child: const Text('open paywall'),
        ),
      ),
    );
  }
}

Future<void> pumpPaywall(
  WidgetTester tester, {
  required bool isPremium,
  required ScanQuota scanQuota,
  required PurchasePremiumPackage purchasePremiumPackage,
  required RestorePurchases restorePurchases,
  required ValueChanged<bool?> onPaywallClosed,
  Offering? offering,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firebaseUserChangesProvider.overrideWith((ref) => Stream.value(null)),
        fetchScanQuotaProvider.overrideWithValue(() async => scanQuota),
        isPremiumProvider.overrideWithValue(isPremium),
        premiumOfferingProvider.overrideWith(
          (ref) async => offering ?? premiumOffering,
        ),
        purchasePremiumPackageProvider.overrideWithValue(
          purchasePremiumPackage,
        ),
        restorePurchasesProvider.overrideWithValue(restorePurchases),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: _PaywallLauncher(onPaywallClosed: onPaywallClosed),
      ),
    ),
  );
  await tester.tap(find.text('open paywall'));
  await tester.pumpAndSettle();
}

/// ペイウォール下部の「購入の復元」まで ListView をスクロールする (テストの画面高では下部が画面外のため)。
Future<void> scrollToRestoreLink(WidgetTester tester) =>
    tester.scrollUntilVisible(
      find.text('購入の復元'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets(
    '無料プラン: 無料枠の消費・特典・月額と年額 (推奨・月換算付き) を表示し、年額の購入でプレミアムになると true で閉じる',
    (tester) async {
      Package? purchasedPackage;
      bool? paywallResult;
      await pumpPaywall(
        tester,
        isPremium: false,
        scanQuota: const ScanQuota(
          monthlyScanCount: 7,
          monthlyFreeScanLimit: 10,
        ),
        purchasePremiumPackage: ({required package}) async {
          purchasedPackage = package;
          return true;
        },
        restorePurchases: () async => false,
        onPaywallClosed: (result) => paywallResult = result,
      );

      expect(find.text('スキャン、し放題に。'), findsOneWidget);
      expect(find.text('今月の無料スキャン 7/10'), findsOneWidget);
      expect(find.text('スキャン無制限'), findsOneWidget);
      expect(find.text('全期間の履歴'), findsOneWidget);
      expect(find.text('¥480'), findsOneWidget);
      expect(find.text('¥3,800'), findsOneWidget);
      // 年額は月額 × 12 = ¥5,760 に対して 34% 引き、月換算 ¥317
      expect(find.text('34%お得'), findsOneWidget);
      expect(find.text('¥317/月換算'), findsOneWidget);
      await scrollToRestoreLink(tester);
      expect(find.text('購入の復元'), findsOneWidget);

      await tester.tap(find.text('プレミアムを始める'));
      await tester.pumpAndSettle();
      expect(purchasedPackage, annualPackage);
      expect(paywallResult, isTrue);
      expect(find.text('スキャン、し放題に。'), findsNothing);
    },
  );

  testWidgets('月額カードを選んで購入すると月額パッケージで購入する', (tester) async {
    Package? purchasedPackage;
    await pumpPaywall(
      tester,
      isPremium: false,
      scanQuota: const ScanQuota(
        monthlyScanCount: 10,
        monthlyFreeScanLimit: 10,
      ),
      purchasePremiumPackage: ({required package}) async {
        purchasedPackage = package;
        return true;
      },
      restorePurchases: () async => false,
      onPaywallClosed: (_) {},
    );

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プレミアムを始める'));
    await tester.pumpAndSettle();
    expect(purchasedPackage, monthlyPackage);
  });

  testWidgets('購入シートを閉じただけ (キャンセル) ならエラーを表示せず開いたままにする', (tester) async {
    bool? paywallResult = false;
    await pumpPaywall(
      tester,
      isPremium: false,
      scanQuota: const ScanQuota(
        monthlyScanCount: 10,
        monthlyFreeScanLimit: 10,
      ),
      purchasePremiumPackage: ({required package}) async {
        throw PlatformException(
          code: PurchasesErrorCode.purchaseCancelledError.index.toString(),
          message: 'Purchase was cancelled.',
        );
      },
      restorePurchases: () async => false,
      onPaywallClosed: (result) => paywallResult = result,
    );

    await tester.tap(find.text('プレミアムを始める'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('スキャン、し放題に。'), findsOneWidget);
    expect(paywallResult, isFalse);
  });

  testWidgets('購入に失敗した場合はエラー文をそのまま表示する', (tester) async {
    await pumpPaywall(
      tester,
      isPremium: false,
      scanQuota: const ScanQuota(
        monthlyScanCount: 10,
        monthlyFreeScanLimit: 10,
      ),
      purchasePremiumPackage: ({required package}) async {
        throw PlatformException(
          code: PurchasesErrorCode.storeProblemError.index.toString(),
          message: 'There was a problem with the store.',
        );
      },
      restorePurchases: () async => false,
      onPaywallClosed: (_) {},
    );

    await tester.tap(find.text('プレミアムを始める'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('There was a problem with the store.'),
      findsOneWidget,
    );
  });

  testWidgets('購入の復元: 復元できる購入が無ければその旨を表示して開いたまま、復元できれば true で閉じる', (
    tester,
  ) async {
    var restoreResult = false;
    bool? paywallResult;
    await pumpPaywall(
      tester,
      isPremium: false,
      scanQuota: const ScanQuota(
        monthlyScanCount: 10,
        monthlyFreeScanLimit: 10,
      ),
      purchasePremiumPackage: ({required package}) async => false,
      restorePurchases: () async => restoreResult,
      onPaywallClosed: (result) => paywallResult = result,
    );

    await scrollToRestoreLink(tester);
    await tester.tap(find.text('購入の復元'));
    await tester.pumpAndSettle();
    expect(find.text('復元できる購入がありません'), findsOneWidget);
    expect(paywallResult, isNull);

    // 「復元できる購入がありません」の SnackBar が消えてから (復元リンクに重ならないように) 再度タップする
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    restoreResult = true;
    await tester.tap(find.text('購入の復元'));
    await tester.pumpAndSettle();
    expect(paywallResult, isTrue);
  });

  testWidgets('プレミアム利用中は料金カードと購入ボタンを出さず、利用中の表示だけにする', (tester) async {
    await pumpPaywall(
      tester,
      isPremium: true,
      scanQuota: const ScanQuota(
        monthlyScanCount: 25,
        monthlyFreeScanLimit: 10,
      ),
      purchasePremiumPackage: ({required package}) async => true,
      restorePurchases: () async => true,
      onPaywallClosed: (_) {},
    );

    expect(find.text('プレミアム利用中'), findsOneWidget);
    expect(find.text('プレミアムを始める'), findsNothing);
    expect(find.text('¥3,800'), findsNothing);
    expect(find.textContaining('今月の無料スキャン'), findsNothing);
  });

  testWidgets('Offering が取得できない (SDK 未設定) 場合は料金プランを取得できない旨を表示する', (
    tester,
  ) async {
    await pumpPaywall(
      tester,
      isPremium: false,
      scanQuota: const ScanQuota(monthlyScanCount: 0, monthlyFreeScanLimit: 10),
      purchasePremiumPackage: ({required package}) async => true,
      restorePurchases: () async => false,
      onPaywallClosed: (_) {},
      offering: const Offering('empty', '', {}, []),
    );

    expect(find.text('料金プランを取得できませんでした'), findsOneWidget);
    expect(find.text('プレミアムを始める'), findsNothing);
  });
}
