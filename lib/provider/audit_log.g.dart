// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$auditLogsHash() => r'7590d7ecd6b2b4e73aea751b7b0d5a8aa1644062';

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
