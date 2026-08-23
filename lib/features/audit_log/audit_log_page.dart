import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/features/audit_log/audit_log_client.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_limit.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_notice.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/audit_log_labels.dart';
import 'package:kashakeibo/provider/audit_log.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 操作履歴画面 (issue #73 の訂正削除履歴)。
///
/// 明細の追加・訂正・削除と元画像の削除の履歴を、Worker から取得した新しい順で表示する。
/// リアルタイムには追従しないため、画面を開いたまま行った操作は pull-to-refresh で取り直す。
/// 履歴は読み取り専用で、ここから明細を復元する導線は持たない。
/// 無料プランでは表示できる期間が制限され (features/paywall/free_plan_history_limit.dart)、
/// その旨の注記からペイウォールへ誘導する。
class AuditLogPage extends ConsumerWidget {
  /// 利用規約・プライバシーポリシーを開く処理 (ペイウォールへ渡す)。
  final OpenExternalUri openExternalUri;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const AuditLogPage({
    required this.openExternalUri,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogsProvider);
    // コールバックで ref を触らないよう、取り直す操作は build で確保する
    // (`.claude/rules/riverpod-rules.md`)。
    final auditLogsNotifier = ref.watch(auditLogsProvider.notifier);
    final isPremium = ref.watch(isPremiumProvider);
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.auditLogTitle)),
      body: SafeArea(
        child: auditLogsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // 通信が復旧した後に画面内から取り直せるよう、エラー表示も引き下げを受け付ける。
          // エラーメッセージは加工せずそのまま表示する
          // (`.claude/rules/coding-conventions.md`)。
          error: (error, _) => RefreshIndicator(
            onRefresh: auditLogsNotifier.refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              // エラー文が画面に収まる時も引いて取り直せるようにする。
              physics: const AlwaysScrollableScrollPhysics(),
              children: [Center(child: Text(error.toString()))],
            ),
          ),
          data: (auditLogs) => RefreshIndicator(
            onRefresh: auditLogsNotifier.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                14,
                AppSpacing.xl,
                24,
              ),
              // 履歴が空・少数で画面に収まる時も引いて取り直せるようにする。
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  l10n.auditLogDescription,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.6,
                    color: appColors.textMuted,
                  ),
                ),
                // 無料プランで表示できるのは直近 freePlanHistoryMonthCount ヶ月だけのため、
                // 一覧が古い履歴を含まない理由を先頭で伝える。
                if (!isPremium) ...[
                  const SizedBox(height: 14),
                  FreePlanHistoryNotice(
                    message: l10n.auditLogFreePlanHistoryLimit(
                      freePlanHistoryMonthCount,
                    ),
                    paywallTrigger: 'audit_log_history_limit',
                    openExternalUri: openExternalUri,
                    logAnalyticsEvent: logAnalyticsEvent,
                  ),
                ],
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
                    DateFormat.yMd(
                      Localizations.localeOf(context).toString(),
                    ).add_Hm().format(auditLog.occurredAt.toLocal()),
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
