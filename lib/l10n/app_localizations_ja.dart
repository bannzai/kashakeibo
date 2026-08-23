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
  String get accountBackupTitle => 'バックアップ';

  @override
  String get accountBackupNotSet => '未設定';

  @override
  String get accountBackupConfigured => '設定済み';

  @override
  String get accountBackupDescription => 'アカウントをリンクすると、機種変更してもデータが引き継げます';

  @override
  String get accountBackupConfiguredDescription =>
      '別の端末で同じアカウントを選ぶと、保存済みのデータを引き継げます';

  @override
  String get linkOrSignInWithApple => 'Appleでリンク';

  @override
  String get linkOrSignInWithGoogle => 'Googleでリンク';

  @override
  String get accountLinked => 'アカウントをリンクしました';

  @override
  String get existingAccountSignedIn => '既存のアカウントへ切り替えました';

  @override
  String get accountSwitchWarningTitle => 'この端末のデータを確認';

  @override
  String get accountSwitchWarningMessage =>
      '選択したアカウントが別の端末で利用中の場合、この端末の匿名データにはアクセスできなくなります。必要な明細を確認してから続けてください。';

  @override
  String get continueAccountLink => '続ける';

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

  @override
  String get addRecordOpen => '記録する';

  @override
  String get addRecordTitle => '記録する';

  @override
  String get captureReceiptWithCamera => 'カメラで撮影';

  @override
  String get captureReceiptWithCameraDescription => 'レシートを撮ると AI が明細を読み取ります';

  @override
  String get capturePickFromPhotoLibrary => '写真・スクショから選ぶ';

  @override
  String get capturePickFromPhotoLibraryDescription =>
      'カード明細や購入履歴のスクショを AI が明細に分けます';

  @override
  String get manualEntryDescription => '画像がない現金支出などを入力します';

  @override
  String get captureAnalyzingTitle => 'AI が読み取っています';

  @override
  String get captureAnalyzingStepLoading => '画像を読み込んでいます';

  @override
  String get captureAnalyzingStepReading => '金額・日付を読み取っています';

  @override
  String get captureAnalyzingStepCategory => 'カテゴリを推定しています';

  @override
  String get captureAnalysisFailedTitle => '読み取れませんでした';

  @override
  String get captureAnalysisNoTransactions => '画像から明細を読み取れませんでした';

  @override
  String get captureRetry => 'もう一度読み取る';

  @override
  String get captureManualFallback => '手動で入力する';

  @override
  String get captureRetake => '取り直す';

  @override
  String get captureConfirmTitle => '読み取り確認';

  @override
  String get captureSourceImageNote => '読み取りに使った元画像は、明細からいつでも見返せます';

  @override
  String get captureRegister => '登録する';

  @override
  String captureCandidatesNote(int count) {
    return '読み取った$count件から登録する明細を選んでください';
  }

  @override
  String get captureCandidateEdit => '修正する';

  @override
  String get captureCandidateApplyEdit => '変更を反映';

  @override
  String captureRegisterCount(int count) {
    return '$count件を登録する';
  }

  @override
  String get captureRegistered => 'カシャッと記録!';

  @override
  String get transactionDetailTitle => '明細';

  @override
  String get transactionDetailSourceImage => '元画像';

  @override
  String get transactionDetailSourceImageNote => '元画像はいつでも確認できます';

  @override
  String get transactionDetailNoImageManual => '手動入力のため元画像なし';

  @override
  String get transactionDetailNoImage => '元画像なし';

  @override
  String get transactionDetailZoom => '拡大';

  @override
  String get transactionDetailDeleteImage => '画像だけを削除';

  @override
  String get transactionDetailDeleteImageConfirmationTitle => '元画像を削除しますか？';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      '明細は残り、元画像だけが削除されます。元に戻せません。';

  @override
  String get transactionDetailImageDeleted => '元画像を削除しました';

  @override
  String get transactionDetailDelete => '明細を削除';

  @override
  String get transactionDetailDeleteConfirmationTitle => '明細を削除しますか？';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      '明細と元画像は完全に削除され、元に戻せません。';

  @override
  String get transactionDetailDeleted => '明細を削除しました';

  @override
  String get transactionDetailNotFound => 'この明細は削除されました';

  @override
  String get transactionDetailProvenance => '出所';

  @override
  String get transactionDetailExcludeFromAggregation => '計算対象から除外';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      'オンにすると合計・カテゴリ内訳に含めません';

  @override
  String get transactionProvenanceAutomatic => '自動取込';

  @override
  String get transactionProvenanceAdjusted => '手調整';

  @override
  String get capturesSection => 'とった記録';

  @override
  String scanQuotaRemaining(int count) {
    return 'スキャン残り$count回';
  }

  @override
  String get scanQuotaUnlimited => 'スキャンし放題';

  @override
  String get scanQuotaExhausted => '今月の無料スキャンを使い切りました';

  @override
  String get paywallTitle => 'スキャンし放題に';

  @override
  String get paywallSubtitle => '連携しないから壊れない。撮るだけでレシートも明細も AI が読み取ります';

  @override
  String get paywallSavingsClaim => '家計簿で支出が減った人の約半数が、月5,000円〜1万円未満の節約を実感*';

  @override
  String get paywallSavingsSource =>
      '* 東証マネ部!「お金に関するアンケート」2022年10月・全国20〜40代の会社員1,111名';

  @override
  String paywallFreeQuota(int used, int limit) {
    return '今月の無料スキャン $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => 'スキャンし放題';

  @override
  String get paywallBenefitFullHistory => '全期間の履歴';

  @override
  String get paywallBenefitFutureFeatures => '今後の新機能';

  @override
  String get paywallMonthlyPlan => '月額';

  @override
  String get paywallAnnualPlan => '年額';

  @override
  String get paywallRecommended => 'おすすめ';

  @override
  String paywallAnnualSavings(int percent) {
    return '$percent%お得';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/月換算';
  }

  @override
  String get paywallStartPremium => 'プレミアムを始める';

  @override
  String get paywallCancelAnytime => 'いつでも解約できます';

  @override
  String get paywallRestore => '購入の復元';

  @override
  String get paywallRestored => 'プレミアムを復元しました';

  @override
  String get paywallRestoreNotFound => '復元できる購入がありません';

  @override
  String get paywallPurchased => 'スキャンし放題のプレミアムを開始しました!';

  @override
  String get paywallPremiumActive => 'プレミアム利用中';

  @override
  String get paywallPremiumActiveDescription => 'スキャンし放題と全期間の履歴が使えます';

  @override
  String get paywallOfferingUnavailable => '料金プランを取得できませんでした';

  @override
  String get paywallFairUseNote =>
      'スキャンし放題は、サービス品質維持のため通常の利用では達しない月間上限の範囲で提供されます';

  @override
  String get paywallSubscriptionNote =>
      '購入の確認時にストアのアカウントに課金されます。期間終了の24時間前までに解約しない限り自動更新されます。解約・管理はストアのアカウント設定から行えます。';

  @override
  String get settingsPlan => 'プラン';

  @override
  String get planFree => '無料';

  @override
  String get planPremium => 'プレミアム';

  @override
  String get settingsAuditLog => '操作履歴';

  @override
  String get auditLogTitle => '操作履歴';

  @override
  String get auditLogDescription => '明細の追加・訂正・削除と、元画像の削除の記録です。';

  @override
  String get auditLogEmpty => '操作の履歴はまだありません';

  @override
  String get auditLogSyncing => '同期中';

  @override
  String get auditLogOperationTransactionCreated => '追加';

  @override
  String get auditLogOperationTransactionUpdated => '訂正';

  @override
  String get auditLogOperationTransactionDeleted => '削除';

  @override
  String get auditLogOperationTransactionImageDeleted => '画像を削除';

  @override
  String get auditLogOperationUnknown => 'その他の操作';

  @override
  String get auditLogChangedFieldExcludedFromAggregation => '計算対象';

  @override
  String get auditLogChangedFieldSourceImage => '元画像';

  @override
  String get auditLogChangedFieldDuplicateDecision => '重複の判定';

  @override
  String get transactionSearchOpen => '明細を検索';

  @override
  String get transactionSearchTitle => '検索';

  @override
  String get transactionSearchPeriod => '取引年月日';

  @override
  String get transactionSearchDateFrom => '開始日';

  @override
  String get transactionSearchDateTo => '終了日';

  @override
  String get transactionSearchDateUnset => '指定なし';

  @override
  String get transactionSearchAmount => '取引金額';

  @override
  String get transactionSearchMinimumAmount => '最小';

  @override
  String get transactionSearchMaximumAmount => '最大';

  @override
  String get transactionSearchTitleKeyword => '取引先';

  @override
  String get transactionSearchSubmit => '検索する';

  @override
  String get transactionSearchClear => '条件をクリア';

  @override
  String get transactionSearchConditionRequired => '検索条件を1つ以上入力してください';

  @override
  String get transactionSearchDateRangeInvalid => '終了日は開始日以降にしてください';

  @override
  String get transactionSearchAmountRangeInvalid => '最大金額は最小金額以上にしてください';

  @override
  String get transactionSearchNoResults => '条件に一致する明細はありません';

  @override
  String transactionSearchResultCount(int count) {
    return '$count件';
  }
}
