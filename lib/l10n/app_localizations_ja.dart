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
  String get monthlyBalance => '残り';

  @override
  String get categoryBreakdown => 'カテゴリ内訳';

  @override
  String get monthlyTransactionsEmpty => '今月の明細はまだありません';

  @override
  String get excludedFromAggregation => '計算対象外';

  @override
  String duplicateCandidateCount(int count) {
    return '重複の可能性が$count件あります';
  }

  @override
  String get duplicateCandidateReviewHint => 'タップして確認';

  @override
  String get duplicateCandidateTitle => '重複候補の確認';

  @override
  String get duplicateCandidateDescription => '金額・日付・店名が近い明細です。同じ支出か確認してください。';

  @override
  String get duplicateCandidateReason => '金額・日付・店名が一致';

  @override
  String get mergeDuplicateCandidate => '1件にまとめる';

  @override
  String get keepBothDuplicateCandidates => '別々の支出として残す';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get categoryFood => '食費';

  @override
  String get categoryEatingOut => '外食';

  @override
  String get categoryDailyGoods => '日用品';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categorySubscription => 'サブスク';

  @override
  String get categorySalary => '給与';

  @override
  String get categoryOther => 'その他';
}
