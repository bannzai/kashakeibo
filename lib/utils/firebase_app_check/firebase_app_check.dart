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
