// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$auditLogsHash() => r'b91daf082b5b341ca10148057990193cb4a5ab81';

/// 操作履歴を新しい順に購読するストリーム。履歴画面の一覧に使う。
///
/// snapshot listener なので、履歴画面を開いたまま行った操作もそのまま追加される。
/// サーバータイムスタンプが確定するまでの書き込み直後のログは
/// [AuditLog.serverCreatedDateTime] が null で流れる (Firestore の並び順では末尾になる)。
///
/// Copied from [auditLogs].
@ProviderFor(auditLogs)
final auditLogsProvider = AutoDisposeStreamProvider<List<AuditLog>>.internal(
  auditLogs,
  name: r'auditLogsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$auditLogsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuditLogsRef = AutoDisposeStreamProviderRef<List<AuditLog>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
