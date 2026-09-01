import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// ペイウォールを全画面ダイアログとして開く。
///
/// 閉じた時の値は、購入・復元でプレミアムになった場合に true (以降の解析を再試行できる)。
/// [trigger] は開いた導線 (残量チップ / 記録ボタン / 設定のプラン行 / 無料枠超過) の Analytics 用の値。
Future<bool?> showPaywall({
  required BuildContext context,
  required String trigger,
  required OpenExternalUri openExternalUri,
  required LogAnalyticsEvent logAnalyticsEvent,
}) {
  unawaited(
    logAnalyticsEvent(name: 'paywall_open', parameters: {'trigger': trigger}),
  );
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (context) => PaywallPage(
        openExternalUri: openExternalUri,
        logAnalyticsEvent: logAnalyticsEvent,
      ),
    ),
  );
}

/// プレミアム (スキャンし放題 + 全履歴) のハードペイウォール
/// (design_handoff_kashakeibo/README.md の 9「ペイウォール」)。
///
/// 今月の無料枠の消費状況、特典、月額 / 年額 (推奨) の料金カード、購入 CTA、購入の復元を表示する。
/// 価格はストアが解決した値 (RevenueCat の Offering) をそのまま表示する。
/// 既にプレミアムのユーザーには利用中の表示だけを出す。
class PaywallPage extends HookConsumerWidget {
  /// 利用規約・プライバシーポリシーを開く処理。
  final OpenExternalUri openExternalUri;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const PaywallPage({
    required this.openExternalUri,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final scanQuotaAsync = ref.watch(monthlyScanQuotaProvider);
    final premiumOfferingAsync = ref.watch(premiumOfferingProvider);
    final purchasePremiumPackage = ref.watch(purchasePremiumPackageProvider);
    final restorePurchases = ref.watch(restorePurchasesProvider);
    // 選択中の料金プラン。デザインどおり年額 (推奨) を初期選択にする。
    final selectedPackageType = useState(PackageType.annual);
    // 購入・復元の実行中。二重実行と閉じる操作を防ぐ。
    final purchaseInProgress = useState(false);
    // 閉じる経路 (X / システムの戻る) によらず一度だけ記録する。
    final paywallCloseLogged = useRef(false);
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;

    void logPaywallClose() {
      if (paywallCloseLogged.value) {
        return;
      }
      paywallCloseLogged.value = true;
      unawaited(logAnalyticsEvent(name: 'paywall_close'));
    }

    /// 購入・復元の結果を画面に表示し、プレミアムになっていれば true で閉じる。
    Future<void> runPurchaseAction({
      required String analyticsEventName,
      required Future<bool> Function() purchaseAction,
      required String premiumUnlockedMessage,
      required String notUnlockedMessage,
    }) async {
      if (purchaseInProgress.value) {
        return;
      }
      purchaseInProgress.value = true;
      unawaited(logAnalyticsEvent(name: '${analyticsEventName}_start'));
      try {
        final premiumUnlocked = await purchaseAction();
        if (!context.mounted) {
          return;
        }
        if (!premiumUnlocked) {
          unawaited(
            logAnalyticsEvent(name: '${analyticsEventName}_not_unlocked'),
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notUnlockedMessage)));
          return;
        }
        unawaited(logAnalyticsEvent(name: '${analyticsEventName}_succeeded'));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(premiumUnlockedMessage)));
        paywallCloseLogged.value = true;
        Navigator.of(context).pop(true);
      } on PlatformException catch (error) {
        if (!context.mounted) {
          return;
        }
        if (_isPurchaseCancelled(error: error)) {
          // ユーザーがストアの購入シートを閉じただけなのでエラー表示はしない
          unawaited(logAnalyticsEvent(name: '${analyticsEventName}_cancelled'));
          return;
        }
        unawaited(logAnalyticsEvent(name: '${analyticsEventName}_failed'));
        // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        unawaited(logAnalyticsEvent(name: '${analyticsEventName}_failed'));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (context.mounted) {
          purchaseInProgress.value = false;
        }
      }
    }

    return PopScope<bool>(
      canPop: !purchaseInProgress.value,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          logPaywallClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appColors.background,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: purchaseInProgress.value
                ? null
                : () {
                    logPaywallClose();
                    Navigator.of(context).pop(false);
                  },
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: appColors.accent200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: appColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isPremium ? l10n.paywallPremiumActive : l10n.paywallTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isPremium
                    ? l10n.paywallPremiumActiveDescription
                    : l10n.paywallSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appColors.textMuted,
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(height: AppSpacing.lg),
                const _SavingsResearchCard(),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (!isPremium && scanQuotaAsync.valueOrNull != null)
                _FreeQuotaBar(scanQuota: scanQuotaAsync.valueOrNull!),
              const SizedBox(height: AppSpacing.lg),
              _BenefitRow(label: l10n.paywallBenefitUnlimitedScans),
              const SizedBox(height: AppSpacing.sm),
              _BenefitRow(label: l10n.paywallBenefitFullHistory),
              const SizedBox(height: AppSpacing.sm),
              _BenefitRow(label: l10n.paywallBenefitFutureFeatures),
              if (!isPremium) ...[
                const SizedBox(height: AppSpacing.xl),
                premiumOfferingAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
                  error: (error, _) => Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: appColors.textMuted),
                  ),
                  data: (premiumOffering) {
                    final monthlyPackage = premiumOffering?.monthly;
                    final annualPackage = premiumOffering?.annual;
                    if (monthlyPackage == null && annualPackage == null) {
                      return Text(
                        l10n.paywallOfferingUnavailable,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: appColors.textMuted,
                        ),
                      );
                    }
                    final selectedPackage = switch (selectedPackageType.value) {
                      PackageType.annual => annualPackage ?? monthlyPackage,
                      _ => monthlyPackage ?? annualPackage,
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2 枚のカードの高さを揃える (バッジ・注記の有無で片方だけ高くならないように)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (monthlyPackage != null)
                                Expanded(
                                  child: _PlanCard(
                                    planLabel: l10n.paywallMonthlyPlan,
                                    priceString:
                                        monthlyPackage.storeProduct.priceString,
                                    badgeLabel: null,
                                    noteLabel: null,
                                    selected: selectedPackage == monthlyPackage,
                                    onTap: () {
                                      unawaited(
                                        logAnalyticsEvent(
                                          name: 'paywall_select_plan',
                                          parameters: {'plan': 'monthly'},
                                        ),
                                      );
                                      selectedPackageType.value =
                                          PackageType.monthly;
                                    },
                                  ),
                                ),
                              if (monthlyPackage != null &&
                                  annualPackage != null)
                                const SizedBox(width: AppSpacing.md),
                              if (annualPackage != null)
                                Expanded(
                                  child: _PlanCard(
                                    planLabel: l10n.paywallAnnualPlan,
                                    priceString:
                                        annualPackage.storeProduct.priceString,
                                    badgeLabel: _annualSavingsLabel(
                                      l10n: l10n,
                                      monthlyPackage: monthlyPackage,
                                      annualPackage: annualPackage,
                                    ),
                                    noteLabel: l10n.paywallPerMonthEquivalent(
                                      _perMonthPriceString(
                                        annualPackage: annualPackage,
                                      ),
                                    ),
                                    selected: selectedPackage == annualPackage,
                                    onTap: () {
                                      unawaited(
                                        logAnalyticsEvent(
                                          name: 'paywall_select_plan',
                                          parameters: {'plan': 'annual'},
                                        ),
                                      );
                                      selectedPackageType.value =
                                          PackageType.annual;
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed:
                              purchaseInProgress.value ||
                                  selectedPackage == null
                              ? null
                              : () => runPurchaseAction(
                                  analyticsEventName: 'paywall_purchase',
                                  purchaseAction: () async {
                                    final premiumPurchaseActivation =
                                        await purchasePremiumPackage(
                                          package: selectedPackage,
                                        );
                                    if (premiumPurchaseActivation ==
                                        PremiumPurchaseActivation.trial) {
                                      unawaited(
                                        logAnalyticsEvent(name: 'trial_start'),
                                      );
                                    } else if (premiumPurchaseActivation ==
                                        PremiumPurchaseActivation.paid) {
                                      unawaited(
                                        logAnalyticsEvent(
                                          name: 'purchase_complete',
                                        ),
                                      );
                                    }
                                    return premiumPurchaseActivation != null;
                                  },
                                  premiumUnlockedMessage: l10n.paywallPurchased,
                                  notUnlockedMessage:
                                      l10n.paywallOfferingUnavailable,
                                ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(l10n.paywallStartPremium),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.paywallCancelAnytime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: appColors.textMuted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        '·',
                        style: TextStyle(color: appColors.textMuted),
                      ),
                    ),
                    TextButton(
                      onPressed: purchaseInProgress.value
                          ? null
                          : () => runPurchaseAction(
                              analyticsEventName: 'paywall_restore',
                              purchaseAction: restorePurchases,
                              premiumUnlockedMessage: l10n.paywallRestored,
                              notUnlockedMessage: l10n.paywallRestoreNotFound,
                            ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.paywallRestore,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.paywallSubscriptionNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: appColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 「スキャンし放題」の表記と月次上限 (workers/image の monthlyPremiumScanLimit) を両立させる
                // フェアユースの注記 (誇大表示にしないための開示。documents/PROJECT.md の課金設計)
                Text(
                  l10n.paywallFairUseNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: appColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegalLinkButton(
                      label: l10n.termsOfService,
                      document: 'terms',
                      uri: legalDocumentUri(path: 'Terms'),
                      openExternalUri: openExternalUri,
                      logAnalyticsEvent: logAnalyticsEvent,
                    ),
                    Text('·', style: TextStyle(color: appColors.textMuted)),
                    _LegalLinkButton(
                      label: l10n.privacyPolicy,
                      document: 'privacy_policy',
                      uri: legalDocumentUri(
                        // プライバシーポリシーは日本語版と英語版の 2 種類のみ用意しているため、
                        // 日本語ロケール以外 (en / ko / zh 等) は英語版へフォールバックする。
                        path:
                            Localizations.localeOf(context).languageCode == 'ja'
                            ? 'PrivacyPolicy'
                            : 'PrivacyPolicy-en',
                      ),
                      openExternalUri: openExternalUri,
                      logAnalyticsEvent: logAnalyticsEvent,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ユーザーがストアの購入シートを閉じただけのエラーかどうか。
///
/// RevenueCat SDK は PlatformException の code に PurchasesErrorCode の序数を数値文字列で入れる。
/// 数値でない code (SDK 以外の PlatformException) は PurchasesErrorHelper が FormatException を
/// 投げるため、先に判定してキャンセル以外として扱う。
bool _isPurchaseCancelled({required PlatformException error}) =>
    num.tryParse(error.code) != null &&
    PurchasesErrorHelper.getErrorCode(error) ==
        PurchasesErrorCode.purchaseCancelledError;

/// 年額プランの割引率ラベル (月額 × 12 に対する割引。月額が無ければ表示しない)。
String? _annualSavingsLabel({
  required AppLocalizations l10n,
  required Package? monthlyPackage,
  required Package annualPackage,
}) {
  if (monthlyPackage == null || monthlyPackage.storeProduct.price <= 0) {
    return null;
  }
  final savingsPercent =
      ((1 -
                  annualPackage.storeProduct.price /
                      (monthlyPackage.storeProduct.price * 12)) *
              100)
          .round();
  if (savingsPercent <= 0) {
    return null;
  }
  return l10n.paywallAnnualSavings(savingsPercent);
}

/// 年額プランの月あたり換算価格 (ストアの通貨で表示)。
String _perMonthPriceString({required Package annualPackage}) =>
    NumberFormat.simpleCurrency(
      name: annualPackage.storeProduct.currencyCode,
      // 日本円は小数を持たないため。他通貨はストアの表示に合わせて 2 桁
      decimalDigits: annualPackage.storeProduct.currencyCode == 'JPY' ? 0 : 2,
    ).format(annualPackage.storeProduct.price / 12);

/// 家計簿をつけることの節約効果 (調査データ) を訴求するカード。
///
/// 出典は東証マネ部! (JPX 運営メディア) の「お金に関するアンケート」
/// (調査時期 2022年10月・全国20〜40代の会社員・有効回答 1,111 件)
/// https://money-bu-jpx.com/news/article042167/ 。
/// 家計簿をつけている人のうち「支出が減った」が 34.1%、その支出が減った人のうち
/// 月「5,000円〜1万円未満」の節約が 48.6% (最多) で、文言の「約半数」「月5,000円〜1万円未満」は
/// この 48.6% と価格帯に対応する。文言の数字は原典と一致させる。
class _SavingsResearchCard extends StatelessWidget {
  const _SavingsResearchCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: appShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.paywallSavingsClaim,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.paywallSavingsSource,
            style: TextStyle(fontSize: 9.5, color: appColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 今月の無料スキャンの消費バー (「今月の無料スキャン n/10」+ accent-500 のバー)。
class _FreeQuotaBar extends StatelessWidget {
  /// 今月のスキャン回数と無料枠。
  final ScanQuota scanQuota;

  const _FreeQuotaBar({required this.scanQuota});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: appShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.paywallFreeQuota(
              scanQuota.monthlyScanCount.clamp(
                0,
                scanQuota.monthlyFreeScanLimit,
              ),
              scanQuota.monthlyFreeScanLimit,
            ),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: scanQuota.monthlyFreeScanLimit == 0
                  ? 1
                  : (scanQuota.monthlyScanCount /
                            scanQuota.monthlyFreeScanLimit)
                        .clamp(0, 1)
                        .toDouble(),
              color: appColors.accent500,
              backgroundColor: appColors.neutral200,
            ),
          ),
        ],
      ),
    );
  }
}

/// 特典 1 行 (セージのチェックチップ + 特典名)。
class _BenefitRow extends StatelessWidget {
  /// 特典名。
  final String label;

  const _BenefitRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: appColors.sage100,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 16, color: appColors.sage700),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: AppTextStyles.body)),
      ],
    );
  }
}

