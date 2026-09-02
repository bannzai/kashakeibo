// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Kashakeibo';

  @override
  String get monthlyIncome => '收入';

  @override
  String get monthlyExpense => '支出';

  @override
  String get monthlyBalance => '结余';

  @override
  String get categoryBreakdown => '分类';

  @override
  String get monthlyTransactionsEmpty => '本月暂无交易记录';

  @override
  String get excludedFromAggregation => '已排除';

  @override
  String duplicateCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 笔可能重复的记录',
    );
    return '$_temp0';
  }

  @override
  String get duplicateCandidateReviewHint => '点击查看';

  @override
  String get duplicateCandidateTitle => '检查可能重复的记录';

  @override
  String get duplicateCandidateDescription =>
      '这些交易的金额、日期和商店名称相似。请确认它们是否为同一笔支出。';

  @override
  String get duplicateCandidateReason => '金额相同，日期接近，商家名称相似';

  @override
  String get duplicateCandidateKeep => '保留此笔交易';

  @override
  String get mergeDuplicateCandidate => '合并为一笔';

  @override
  String get keepBothDuplicateCandidates => '分别保留为支出';

  @override
  String get previousMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String get openSettings => '打开设置';

  @override
  String get settings => '设置';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get specifiedCommercialTransactionAct => '商业交易披露';

  @override
  String get accountBackupTitle => '备份';

  @override
  String get accountBackupNotSet => '未设置';

  @override
  String get accountBackupConfigured => '已设置';

  @override
  String get accountBackupDescription => '关联账户，以便更换设备时保留您的数据。';

  @override
  String get accountBackupConfiguredDescription => '在其他设备上选择同一账号，即可访问已保存的数据。';

  @override
  String get linkOrSignInWithApple => '关联 Apple';

  @override
  String get linkOrSignInWithGoogle => '使用 Google 关联';

  @override
  String get accountLinked => '账号已关联';

  @override
  String get existingAccountSignedIn => '已切换到您已有的账户';

  @override
  String get accountSwitchWarningTitle => '检查此设备上的数据';

  @override
  String get accountSwitchWarningMessage =>
      '如果您选择的账户已在其他设备上使用，此设备上的匿名数据将无法再访问。继续前请查看需要保留的交易记录。';

  @override
  String get continueAccountLink => '继续';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountConfirmationTitle => '要删除您的账户吗？';

  @override
  String get deleteAccountConfirmationMessage => '您的账户和已保存的交易记录将永久删除，且无法恢复。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get categoryFood => '食品';

  @override
  String get categoryEatingOut => '外出就餐';

  @override
  String get categoryDailyGoods => '日用品';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categorySubscription => '订阅';

  @override
  String get categorySalary => '工资';

  @override
  String get categoryOther => '其他';

  @override
  String get manualEntryOpen => '手动输入';

  @override
  String get manualEntryTitle => '手动输入';

  @override
  String get manualEntryAmount => '金额';

  @override
  String get manualEntryAmountRequired => '请输入至少 1 日元的金额';

  @override
  String get manualEntryStore => '商店或备注';

  @override
  String get manualEntryDefaultTitle => '现金支出';

  @override
  String get manualEntryStoreRequired => '请输入商店或备注';

  @override
  String get manualEntryType => '交易类型';

  @override
  String get manualEntryCategory => '分类';

  @override
  String get manualEntryCategoryRequired => '选择分类';

  @override
  String get manualEntryDate => '日期';

  @override
  String get manualEntryRegister => '添加账目';

  @override
  String get manualEntryRegistered => '已添加交易记录';

  @override
  String get transactionSourceReceipt => '小票';

  @override
  String get transactionSourceScreenshot => '截图';

  @override
  String get transactionSourceManual => '手动';

  @override
  String get transactionSourceUnknown => '未知来源';

  @override
  String get addRecordOpen => '添加记录';

  @override
  String get addRecordTitle => '添加记录';

  @override
  String get captureReceiptWithCamera => '拍照';

  @override
  String get captureReceiptWithCameraDescription => '拍摄收据，AI 自动读取明细';

  @override
  String get capturePickFromPhotoLibrary => '从照片中选择';

  @override
  String get capturePickFromPhotoLibraryDescription => 'AI 会将账单或订单截图拆分为多笔记录';

  @override
  String get manualEntryDescription => '输入无图片的现金支出';

  @override
  String get captureAnalyzingTitle => 'AI 正在读取您的图片';

  @override
  String get captureAnalyzingStepLoading => '正在加载图片';

  @override
  String get captureAnalyzingStepReading => '正在读取金额和日期';

  @override
  String get captureAnalyzingStepCategory => '正在推测类别';

  @override
  String get captureAnalysisFailedTitle => '无法读取图片';

  @override
  String get captureAnalysisNoTransactions => '无法从图片中读取交易记录';

  @override
  String get captureRetry => '再试一次';

  @override
  String get captureManualFallback => '手动输入';

  @override
  String get captureRetake => '重新拍摄';

  @override
  String get captureConfirmTitle => '查看明细';

  @override
  String get captureSourceImageNote => '您可以随时从明细中查看原始图片';

  @override
  String get captureRegister => '记录';

  @override
  String captureCandidatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已读取 $count 笔账目，请选择要记录的项目',
    );
    return '$_temp0';
  }

  @override
  String get captureCandidateEdit => '编辑';

  @override
  String get captureCandidateApplyEdit => '应用更改';

  @override
  String captureRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '记录 $count 笔',
    );
    return '$_temp0';
  }

  @override
  String get captureRegistered => '已记录 ✓';

  @override
  String get captureInstructionSectionTitle => '给 AI 的补充指示';

  @override
  String get captureInstructionOpen => '让 AI 重新识别';

  @override
  String get captureInstructionHint => '例如：最后一条明细没有识别 / 第二条金额不对';

  @override
  String get captureInstructionScanNote => '重新识别会使用 1 次扫描';

  @override
  String get captureInstructionSend => '发送并重新识别';

  @override
  String captureInstructionResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重新识别后共 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailTitle => '明细';

  @override
  String get transactionDetailSourceImage => '原始图片';

  @override
  String get transactionDetailSourceImageNote => '随时查看原始图片';

  @override
  String get transactionDetailNoImageManual => '无图片 · 手动输入';

  @override
  String get transactionDetailNoImage => '暂无原图';

  @override
  String get transactionDetailZoom => '缩放';

  @override
  String get transactionDetailDeleteImage => '仅删除图片';

  @override
  String get transactionDetailDeleteImageConfirmationTitle => '要删除原始图片吗？';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      '交易记录会保留，仅删除图片。此操作无法撤销。';

  @override
  String get transactionDetailImageDeleted => '原始图片已删除';

  @override
  String get transactionDetailDelete => '删除交易';

  @override
  String get transactionDetailDeleteConfirmationTitle => '删除此笔明细？';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      '交易记录及其来源图片将被永久删除。此操作无法撤销。';

  @override
  String get transactionDetailDeleted => '交易记录已删除';

  @override
  String get transactionDetailNotFound => '这笔明细已删除';

  @override
  String get transactionDetailProvenance => '来源';

  @override
  String captureInstructionLimitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每张图片最多可补充指示 $count 次',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailAnalysisInstructions => '给 AI 的指示';

  @override
  String get transactionDetailExcludeFromAggregation => '不计入总额';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      '开启后，将不计入总额和分类明细';

  @override
  String get transactionProvenanceAutomatic => '自动导入';

  @override
  String get transactionProvenanceAdjusted => '已调整';

  @override
  String get capturesSection => '截图记录';

  @override
  String scanQuotaRemaining(int count) {
    return '剩余 $count 次扫描';
  }

  @override
  String get scanQuotaUnlimited => '尽情扫描';

  @override
  String get scanQuotaExhausted => '本月免费扫描次数已用完';

  @override
  String get paywallTitle => '使用高级版，尽情扫描';

  @override
  String get paywallSubtitle => '无需关联账户。拍照即可，高级版会为您读取每张收据和每份账单。';

  @override
  String get paywallSavingsClaim => '通过记账减少支出的人中，约一半每月节省 ¥5,000 至不足 ¥10,000*';

  @override
  String get paywallSavingsSource =>
      '* 调查：JPX\'s Money-bu!（2022年10月，日本1,111名上班族）';

  @override
  String paywallFreeQuota(int used, int limit) {
    return '本月免费扫描 $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => '自由扫描';

  @override
  String get paywallBenefitFullHistory => '每月查看完整记录';

  @override
  String get paywallBenefitFutureFeatures => '即将推出的功能';

  @override
  String get paywallMonthlyPlan => '每月';

  @override
  String get paywallAnnualPlan => '年付';

  @override
  String get paywallRecommended => '最划算';

  @override
  String paywallAnnualSavings(int percent) {
    return '节省 $percent%';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/月';
  }

  @override
  String get paywallStartPremium => '开通高级版';

  @override
  String get paywallCancelAnytime => '随时取消';

  @override
  String get paywallRestore => '恢复购买';

  @override
  String get paywallRestored => '已恢复购买。高级版已启用。';

  @override
  String get paywallRestoreNotFound => '没有可恢复的购买记录';

  @override
  String get paywallPurchased => '高级版已启用。尽情扫描吧！';

  @override
  String get paywallPremiumActive => '高级版已启用';

  @override
  String get paywallPremiumActiveDescription => '您可以尽情扫描并查看完整记录。';

  @override
  String get paywallOfferingUnavailable => '目前暂时无法获取套餐';

  @override
  String get paywallFairUseNote => '扫描功能每月有合理使用上限，正常使用一般不会达到。';

  @override
  String get paywallSubscriptionNote =>
      '确认后，费用将从您的商店账户中扣除。除非您在当前订阅周期结束前至少24小时取消订阅，否则订阅将自动续订。您可以在商店账户设置中管理或取消订阅。';

  @override
  String get settingsPlan => '方案';

  @override
  String get planFree => '免费';

  @override
  String get planPremium => '高级版';

  @override
  String get settingsAuditLog => '操作记录';

  @override
  String get auditLogTitle => '操作记录';

  @override
  String get auditLogDescription => '记录您添加、更正或删除的明细，以及删除原始图片的操作。';

  @override
  String get auditLogEmpty => '暂无操作记录';

  @override
  String get auditLogSyncing => '正在同步';

  @override
  String get auditLogOperationTransactionCreated => '已添加';

  @override
  String get auditLogOperationTransactionUpdated => '已更正';

  @override
  String get auditLogOperationTransactionDeleted => '已删除';

  @override
  String get auditLogOperationTransactionImageDeleted => '已删除图片';

  @override
  String get auditLogOperationUnknown => '其他操作';

  @override
  String get auditLogChangedFieldExcludedFromAggregation => '计入总额';

  @override
  String get auditLogChangedFieldSourceImage => '原始图片';

  @override
  String get auditLogChangedFieldDuplicateDecision => '重复项处理方式';

  @override
  String get transactionSearchOpen => '搜索交易记录';

  @override
  String get transactionSearchTitle => '搜索';

  @override
  String get transactionSearchPeriod => '日期';

  @override
  String get transactionSearchDateFrom => '开始日期';

  @override
  String get transactionSearchDateTo => '结束日期';

  @override
  String get transactionSearchDateUnset => '不限';

  @override
  String get transactionSearchAmount => '金额';

  @override
  String get transactionSearchMinimumAmount => '最低';

  @override
  String get transactionSearchMaximumAmount => '最高';

  @override
  String get transactionSearchTitleKeyword => '店家';

  @override
  String get transactionSearchSubmit => '搜索';

  @override
  String get transactionSearchClear => '清除条件';

  @override
  String get transactionSearchConditionRequired => '请输入至少一个条件';

  @override
  String get transactionSearchDateRangeInvalid => '结束日期必须晚于或等于开始日期';

  @override
  String get transactionSearchAmountRangeInvalid => '最大值应设置为最小值或更大';

  @override
  String get transactionSearchNoResults => '没有符合条件的交易';

  @override
  String transactionSearchResultCount(int count) {
    return '$count 笔';
  }

  @override
  String transactionSearchFreePlanHistoryLimit(int monthCount) {
    return '免费版仅搜索最近 $monthCount 个月的记录';
  }

  @override
  String auditLogFreePlanHistoryLimit(int monthCount) {
    return '免费方案仅显示最近 $monthCount 个月的操作记录';
  }

  @override
  String get freePlanHistoryLimitUpgrade => '使用高级版查看完整记录';

  @override
  String get onboardingContinue => '下一步';

  @override
  String get onboardingSeePremium => '查看高级版方案';

  @override
  String get onboardingWelcomeTitle => '让家庭收支记录更轻松';

  @override
  String get onboardingWelcomeDescription => '拍下收据或在线账单即可记入家庭账本';

  @override
  String get onboardingValueTitle => '现在拍下以后查看';

  @override
  String get onboardingValueDescription =>
      'Kashakeibo 使用 AI 整理商店、金额、日期和类别，让您专注于了解自己的财务状况';

  @override
  String get onboardingPainTitle => '管理收支时最困扰你的是什么？';

  @override
  String get onboardingPainDescription => '选择你最想先解决的问题';

  @override
  String get onboardingPainRecordingEffort => '每次手动输入太麻烦难以坚持';

  @override
  String get onboardingPainSpendingVisibility => '看不清钱花在了哪里';

  @override
  String get onboardingPainReviewTime => '没有时间回顾支出';

  @override
  String get onboardingSourceTitle => '你想记录什么？';

  @override
  String get onboardingSourceDescription => '我们会根据回答建议使用方案';

  @override
  String get onboardingSourceReceipt => '纸质收据';

  @override
  String get onboardingSourceOnlineStatement => '信用卡和网购账单';

  @override
  String get onboardingSourceBoth => '收据和在线账单都要';

  @override
  String get onboardingFrequencyTitle => '你现在多久记录一次？';

  @override
  String get onboardingFrequencyDescription => '任何回答都可以';

  @override
  String get onboardingFrequencyDaily => '几乎每天';

  @override
  String get onboardingFrequencyWeekly => '每周一到两次';

  @override
  String get onboardingFrequencyOccasionally => '想起来时才记录';

  @override
  String get onboardingGoalTitle => '你希望通过家庭账本实现什么？';

  @override
  String get onboardingGoalDescription => '选择对你最重要的目标';

  @override
  String get onboardingGoalSpendLess => '减少不必要的支出';

  @override
  String get onboardingGoalUnderstandSpending => '了解自己的支出规律';

  @override
  String get onboardingGoalSaveTime => '减少记账所花的时间';

  @override
  String get onboardingSocialProofTitle => '小小的记录也能带来节省';

  @override
  String get onboardingCommitmentTitle => '准备开始轻松记录了吗？';

  @override
  String get onboardingCommitmentDescription => '先从消费时拍一张照片的简单习惯开始';

  @override
  String get onboardingGeneratingTitle => '正在生成你的使用方案';

  @override
  String get onboardingGeneratingDescription => '正在结合你的困扰记录来源和目标';

  @override
  String get onboardingResultTitle => '你的使用方案已准备好';

  @override
  String get onboardingResultDescription => 'Kashakeibo 将您的截图和照片整理成一目了然的月度视图';

  @override
  String get onboardingResultRecordingEffort => '减少输入负担并轻松坚持的方案';

  @override
  String get onboardingResultSpendingVisibility => '让每笔支出清晰可见的方案';

  @override
  String get onboardingResultReviewTime => '快速回顾每月收支的方案';

  @override
  String get onboardingPlanReceipt => '收到收据时拍下来并交给AI生成记录';

  @override
  String get onboardingPlanOnlineStatement => '共享信用卡或购物账单并交给AI生成记录';

  @override
  String get onboardingPlanBoth => '拍下收据或共享截图并把所有支出集中在一处';

  @override
  String get onboardingPlanSpendLess => '从月度页面找出想要减少的支出';

  @override
  String get onboardingPlanUnderstandSpending => '通过类别和月度总额了解支出规律';

  @override
  String get onboardingPlanSaveTime => '用照片和截图代替重复输入';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appName => 'Kashakeibo';

  @override
  String get monthlyIncome => '收入';

  @override
  String get monthlyExpense => '支出';

  @override
  String get monthlyBalance => '结余';

  @override
  String get categoryBreakdown => '分类';

  @override
  String get monthlyTransactionsEmpty => '本月暂无交易记录';

  @override
  String get excludedFromAggregation => '已排除';

  @override
  String duplicateCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 笔可能重复的记录',
    );
    return '$_temp0';
  }

  @override
  String get duplicateCandidateReviewHint => '点击查看';

  @override
  String get duplicateCandidateTitle => '检查可能重复的记录';

  @override
  String get duplicateCandidateDescription =>
      '这些交易的金额、日期和商店名称相似。请确认它们是否为同一笔支出。';

  @override
  String get duplicateCandidateReason => '金额相同，日期接近，商家名称相似';

  @override
  String get duplicateCandidateKeep => '保留此笔交易';

  @override
  String get mergeDuplicateCandidate => '合并为一笔';

  @override
  String get keepBothDuplicateCandidates => '分别保留为支出';

  @override
  String get previousMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String get openSettings => '打开设置';

  @override
  String get settings => '设置';

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get specifiedCommercialTransactionAct => '商业交易披露';

  @override
  String get accountBackupTitle => '备份';

  @override
  String get accountBackupNotSet => '未设置';

  @override
  String get accountBackupConfigured => '已设置';

  @override
  String get accountBackupDescription => '关联账户，以便更换设备时保留您的数据。';

  @override
  String get accountBackupConfiguredDescription => '在其他设备上选择同一账号，即可访问已保存的数据。';

  @override
  String get linkOrSignInWithApple => '关联 Apple';

  @override
  String get linkOrSignInWithGoogle => '使用 Google 关联';

  @override
  String get accountLinked => '账号已关联';

  @override
  String get existingAccountSignedIn => '已切换到您已有的账户';

  @override
  String get accountSwitchWarningTitle => '检查此设备上的数据';

  @override
  String get accountSwitchWarningMessage =>
      '如果您选择的账户已在其他设备上使用，此设备上的匿名数据将无法再访问。继续前请查看需要保留的交易记录。';

  @override
  String get continueAccountLink => '继续';

  @override
  String get deleteAccount => '删除账户';

  @override
  String get deleteAccountConfirmationTitle => '要删除您的账户吗？';

  @override
  String get deleteAccountConfirmationMessage => '您的账户和已保存的交易记录将永久删除，且无法恢复。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get categoryFood => '食品';

  @override
  String get categoryEatingOut => '外出就餐';

  @override
  String get categoryDailyGoods => '日用品';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categorySubscription => '订阅';

  @override
  String get categorySalary => '工资';

  @override
  String get categoryOther => '其他';

  @override
  String get manualEntryOpen => '手动输入';

  @override
  String get manualEntryTitle => '手动输入';

  @override
  String get manualEntryAmount => '金额';

  @override
  String get manualEntryAmountRequired => '请输入至少 1 日元的金额';

  @override
  String get manualEntryStore => '商店或备注';

  @override
  String get manualEntryDefaultTitle => '现金支出';

  @override
  String get manualEntryStoreRequired => '请输入商店或备注';

  @override
  String get manualEntryType => '交易类型';

  @override
  String get manualEntryCategory => '分类';

  @override
  String get manualEntryCategoryRequired => '选择分类';

  @override
  String get manualEntryDate => '日期';

  @override
  String get manualEntryRegister => '添加账目';

  @override
  String get manualEntryRegistered => '已添加交易记录';

  @override
  String get transactionSourceReceipt => '小票';

  @override
  String get transactionSourceScreenshot => '截图';

  @override
  String get transactionSourceManual => '手动';

  @override
  String get transactionSourceUnknown => '未知来源';

  @override
  String get addRecordOpen => '添加记录';

  @override
  String get addRecordTitle => '添加记录';

  @override
  String get captureReceiptWithCamera => '拍照';

  @override
  String get captureReceiptWithCameraDescription => '拍摄收据，AI 自动读取明细';

  @override
  String get capturePickFromPhotoLibrary => '从照片中选择';

  @override
  String get capturePickFromPhotoLibraryDescription => 'AI 会将账单或订单截图拆分为多笔记录';

  @override
  String get manualEntryDescription => '输入无图片的现金支出';

  @override
  String get captureAnalyzingTitle => 'AI 正在读取您的图片';

  @override
  String get captureAnalyzingStepLoading => '正在加载图片';

  @override
  String get captureAnalyzingStepReading => '正在读取金额和日期';

  @override
  String get captureAnalyzingStepCategory => '正在推测类别';

  @override
  String get captureAnalysisFailedTitle => '无法读取图片';

  @override
  String get captureAnalysisNoTransactions => '无法从图片中读取交易记录';

  @override
  String get captureRetry => '再试一次';

  @override
  String get captureManualFallback => '手动输入';

  @override
  String get captureRetake => '重新拍摄';

  @override
  String get captureConfirmTitle => '查看明细';

  @override
  String get captureSourceImageNote => '您可以随时从明细中查看原始图片';

  @override
  String get captureRegister => '记录';

  @override
  String captureCandidatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已读取 $count 笔账目，请选择要记录的项目',
    );
    return '$_temp0';
  }

  @override
  String get captureCandidateEdit => '编辑';

  @override
  String get captureCandidateApplyEdit => '应用更改';

  @override
  String captureRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '记录 $count 笔',
    );
    return '$_temp0';
  }

  @override
  String get captureRegistered => '已记录 ✓';

  @override
  String get captureInstructionSectionTitle => '给 AI 的补充指示';

  @override
  String get captureInstructionOpen => '让 AI 重新识别';

  @override
  String get captureInstructionHint => '例如：最后一条明细没有识别 / 第二条金额不对';

  @override
  String get captureInstructionScanNote => '重新识别会使用 1 次扫描';

  @override
  String get captureInstructionSend => '发送并重新识别';

  @override
  String captureInstructionResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重新识别后共 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailTitle => '明细';

  @override
  String get transactionDetailSourceImage => '原始图片';

  @override
  String get transactionDetailSourceImageNote => '随时查看原始图片';

  @override
  String get transactionDetailNoImageManual => '无图片 · 手动输入';

  @override
  String get transactionDetailNoImage => '暂无原图';

  @override
  String get transactionDetailZoom => '缩放';

  @override
  String get transactionDetailDeleteImage => '仅删除图片';

  @override
  String get transactionDetailDeleteImageConfirmationTitle => '要删除原始图片吗？';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      '交易记录会保留，仅删除图片。此操作无法撤销。';

  @override
  String get transactionDetailImageDeleted => '原始图片已删除';

  @override
  String get transactionDetailDelete => '删除交易';

  @override
  String get transactionDetailDeleteConfirmationTitle => '删除此笔明细？';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      '交易记录及其来源图片将被永久删除。此操作无法撤销。';

  @override
  String get transactionDetailDeleted => '交易记录已删除';

  @override
  String get transactionDetailNotFound => '这笔明细已删除';

  @override
  String get transactionDetailProvenance => '来源';

  @override
  String captureInstructionLimitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每张图片最多可补充指示 $count 次',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailAnalysisInstructions => '给 AI 的指示';

  @override
  String get transactionDetailExcludeFromAggregation => '不计入总额';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      '开启后，将不计入总额和分类明细';

  @override
  String get transactionProvenanceAutomatic => '自动导入';

  @override
  String get transactionProvenanceAdjusted => '已调整';

  @override
  String get capturesSection => '截图记录';

  @override
  String scanQuotaRemaining(int count) {
    return '剩余 $count 次扫描';
  }

  @override
  String get scanQuotaUnlimited => '尽情扫描';

  @override
  String get scanQuotaExhausted => '本月免费扫描次数已用完';

  @override
  String get paywallTitle => '使用高级版，尽情扫描';

  @override
  String get paywallSubtitle => '无需关联账户。拍照即可，高级版会为您读取每张收据和每份账单。';

  @override
  String get paywallSavingsClaim => '通过记账减少支出的人中，约一半每月节省 ¥5,000 至不足 ¥10,000*';

  @override
  String get paywallSavingsSource =>
      '* 调查：JPX\'s Money-bu!（2022年10月，日本1,111名上班族）';

  @override
  String paywallFreeQuota(int used, int limit) {
    return '本月免费扫描 $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => '自由扫描';

  @override
  String get paywallBenefitFullHistory => '每月查看完整记录';

  @override
  String get paywallBenefitFutureFeatures => '即将推出的功能';

  @override
  String get paywallMonthlyPlan => '每月';

  @override
  String get paywallAnnualPlan => '年付';

  @override
  String get paywallRecommended => '最划算';

  @override
  String paywallAnnualSavings(int percent) {
    return '节省 $percent%';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/月';
  }

  @override
  String get paywallStartPremium => '开通高级版';

  @override
  String get paywallCancelAnytime => '随时取消';

  @override
  String get paywallRestore => '恢复购买';

  @override
  String get paywallRestored => '已恢复购买。高级版已启用。';

  @override
  String get paywallRestoreNotFound => '没有可恢复的购买记录';

  @override
  String get paywallPurchased => '高级版已启用。尽情扫描吧！';

  @override
  String get paywallPremiumActive => '高级版已启用';

  @override
  String get paywallPremiumActiveDescription => '您可以尽情扫描并查看完整记录。';

  @override
  String get paywallOfferingUnavailable => '目前暂时无法获取套餐';

  @override
  String get paywallFairUseNote => '扫描功能每月有合理使用上限，正常使用一般不会达到。';

  @override
  String get paywallSubscriptionNote =>
      '确认后，费用将从您的商店账户中扣除。除非您在当前订阅周期结束前至少24小时取消订阅，否则订阅将自动续订。您可以在商店账户设置中管理或取消订阅。';

  @override
  String get settingsPlan => '方案';

  @override
  String get planFree => '免费';

  @override
  String get planPremium => '高级版';

  @override
  String get settingsAuditLog => '操作记录';

  @override
  String get auditLogTitle => '操作记录';

  @override
  String get auditLogDescription => '记录您添加、更正或删除的明细，以及删除原始图片的操作。';

  @override
  String get auditLogEmpty => '暂无操作记录';

  @override
  String get auditLogSyncing => '正在同步';

  @override
  String get auditLogOperationTransactionCreated => '已添加';

  @override
  String get auditLogOperationTransactionUpdated => '已更正';

  @override
  String get auditLogOperationTransactionDeleted => '已删除';

  @override
  String get auditLogOperationTransactionImageDeleted => '已删除图片';

  @override
  String get auditLogOperationUnknown => '其他操作';

  @override
  String get auditLogChangedFieldExcludedFromAggregation => '计入总额';

  @override
  String get auditLogChangedFieldSourceImage => '原始图片';

  @override
  String get auditLogChangedFieldDuplicateDecision => '重复项处理方式';

  @override
  String get transactionSearchOpen => '搜索交易记录';

  @override
  String get transactionSearchTitle => '搜索';

  @override
  String get transactionSearchPeriod => '日期';

  @override
  String get transactionSearchDateFrom => '开始日期';

  @override
  String get transactionSearchDateTo => '结束日期';

  @override
  String get transactionSearchDateUnset => '不限';

  @override
  String get transactionSearchAmount => '金额';

  @override
  String get transactionSearchMinimumAmount => '最低';

  @override
  String get transactionSearchMaximumAmount => '最高';

  @override
  String get transactionSearchTitleKeyword => '店家';

  @override
  String get transactionSearchSubmit => '搜索';

  @override
  String get transactionSearchClear => '清除条件';

  @override
  String get transactionSearchConditionRequired => '请输入至少一个条件';

  @override
  String get transactionSearchDateRangeInvalid => '结束日期必须晚于或等于开始日期';

  @override
  String get transactionSearchAmountRangeInvalid => '最大值应设置为最小值或更大';

  @override
  String get transactionSearchNoResults => '没有符合条件的交易';

  @override
  String transactionSearchResultCount(int count) {
    return '$count 笔';
  }

  @override
  String transactionSearchFreePlanHistoryLimit(int monthCount) {
    return '免费版仅搜索最近 $monthCount 个月的记录';
  }

  @override
  String auditLogFreePlanHistoryLimit(int monthCount) {
    return '免费方案仅显示最近 $monthCount 个月的操作记录';
  }

  @override
  String get freePlanHistoryLimitUpgrade => '使用高级版查看完整记录';

  @override
  String get onboardingContinue => '下一步';

  @override
  String get onboardingSeePremium => '查看高级版方案';

  @override
  String get onboardingWelcomeTitle => '让家庭收支记录更轻松';

  @override
  String get onboardingWelcomeDescription => '拍下收据或在线账单即可记入家庭账本';

  @override
  String get onboardingValueTitle => '现在拍下以后查看';

  @override
  String get onboardingValueDescription =>
      'Kashakeibo 使用 AI 整理商店、金额、日期和类别，让您专注于了解自己的财务状况';

  @override
  String get onboardingPainTitle => '管理收支时最困扰你的是什么？';

  @override
  String get onboardingPainDescription => '选择你最想先解决的问题';

  @override
  String get onboardingPainRecordingEffort => '每次手动输入太麻烦难以坚持';

  @override
  String get onboardingPainSpendingVisibility => '看不清钱花在了哪里';

  @override
  String get onboardingPainReviewTime => '没有时间回顾支出';

  @override
  String get onboardingSourceTitle => '你想记录什么？';

  @override
  String get onboardingSourceDescription => '我们会根据回答建议使用方案';

  @override
  String get onboardingSourceReceipt => '纸质收据';

  @override
  String get onboardingSourceOnlineStatement => '信用卡和网购账单';

  @override
  String get onboardingSourceBoth => '收据和在线账单都要';

  @override
  String get onboardingFrequencyTitle => '你现在多久记录一次？';

  @override
  String get onboardingFrequencyDescription => '任何回答都可以';

  @override
  String get onboardingFrequencyDaily => '几乎每天';

  @override
  String get onboardingFrequencyWeekly => '每周一到两次';

  @override
  String get onboardingFrequencyOccasionally => '想起来时才记录';

  @override
  String get onboardingGoalTitle => '你希望通过家庭账本实现什么？';

  @override
  String get onboardingGoalDescription => '选择对你最重要的目标';

  @override
  String get onboardingGoalSpendLess => '减少不必要的支出';

  @override
  String get onboardingGoalUnderstandSpending => '了解自己的支出规律';

  @override
  String get onboardingGoalSaveTime => '减少记账所花的时间';

  @override
  String get onboardingSocialProofTitle => '小小的记录也能带来节省';

  @override
  String get onboardingCommitmentTitle => '准备开始轻松记录了吗？';

  @override
  String get onboardingCommitmentDescription => '先从消费时拍一张照片的简单习惯开始';

  @override
  String get onboardingGeneratingTitle => '正在生成你的使用方案';

  @override
  String get onboardingGeneratingDescription => '正在结合你的困扰记录来源和目标';

  @override
  String get onboardingResultTitle => '你的使用方案已准备好';

  @override
  String get onboardingResultDescription => 'Kashakeibo 将您的截图和照片整理成一目了然的月度视图';

  @override
  String get onboardingResultRecordingEffort => '减少输入负担并轻松坚持的方案';

  @override
  String get onboardingResultSpendingVisibility => '让每笔支出清晰可见的方案';

  @override
  String get onboardingResultReviewTime => '快速回顾每月收支的方案';

  @override
  String get onboardingPlanReceipt => '收到收据时拍下来并交给AI生成记录';

  @override
  String get onboardingPlanOnlineStatement => '共享信用卡或购物账单并交给AI生成记录';

  @override
  String get onboardingPlanBoth => '拍下收据或共享截图并把所有支出集中在一处';

  @override
  String get onboardingPlanSpendLess => '从月度页面找出想要减少的支出';

  @override
  String get onboardingPlanUnderstandSpending => '通过类别和月度总额了解支出规律';

  @override
  String get onboardingPlanSaveTime => '用照片和截图代替重复输入';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appName => 'Kashakeibo';

  @override
  String get monthlyIncome => '收入';

  @override
  String get monthlyExpense => '支出';

  @override
  String get monthlyBalance => '結餘';

  @override
  String get categoryBreakdown => '分類';

  @override
  String get monthlyTransactionsEmpty => '本月尚無交易紀錄';

  @override
  String get excludedFromAggregation => '已排除';

  @override
  String duplicateCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 筆可能重複的紀錄',
    );
    return '$_temp0';
  }

  @override
  String get duplicateCandidateReviewHint => '點選查看';

  @override
  String get duplicateCandidateTitle => '檢查可能重複的記錄';

  @override
  String get duplicateCandidateDescription => '這些交易的金額、日期和商店名稱相近。請確認是否為同一筆支出。';

  @override
  String get duplicateCandidateReason => '金額相同、日期相近，商店名稱相似';

  @override
  String get duplicateCandidateKeep => '保留這筆交易';

  @override
  String get mergeDuplicateCandidate => '合併為一筆';

  @override
  String get keepBothDuplicateCandidates => '分別保留為支出';

  @override
  String get previousMonth => '上個月';

  @override
  String get nextMonth => '下個月';

  @override
  String get openSettings => '開啟設定';

  @override
  String get settings => '設定';

  @override
  String get termsOfService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get specifiedCommercialTransactionAct => '商業交易揭露';

  @override
  String get accountBackupTitle => '備份';

  @override
  String get accountBackupNotSet => '尚未設定';

  @override
  String get accountBackupConfigured => '已設定';

  @override
  String get accountBackupDescription => '連結帳戶，換裝置時也能保留資料。';

  @override
  String get accountBackupConfiguredDescription => '在其他裝置上選擇相同的帳號，即可存取已儲存的資料。';

  @override
  String get linkOrSignInWithApple => '連結 Apple';

  @override
  String get linkOrSignInWithGoogle => '使用 Google 連結';

  @override
  String get accountLinked => '帳戶已連結';

  @override
  String get existingAccountSignedIn => '已切換至您現有的帳戶';

  @override
  String get accountSwitchWarningTitle => '檢查此裝置上的資料';

  @override
  String get accountSwitchWarningMessage =>
      '如果您選擇的帳戶已在其他裝置上使用，此裝置上的匿名資料將無法再存取。繼續前請查看需要保留的交易紀錄。';

  @override
  String get continueAccountLink => '繼續';

  @override
  String get deleteAccount => '刪除帳戶';

  @override
  String get deleteAccountConfirmationTitle => '要刪除您的帳戶嗎？';

  @override
  String get deleteAccountConfirmationMessage => '您的帳戶和已儲存的交易記錄將永久刪除，且無法復原。';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get categoryFood => '食品';

  @override
  String get categoryEatingOut => '外食';

  @override
  String get categoryDailyGoods => '日用品';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categorySubscription => '訂閱';

  @override
  String get categorySalary => '薪資';

  @override
  String get categoryOther => '其他';

  @override
  String get manualEntryOpen => '手動輸入';

  @override
  String get manualEntryTitle => '手動輸入';

  @override
  String get manualEntryAmount => '金額';

  @override
  String get manualEntryAmountRequired => '請輸入至少 1 日圓的金額';

  @override
  String get manualEntryStore => '商店或備註';

  @override
  String get manualEntryDefaultTitle => '現金支出';

  @override
  String get manualEntryStoreRequired => '請輸入商店或備註';

  @override
  String get manualEntryType => '交易類型';

  @override
  String get manualEntryCategory => '類別';

  @override
  String get manualEntryCategoryRequired => '選擇分類';

  @override
  String get manualEntryDate => '日期';

  @override
  String get manualEntryRegister => '新增帳目';

  @override
  String get manualEntryRegistered => '已新增交易紀錄';

  @override
  String get transactionSourceReceipt => '收據';

  @override
  String get transactionSourceScreenshot => '截圖';

  @override
  String get transactionSourceManual => '手動';

  @override
  String get transactionSourceUnknown => '來源不明';

  @override
  String get addRecordOpen => '新增記錄';

  @override
  String get addRecordTitle => '新增記錄';

  @override
  String get captureReceiptWithCamera => '拍照';

  @override
  String get captureReceiptWithCameraDescription => '拍攝收據，AI 自動讀取明細';

  @override
  String get capturePickFromPhotoLibrary => '從照片中選擇';

  @override
  String get capturePickFromPhotoLibraryDescription => 'AI 會將帳單或訂單截圖拆分為多筆記錄';

  @override
  String get manualEntryDescription => '輸入沒有圖片的現金支出';

  @override
  String get captureAnalyzingTitle => 'AI 正在讀取您的圖片';

  @override
  String get captureAnalyzingStepLoading => '正在載入圖片';

  @override
  String get captureAnalyzingStepReading => '正在讀取金額和日期';

  @override
  String get captureAnalyzingStepCategory => '正在推測類別';

  @override
  String get captureAnalysisFailedTitle => '無法讀取圖片';

  @override
  String get captureAnalysisNoTransactions => '無法從圖片中讀取交易紀錄';

  @override
  String get captureRetry => '再試一次';

  @override
  String get captureManualFallback => '手動輸入';

  @override
  String get captureRetake => '重新拍攝';

  @override
  String get captureConfirmTitle => '檢視明細';

  @override
  String get captureSourceImageNote => '您可以隨時從明細中查看原始圖片';

  @override
  String get captureRegister => '記錄';

  @override
  String captureCandidatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已讀取 $count 筆帳目，請選擇要記錄的項目',
    );
    return '$_temp0';
  }

  @override
  String get captureCandidateEdit => '編輯';

  @override
  String get captureCandidateApplyEdit => '套用變更';

  @override
  String captureRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '記錄 $count 筆',
    );
    return '$_temp0';
  }

  @override
  String get captureRegistered => '已記錄 ✓';

  @override
  String get captureInstructionSectionTitle => '給 AI 的補充指示';

  @override
  String get captureInstructionOpen => '請 AI 重新辨識';

  @override
  String get captureInstructionHint => '例如：最後一筆明細沒有辨識 / 第二筆金額不對';

  @override
  String get captureInstructionScanNote => '重新辨識會使用 1 次掃描';

  @override
  String get captureInstructionSend => '送出並重新辨識';

  @override
  String captureInstructionResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '重新辨識後共 $count 筆',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailTitle => '明細';

  @override
  String get transactionDetailSourceImage => '原始圖片';

  @override
  String get transactionDetailSourceImageNote => '隨時查看原始圖片';

  @override
  String get transactionDetailNoImageManual => '無圖片 · 手動輸入';

  @override
  String get transactionDetailNoImage => '沒有原始圖片';

  @override
  String get transactionDetailZoom => '縮放';

  @override
  String get transactionDetailDeleteImage => '僅刪除圖片';

  @override
  String get transactionDetailDeleteImageConfirmationTitle => '要刪除原始圖片嗎？';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      '交易記錄會保留，僅刪除圖片。此操作無法復原。';

  @override
  String get transactionDetailImageDeleted => '原始圖片已刪除';

  @override
  String get transactionDetailDelete => '刪除交易';

  @override
  String get transactionDetailDeleteConfirmationTitle => '刪除此筆明細？';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      '交易紀錄及其來源圖片將永久刪除。此操作無法復原。';

  @override
  String get transactionDetailDeleted => '交易記錄已刪除';

  @override
  String get transactionDetailNotFound => '這筆明細已刪除';

  @override
  String get transactionDetailProvenance => '來源';

  @override
  String captureInstructionLimitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每張圖片最多可補充指示 $count 次',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailAnalysisInstructions => '給 AI 的指示';

  @override
  String get transactionDetailExcludeFromAggregation => '不計入總額';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      '開啟後，將不計入總額和分類明細';

  @override
  String get transactionProvenanceAutomatic => '自動匯入';

  @override
  String get transactionProvenanceAdjusted => '已調整';

  @override
  String get capturesSection => '截圖記錄';

  @override
  String scanQuotaRemaining(int count) {
    return '剩餘 $count 次掃描';
  }

  @override
  String get scanQuotaUnlimited => '盡情掃描';

  @override
  String get scanQuotaExhausted => '本月免費掃描次數已用完';

  @override
  String get paywallTitle => '使用進階版，盡情掃描';

  @override
  String get paywallSubtitle => '無需連結帳戶。拍照即可，進階版會為您讀取每張收據和每份帳單。';

  @override
  String get paywallSavingsClaim => '透過記帳減少支出的人中，約一半每月省下 ¥5,000 至不足 ¥10,000*';

  @override
  String get paywallSavingsSource =>
      '* 調查：JPX\'s Money-bu!（2022 年 10 月，日本 1,111 名上班族）';

  @override
  String paywallFreeQuota(int used, int limit) {
    return '本月免費掃描 $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => '自由掃描';

  @override
  String get paywallBenefitFullHistory => '每月查看完整記錄';

  @override
  String get paywallBenefitFutureFeatures => '即將推出的功能';

  @override
  String get paywallMonthlyPlan => '每月';

  @override
  String get paywallAnnualPlan => '年付';

  @override
  String get paywallRecommended => '最划算';

  @override
  String paywallAnnualSavings(int percent) {
    return '節省 $percent%';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/月';
  }

  @override
  String get paywallStartPremium => '開通進階版';

  @override
  String get paywallCancelAnytime => '隨時取消';

  @override
  String get paywallRestore => '回復購買';

  @override
  String get paywallRestored => '已恢復購買。進階版已啟用。';

  @override
  String get paywallRestoreNotFound => '沒有可還原的購買項目';

  @override
  String get paywallPurchased => '進階版已啟用。盡情掃描吧！';

  @override
  String get paywallPremiumActive => '進階版已啟用';

  @override
  String get paywallPremiumActiveDescription => '您可以盡情掃描並查看完整記錄。';

  @override
  String get paywallOfferingUnavailable => '目前暫時無法取得方案';

  @override
  String get paywallFairUseNote => '掃描功能每月設有合理使用上限，一般使用情況下不會達到。';

  @override
  String get paywallSubscriptionNote =>
      '確認後，費用將從您的商店帳號中扣除。除非您在目前訂閱週期結束前至少 24 小時取消訂閱，否則訂閱將自動續訂。您可以在商店帳號設定中管理或取消訂閱。';

  @override
  String get settingsPlan => '方案';

  @override
  String get planFree => '免費';

  @override
  String get planPremium => '進階版';

  @override
  String get settingsAuditLog => '操作記錄';

  @override
  String get auditLogTitle => '操作記錄';

  @override
  String get auditLogDescription => '記錄您新增、修正或刪除的明細，以及刪除原始圖片的操作。';

  @override
  String get auditLogEmpty => '尚無操作記錄';

  @override
  String get auditLogSyncing => '正在同步';

  @override
  String get auditLogOperationTransactionCreated => '已新增';

  @override
  String get auditLogOperationTransactionUpdated => '已更正';

  @override
  String get auditLogOperationTransactionDeleted => '已刪除';

  @override
  String get auditLogOperationTransactionImageDeleted => '已刪除圖片';

  @override
  String get auditLogOperationUnknown => '其他操作';

  @override
  String get auditLogChangedFieldExcludedFromAggregation => '計入總額';

  @override
  String get auditLogChangedFieldSourceImage => '原始圖片';

  @override
  String get auditLogChangedFieldDuplicateDecision => '重複項處理方式';

  @override
  String get transactionSearchOpen => '搜尋交易紀錄';

  @override
  String get transactionSearchTitle => '搜尋';

  @override
  String get transactionSearchPeriod => '日期';

  @override
  String get transactionSearchDateFrom => '開始日期';

  @override
  String get transactionSearchDateTo => '結束日期';

  @override
  String get transactionSearchDateUnset => '不限';

  @override
  String get transactionSearchAmount => '金額';

  @override
  String get transactionSearchMinimumAmount => '最低';

  @override
  String get transactionSearchMaximumAmount => '最高';

  @override
  String get transactionSearchTitleKeyword => '店家';

  @override
  String get transactionSearchSubmit => '搜尋';

  @override
  String get transactionSearchClear => '清除條件';

  @override
  String get transactionSearchConditionRequired => '請至少輸入一項條件';

  @override
  String get transactionSearchDateRangeInvalid => '結束日期必須晚於或等於開始日期';

  @override
  String get transactionSearchAmountRangeInvalid => '最大值應設為最小值或更大';

  @override
  String get transactionSearchNoResults => '沒有符合條件的交易';

  @override
  String transactionSearchResultCount(int count) {
    return '$count 筆';
  }

  @override
  String transactionSearchFreePlanHistoryLimit(int monthCount) {
    return '免費版僅搜尋最近 $monthCount 個月的紀錄';
  }

  @override
  String auditLogFreePlanHistoryLimit(int monthCount) {
    return '免費方案僅顯示最近 $monthCount 個月的操作記錄';
  }

  @override
  String get freePlanHistoryLimitUpgrade => '使用進階版查看完整記錄';

  @override
  String get onboardingContinue => '下一步';

  @override
  String get onboardingSeePremium => '查看進階版方案';

  @override
  String get onboardingWelcomeTitle => '讓家庭收支記錄更輕鬆';

  @override
  String get onboardingWelcomeDescription => '拍下收據或線上帳單即可記入家庭帳本';

  @override
  String get onboardingValueTitle => '現在拍下以後查看';

  @override
  String get onboardingValueDescription =>
      'Kashakeibo 使用 AI 整理商店、金額、日期和類別，讓您專注於了解自己的財務狀況';

  @override
  String get onboardingPainTitle => '管理收支時最困擾你的是什麼？';

  @override
  String get onboardingPainDescription => '選擇你最想先解決的問題';

  @override
  String get onboardingPainRecordingEffort => '每次手動輸入太麻煩難以堅持';

  @override
  String get onboardingPainSpendingVisibility => '看不清錢花在了哪裡';

  @override
  String get onboardingPainReviewTime => '沒有時間回顧支出';

  @override
  String get onboardingSourceTitle => '你想記錄什麼？';

  @override
  String get onboardingSourceDescription => '我們會根據回答建議使用方案';

  @override
  String get onboardingSourceReceipt => '紙本收據';

  @override
  String get onboardingSourceOnlineStatement => '信用卡和網購帳單';

  @override
  String get onboardingSourceBoth => '收據和線上帳單都要';

  @override
  String get onboardingFrequencyTitle => '你現在多久記錄一次？';

  @override
  String get onboardingFrequencyDescription => '任何回答都可以';

  @override
  String get onboardingFrequencyDaily => '幾乎每天';

  @override
  String get onboardingFrequencyWeekly => '每週一到兩次';

  @override
  String get onboardingFrequencyOccasionally => '想起來時才記錄';

  @override
  String get onboardingGoalTitle => '你希望透過家庭帳本實現什麼？';

  @override
  String get onboardingGoalDescription => '選擇對你最重要的目標';

  @override
  String get onboardingGoalSpendLess => '減少不必要的支出';

  @override
  String get onboardingGoalUnderstandSpending => '了解自己的支出規律';

  @override
  String get onboardingGoalSaveTime => '減少記帳所花的時間';

  @override
  String get onboardingSocialProofTitle => '小小的記錄也能帶來節省';

  @override
  String get onboardingCommitmentTitle => '準備開始輕鬆記錄了嗎？';

  @override
  String get onboardingCommitmentDescription => '先從消費時拍一張照片的簡單習慣開始';

  @override
  String get onboardingGeneratingTitle => '正在產生你的使用方案';

  @override
  String get onboardingGeneratingDescription => '正在結合你的困擾記錄來源和目標';

  @override
  String get onboardingResultTitle => '你的使用方案已準備好';

  @override
  String get onboardingResultDescription => 'Kashakeibo 將您的截圖和照片整理成一目了然的月度檢視';

  @override
  String get onboardingResultRecordingEffort => '減少輸入負擔並輕鬆堅持的方案';

  @override
  String get onboardingResultSpendingVisibility => '讓每筆支出清晰可見的方案';

  @override
  String get onboardingResultReviewTime => '快速回顧每月收支的方案';

  @override
  String get onboardingPlanReceipt => '收到收據時拍下來並交給AI產生記錄';

  @override
  String get onboardingPlanOnlineStatement => '分享信用卡或購物帳單並交給AI產生記錄';

  @override
  String get onboardingPlanBoth => '拍下收據或分享截圖並把所有支出集中在一處';

  @override
  String get onboardingPlanSpendLess => '從月度頁面找出想要減少的支出';

  @override
  String get onboardingPlanUnderstandSpending => '透過類別和月度總額了解支出規律';

  @override
  String get onboardingPlanSaveTime => '用照片和截圖代替重複輸入';
}
