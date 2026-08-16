// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kashakeibo';

  @override
  String get monthlyIncome => 'Income';

  @override
  String get monthlyExpense => 'Spending';

  @override
  String get monthlyBalance => 'Balance';

  @override
  String get categoryBreakdown => 'Categories';

  @override
  String get monthlyTransactionsEmpty => 'No transactions this month';

  @override
  String get excludedFromAggregation => 'Excluded';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryEatingOut => 'Eating out';

  @override
  String get categoryDailyGoods => 'Daily goods';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categorySubscription => 'Subscriptions';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryOther => 'Other';
}
