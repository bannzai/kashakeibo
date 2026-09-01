import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

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
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
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
  /// **'AI is reading your image'**
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
  /// **'{count, plural, =1{Found 1 entry. Choose which one to register.} other{Found {count} entries. Choose which ones to register.}}'**
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
  /// **'{count, plural, =1{Register 1 entry} other{Register {count} entries}}'**
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

  /// No description provided for @capturesSection.
  ///
  /// In en, this message translates to:
  /// **'Captures'**
  String get capturesSection;

  /// No description provided for @scanQuotaRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} scans left'**
  String scanQuotaRemaining(int count);

  /// No description provided for @scanQuotaUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Scan freely'**
  String get scanQuotaUnlimited;

  /// No description provided for @scanQuotaExhausted.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all free scans this month'**
  String get scanQuotaExhausted;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan freely with Premium'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No account linking. Just snap, and Premium reads every receipt and statement for you.'**
  String get paywallSubtitle;

  /// ペイウォールの節約効果訴求。出典: 東証マネ部!「お金に関するアンケート」(2022年10月、n=1,111) https://money-bu-jpx.com/news/article042167/ — 家計簿で支出が減った人 (34.1%) のうち 48.6% が月5,000円〜1万円未満の節約と回答。数字は原典と一致させること
  ///
  /// In en, this message translates to:
  /// **'About half of people who cut spending with a household budget saved ¥5,000 to under ¥10,000 a month*'**
  String get paywallSavingsClaim;

  /// 節約効果訴求の出典注記 (調査主体・時期・N数)
  ///
  /// In en, this message translates to:
  /// **'* Survey by JPX\'s Money-bu! (Oct 2022, 1,111 office workers in Japan)'**
  String get paywallSavingsSource;

  /// No description provided for @paywallFreeQuota.
  ///
  /// In en, this message translates to:
  /// **'Free scans this month {used}/{limit}'**
  String paywallFreeQuota(int used, int limit);

  /// No description provided for @paywallBenefitUnlimitedScans.
  ///
  /// In en, this message translates to:
  /// **'Scan freely'**
  String get paywallBenefitUnlimitedScans;

  /// No description provided for @paywallBenefitFullHistory.
  ///
  /// In en, this message translates to:
  /// **'Full history, every month'**
  String get paywallBenefitFullHistory;

  /// No description provided for @paywallBenefitFutureFeatures.
  ///
  /// In en, this message translates to:
  /// **'Upcoming features'**
  String get paywallBenefitFutureFeatures;

  /// No description provided for @paywallMonthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthlyPlan;

  /// No description provided for @paywallAnnualPlan.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get paywallAnnualPlan;

  /// No description provided for @paywallRecommended.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get paywallRecommended;

  /// No description provided for @paywallAnnualSavings.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallAnnualSavings(int percent);

  /// No description provided for @paywallPerMonthEquivalent.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String paywallPerMonthEquivalent(String price);

  /// No description provided for @paywallStartPremium.
  ///
  /// In en, this message translates to:
  /// **'Start Premium'**
  String get paywallStartPremium;

  /// No description provided for @paywallCancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get paywallCancelAnytime;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// No description provided for @paywallRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored. Premium is active.'**
  String get paywallRestored;

  /// No description provided for @paywallRestoreNotFound.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore'**
  String get paywallRestoreNotFound;

  /// No description provided for @paywallPurchased.
  ///
  /// In en, this message translates to:
  /// **'Premium is active. Scan freely!'**
  String get paywallPurchased;

  /// No description provided for @paywallPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium is active'**
  String get paywallPremiumActive;

  /// No description provided for @paywallPremiumActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'You can scan freely and browse your full history.'**
  String get paywallPremiumActiveDescription;

  /// No description provided for @paywallOfferingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans are unavailable right now'**
  String get paywallOfferingUnavailable;

  /// No description provided for @paywallFairUseNote.
  ///
  /// In en, this message translates to:
  /// **'Scanning is subject to a monthly fair-use limit that typical use won\'t reach.'**
  String get paywallFairUseNote;

  /// No description provided for @paywallSubscriptionNote.
  ///
  /// In en, this message translates to:
  /// **'Payment is charged to your store account at confirmation. The subscription renews automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel it in your store account settings.'**
  String get paywallSubscriptionNote;

  /// No description provided for @settingsPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get settingsPlan;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planFree;

  /// No description provided for @planPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planPremium;

  /// Settings row that opens the history of transaction edits and deletions
  ///
  /// In en, this message translates to:
  /// **'Operation history'**
  String get settingsAuditLog;

  /// Title of the operation history screen
  ///
  /// In en, this message translates to:
  /// **'Operation history'**
  String get auditLogTitle;

  /// Explanation shown at the top of the operation history screen
  ///
  /// In en, this message translates to:
  /// **'A record of transactions you added, corrected, or deleted, and of deleted source images.'**
  String get auditLogDescription;

  /// Placeholder shown when no operation has been recorded
  ///
  /// In en, this message translates to:
  /// **'No operations recorded yet'**
  String get auditLogEmpty;

  /// Shown instead of a timestamp until the server records the operation time
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get auditLogSyncing;

  /// Operation label for creating a transaction
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get auditLogOperationTransactionCreated;

  /// Operation label for correcting a transaction
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get auditLogOperationTransactionUpdated;

  /// Operation label for deleting a transaction
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get auditLogOperationTransactionDeleted;

  /// Operation label for deleting the source image of a transaction
  ///
  /// In en, this message translates to:
  /// **'Image deleted'**
  String get auditLogOperationTransactionImageDeleted;

  /// Operation label for a record written by a newer version of the app
  ///
  /// In en, this message translates to:
  /// **'Other operation'**
  String get auditLogOperationUnknown;

  /// Name of the corrected field: whether the transaction counts toward totals
  ///
  /// In en, this message translates to:
  /// **'Totals inclusion'**
  String get auditLogChangedFieldExcludedFromAggregation;

  /// Name of the corrected field: link to the source image
  ///
  /// In en, this message translates to:
  /// **'Source image'**
  String get auditLogChangedFieldSourceImage;

  /// Name of the corrected field: the merge or keep-both decision on duplicates
  ///
  /// In en, this message translates to:
  /// **'Duplicate decision'**
  String get auditLogChangedFieldDuplicateDecision;

  /// Tooltip for the search button in the monthly screen app bar
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get transactionSearchOpen;

  /// Title of the transaction search screen
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get transactionSearchTitle;

  /// Section label for the transaction date range
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get transactionSearchPeriod;

  /// Label of the start date field
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transactionSearchDateFrom;

  /// Label of the end date field
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transactionSearchDateTo;

  /// Shown on a date field that has no date selected
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get transactionSearchDateUnset;

  /// Section label for the amount range
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get transactionSearchAmount;

  /// Label of the minimum amount field
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get transactionSearchMinimumAmount;

  /// Label of the maximum amount field
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get transactionSearchMaximumAmount;

  /// Label of the store name keyword field
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get transactionSearchTitleKeyword;

  /// Button that runs the search with the entered conditions
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get transactionSearchSubmit;

  /// Button that clears every search condition
  ///
  /// In en, this message translates to:
  /// **'Clear conditions'**
  String get transactionSearchClear;

  /// Message shown before any search condition is entered
  ///
  /// In en, this message translates to:
  /// **'Enter at least one condition'**
  String get transactionSearchConditionRequired;

  /// Validation message when the end date precedes the start date
  ///
  /// In en, this message translates to:
  /// **'Set the end date to the start date or later'**
  String get transactionSearchDateRangeInvalid;

  /// Validation message when the maximum amount is below the minimum amount
  ///
  /// In en, this message translates to:
  /// **'Set the maximum to the minimum or more'**
  String get transactionSearchAmountRangeInvalid;

  /// Placeholder shown when the search returns nothing
  ///
  /// In en, this message translates to:
  /// **'No transactions match your conditions'**
  String get transactionSearchNoResults;

  /// Number of transactions found by the search
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String transactionSearchResultCount(int count);

  /// Notice shown on the search screen to free plan users, explaining that older transactions are out of range
  ///
  /// In en, this message translates to:
  /// **'The free plan searches only the last {monthCount} months'**
  String transactionSearchFreePlanHistoryLimit(int monthCount);

  /// Notice shown on the operation history screen to free plan users, explaining that older operations are out of range
  ///
  /// In en, this message translates to:
  /// **'The free plan shows only the last {monthCount} months of operations'**
  String auditLogFreePlanHistoryLimit(int monthCount);

  /// Tappable hint under the free plan history notice that opens the paywall
  ///
  /// In en, this message translates to:
  /// **'See your full history with Premium'**
  String get freePlanHistoryLimitUpgrade;

  /// Button that advances to the next onboarding step
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// Final onboarding button that opens the paywall
  ///
  /// In en, this message translates to:
  /// **'See my Premium plan'**
  String get onboardingSeePremium;

  /// Onboarding welcome title
  ///
  /// In en, this message translates to:
  /// **'Make money tracking effortless'**
  String get onboardingWelcomeTitle;

  /// Onboarding welcome description
  ///
  /// In en, this message translates to:
  /// **'Turn receipts and online statements into records with a photo or screenshot'**
  String get onboardingWelcomeDescription;

  /// Long funnel value explanation title
  ///
  /// In en, this message translates to:
  /// **'Capture it now and review it later'**
  String get onboardingValueTitle;

  /// Long funnel value explanation
  ///
  /// In en, this message translates to:
  /// **'Kashakeibo uses AI to organize the store, amount, date, and category so you can spend your time understanding your money'**
  String get onboardingValueDescription;

  /// Pain recognition question title
  ///
  /// In en, this message translates to:
  /// **'What makes budgeting hardest?'**
  String get onboardingPainTitle;

  /// Pain recognition question description
  ///
  /// In en, this message translates to:
  /// **'Choose the challenge you want to solve first'**
  String get onboardingPainDescription;

  /// Pain option for manual entry effort
  ///
  /// In en, this message translates to:
  /// **'Entering every purchase takes too much work'**
  String get onboardingPainRecordingEffort;

  /// Pain option for spending visibility
  ///
  /// In en, this message translates to:
  /// **'I cannot see where my money goes'**
  String get onboardingPainSpendingVisibility;

  /// Pain option for review time
  ///
  /// In en, this message translates to:
  /// **'I never find time to review spending'**
  String get onboardingPainReviewTime;

  /// Personalization question for record sources
  ///
  /// In en, this message translates to:
  /// **'What do you want to capture?'**
  String get onboardingSourceTitle;

  /// Record source question description
  ///
  /// In en, this message translates to:
  /// **'Your answer shapes the plan we show you'**
  String get onboardingSourceDescription;

  /// Receipt source option
  ///
  /// In en, this message translates to:
  /// **'Paper receipts'**
  String get onboardingSourceReceipt;

  /// Online statement source option
  ///
  /// In en, this message translates to:
  /// **'Card and online shopping statements'**
  String get onboardingSourceOnlineStatement;

  /// All record sources option
  ///
  /// In en, this message translates to:
  /// **'Both receipts and online statements'**
  String get onboardingSourceBoth;

  /// Long funnel tracking frequency question
  ///
  /// In en, this message translates to:
  /// **'How often do you track spending now?'**
  String get onboardingFrequencyTitle;

  /// Tracking frequency question description
  ///
  /// In en, this message translates to:
  /// **'There is no wrong answer'**
  String get onboardingFrequencyDescription;

  /// Daily tracking frequency option
  ///
  /// In en, this message translates to:
  /// **'Almost every day'**
  String get onboardingFrequencyDaily;

  /// Weekly tracking frequency option
  ///
  /// In en, this message translates to:
  /// **'Once or twice a week'**
  String get onboardingFrequencyWeekly;

  /// Occasional tracking frequency option
  ///
  /// In en, this message translates to:
  /// **'Only when I remember'**
  String get onboardingFrequencyOccasionally;

  /// Onboarding goal and commitment question
  ///
  /// In en, this message translates to:
  /// **'What do you want to achieve?'**
  String get onboardingGoalTitle;

  /// Onboarding goal question description
  ///
  /// In en, this message translates to:
  /// **'Pick the result that matters most to you'**
  String get onboardingGoalDescription;

  /// Spend less goal option
  ///
  /// In en, this message translates to:
  /// **'Reduce unnecessary spending'**
  String get onboardingGoalSpendLess;

  /// Understand spending goal option
  ///
  /// In en, this message translates to:
  /// **'Understand my spending patterns'**
  String get onboardingGoalUnderstandSpending;

  /// Save time goal option
  ///
  /// In en, this message translates to:
  /// **'Spend less time on bookkeeping'**
  String get onboardingGoalSaveTime;

  /// Social proof screen title
  ///
  /// In en, this message translates to:
  /// **'Small records can create real savings'**
  String get onboardingSocialProofTitle;

  /// Long funnel commitment screen title
  ///
  /// In en, this message translates to:
  /// **'Ready to make tracking easier?'**
  String get onboardingCommitmentTitle;

  /// Long funnel commitment screen description
  ///
  /// In en, this message translates to:
  /// **'Your plan starts with one simple habit: capture a purchase when it happens'**
  String get onboardingCommitmentDescription;

  /// Plan generation screen title
  ///
  /// In en, this message translates to:
  /// **'Building your tracking plan'**
  String get onboardingGeneratingTitle;

  /// Plan generation screen description
  ///
  /// In en, this message translates to:
  /// **'Combining your challenge, record sources, and goal'**
  String get onboardingGeneratingDescription;

  /// Fallback personalized result title
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready'**
  String get onboardingResultTitle;

  /// Personalized result screen description
  ///
  /// In en, this message translates to:
  /// **'Kashakeibo turns your captures into a monthly view you can understand at a glance'**
  String get onboardingResultDescription;

  /// Result title for manual entry pain
  ///
  /// In en, this message translates to:
  /// **'A plan that keeps manual entry out of the way'**
  String get onboardingResultRecordingEffort;

  /// Result title for spending visibility pain
  ///
  /// In en, this message translates to:
  /// **'A plan that makes every purchase visible'**
  String get onboardingResultSpendingVisibility;

  /// Result title for review time pain
  ///
  /// In en, this message translates to:
  /// **'A plan built for quick monthly reviews'**
  String get onboardingResultReviewTime;

  /// Result plan for receipt users
  ///
  /// In en, this message translates to:
  /// **'Photograph receipts when you receive them and let AI prepare the record'**
  String get onboardingPlanReceipt;

  /// Result plan for online statement users
  ///
  /// In en, this message translates to:
  /// **'Share card and shopping screenshots and let AI prepare the record'**
  String get onboardingPlanOnlineStatement;

  /// Result plan for all record sources
  ///
  /// In en, this message translates to:
  /// **'Capture receipts or share screenshots and keep every purchase in one place'**
  String get onboardingPlanBoth;

  /// Result plan for spending reduction goal
  ///
  /// In en, this message translates to:
  /// **'Use the monthly view to find spending you want to reduce'**
  String get onboardingPlanSpendLess;

  /// Result plan for spending understanding goal
  ///
  /// In en, this message translates to:
  /// **'Use categories and monthly totals to understand your spending patterns'**
  String get onboardingPlanUnderstandSpending;

  /// Result plan for time saving goal
  ///
  /// In en, this message translates to:
  /// **'Replace repetitive entry with photos and screenshots'**
  String get onboardingPlanSaveTime;
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
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
