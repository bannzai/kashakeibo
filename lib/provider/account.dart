import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kashakeibo/features/audit_log/audit_log_client.dart'
    as audit_log;
import 'package:kashakeibo/features/image_upload/image_upload_client.dart'
    as image_upload;
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/utils/firebase_app_check/firebase_app_check.dart';

/// 設定画面から実行するアカウント操作。
typedef AccountAction = Future<AccountActionResult> Function();

/// アカウント操作が現在 UID へのリンクか、既存 UID への切替か。
enum AccountActionResult {
  /// 現在の UID へ認証情報をリンクした。
  linked,

  /// 認証情報が使用済みだったため既存 UID へ切り替えた。
  signedInExistingAccount,
}

/// アカウント削除前の再認証を実行し、Apple の認可コードがあれば返す関数。
typedef ReauthenticateForAccountDeletion =
    Future<String?> Function({required User user});

/// アカウントに属する R2 画像を削除する関数。
typedef DeleteAllImagesForAccount = Future<void> Function({required User user});

/// アカウントに属する操作履歴のパージを Worker へ依頼する関数。
typedef DeleteAuditLogsForAccount = Future<void> Function({required User user});

/// 現在の匿名ユーザーに保存済みデータがあるかを返す関数。
typedef HasCurrentUserData = Future<bool> Function();

/// Apple アカウントのリンク、または既存アカウントへのサインイン操作。
final linkOrSignInWithAppleProvider = Provider<AccountAction>(
  (ref) => linkOrSignInCurrentUserWithApple,
);

/// Google アカウントのリンク、または既存アカウントへのサインイン操作。
final linkOrSignInWithGoogleProvider = Provider<AccountAction>(
  (ref) => linkOrSignInCurrentUserWithGoogle,
);

/// 現在の匿名ユーザーに保存済みデータがあるかを確認する機能。
final hasCurrentUserDataProvider = Provider<HasCurrentUserData>(
  (ref) => hasCurrentUserData,
);

/// 現在のユーザーと、現在保存済みのユーザーデータを削除する機能。
final deleteAccountProvider = Provider<DeleteAccount>(
  (ref) => FirebaseDeleteAccount(
    firebaseAuth: FirebaseAuth.instance,
    firebaseFirestore: FirebaseFirestore.instance,
    reauthenticateForAccountDeletion: reauthenticateForAccountDeletion,
    deleteAllImagesForAccount: deleteAllImagesForAccount,
    deleteAuditLogsForAccount: deleteAuditLogsForAccount,
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
  final googleAuthentication =
      (await GoogleSignIn.instance.authenticate()).authentication;
  final googleIDToken = googleAuthentication.idToken;
  if (googleIDToken == null) {
    throw StateError('Googleの認証情報を取得できないため、アカウントをリンクできない');
  }
  return GoogleAuthProvider.credential(idToken: googleIDToken);
}

/// 現在の匿名ユーザーへ Apple をリンクする。
///
/// 同じ Apple ID が既存の Firebase ユーザーへリンク済みなら、そのユーザーへ
/// サインインする。これにより別端末でも同じ UID 配下のデータを参照できる。
Future<AccountActionResult> linkOrSignInCurrentUserWithApple() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw StateError('サインイン前に Apple アカウントはリンクできない');
  }
  if (hasLinkedProvider(user: currentUser, providerID: 'apple.com')) {
    return AccountActionResult.linked;
  }

  final appleAuthProvider = AppleAuthProvider();
  try {
    await currentUser.linkWithProvider(appleAuthProvider);
    return AccountActionResult.linked;
  } on FirebaseAuthException catch (error) {
    if (error.code != 'credential-already-in-use') {
      rethrow;
    }
    if (!currentUser.isAnonymous) {
      rethrow;
    }
    if (error.credential != null) {
      await FirebaseAuth.instance.signInWithCredential(error.credential!);
      return AccountActionResult.signedInExistingAccount;
    }
    // Apple のプラットフォーム実装が衝突時の credential を返さない場合だけ、
    // 既存ユーザーへのサインインフローを再度表示する。
    await FirebaseAuth.instance.signInWithProvider(appleAuthProvider);
    return AccountActionResult.signedInExistingAccount;
  }
}

/// 現在の匿名ユーザーへ Google をリンクする。
///
/// 同じ Google アカウントが既存の Firebase ユーザーへリンク済みなら、その
/// ユーザーへサインインする。これにより別端末でも同じ UID のデータを参照できる。
Future<AccountActionResult> linkOrSignInCurrentUserWithGoogle() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw StateError('サインイン前に Google アカウントはリンクできない');
  }
  if (hasLinkedProvider(user: currentUser, providerID: 'google.com')) {
    return AccountActionResult.linked;
  }

  final googleAuthCredential = await requestGoogleCredential();
  try {
    await currentUser.linkWithCredential(googleAuthCredential);
    return AccountActionResult.linked;
  } on FirebaseAuthException catch (error) {
    if (error.code != 'credential-already-in-use') {
      rethrow;
    }
    if (!currentUser.isAnonymous) {
      rethrow;
    }
    await FirebaseAuth.instance.signInWithCredential(googleAuthCredential);
    return AccountActionResult.signedInExistingAccount;
  }
}

