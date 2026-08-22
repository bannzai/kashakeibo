// RevenueCat SDK (purchases_flutter) の初期化と設定値。
// 課金の決定は documents/adr/0001-tech-stack.md の「課金」、無料枠の設計は documents/PROJECT.md の「課金設計」。
// 購入・リストア・entitlement の Provider は lib/provider/purchase.dart、ペイウォールは lib/features/paywall。
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat の App Store 用 public API key (`appl_...`)。release / profile ビルドの iOS で使う。
///
/// リポジトリが public のためソースに置かず、`--dart-define=REVENUECAT_APPLE_PUBLIC_API_KEY=...` で注入する
/// (~/.claude/skills/revenuecat-product-setup/references/api_key_handling.md)。既定値は空文字で、
/// 空のままなら SDK を初期化しない (課金なしで起動できる)。
const revenueCatApplePublicApiKey = String.fromEnvironment(
  'REVENUECAT_APPLE_PUBLIC_API_KEY',
);

/// RevenueCat の Play Store 用 public API key (`goog_...`)。release / profile ビルドの Android で使う。
const revenueCatGooglePublicApiKey = String.fromEnvironment(
  'REVENUECAT_GOOGLE_PUBLIC_API_KEY',
);

/// RevenueCat の Test Store 用 public API key (`test_...`)。debug ビルドで使い、
/// ストアの Sandbox なしに mock 購入で購入・リストア・entitlement 解放のフローを確認する。
const revenueCatTestStorePublicApiKey = String.fromEnvironment(
  'REVENUECAT_TEST_STORE_API_KEY',
);

/// プレミアム (スキャンし放題 + 全履歴) の entitlement 識別子。
/// RevenueCat 側の entitlement の lookup_key と一致させる (~/.claude/skills/revenuecat-product-setup の config)。
const premiumEntitlementIdentifier = 'premium';

/// 実行中のビルドで RevenueCat SDK に渡す public API key。
///
/// debug ビルドは Test Store、release / profile ビルドはプラットフォームごとのストアのキーを使う
/// (debug で本番キーを誤って使わないためのガード)。未注入なら空文字。
String get revenueCatPublicApiKey {
  if (kDebugMode) {
    return revenueCatTestStorePublicApiKey;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => revenueCatApplePublicApiKey,
    TargetPlatform.android => revenueCatGooglePublicApiKey,
    _ => '',
  };
}

/// RevenueCat SDK が初期化済み (public API key が注入されている) かどうか。
///
/// 未注入のビルド (キー無しのローカル・CI ビルド、テスト) では課金機能を呼ばずに動作させるための判定。
bool get isPurchasesConfigured => revenueCatPublicApiKey.isNotEmpty;

/// RevenueCat SDK を初期化する。main() で Firebase 初期化の後に一度だけ呼ぶ。
///
/// app user ID はここでは渡さず、サインイン完了後に Firebase uid で `Purchases.logIn` する
/// (features/auth の SignInResolver)。Worker が同じ uid で entitlement を検証するため
/// (workers/image/src/entitlement.ts)、RevenueCat の匿名 ID のままにしない。
/// public API key が未注入なら何もしない (課金なしで起動する)。
Future<void> initializePurchases() async {
  if (!isPurchasesConfigured) {
    debugPrint('RevenueCat の public API key が未注入のため、課金機能を初期化しません');
    return;
  }
  await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
  await Purchases.configure(PurchasesConfiguration(revenueCatPublicApiKey));
}
