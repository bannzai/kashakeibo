import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/utils/purchase/purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// プレミアムのパッケージ (月額 / 年額) を購入し、購入後にプレミアムが有効なら true を返す操作。
typedef PurchasePremiumPackage =
    Future<bool> Function({required Package package});

/// 購入を復元し、復元後にプレミアムが有効なら true を返す操作。
typedef RestorePurchases = Future<bool> Function();

/// RevenueCat の app user ID を Firebase uid に揃える操作。
typedef LogInPurchases = Future<void> Function({required String appUserID});

/// RevenueCat の CustomerInfo (entitlement・購読状況) のストリーム。
///
/// 初回に `Purchases.getCustomerInfo()` の結果を流し、以降は SDK の更新通知
/// (購入・リストア・logIn・期限切れ) を流す。SDK 未初期化 (public API key 未注入) では null だけを流す。
/// テストでは差し替える。
final customerInfoProvider = StreamProvider<CustomerInfo?>((ref) {
  if (!isPurchasesConfigured) {
    return Stream.value(null);
  }
  final customerInfoStreamController = StreamController<CustomerInfo?>();
  Purchases.getCustomerInfo().then(
    (customerInfo) {
      if (!customerInfoStreamController.isClosed) {
        customerInfoStreamController.add(customerInfo);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!customerInfoStreamController.isClosed) {
        customerInfoStreamController.addError(error, stackTrace);
      }
    },
  );
  void customerInfoUpdateListener(CustomerInfo customerInfo) {
    customerInfoStreamController.add(customerInfo);
  }

  Purchases.addCustomerInfoUpdateListener(customerInfoUpdateListener);
  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(customerInfoUpdateListener);
    customerInfoStreamController.close();
  });
  return customerInfoStreamController.stream;
});

/// プレミアム (スキャンし放題 + 全履歴) が有効かどうか。取得前・SDK 未初期化・取得失敗は false。
///
/// サーバー側の判定は Worker が RevenueCat に直接問い合わせるため (workers/image/src/entitlement.ts)、
/// この値は UI の表示 (残量チップ・ペイウォールの出し分け) にだけ使う。
final isPremiumProvider = Provider<bool>(
  (ref) => hasPremiumEntitlement(
    customerInfo: ref.watch(customerInfoProvider).valueOrNull,
  ),
);

/// CustomerInfo にプレミアムの entitlement が有効な状態で含まれているか。
bool hasPremiumEntitlement({required CustomerInfo? customerInfo}) =>
    customerInfo?.entitlements.active.containsKey(
      premiumEntitlementIdentifier,
    ) ??
    false;

/// ペイウォールに表示するプレミアムの Offering (RevenueCat の Current Offering)。
///
/// 月額・年額のパッケージと、ストアから解決した価格を含む。SDK 未初期化なら null。テストでは差し替える。
final premiumOfferingProvider = FutureProvider<Offering?>((ref) async {
  if (!isPurchasesConfigured) {
    return null;
  }
  return (await Purchases.getOfferings()).current;
});

/// プレミアムのパッケージの購入操作。テストでは差し替える。
final purchasePremiumPackageProvider = Provider<PurchasePremiumPackage>(
  (ref) => purchasePremiumPackage,
);

/// 購入の復元操作。テストでは差し替える。
final restorePurchasesProvider = Provider<RestorePurchases>(
  (ref) => restorePurchases,
);

/// RevenueCat の app user ID を Firebase uid に揃える操作。テストでは差し替える。
final logInPurchasesProvider = Provider<LogInPurchases>(
  (ref) => logInPurchases,
);

/// パッケージを購入し、購入後にプレミアムの entitlement が有効なら true を返す。
///
/// ストアの購入シートを開くユーザー操作ごとの副作用のため冪等ではない。
/// キャンセルを含むエラーは PlatformException のまま投げ、呼び出し側が
/// `PurchasesErrorHelper.getErrorCode` で判定する。
Future<bool> purchasePremiumPackage({required Package package}) async {
  await _ensurePurchasesAppUserIdMatchesFirebaseUid();
  return hasPremiumEntitlement(
    customerInfo: (await Purchases.purchase(
      PurchaseParams.package(package),
    )).customerInfo,
  );
}

/// ストアの購入履歴から entitlement を復元し、プレミアムが有効なら true を返す。
/// 冪等 (何度呼んでも同じ購読状態に収束する)。
Future<bool> restorePurchases() async {
  await _ensurePurchasesAppUserIdMatchesFirebaseUid();
  return hasPremiumEntitlement(
    customerInfo: await Purchases.restorePurchases(),
  );
}

/// 購入・復元の直前に、RevenueCat の app user ID が Firebase uid と一致していることを保証する。
///
/// 起動時の `Purchases.logIn` (SignInResolver) が一時的に失敗したままだと、購入が RevenueCat の
/// 匿名ユーザーに紐づき、Worker は Firebase uid で entitlement を引くため解析が 402 のままになる。
/// ここで一致を確認し、ずれていれば logIn し直すことで、購入が常に Firebase uid に紐づく
/// (logIn できない状態なら購入自体を失敗させ、エラーは呼び出し側がそのまま表示する)。冪等。
Future<void> _ensurePurchasesAppUserIdMatchesFirebaseUid() async {
  final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
  if (firebaseUid == null) {
    throw StateError('サインイン前に購入はできない');
  }
  if (await Purchases.appUserID != firebaseUid) {
    await Purchases.logIn(firebaseUid);
  }
}

/// RevenueCat の app user ID を Firebase uid に揃える。
///
/// 同じ uid での再実行は SDK 側で no-op になるため冪等。SDK 未初期化なら何もしない。
Future<void> logInPurchases({required String appUserID}) async {
  if (!isPurchasesConfigured) {
    return;
  }
  await Purchases.logIn(appUserID);
}
