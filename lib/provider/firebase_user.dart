import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_user.g.dart';

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