/// 現在のユーザーに明細が1件以上保存されているかを返す。
Future<bool> hasCurrentUserData() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    return false;
  }
  final transactionDocuments = await transactionDocumentsReference(
    userID: currentUser.uid,
  ).limit(1).get();
  return transactionDocuments.docs.isNotEmpty;
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

/// Firebase ID token が有効なうちに、削除対象のユーザーとして Worker API を 1 回呼ぶ。
/// Worker は ID token に加えて App Check token (正規アプリからの証明) も要求する。
Future<void> _callWorkerApiForAccountDeletion({
  required User user,
  required Future<void> Function({
    required String firebaseIdToken,
    required String firebaseAppCheckToken,
    required http.Client httpClient,
  })
  workerApiCall,
}) async {
  final firebaseIdToken = await user.getIdToken(true);
  if (firebaseIdToken == null) {
    throw StateError('削除に必要な認証情報を取得できないため、アカウントを削除できない');
  }
  final firebaseAppCheckToken = await fetchFirebaseAppCheckToken();
  final httpClient = http.Client();
  try {
    await workerApiCall(
      firebaseIdToken: firebaseIdToken,
      firebaseAppCheckToken: firebaseAppCheckToken,
      httpClient: httpClient,
    );
  } finally {
    httpClient.close();
  }
}

/// Worker 経由で本人の R2 画像を全削除する。
Future<void> deleteAllImagesForAccount({required User user}) =>
    _callWorkerApiForAccountDeletion(
      user: user,
      workerApiCall:
          ({
            required firebaseIdToken,
            required firebaseAppCheckToken,
            required httpClient,
          }) => image_upload.deleteAllImages(
            firebaseIdToken: firebaseIdToken,
            firebaseAppCheckToken: firebaseAppCheckToken,
            httpClient: httpClient,
          ),
    );

/// Worker 経由で本人の操作履歴 (BigQuery の changelog) のパージを依頼する。
/// Worker がパージの登録を受け付けた時点で成功として扱う (実削除は Worker 側で遅延実行される)。
Future<void> deleteAuditLogsForAccount({required User user}) =>
    _callWorkerApiForAccountDeletion(
      user: user,
      workerApiCall:
          ({
            required firebaseIdToken,
            required firebaseAppCheckToken,
            required httpClient,
          }) => audit_log.deleteAuditLogs(
            firebaseIdToken: firebaseIdToken,
            firebaseAppCheckToken: firebaseAppCheckToken,
            httpClient: httpClient,
          ),
    );

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

  /// Worker 経由で R2 の全画像を削除する関数。
  final DeleteAllImagesForAccount deleteAllImagesForAccount;

  /// Worker 経由で操作履歴のパージを依頼する関数。
  final DeleteAuditLogsForAccount deleteAuditLogsForAccount;

  /// Firebase クライアントと再認証関数を指定して削除機能を作る。
  FirebaseDeleteAccount({
    required this.firebaseAuth,
    required this.firebaseFirestore,
    required this.reauthenticateForAccountDeletion,
    required this.deleteAllImagesForAccount,
    required this.deleteAuditLogsForAccount,
  });

  /// R2 画像、操作履歴、Firestore データ、Firebase Auth を削除する。
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

    await deleteAllImagesForAccount(user: currentUser);
    // 操作履歴の実体は明細の変更を写した BigQuery の changelog のため、明細を消す前に
    // パージを登録する。登録後に発生する明細の削除イベントも Worker 側の遅延パージが拾う。
    await deleteAuditLogsForAccount(user: currentUser);
    // サブコレクションは親ドキュメントの削除では消えないため、users/{uid} を消す前に
    // 明細を個別に削除する。
    await _deleteCollectionDocuments(
      collectionReference: transactionDocumentsReference(
        userID: currentUser.uid,
        firebaseFirestore: firebaseFirestore,
      ),
    );
    await firebaseFirestore.collection('users').doc(currentUser.uid).delete();
    if (appleAuthorizationCode != null) {
      await firebaseAuth.revokeTokenWithAuthorizationCode(
        appleAuthorizationCode,
      );
    }
    try {
      await currentUser.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login' || !currentUser.isAnonymous) {
        rethrow;
      }
      // 匿名ユーザーには再認証に使える credential が無く、recent-login 状態を
      // 回復して delete() を成功させる手段が無い。ここまでで保存データの削除は
      // 完了しているため、個人情報を含まない空の匿名 Auth レコードが残ることを
      // 許容してサインアウトし、SignInResolver に新しい匿名アカウントを作らせる。
      await firebaseAuth.signOut();
    }
  }

  /// 指定コレクションの全ドキュメントを Firestore の上限内のバッチへ分割して削除する。
  Future<void> _deleteCollectionDocuments({
    required CollectionReference<Map<String, dynamic>> collectionReference,
  }) async {
    while (true) {
      // Firestore の1バッチ上限500件に対して、将来同じバッチへ別の削除を追加しても
      // 上限を越えない余裕を残すため400件ずつ処理する。
      final documents = await collectionReference.limit(400).get();
      if (documents.docs.isEmpty) {
        return;
      }
      final writeBatch = firebaseFirestore.batch();
      for (final document in documents.docs) {
        writeBatch.delete(document.reference);
      }
      await writeBatch.commit();
    }
  }
}
