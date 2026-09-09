import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/utils/firebase_app_check/firebase_app_check.dart';

/// App Check の実機用プロバイダとデバッグ用プロバイダの分離を検証する。
void main() {
  test('debug ビルドでは秘密トークンを埋め込まずデバッグプロバイダを使う', () {
    final provider = appCheckAppleProvider(isDebugBuild: true);
    expect(provider, isA<AppleDebugProvider>());
    expect((provider as AppleDebugProvider).debugToken, isNull);
  });

  test('release と profile ビルドでは App Attest と DeviceCheck を使う', () {
    expect(
      appCheckAppleProvider(isDebugBuild: false),
      isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
    );
  });
}
