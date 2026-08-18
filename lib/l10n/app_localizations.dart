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
