// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'カシャケイボ';

  @override
  String get monthlyIncome => '収入';

  @override
  String get monthlyExpense => '支出';

  @override
  String get monthlyBalance => '収支';

  @override
  String get categoryBreakdown => 'カテゴリ内訳';

  @override
  String get monthlyTransactionsEmpty => '今月の明細はまだありません';

  @override
  String get excludedFromAggregation => '計算対象外';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get categoryFood => '食費';

  @override
  String get categoryDailyGoods => '日用品';

  @override
  String get categoryTransportation => '交通費';

  @override
  String get categoryUtilities => '水道・光熱費';

  @override
  String get categoryCommunication => '通信費';

  @override
  String get categoryHousing => '住居費';

  @override
  String get categoryMedical => '医療費';

  @override
  String get categoryEntertainment => '娯楽費';

  @override
  String get categoryClothing => '衣服・美容';

  @override
  String get categoryEducation => '教育費';

  @override
  String get categorySalary => '給与';

  @override
  String get categoryOther => 'その他';
}
