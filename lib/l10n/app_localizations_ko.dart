// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Kashakeibo';

  @override
  String get monthlyIncome => '수입';

  @override
  String get monthlyExpense => '지출';

  @override
  String get monthlyBalance => '잔액';

  @override
  String get categoryBreakdown => '카테고리';

  @override
  String get monthlyTransactionsEmpty => '이번 달 거래 내역이 없습니다';

  @override
  String get excludedFromAggregation => '제외됨';

  @override
  String duplicateCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '중복 가능성이 있는 내역이 $count건 있습니다',
    );
    return '$_temp0';
  }

  @override
  String get duplicateCandidateReviewHint => '탭하여 검토';

  @override
  String get duplicateCandidateTitle => '중복 가능 항목 검토';

  @override
  String get duplicateCandidateDescription =>
      '이 거래들은 금액, 날짜, 상점명이 비슷합니다. 동일한 지출인지 확인해 주십시오.';

  @override
  String get duplicateCandidateReason => '금액이 같고 날짜가 가까우며 상점명이 유사합니다.';

  @override
  String get duplicateCandidateKeep => '이 거래 유지';

  @override
  String get mergeDuplicateCandidate => '한 건으로 병합';

  @override
  String get keepBothDuplicateCandidates => '별도 지출로 유지';

  @override
  String get previousMonth => '이전 달';

  @override
  String get nextMonth => '다음 달';

  @override
  String get openSettings => '설정 열기';

  @override
  String get settings => '설정';

  @override
  String get termsOfService => '이용 약관';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get specifiedCommercialTransactionAct => '상거래 공개';

  @override
  String get accountBackupTitle => '백업';

  @override
  String get accountBackupNotSet => '미설정';

  @override
  String get accountBackupConfigured => '설정됨';

  @override
  String get accountBackupDescription => '기기를 변경해도 데이터를 유지하려면 계정을 연결하십시오.';

  @override
  String get accountBackupConfiguredDescription =>
      '다른 기기에서 같은 계정을 선택하면 저장된 데이터에 액세스할 수 있습니다.';

  @override
  String get linkOrSignInWithApple => 'Apple 연결';

  @override
  String get linkOrSignInWithGoogle => 'Google 연결';

  @override
  String get accountLinked => '계정이 연결되었습니다';

  @override
  String get existingAccountSignedIn => '기존 계정으로 전환되었습니다.';

  @override
  String get accountSwitchWarningTitle => '이 기기의 데이터 확인';

  @override
  String get accountSwitchWarningMessage =>
      '선택한 계정이 다른 기기에서 이미 사용 중인 경우, 이 기기에서 익명으로 저장된 데이터에 더 이상 접근할 수 없습니다. 계속하기 전에 필요한 거래 내역을 확인하시기 바랍니다.';

  @override
  String get continueAccountLink => '계속';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get deleteAccountConfirmationTitle => '계정을 삭제하시겠습니까?';

  @override
  String get deleteAccountConfirmationMessage =>
      '계정과 저장된 거래 내역이 영구적으로 삭제되며, 복구할 수 없습니다.';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get categoryFood => '식비';

  @override
  String get categoryEatingOut => '외식';

  @override
  String get categoryDailyGoods => '생활용품';

  @override
  String get categoryTransportation => '교통';

  @override
  String get categorySubscription => '구독';

  @override
  String get categorySalary => '급여';

  @override
  String get categoryOther => '기타';

  @override
  String get manualEntryOpen => '수동 입력';

  @override
  String get manualEntryTitle => '수동 입력';

  @override
  String get manualEntryAmount => '금액';

  @override
  String get manualEntryAmountRequired => '1엔 이상의 금액을 입력하십시오';

  @override
  String get manualEntryStore => '매장 또는 메모';

  @override
  String get manualEntryDefaultTitle => '현금 지출';

  @override
  String get manualEntryStoreRequired => '가게 또는 메모 입력';

  @override
  String get manualEntryType => '거래 유형';

  @override
  String get manualEntryCategory => '카테고리';

  @override
  String get manualEntryCategoryRequired => '카테고리 선택';

  @override
  String get manualEntryDate => '날짜';

  @override
  String get manualEntryRegister => '거래 추가';

  @override
  String get manualEntryRegistered => '거래가 추가되었습니다';

  @override
  String get transactionSourceReceipt => '영수증';

  @override
  String get transactionSourceScreenshot => '스크린샷';

  @override
  String get transactionSourceManual => '수동';

  @override
  String get transactionSourceUnknown => '출처 불명';

  @override
  String get addRecordOpen => '기록 추가';

  @override
  String get addRecordTitle => '기록 추가';

  @override
  String get captureReceiptWithCamera => '사진 촬영';

  @override
  String get captureReceiptWithCameraDescription => '영수증을 촬영하면 AI가 내역을 읽습니다';

  @override
  String get capturePickFromPhotoLibrary => '사진에서 선택';

  @override
  String get capturePickFromPhotoLibraryDescription =>
      'AI가 명세서 또는 주문 스크린샷을 항목별 내역으로 분할합니다';

  @override
  String get manualEntryDescription => '이미지 없이 현금 지출 입력';

  @override
  String get captureAnalyzingTitle => 'AI가 이미지를 읽고 있습니다';

  @override
  String get captureAnalyzingStepLoading => '이미지를 불러오는 중입니다';

  @override
  String get captureAnalyzingStepReading => '금액과 날짜를 읽고 있습니다';

  @override
  String get captureAnalyzingStepCategory => '카테고리를 추정하고 있습니다';

  @override
  String get captureAnalysisFailedTitle => '이미지를 읽을 수 없습니다';

  @override
  String get captureAnalysisNoTransactions => '이미지에서 거래 내역을 읽을 수 없습니다';

  @override
  String get captureRetry => '다시 시도';

  @override
  String get captureManualFallback => '수동 입력';

  @override
  String get captureRetake => '재촬영';

  @override
  String get captureConfirmTitle => '상세 내역 검토';

  @override
  String get captureSourceImageNote => '거래 내역에서 원본 이미지를 언제든지 다시 확인할 수 있습니다.';

  @override
  String get captureRegister => '등록';

  @override
  String captureCandidatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '읽어들인 $count건 중 등록할 내역을 선택해 주세요',
    );
    return '$_temp0';
  }

  @override
  String get captureCandidateEdit => '편집';

  @override
  String get captureCandidateApplyEdit => '변경 사항 적용';

  @override
  String captureRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건 등록',
    );
    return '$_temp0';
  }

  @override
  String get captureRegistered => '기록되었습니다 ✓';

  @override
  String get captureInstructionSectionTitle => 'AI에 보낸 추가 지시';

  @override
  String get captureInstructionOpen => 'AI에 지시하여 다시 읽기';

  @override
  String get captureInstructionHint => '예: 맨 아래 내역이 읽히지 않음 / 두 번째 금액이 다름';

  @override
  String get captureInstructionScanNote => '다시 읽기에는 스캔 1회가 사용됩니다';

  @override
  String get captureInstructionSend => '보내고 다시 읽기';

  @override
  String captureInstructionResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '다시 읽어 $count건이 되었습니다',
    );
    return '$_temp0';
  }

  @override
  String get transactionDetailTitle => '거래 내역';

  @override
  String get transactionDetailSourceImage => '원본 이미지';

  @override
  String get transactionDetailSourceImageNote => '언제든지 원본 이미지를 다시 확인할 수 있습니다';

  @override
  String get transactionDetailNoImageManual => '이미지 없음 · 수동 입력';

  @override
  String get transactionDetailNoImage => '원본 이미지 없음';

  @override
  String get transactionDetailZoom => '확대';

  @override
  String get transactionDetailDeleteImage => '이미지만 삭제';

  @override
  String get transactionDetailDeleteImageConfirmationTitle =>
      '원본 이미지를 삭제하시겠습니까?';

  @override
  String get transactionDetailDeleteImageConfirmationMessage =>
      '거래 내역은 유지되고 이미지만 삭제됩니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get transactionDetailImageDeleted => '원본 이미지가 삭제되었습니다.';

  @override
  String get transactionDetailDelete => '거래 삭제';

  @override
  String get transactionDetailDeleteConfirmationTitle => '이 거래 내역을 삭제하시겠습니까?';

  @override
  String get transactionDetailDeleteConfirmationMessage =>
      '거래 내역과 원본 이미지는 영구적으로 삭제됩니다. 이 작업은 취소할 수 없습니다.';

  @override
  String get transactionDetailDeleted => '거래 내역이 삭제되었습니다';

  @override
  String get transactionDetailNotFound => '이 내역은 삭제되었습니다';

  @override
  String get transactionDetailProvenance => '출처';

  @override
  String get transactionDetailAnalysisInstructions => 'AI에 보낸 지시';

  @override
  String get transactionDetailExcludeFromAggregation => '합계에서 제외';

  @override
  String get transactionDetailExcludeFromAggregationDescription =>
      '켜면 합계와 카테고리별 내역에 포함되지 않습니다.';

  @override
  String get transactionProvenanceAutomatic => '자동 가져오기';

  @override
  String get transactionProvenanceAdjusted => '조정됨';

  @override
  String get capturesSection => '캡처 기록';

  @override
  String scanQuotaRemaining(int count) {
    return '스캔 $count회 남음';
  }

  @override
  String get scanQuotaUnlimited => '마음껏 스캔';

  @override
  String get scanQuotaExhausted => '이번 달 무료 스캔을 모두 사용했습니다.';

  @override
  String get paywallTitle => '프리미엄으로 자유롭게 스캔';

  @override
  String get paywallSubtitle =>
      '계정 연동이 필요 없습니다. 촬영만 하면 프리미엄이 모든 영수증과 명세서를 읽어드립니다.';

  @override
  String get paywallSavingsClaim =>
      '가계부로 지출을 줄인 사람 중 약 절반이 매월 ¥5,000 이상 ¥10,000 미만을 절약했습니다*';

  @override
  String get paywallSavingsSource =>
      '* JPX\'s Money-bu! 조사 (2022년 10월, 일본 직장인 1,111명)';

  @override
  String paywallFreeQuota(int used, int limit) {
    return '이번 달 무료 스캔 $used/$limit';
  }

  @override
  String get paywallBenefitUnlimitedScans => '자유로운 스캔';

  @override
  String get paywallBenefitFullHistory => '매월 전체 내역';

  @override
  String get paywallBenefitFutureFeatures => '추가 예정 기능';

  @override
  String get paywallMonthlyPlan => '월간';

  @override
  String get paywallAnnualPlan => '연간';

  @override
  String get paywallRecommended => '최고 혜택';

  @override
  String paywallAnnualSavings(int percent) {
    return '$percent% 할인';
  }

  @override
  String paywallPerMonthEquivalent(String price) {
    return '$price/월';
  }

  @override
  String get paywallStartPremium => '프리미엄 이용 시작';

  @override
  String get paywallCancelAnytime => '언제든지 취소할 수 있습니다';

  @override
  String get paywallRestore => '구매 복원';

  @override
  String get paywallRestored => '구매 항목이 복원되었습니다. 프리미엄이 활성화되었습니다.';

  @override
  String get paywallRestoreNotFound => '복원할 구매 내역이 없습니다';

  @override
  String get paywallPurchased => '프리미엄이 활성화되었습니다. 마음껏 스캔하세요!';

  @override
  String get paywallPremiumActive => '프리미엄이 활성화되어 있습니다';

  @override
  String get paywallPremiumActiveDescription => '마음껏 스캔하고 전체 기록을 확인할 수 있습니다.';

  @override
  String get paywallOfferingUnavailable => '현재 요금제를 이용할 수 없습니다';

  @override
  String get paywallFairUseNote =>
      '스캔 기능에는 월별 공정 사용 한도가 있으며, 일반적인 사용으로는 한도에 도달하지 않습니다.';

  @override
  String get paywallSubscriptionNote =>
      '확인 시 스토어 계정으로 요금이 청구됩니다. 현재 구독 기간이 종료되기 최소 24시간 전에 취소하지 않으면 구독이 자동으로 갱신됩니다. 스토어 계정 설정에서 구독을 관리하거나 취소할 수 있습니다.';

  @override
  String get settingsPlan => '요금제';

  @override
  String get planFree => '무료';

  @override
  String get planPremium => '프리미엄';

  @override
  String get settingsAuditLog => '작업 기록';

  @override
  String get auditLogTitle => '작업 기록';

  @override
  String get auditLogDescription => '추가, 수정 또는 삭제한 내역과 삭제한 원본 이미지의 기록입니다.';

  @override
  String get auditLogEmpty => '아직 기록된 작업이 없습니다';

  @override
  String get auditLogSyncing => '동기화 중';

  @override
  String get auditLogOperationTransactionCreated => '추가됨';

  @override
  String get auditLogOperationTransactionUpdated => '수정됨';

  @override
  String get auditLogOperationTransactionDeleted => '삭제';

  @override
  String get auditLogOperationTransactionImageDeleted => '이미지 삭제';

  @override
  String get auditLogOperationUnknown => '기타 작업';

  @override
  String get auditLogChangedFieldExcludedFromAggregation => '합계 포함 여부';

  @override
  String get auditLogChangedFieldSourceImage => '원본 이미지';

  @override
  String get auditLogChangedFieldDuplicateDecision => '중복 항목 처리 방식';

  @override
  String get transactionSearchOpen => '거래 검색';

  @override
  String get transactionSearchTitle => '검색';

  @override
  String get transactionSearchPeriod => '날짜';

  @override
  String get transactionSearchDateFrom => '시작일';

  @override
  String get transactionSearchDateTo => '종료일';

  @override
  String get transactionSearchDateUnset => '전체';

  @override
  String get transactionSearchAmount => '금액';

  @override
  String get transactionSearchMinimumAmount => '최소';

  @override
  String get transactionSearchMaximumAmount => '최대';

  @override
  String get transactionSearchTitleKeyword => '상호';

  @override
  String get transactionSearchSubmit => '검색';

  @override
  String get transactionSearchClear => '조건 지우기';

  @override
  String get transactionSearchConditionRequired => '조건을 하나 이상 입력하십시오';

  @override
  String get transactionSearchDateRangeInvalid => '종료 날짜는 시작 날짜와 같거나 이후여야 합니다';

  @override
  String get transactionSearchAmountRangeInvalid => '최댓값은 최솟값 이상으로 설정해야 합니다.';

  @override
  String get transactionSearchNoResults => '조건에 일치하는 거래가 없습니다';

  @override
  String transactionSearchResultCount(int count) {
    return '$count건';
  }

  @override
  String transactionSearchFreePlanHistoryLimit(int monthCount) {
    return '무료 플랜에서는 최근 $monthCount개월만 검색합니다';
  }

  @override
  String auditLogFreePlanHistoryLimit(int monthCount) {
    return '무료 플랜에서는 최근 $monthCount개월의 작업 기록만 표시됩니다';
  }

  @override
  String get freePlanHistoryLimitUpgrade => '프리미엄으로 전체 내역 보기';

  @override
  String get onboardingContinue => '다음';

  @override
  String get onboardingSeePremium => '프리미엄 플랜 보기';

  @override
  String get onboardingWelcomeTitle => '가계 기록을 더 간편하게';

  @override
  String get onboardingWelcomeDescription =>
      '영수증이나 온라인 명세서를 촬영하면 가계부에 기록할 수 있어요';

  @override
  String get onboardingValueTitle => '지금 촬영하고 나중에 확인하세요';

  @override
  String get onboardingValueDescription =>
      'AI가 상점과 금액과 날짜와 카테고리를 정리해 줘서 지출을 이해하는 데 집중할 수 있어요';

  @override
  String get onboardingPainTitle => '가계 관리에서 가장 어려운 점은 무엇인가요?';

  @override
  String get onboardingPainDescription => '먼저 해결하고 싶은 고민을 선택하세요';

  @override
  String get onboardingPainRecordingEffort => '매번 입력하기 번거로워서 계속하지 못해요';

  @override
  String get onboardingPainSpendingVisibility => '어디에 썼는지 파악하기 어려워요';

  @override
  String get onboardingPainReviewTime => '지출을 돌아볼 시간이 없어요';

  @override
  String get onboardingSourceTitle => '무엇을 기록하고 싶나요?';

  @override
  String get onboardingSourceDescription => '답변에 맞춰 사용 계획을 제안해 드려요';

  @override
  String get onboardingSourceReceipt => '종이 영수증';

  @override
  String get onboardingSourceOnlineStatement => '카드와 온라인 쇼핑 명세서';

  @override
  String get onboardingSourceBoth => '영수증과 온라인 명세서 모두';

  @override
  String get onboardingFrequencyTitle => '지금은 얼마나 자주 기록하나요?';

  @override
  String get onboardingFrequencyDescription => '어떤 답변이든 괜찮아요';

  @override
  String get onboardingFrequencyDaily => '거의 매일';

  @override
  String get onboardingFrequencyWeekly => '일주일에 한두 번';

  @override
  String get onboardingFrequencyOccasionally => '생각날 때만';

  @override
  String get onboardingGoalTitle => '가계부로 무엇을 이루고 싶나요?';

  @override
  String get onboardingGoalDescription => '가장 중요한 목표를 선택하세요';

  @override
  String get onboardingGoalSpendLess => '불필요한 지출을 줄이고 싶어요';

  @override
  String get onboardingGoalUnderstandSpending => '지출 패턴을 알고 싶어요';

  @override
  String get onboardingGoalSaveTime => '가계부에 드는 시간을 줄이고 싶어요';

  @override
  String get onboardingSocialProofTitle => '작은 기록이 절약으로 이어져요';

  @override
  String get onboardingCommitmentTitle => '간편한 기록을 시작할까요?';

  @override
  String get onboardingCommitmentDescription => '결제할 때 촬영하는 간단한 습관부터 시작해요';

  @override
  String get onboardingGeneratingTitle => '맞춤 사용 계획을 만드는 중';

  @override
  String get onboardingGeneratingDescription => '고민과 기록할 명세서와 목표를 조합하고 있어요';

  @override
  String get onboardingResultTitle => '맞춤 사용 계획이 준비됐어요';

  @override
  String get onboardingResultDescription =>
      '촬영한 명세서를 월별로 정리해 지출을 한눈에 돌아볼 수 있어요';

  @override
  String get onboardingResultRecordingEffort => '입력 수고를 줄여 꾸준히 기록하는 계획';

  @override
  String get onboardingResultSpendingVisibility => '사용한 돈을 선명하게 보여 주는 계획';

  @override
  String get onboardingResultReviewTime => '짧은 시간에 지출을 돌아보는 계획';

  @override
  String get onboardingPlanReceipt => '영수증을 받으면 촬영하고 AI에게 기록을 맡겨요';

  @override
  String get onboardingPlanOnlineStatement => '카드와 쇼핑 명세서를 공유하고 AI에게 기록을 맡겨요';

  @override
  String get onboardingPlanBoth => '영수증과 온라인 명세서를 촬영해 지출을 한곳에 모아요';

  @override
  String get onboardingPlanSpendLess => '월간 화면에서 줄이고 싶은 지출을 찾아요';

  @override
  String get onboardingPlanUnderstandSpending => '카테고리와 월 합계로 지출 패턴을 파악해요';

  @override
  String get onboardingPlanSaveTime => '반복 입력 대신 사진과 스크린샷으로 기록해요';
}
