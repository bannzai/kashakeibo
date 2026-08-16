import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// `--dart-define=USE_FIREBASE_EMULATOR=true` を付けたビルドかどうか。
/// 未指定(デフォルト)は false で、GoogleService-Info.plist / google-services.json の
/// 設定に従い kashakeibo-dev (debug) / kashakeibo-prod (release) に接続する。
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Firebase を初期化する。
///
/// Emulator ビルドでもオプションは渡さず、バンドル済みの設定ファイル
/// (GoogleService-Info.plist / google-services.json) で初期化する。
/// iOS では native 層が plist から default app を自動構成するため、
/// 別オプションを渡すと [core/duplicate-app] で衝突する (実測)。
/// ローカル完結は Emulator 側で担保する: `firebase emulators:start --project
/// demo-kashakeibo` の demo- プレフィックスにより Emulator はクラウドに一切
/// 接続せず、SDK の通信も [_connectFirebaseEmulator] で全て Emulator へ向く
/// (plist のプロジェクト ID は Emulator 内の名前空間としてだけ使われる)。
Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
  if (useFirebaseEmulator) {
    await _connectFirebaseEmulator();
  }
}

/// ローカルの Firebase Emulator に各 Firebase SDK を接続する。
Future<void> _connectFirebaseEmulator() async {
  // Android (Emulator) では localhost が端末自身を指すため、ホストマシンへの
  // ループバックである 10.0.2.2 を既定にする。Android 実機などホストマシンに
  // 別アドレスで到達する構成では FIREBASE_EMULATOR_HOST で明示的に上書きする。
  const overrideHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  final emulatorHost = overrideHost.isNotEmpty
      ? overrideHost
      : (defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : 'localhost');
  // 前回実行時のディスクキャッシュが Emulator の空データより優先して返り、
  // 動作確認が再現可能でなくなるのを防ぐため、Emulator 接続時は
  // Firestore の永続キャッシュを無効化する (メモリキャッシュのみ)。
  // useFirestoreEmulator は settings を copyWith で上書きするため、先に設定する。
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  // ポートは firebase/firebase.json の emulators セクションと一致させる。
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
}
