import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// The application name shown in the app bar and store listings
  ///
  /// In en, this message translates to:
  /// **'Kashakeibo'**
  String get appName;

  /// Label for the monthly income total
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get monthlyIncome;

  /// Label for the monthly spending total
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get monthlyExpense;

  /// Label for the monthly balance (income - spending)
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get monthlyBalance;

  /// Section title for the spending breakdown by category
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoryBreakdown;

  /// Placeholder shown when the month has no transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions this month'**
  String get monthlyTransactionsEmpty;

  /// Note on a transaction excluded from aggregation totals
  ///
  /// In en, this message translates to:
  /// **'Excluded'**
  String get excludedFromAggregation;

  /// Number of unresolved possible duplicate transaction pairs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 possible duplicate} other{{count} possible duplicates}}'**
  String duplicateCandidateCount(int count);

  /// Hint shown below the duplicate candidate banner
  ///
  /// In en, this message translates to:
  /// **'Tap to review'**
  String get duplicateCandidateReviewHint;

  /// Title of the duplicate candidate confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Review possible duplicate'**
  String get duplicateCandidateTitle;

  /// Explanation shown above a possible duplicate pair
  ///
  /// In en, this message translates to:
  /// **'These transactions have similar amounts, dates, and store names. Check whether they are the same expense.'**
  String get duplicateCandidateDescription;

  /// Reason why two transactions were detected as possible duplicates
  ///
  /// In en, this message translates to:
  /// **'Same amount with nearby dates and similar store names'**
  String get duplicateCandidateReason;

  /// Label on the transaction selected to remain after merging
  ///
  /// In en, this message translates to:
  /// **'Keep this transaction'**
  String get duplicateCandidateKeep;

  /// Button that merges two duplicate transactions
  ///
  /// In en, this message translates to:
  /// **'Merge into one'**
  String get mergeDuplicateCandidate;

  /// Button that confirms two transactions are not duplicates
  ///
  /// In en, this message translates to:
  /// **'Keep as separate expenses'**
  String get keepBothDuplicateCandidates;

  /// Tooltip for the previous month button
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// Tooltip for the next month button
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Tooltip for the settings button
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Link label for the terms of service
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Link label for the privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Link label for the disclosure required by Japan's Specified Commercial Transactions Act
  ///
  /// In en, this message translates to:
  /// **'Commercial Transaction Disclosure'**
  String get specifiedCommercialTransactionAct;

  /// Title of the account backup card
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get accountBackupTitle;

  /// Status shown while an anonymous account has no linked sign-in provider
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get accountBackupNotSet;

  /// Status shown after an account has a linked sign-in provider
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get accountBackupConfigured;

  /// Explanation shown before account linking
  ///
  /// In en, this message translates to:
  /// **'Link an account to keep your data when you change devices.'**
  String get accountBackupDescription;

  /// Explanation shown after account linking
  ///
  /// In en, this message translates to:
  /// **'Choose the same account on another device to access your saved data.'**
  String get accountBackupConfiguredDescription;

  /// Button that links Apple or signs in to an existing Apple-linked account
  ///
  /// In en, this message translates to:
  /// **'Link with Apple'**
  String get linkOrSignInWithApple;

  /// Button that links Google or signs in to an existing Google-linked account
  ///
  /// In en, this message translates to:
  /// **'Link with Google'**
  String get linkOrSignInWithGoogle;

  /// Message shown after account linking succeeds
  ///
  /// In en, this message translates to:
  /// **'Account linked'**
  String get accountLinked;

  /// Message shown after signing in to an account that was already linked on another device
  ///
  /// In en, this message translates to:
  /// **'Switched to your existing account'**
  String get existingAccountSignedIn;

  /// Title shown before linking when the anonymous user already has data
  ///
  /// In en, this message translates to:
  /// **'Check this device\'s data'**
  String get accountSwitchWarningTitle;

  /// Warning that switching to an existing account cannot carry over anonymous data
  ///
  /// In en, this message translates to:
  /// **'If the account you choose is already used on another device, this device\'s anonymous data will no longer be accessible. Review any transactions you need before continuing.'**
  String get accountSwitchWarningMessage;

  /// Button that accepts the anonymous data warning and continues account linking
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAccountLink;

  /// Button that starts account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Title of the account deletion confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmationTitle;

  /// Warning shown before account deletion
  ///
  /// In en, this message translates to:
  /// **'Your account and saved transactions will be permanently deleted. This cannot be undone.'**
  String get deleteAccountConfirmationMessage;

  /// Button that cancels a destructive confirmation
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button that confirms account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Transaction category: food (groceries)
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// Transaction category: eating out
  ///
  /// In en, this message translates to:
  /// **'Eating out'**
  String get categoryEatingOut;

  /// Transaction category: daily goods
  ///
  /// In en, this message translates to:
  /// **'Daily goods'**
  String get categoryDailyGoods;

  /// Transaction category: transportation
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransportation;

  /// Transaction category: subscriptions
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get categorySubscription;

  /// Transaction category: salary (income)
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// Transaction category: other
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @manualEntryOpen.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get manualEntryOpen;

  /// No description provided for @manualEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get manualEntryTitle;

  /// No description provided for @manualEntryAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get manualEntryAmount;

  /// No description provided for @manualEntryAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount of at least 1 yen'**
  String get manualEntryAmountRequired;

  /// No description provided for @manualEntryStore.
  ///
  /// In en, this message translates to:
  /// **'Store or note'**
  String get manualEntryStore;

  /// No description provided for @manualEntryDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash expense'**
  String get manualEntryDefaultTitle;

  /// No description provided for @manualEntryStoreRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a store or note'**
  String get manualEntryStoreRequired;

  /// No description provided for @manualEntryType.
  ///
  /// In en, this message translates to:
  /// **'Transaction type'**
  String get manualEntryType;

  /// No description provided for @manualEntryCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get manualEntryCategory;

  /// No description provided for @manualEntryCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get manualEntryCategoryRequired;

  /// No description provided for @manualEntryDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get manualEntryDate;

  /// No description provided for @manualEntryRegister.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get manualEntryRegister;

  /// No description provided for @manualEntryRegistered.
  ///
  /// In en, this message translates to:
  /// **'Transaction added'**
  String get manualEntryRegistered;

  /// No description provided for @transactionSourceReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get transactionSourceReceipt;

  /// No description provided for @transactionSourceScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get transactionSourceScreenshot;

  /// No description provided for @transactionSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get transactionSourceManual;

  /// No description provided for @transactionSourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get transactionSourceUnknown;

  /// No description provided for @addRecordOpen.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get addRecordOpen;

  /// No description provided for @addRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get addRecordTitle;

  /// No description provided for @captureReceiptWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get captureReceiptWithCamera;

  /// No description provided for @captureReceiptWithCameraDescription.
  ///
  /// In en, this message translates to:
  /// **'Snap a receipt and AI reads the details'**
  String get captureReceiptWithCameraDescription;

  /// No description provided for @capturePickFromPhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from Photos'**
  String get capturePickFromPhotoLibrary;

  /// No description provided for @capturePickFromPhotoLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'AI splits statement or order screenshots into entries'**
  String get capturePickFromPhotoLibraryDescription;

  /// No description provided for @manualEntryDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter cash spending without an image'**
  String get manualEntryDescription;

  /// No description provided for @captureAnalyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'AI is reading your receipt'**
  String get captureAnalyzingTitle;

  /// No description provided for @captureAnalyzingStepLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the image'**
  String get captureAnalyzingStepLoading;

  /// No description provided for @captureAnalyzingStepReading.
  ///
  /// In en, this message translates to:
  /// **'Reading amount and date'**
  String get captureAnalyzingStepReading;

  /// No description provided for @captureAnalyzingStepCategory.
  ///
  /// In en, this message translates to:
  /// **'Guessing the category'**
  String get captureAnalyzingStepCategory;

  /// No description provided for @captureAnalysisFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the image'**
  String get captureAnalysisFailedTitle;

  /// No description provided for @captureAnalysisNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transaction could be read from the image'**
  String get captureAnalysisNoTransactions;

  /// No description provided for @captureRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get captureRetry;

  /// No description provided for @captureManualFallback.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get captureManualFallback;

  /// No description provided for @captureRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get captureRetake;

  /// No description provided for @captureConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get captureConfirmTitle;

  /// No description provided for @captureSourceImageNote.
  ///
  /// In en, this message translates to:
  /// **'You can always revisit the source image from the transaction'**
  String get captureSourceImageNote;

  /// No description provided for @captureRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get captureRegister;

  /// Note shown above the candidate list when one image contains multiple transactions
  ///
  /// In en, this message translates to:
  /// **'Found {count} entries. Choose which ones to register.'**
  String captureCandidatesNote(int count);

  /// No description provided for @captureCandidateEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get captureCandidateEdit;

  /// No description provided for @captureCandidateApplyEdit.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get captureCandidateApplyEdit;

  /// Primary button that registers the selected candidates
  ///
  /// In en, this message translates to:
  /// **'Register {count} entries'**
  String captureRegisterCount(int count);

  /// No description provided for @captureRegistered.
  ///
  /// In en, this message translates to:
  /// **'Logged ✓'**
  String get captureRegistered;

  /// No description provided for @transactionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionDetailTitle;

  /// No description provided for @transactionDetailSourceImage.
  ///
  /// In en, this message translates to:
  /// **'Source image'**
  String get transactionDetailSourceImage;

  /// No description provided for @transactionDetailSourceImageNote.
  ///
  /// In en, this message translates to:
  /// **'You can revisit the source image anytime'**
  String get transactionDetailSourceImageNote;

  /// No description provided for @transactionDetailNoImageManual.
  ///
  /// In en, this message translates to:
  /// **'No image · entered manually'**
  String get transactionDetailNoImageManual;

  /// No description provided for @transactionDetailNoImage.
  ///
  /// In en, this message translates to:
  /// **'No source image'**
  String get transactionDetailNoImage;

  /// No description provided for @transactionDetailZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get transactionDetailZoom;

  /// No description provided for @transactionDetailDeleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete image only'**
  String get transactionDetailDeleteImage;

  /// No description provided for @transactionDetailDeleteImageConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the source image?'**
  String get transactionDetailDeleteImageConfirmationTitle;

  /// No description provided for @transactionDetailDeleteImageConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'The transaction stays and only the image is deleted. This cannot be undone.'**
  String get transactionDetailDeleteImageConfirmationMessage;

  /// No description provided for @transactionDetailImageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Source image deleted'**
  String get transactionDetailImageDeleted;

  /// No description provided for @transactionDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction'**
  String get transactionDetailDelete;

  /// No description provided for @transactionDetailDeleteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get transactionDetailDeleteConfirmationTitle;

  /// No description provided for @transactionDetailDeleteConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'The transaction and its source image will be permanently deleted. This cannot be undone.'**
  String get transactionDetailDeleteConfirmationMessage;

  /// No description provided for @transactionDetailDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDetailDeleted;

  /// No description provided for @transactionDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This transaction was deleted'**
  String get transactionDetailNotFound;

  /// No description provided for @transactionDetailProvenance.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get transactionDetailProvenance;

  /// No description provided for @transactionDetailExcludeFromAggregation.
  ///
  /// In en, this message translates to:
  /// **'Exclude from totals'**
  String get transactionDetailExcludeFromAggregation;

  /// No description provided for @transactionDetailExcludeFromAggregationDescription.
  ///
  /// In en, this message translates to:
  /// **'When on, this is left out of totals and the category breakdown'**
  String get transactionDetailExcludeFromAggregationDescription;

  /// No description provided for @transactionProvenanceAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Auto-imported'**
  String get transactionProvenanceAutomatic;

  /// No description provided for @transactionProvenanceAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjusted'**
  String get transactionProvenanceAdjusted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
