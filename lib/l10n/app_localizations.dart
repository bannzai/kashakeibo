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

  /// Label for the monthly expense total
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get monthlyExpense;

  /// Label for the monthly balance (income - expense)
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get monthlyBalance;

  /// Section title for the expense breakdown by category
  ///
  /// In en, this message translates to:
  /// **'Category breakdown'**
  String get categoryBreakdown;

  /// Placeholder shown when the month has no transactions
  ///
  /// In en, this message translates to:
  /// **'No transactions this month'**
  String get monthlyTransactionsEmpty;

  /// Badge on a transaction excluded from aggregation totals
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

  /// Transaction category: food
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// Transaction category: daily goods
  ///
  /// In en, this message translates to:
  /// **'Daily goods'**
  String get categoryDailyGoods;

  /// Transaction category: transportation
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryTransportation;

  /// Transaction category: utilities
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// Transaction category: communication
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get categoryCommunication;

  /// Transaction category: housing
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get categoryHousing;

  /// Transaction category: medical
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryMedical;

  /// Transaction category: entertainment
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// Transaction category: clothing and beauty
  ///
  /// In en, this message translates to:
  /// **'Clothing & beauty'**
  String get categoryClothing;

  /// Transaction category: education
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

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
