// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$auditLogsHash() => r'cd1e82819b1dc6a46cd8b2f0db8f16785ea71f9d';

/// 履歴画面に表示する操作履歴 (新しい順)。
///
/// 履歴の正は明細の変更を写した BigQuery の changelog で、件数の上限と無料プランの
/// 期間制限は Worker が適用済みの結果を返す (lib/features/audit_log/audit_log_client.dart)。
/// Firestore の snapshot listener で購読していた頃のリアルタイム反映は API 化で失われるため、
/// 画面を開いたまま行った操作は [refresh] (履歴画面の pull-to-refresh) で取り直す。
///
/// Copied from [AuditLogs].
@ProviderFor(AuditLogs)
final auditLogsProvider =
    AutoDisposeAsyncNotifierProvider<
      AuditLogs,
      List<audit_log_client.AuditLog>
    >.internal(
      AuditLogs.new,
      name: r'auditLogsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$auditLogsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuditLogs = AutoDisposeAsyncNotifier<List<audit_log_client.AuditLog>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
