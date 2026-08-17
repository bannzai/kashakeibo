import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 設定画面から実行するアカウント操作。
typedef AccountAction = Future<void> Function();

/// アカウント削除前の再認証を実行し、Apple の認可コードがあれば返す関数。
typedef ReauthenticateForAccountDeletion =
    Future<String?> Function({required User user});

/// Apple アカウントのリンク、または既存アカウントへのサインイン操作。
final linkOrSignInWithAppleProvider = Provider<AccountAction>(
  (ref) => linkOrSignInCurrentUserWithApple,
);

/// Google アカウントのリンク、または既存アカウントへのサインイン操作。
final linkOrSignInWithGoogleProvider = Provider<AccountAction>(
  (ref) => linkOrSignInCurrentUserWithGoogle,
);

/// 現在のユーザーと、現在保存済みのユーザーデータを削除する機能。
final deleteAccountProvider = Provider<DeleteAccount>(
  (ref) => FirebaseDeleteAccount(
    firebaseAuth: FirebaseAuth.instance,
    firebaseFirestore: FirebaseFirestore.instance,
    reauthenticateForAccountDeletion: reauthenticateForAccountDeletion,
  ),
);

/// Google Sign-In の初期化が完了済みか。
bool _googleSignInInitialized = false;

/// Google Sign-In をプロセス内で一度だけ初期化する。
Future<void> initializeGoogleSignInIfNeeded() async {
  if (_googleSignInInitialized) {
    return;
  }
  await GoogleSignIn.instance.initialize(
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? Firebase.app().options.iosClientId
        : null,
  );
  _googleSignInInitialized = true;
}

/// Google の認証フローを実行し、Firebase Auth 用の認証情報を返す。
Future<OAuthCredential> requestGoogleCredential() async {
  await initializeGoogleSignInIfNeeded();
  return GoogleAuthProvider.credential(
    idToken:
        (await GoogleSignIn.instance.authenticate()).authentication.idToken,
  );
}

/// 現在の匿名ユーザーへ Apple をリンクする。
///
/// 同じ Apple ID が既存の Firebase ユーザーへリンク済みなら、そのユーザーへ
/// サインインする。これにより別端末でも同じ UID 配下のデータを参照できる。
Future<void> linkOrSignInCurrentUserWithApple() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw StateError('サインイン前に Apple アカウントはリンクできない');
  }
  if (hasLinkedProvider(user: currentUser, providerID: 'apple.com')) {
    return;
  }

  final appleAuthProvider = AppleAuthProvider();
  try {
    await currentUser.linkWithProvider(appleAuthProvider);
  } on FirebaseAuthException catch (error) {
    if (error.code != 'credential-already-in-use') {
      rethrow;
    }
    if (!currentUser.isAnonymous) {
      rethrow;
    }
    if (error.credential != null) {
      await FirebaseAuth.instance.signInWithCredential(error.credential!);
      return;
    }
    // Apple のプラットフォーム実装が衝突時の credential を返さない場合だけ、
    // 既存ユーザーへのサインインフローを再度表示する。
    await FirebaseAuth.instance.signInWithProvider(appleAuthProvider);
  }
}

/// 現在の匿名ユーザーへ Google をリンクする。
///
/// 同じ Google アカウントが既存の Firebase ユーザーへリンク済みなら、その
/// ユーザーへサインインする。これにより別端末でも同じ UID のデータを参照できる。
Future<void> linkOrSignInCurrentUserWithGoogle() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw StateError('サインイン前に Google アカウントはリンクできない');
  }
  if (hasLinkedProvider(user: currentUser, providerID: 'google.com')) {
    return;
  }

  final googleAuthCredential = await requestGoogleCredential();
  try {
    await currentUser.linkWithCredential(googleAuthCredential);
  } on FirebaseAuthException catch (error) {
    if (error.code != 'credential-already-in-use') {
      rethrow;
    }
    if (!currentUser.isAnonymous) {
      rethrow;
    }
    await FirebaseAuth.instance.signInWithCredential(googleAuthCredential);
  }
}

/// ユーザーに指定プロバイダがリンク済みかを返す。
bool hasLinkedProvider({required User user, required String providerID}) =>
    user.providerData.any((userInfo) => userInfo.providerId == providerID);

/// アカウント削除前に、リンク済みプロバイダで再認証する。
///
/// Apple の場合は認可トークン失効に必要な認可コードを返す。匿名ユーザーは
/// 再認証に使える外部プロバイダが無いため、そのまま削除処理へ進む。
Future<String?> reauthenticateForAccountDeletion({required User user}) async {
  if (hasLinkedProvider(user: user, providerID: 'apple.com')) {
    final appleAuthorizationCode = (await user.reauthenticateWithProvider(
      AppleAuthProvider(),
    )).additionalUserInfo?.authorizationCode;
    if (appleAuthorizationCode == null) {
      throw StateError('Appleの認可トークンを失効できないため、アカウントを削除できない');
    }
    return appleAuthorizationCode;
  }
  if (hasLinkedProvider(user: user, providerID: 'google.com')) {
    await user.reauthenticateWithCredential(await requestGoogleCredential());
  }
  return null;
}

/// アカウントと、その UID 配下のアプリデータを削除する機能。
abstract interface class DeleteAccount {
  /// 削除を実行する。
  Future<void> call();
}

/// Firebase Auth と Firestore に保存済みのアカウントデータを削除する。
class FirebaseDeleteAccount implements DeleteAccount {
  /// Firebase Auth クライアント。
  final FirebaseAuth firebaseAuth;

  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  /// 削除直前にリンク済みプロバイダで再認証する関数。
  final ReauthenticateForAccountDeletion reauthenticateForAccountDeletion;

  /// Firebase クライアントと再認証関数を指定して削除機能を作る。
  FirebaseDeleteAccount({
    required this.firebaseAuth,
    required this.firebaseFirestore,
    required this.reauthenticateForAccountDeletion,
  });

  /// Firestore の明細・ユーザードキュメントと Firebase Auth を削除する。
  ///
  /// 各削除は存在しないデータに対しても成功するため、途中失敗後の再実行を含めて
  /// 冪等。リンク済みアカウントは先に再認証し、データ削除後に recent-login
  /// エラーとなる可能性を避ける。
  @override
  Future<void> call() async {
    final currentUser = firebaseAuth.currentUser;
    if (currentUser == null) {
      return;
    }

    final appleAuthorizationCode = await reauthenticateForAccountDeletion(
      user: currentUser,
    );
    if (appleAuthorizationCode != null) {
      await firebaseAuth.revokeTokenWithAuthorizationCode(
        appleAuthorizationCode,
      );
    }

    await _deleteTransactions(userID: currentUser.uid);
    await firebaseFirestore.collection('users').doc(currentUser.uid).delete();
    await currentUser.delete();
  }

  /// 指定ユーザーの明細を Firestore の上限内のバッチへ分割して削除する。
  Future<void> _deleteTransactions({required String userID}) async {
    while (true) {
      // Firestore の1バッチ上限500件に対して、将来同じバッチへ別の削除を追加しても
      // 上限を越えない余裕を残すため400件ずつ処理する。
      final transactionDocuments = await firebaseFirestore
          .collection('users')
          .doc(userID)
          .collection('transactions')
          .limit(400)
          .get();
      if (transactionDocuments.docs.isEmpty) {
        return;
      }
      final writeBatch = firebaseFirestore.batch();
      for (final transactionDocument in transactionDocuments.docs) {
        writeBatch.delete(transactionDocument.reference);
      }
      await writeBatch.commit();
    }
  }
}
