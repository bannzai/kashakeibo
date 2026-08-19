import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'package:kashakeibo/utils/firebase_emulator/firebase_emulator.dart';

/// App Check を有効化する。バックエンド (Firestore / Firebase AI Logic 等) への
/// リクエストに正規アプリ由来であることの証明トークンを添付する。
///
/// プロバイダはビルド種別で分離する:
/// - debug ビルド: debug プロバイダ (Firebase Console に登録したデバッグトークンで検証)
/// - release ビルド: iOS は DeviceCheck、Android は Play Integrity
///
/// iOS で App Attest を使うには App ID に App Attest capability を有効化して
/// provisioning profile を再生成する必要があり、この操作は Apple Developer Portal
/// でしか行えない。1.0 は DeviceCheck で出し、profile を整備してから
/// App Attest へ切り替える (shoppinglist と同判断)。
Future<void> activateAppCheck() async {
  // Emulator ビルドは App Check バックエンドに到達できずローカル完結が崩れるため
  // 有効化しない (Emulator 側も App Check を検証しない)。
  if (useFirebaseEmulator) {
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleDeviceCheckProvider(),
  );
}

/// Firebase 以外のバックエンド (画像アップロード Worker `workers/image`) へ
/// 「正規のアプリからのリクエストか」を証明するための App Check token を取得する。
///
/// Firebase バックエンド (Firestore 等) へは SDK が自動で添付するが、Cloudflare
/// Worker は Firebase バックエンドではないため、取得した token を呼び出し側が
/// `X-Firebase-AppCheck` ヘッダーで明示的に送る (Worker 側の検証は
/// `workers/image/src/app_check.ts`)。SDK が token をキャッシュし失効前に更新する
/// ため、リクエストの都度呼んでよい。
///
/// Emulator ビルドは [activateAppCheck] で App Check を有効化しておらず token を
/// 得られない。Worker は App Check token 無しのリクエストを拒否するため、
/// Emulator ビルドから Worker は利用できない (現状 Emulator ビルドは
/// IMAGE_API_BASE_URL も未設定で、Worker を使う経路が無い)。
Future<String> fetchFirebaseAppCheckToken() async {
  if (useFirebaseEmulator) {
    throw StateError(
      'Emulator ビルドでは App Check を有効化していないため、画像アップロード Worker 用の App Check token を取得できない',
    );
  }
  final firebaseAppCheckToken = await FirebaseAppCheck.instance.getToken();
  if (firebaseAppCheckToken == null || firebaseAppCheckToken.isEmpty) {
    throw StateError('App Check token を取得できないため、画像アップロード Worker を呼び出せない');
  }
  return firebaseAppCheckToken;
}
