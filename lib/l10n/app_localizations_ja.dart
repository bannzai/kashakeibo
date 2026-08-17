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
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get openSettings => '設定を開く';

  @override
  String get settingsTitle => '設定';

  @override
  String get accountBackupTitle => 'バックアップ';

  @override
  String get accountBackupNotSet => '未設定';

  @override
  String get accountBackupConfigured => '設定済み';

  @override
  String get accountBackupDescription => 'アカウントをリンクすると、機種変更してもデータが引き継げます。';

  @override
  String get accountBackupConfiguredDescription =>
      '別の端末で同じアカウントを選ぶと、保存済みのデータを引き継げます。';

  @override
  String get linkOrSignInWithApple => 'Appleでリンク';

  @override
  String get linkOrSignInWithGoogle => 'Googleでリンク';

  @override
  String get accountLinked => 'アカウントをリンクしました';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountConfirmationTitle => 'アカウントを削除しますか？';

  @override
  String get deleteAccountConfirmationMessage =>
      'アカウントと保存済みの明細は完全に削除され、元に戻せません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除する';

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