/// 料金カード (プラン名 + 価格。年額は上部バッジと月換算の注記付き。選択中は accent 枠 + accent-100 地)。
class _PlanCard extends StatelessWidget {
  /// プラン名 (月額 / 年額)。
  final String planLabel;

  /// ストアが解決した価格の表示文字列。
  final String priceString;

  /// カード上部のバッジ (割引率)。無ければ表示しない。
  final String? badgeLabel;

  /// 価格の下の注記 (月換算)。無ければ表示しない。
  final String? noteLabel;

  /// 選択中かどうか。
  final bool selected;

  /// タップ時の処理。
  final VoidCallback onTap;

  const _PlanCard({
    required this.planLabel,
    required this.priceString,
    required this.badgeLabel,
    required this.noteLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? appColors.accent100 : appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? appColors.primary : appColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badgeLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: appColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: appColors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  planLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: appColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  priceString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (noteLabel != null)
                  Text(
                    noteLabel!,
                    style: TextStyle(fontSize: 10, color: appColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 利用規約・プライバシーポリシーへのリンク (サブスクリプションの表示要件)。
class _LegalLinkButton extends StatelessWidget {
  /// リンクの文言。
  final String label;

  /// Analytics で法務ドキュメントを識別する値。
  final String document;

  /// 開く URL。
  final Uri uri;

  /// 外部 URL を開く処理。
  final OpenExternalUri openExternalUri;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const _LegalLinkButton({
    required this.label,
    required this.document,
    required this.uri,
    required this.openExternalUri,
    required this.logAnalyticsEvent,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        unawaited(
          logAnalyticsEvent(
            name: 'paywall_legal_document_open',
            parameters: {'document': document},
          ),
        );
        try {
          await openExternalUri(uri: uri);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
