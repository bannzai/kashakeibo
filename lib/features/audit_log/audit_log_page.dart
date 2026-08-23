import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/audit_log.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/audit_log_labels.dart';
import 'package:kashakeibo/provider/audit_log.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';

/// 操作履歴画面 (issue #73 の訂正削除履歴)。
///
/// 明細の追加・訂正・削除と元画像の削除の履歴を、記録されたサーバー時刻の新しい順で表示する。
/// 履歴は読み取り専用で、ここから明細を復元する導線は持たない。
class AuditLogPage extends ConsumerWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogsProvider);
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditLogTitle)),
      body: SafeArea(
        child: auditLogsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // エラーメッセージは加工せずそのまま表示する
          // (`.claude/rules/coding-conventions.md`)。
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(error.toString()),
            ),
          ),
          data: (auditLogs) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              14,
              AppSpacing.xl,
              24,
            ),
            children: [
              Text(
                l10n.auditLogDescription,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  color: appColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              if (auditLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      l10n.auditLogEmpty,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: appColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                for (final auditLog in auditLogs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _AuditLogRow(auditLog: auditLog),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作履歴 1 件の行。操作種別のラベル・対象明細の店名と金額・記録時刻を表示する。
class _AuditLogRow extends StatelessWidget {
  /// 表示する操作履歴。
  final AuditLog auditLog;

  const _AuditLogRow({required this.auditLog});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    final serverCreatedDateTime = auditLog.serverCreatedDateTime;
    final changedFieldLabels = [
      for (final changedFieldName in auditLog.changedFieldNames)
        ?auditLogChangedFieldLabel(
          changedFieldName: changedFieldName,
          l10n: l10n,
        ),
    ];
    final transactionAmount = auditLog.transactionAmount;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: appColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              auditLogOperationLabel(operation: auditLog.operation, l10n: l10n),
              style: AppTextStyles.label.copyWith(color: appColors.neutral700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (auditLog.transactionTitle != null)
                  Text(
                    auditLog.transactionTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                Text(
                  [
                    // サーバー時刻が確定するまでは日時を持たない (provider/audit_log.dart)。
                    if (serverCreatedDateTime == null)
                      l10n.auditLogSyncing
                    else
                      DateFormat.yMd(
                        Localizations.localeOf(context).toString(),
                      ).add_Hm().format(serverCreatedDateTime.toLocal()),
                    ...changedFieldLabels,
                  ].join(' · '),
                  style: AppTextStyles.caption.copyWith(
                    color: appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (transactionAmount != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              '¥${formatAmountNumber(amount: transactionAmount)}',
              style: AppTextStyles.amountRow,
            ),
          ],
        ],
      ),
    );
  }
}
