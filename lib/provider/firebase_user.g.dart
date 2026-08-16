// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_user.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseUserChangesHash() =>
    r'eeeec1542315417039b10f164b7b94b52db66697';

/// Firebase Auth のユーザー状態 (サインイン・サインアウト・トークン更新) のストリーム。
///
/// Copied from [firebaseUserChanges].
@ProviderFor(firebaseUserChanges)
final firebaseUserChangesProvider = StreamProvider<User?>.internal(
  firebaseUserChanges,
  name: r'firebaseUserChangesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$firebaseUserChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseUserChangesRef = StreamProviderRef<User?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
