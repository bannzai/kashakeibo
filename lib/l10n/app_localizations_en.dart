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
  String duplicateCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possible duplicates',
      one: '1 possible duplicate',
    );
    return '$_temp0';
  }

  @override
  String get duplicateCandidateReviewHint => 'Tap to review';

  @override
  String get duplicateCandidateTitle => 'Review possible duplicate';

  @override
  String get duplicateCandidateDescription =>
      'These transactions have similar amounts, dates, and store names. Check whether they are the same expense.';

  @override
  String get duplicateCandidateReason =>
      'Same amount with nearby dates and similar store names';

  @override
  String get duplicateCandidateKeep => 'Keep this transaction';

  @override
  String get mergeDuplicateCandidate => 'Merge into one';

  @override
  String get keepBothDuplicateCandidates => 'Keep as separate expenses';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get openSettings => 'Open settings';

  @override
  String get settings => 'Settings';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get specifiedCommercialTransactionAct =>
      'Commercial Transaction Disclosure';

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
  String get existingAccountSignedIn => 'Switched to your existing account';

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

  @override
  String get manualEntryOpen => 'Enter manually';

  @override
  String get manualEntryTitle => 'Manual entry';

  @override
  String get manualEntryAmount => 'Amount';

  @override
  String get manualEntryAmountRequired => 'Enter an amount of at least 1 yen';

  @override
  String get manualEntryStore => 'Store or note';

  @override
  String get manualEntryDefaultTitle => 'Cash expense';

  @override
  String get manualEntryStoreRequired => 'Enter a store or note';

  @override
  String get manualEntryType => 'Transaction type';

  @override
  String get manualEntryCategory => 'Category';

  @override
  String get manualEntryCategoryRequired => 'Select a category';

  @override
  String get manualEntryDate => 'Date';

  @override
  String get manualEntryRegister => 'Add transaction';

  @override
  String get manualEntryRegistered => 'Transaction added';

  @override
  String get transactionSourceReceipt => 'Receipt';

  @override
  String get transactionSourceScreenshot => 'Screenshot';

  @override
  String get transactionSourceManual => 'Manual';

  @override
  String get transactionSourceUnknown => 'Unknown source';
}
