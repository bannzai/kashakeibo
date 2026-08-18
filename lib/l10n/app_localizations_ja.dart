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
  String get duplicateCandidateReason => '金額が同じ・日付と店名が近い';

  @override
  String get duplicateCandidateKeep => 'この明細を残す';

  @override
  String get mergeDuplicateCandidate => '1件にまとめる';

  @override
  String get keepBothDuplicateCandidates => '別々の支出として残す';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String get openSettings => '設定を開く';

  @override
  String get settings => '設定';

  @override
  String get termsOfService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get specifiedCommercialTransactionAct => '特定商取引法に基づく表示';

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

  @override
  String get manualEntryOpen => '手動で入力';

  @override
  String get manualEntryTitle => '手動明細入力';

  @override
  String get manualEntryAmount => '金額';

  @override
  String get manualEntryAmountRequired => '1円以上の金額を入力してください';

  @override
  String get manualEntryStore => '店名・メモ';

  @override
  String get manualEntryDefaultTitle => '現金支出';

  @override
  String get manualEntryStoreRequired => '店名・メモを入力してください';

  @override
  String get manualEntryType => '収支種別';

  @override
  String get manualEntryCategory => 'カテゴリ';

  @override
  String get manualEntryCategoryRequired => 'カテゴリを選択してください';

  @override
  String get manualEntryDate => '日付';

  @override
  String get manualEntryRegister => '登録する';

  @override
  String get manualEntryRegistered => '明細を登録しました';

  @override
  String get transactionSourceReceipt => 'レシート';

  @override
  String get transactionSourceScreenshot => 'スクショ';

  @override
  String get transactionSourceManual => '手動';

  @override
  String get transactionSourceUnknown => '出所不明';
}
