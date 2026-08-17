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
