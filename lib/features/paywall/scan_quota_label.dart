import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';

/// 今月のスキャン残量の表示文言 (残量チップ・「記録する」シートの下部で共用)。
///
/// プレミアムなら「スキャン無制限」、無料プランなら残り回数 (0 未満にはしない)。
/// [scanQuota] が未取得 (null) で無料プランの場合は表示するものが無いため空文字。
String scanQuotaLabel({
  required AppLocalizations l10n,
  required bool isPremium,
  required ScanQuota? scanQuota,
}) {
  if (isPremium) {
    return l10n.scanQuotaUnlimited;
  }
  if (scanQuota == null) {
    return '';
  }
  return l10n.scanQuotaRemaining(remainingScanCount(scanQuota: scanQuota));
}

/// 無料プランの今月の残りスキャン回数 (0 未満にはしない)。
int remainingScanCount({required ScanQuota scanQuota}) =>
    (scanQuota.monthlyFreeScanLimit - scanQuota.monthlyScanCount).clamp(
      0,
      scanQuota.monthlyFreeScanLimit,
    );
