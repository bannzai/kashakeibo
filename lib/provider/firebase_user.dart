import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_user.g.dart';

/// 未サインイン時に匿名認証を保証する操作。
typedef EnsureAnonymousSignIn = Future<void> Function();

/// 未サインイン時の匿名認証操作。
final ensureAnonymousSignInProvider = Provider<EnsureAnonymousSignIn>(
  (ref) => ensureAnonymousSignIn,
);

/// Firebase Auth が未サインインなら匿名認証する。
Future<void> ensureAnonymousSignIn() async {
  if (FirebaseAuth.instance.currentUser != null) {
    return;
  }
  await FirebaseAuth.instance.signInAnonymously();
}

/// Firebase Auth のユーザー状態 (サインイン・サインアウト・トークン更新) のストリーム。
@Riverpod(keepAlive: true)
Stream<User?> firebaseUserChanges(Ref ref) =>
    FirebaseAuth.instance.userChanges();

/// 現在サインインしているユーザーの ID。未サインインの場合は null。
final currentUserIDProvider = Provider<String?>((ref) {
  // 初回起動時は userChanges() の stream がまだ流れてこないため、currentUser で補完する。
  return ref.watch(firebaseUserChangesProvider).valueOrNull?.uid ??
      FirebaseAuth.instance.currentUser?.uid;
});
