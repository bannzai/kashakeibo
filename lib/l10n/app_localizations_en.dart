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
  String get openSettings => 'Open settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get accountBackupTitle => 'Backup';

  @override
  String get accountBackupNotSet => 'Not set';

  @override
  String get accountBackupConfigured => 'Set up';

  @override
  String get accountBackupDescription =>
      'Link an account to keep your data when you change devices.';

  @override
  String get accountBackupConfiguredDescription =>
      'Choose the same account on another device to access your saved data.';

  @override
  String get linkOrSignInWithApple => 'Link with Apple';

  @override
  String get linkOrSignInWithGoogle => 'Link with Google';

  @override
  String get accountLinked => 'Account linked';

  @override
  String get accountSwitchWarningTitle => 'Check this device\'s data';

  @override
  String get accountSwitchWarningMessage =>
      'If the account you choose is already used on another device, this device\'s anonymous data will no longer be accessible. Review any transactions you need before continuing.';

  @override
  String get continueAccountLink => 'Continue';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirmationTitle => 'Delete your account?';

  @override
  String get deleteAccountConfirmationMessage =>
      'Your account and saved transactions will be permanently deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

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
