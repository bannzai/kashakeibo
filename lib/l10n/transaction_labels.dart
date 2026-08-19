import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';

/// カテゴリの表示名を返す。
String categoryLabel({
  required TransactionCategory category,
  required AppLocalizations l10n,
}) => switch (category) {
  TransactionCategory.food => l10n.categoryFood,
  TransactionCategory.eatingOut => l10n.categoryEatingOut,
  TransactionCategory.dailyGoods => l10n.categoryDailyGoods,
  TransactionCategory.transportation => l10n.categoryTransportation,
  TransactionCategory.subscription => l10n.categorySubscription,
  TransactionCategory.salary => l10n.categorySalary,
  TransactionCategory.other => l10n.categoryOther,
};

/// 明細の出所の表示名を返す。
String transactionSourceLabel({
  required TransactionSource source,
  required AppLocalizations l10n,
}) => switch (source) {
  TransactionSource.receipt => l10n.transactionSourceReceipt,
  TransactionSource.screenshot => l10n.transactionSourceScreenshot,
  TransactionSource.manual => l10n.transactionSourceManual,
  TransactionSource.unknown => l10n.transactionSourceUnknown,
};

/// 出所記録 (AI 解析結果を修正したか) の表示名を返す。
///
/// 撮影・取込 (receipt / screenshot) の明細だけが対象で、修正なしは「自動取込」、
/// 修正ありは「手調整」。手動入力・出所不明は [transactionSourceLabel] だけで
/// 表しきれるため null を返す。
String? transactionProvenanceLabel({
  required Transaction transaction,
  required AppLocalizations l10n,
}) => switch (transaction.source) {
  TransactionSource.receipt || TransactionSource.screenshot =>
    transaction.analysisAdjustedByUser
        ? l10n.transactionProvenanceAdjusted
        : l10n.transactionProvenanceAutomatic,
  TransactionSource.manual || TransactionSource.unknown => null,
};
