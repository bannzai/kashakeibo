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

  @override
  String get addRecordOpen => 'Add a record';

  @override
  String get addRecordTitle => 'Add a record';

  @override
  String get captureReceiptWithCamera => 'Take a photo';

  @override
  String get captureReceiptWithCameraDescription =>
      'Snap a receipt and AI reads the details';

  @override
  String get capturePickFromPhotoLibrary => 'Choose from Photos';

  @override
  String get capturePickFromPhotoLibraryDescription =>
      'AI splits statement or order screenshots into entries';

  @override
  String get manualEntryDescription => 'Enter cash spending without an image';

  @override
  String get captureAnalyzingTitle => 'AI is reading your image';

  @override
  String get captureAnalyzingStepLoading => 'Loading the image';

  @override
  String get captureAnalyzingStepReading => 'Reading amount and date';

  @override
  String get captureAnalyzingStepCategory => 'Guessing the category';

  @override
  String get captureAnalysisFailedTitle => 'Couldn\'t read the image';

  @override
  String get captureAnalysisNoTransactions =>
      'No transaction could be read from the image';

  @override
  String get captureRetry => 'Try again';

  @override
  String get captureManualFallback => 'Enter manually';

  @override
  String get captureRetake => 'Retake';

  @override
  String get captureConfirmTitle => 'Review details';

  @override
  String get captureSourceImageNote =>
      'You can always revisit the source image from the transaction';

  @override
  String get captureRegister => 'Register';

  @override
  String captureCandidatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count entries. Choose which ones to register.',
      one: 'Found 1 entry. Choose which one to register.',
    );
    return '$_temp0';
  }

  @override
  String get captureCandidateEdit => 'Edit';

  @override
  String get captureCandidateApplyEdit => 'Apply changes';

  @override
  String captureRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Register $count entries',
      one: 'Register 1 entry',
    );
    return '$_temp0';
  }

  @override
  String get captureRegistered => 'Logged ✓';

  @override
  String get transactionDetailTitle => 'Transaction';

  @override
  String get transactionDetailSourceImage => 'Source image';

  @override
  String get transactionDetailSourceImageNote =>
      'You can revisit the source image anytime';

  @override
  String get transactionDetailNoImageManual => 'No image · entered manually';

  @override
  String get transactionDetailNoImage => 'No source image';

  @override
  String get transactionDetailZoom => 'Zoom';

  @override
  String get transactionDetailDeleteImage => 'Delete image only';

  @override
  String get transactionDetailDeleteImageConfirmationTitle =>
      'Delete the source image?';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      'The transaction stays and only the image is deleted. This cannot be undone.';

  @override
  String get transactionDetailImageDeleted => 'Source image deleted';

  @override
  String get transactionDetailDelete => 'Delete transaction';

  @override
  String get transactionDetailDeleteConfirmationTitle =>
      'Delete this transaction?';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      'The transaction and its source image will be permanently deleted. This cannot be undone.';

  @override
  String get transactionDetailDeleted => 'Transaction deleted';

  @override
  String get transactionDetailNotFound => 'This transaction was deleted';

  @override
  String get transactionDetailProvenance => 'Source';

  @override
  String get transactionDetailExcludeFromAggregation => 'Exclude from totals';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      'When on, this is left out of totals and the category breakdown';

  @override
  String get transactionProvenanceAutomatic => 'Auto-imported';

  @override
  String get transactionProvenanceAdjusted => 'Adjusted';

  @override
  String get capturesSection => 'Captures';

  @override
  String scanQuotaRemaining(int count) {
    return '$count scans left';
  }

  @override
  String get scanQuotaUnlimited => 'Unlimited scans';

  @override
  String get scanQuotaExhausted => 'You\'ve used all free scans this month';

  @override
  String get paywallTitle => 'Go unlimited with Premium';

  @override
  String get paywallSubtitle =>
      'No account linking. Just snap, and Premium reads every receipt and statement for you.';

  @override
  String paywallFreeQuota(int used, int limit) {
    return 'Free scans this month $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => 'Unlimited scans';

  @override
  String get paywallBenefitFullHistory => 'Full history, every month';

  @override
  String get paywallBenefitFutureFeatures => 'Upcoming features';

  @override
  String get paywallMonthlyPlan => 'Monthly';

  @override
  String get paywallAnnualPlan => 'Annual';

  @override
  String get paywallRecommended => 'Best value';

  @override
  String paywallAnnualSavings(int percent) {
    return 'Save $percent%';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/mo';
  }

  @override
  String get paywallStartPremium => 'Start Premium';

  @override
  String get paywallCancelAnytime => 'Cancel anytime';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallRestored => 'Purchases restored. Premium is active.';

  @override
  String get paywallRestoreNotFound => 'No purchases to restore';

  @override
  String get paywallPurchased => 'Premium is active. Scan as much as you like!';

  @override
  String get paywallPremiumActive => 'Premium is active';

  @override
  String get paywallPremiumActiveDescription =>
      'You have unlimited scans and full history.';

  @override
  String get paywallOfferingUnavailable => 'Plans are unavailable right now';

  @override
  String get paywallSubscriptionNote =>
      'Payment is charged to your store account at confirmation. The subscription renews automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel it in your store account settings.';

  @override
  String get settingsPlan => 'Plan';

  @override
  String get planFree => 'Free';

  @override
  String get planPremium => 'Premium';
}
