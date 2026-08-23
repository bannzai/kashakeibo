import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/audit_log/audit_log_client.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';

/// 操作種別の表示名を返す。
String auditLogOperationLabel({
  required AuditLogOperation operation,
  required AppLocalizations l10n,
}) => switch (operation) {
  AuditLogOperation.transactionCreated =>
    l10n.auditLogOperationTransactionCreated,
  AuditLogOperation.transactionUpdated =>
    l10n.auditLogOperationTransactionUpdated,
  AuditLogOperation.transactionDeleted =>
    l10n.auditLogOperationTransactionDeleted,
  AuditLogOperation.transactionImageDeleted =>
    l10n.auditLogOperationTransactionImageDeleted,
  AuditLogOperation.unknown => l10n.auditLogOperationUnknown,
};

/// 訂正されたフィールドの表示名を返す。
///
/// 履歴に残るフィールド名は Firestore のフィールド名 (`TransactionFirestoreKeys`) で、
/// 新しいバージョンのアプリが記録した未知のフィールド名は表示名を持たないため null を返す
/// (呼び出し側で表示から落とす)。
String? auditLogChangedFieldLabel({
  required String changedFieldName,
  required AppLocalizations l10n,
}) => switch (changedFieldName) {
  TransactionFirestoreKeys.excludedFromAggregation =>
    l10n.auditLogChangedFieldExcludedFromAggregation,
  TransactionFirestoreKeys.sourceImageObjectKey =>
    l10n.auditLogChangedFieldSourceImage,
  TransactionFirestoreKeys.confirmedDistinctTransactionIDs =>
    l10n.auditLogChangedFieldDuplicateDecision,
  _ => null,
};
