import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kashakeibo/features/paywall/paywall_page.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 無料プランの履歴制限 (free_plan_history_limit.dart) を伝え、タップでペイウォールを開く注記。
///
/// 過去の記録へ届く画面 (検索・操作履歴) で、絞り込みの下限が制限によるものだと分かるようにする。
class FreePlanHistoryNotice extends StatelessWidget {
  /// 制限の内容を説明する文言 (検索 / 操作履歴で書き分ける)。
  final String message;

  /// ペイウォールを開いた導線の Analytics 用の値。
  final String paywallTrigger;

  /// 利用規約・プライバシーポリシーを開く処理 (ペイウォールへ渡す)。
  final OpenExternalUri openExternalUri;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const FreePlanHistoryNotice({
    required this.message,
    required this.paywallTrigger,
    required this.openExternalUri,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    return Material(
      color: appColors.sage100,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: appColors.sage300),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: InkWell(
        onTap: () {
          unawaited(logAnalyticsEvent(name: 'history_limit_paywall_open'));
          showPaywall(
            context: context,
            trigger: paywallTrigger,
            openExternalUri: openExternalUri,
            logAnalyticsEvent: logAnalyticsEvent,
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: 14,
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: appColors.sage700),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: appColors.sage800,
                      ),
                    ),
                    Text(
                      l10n.freePlanHistoryLimitUpgrade,
                      style: AppTextStyles.caption.copyWith(
                        color: appColors.sage700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: appColors.sage700),
            ],
          ),
        ),
      ),
    );
  }
}
