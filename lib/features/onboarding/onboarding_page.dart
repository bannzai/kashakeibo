import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingCompletedPreferenceKey = 'onboarding_completed_v1';
// JP短尺ファネルで待ち時間を増やさず、生成処理を知覚できる長さとして1.2秒にする。
const _planGenerationAnimationDuration = Duration(milliseconds: 1200);

/// オンボーディング完了状態を読み込む処理。
typedef LoadOnboardingCompletion = Future<bool> Function();

/// オンボーディング完了状態を保存する処理。
typedef SaveOnboardingCompletion = Future<void> Function();

/// オンボーディング直後のペイウォールを開く処理。
typedef OpenOnboardingPaywall =
    Future<void> Function({required BuildContext context});

/// 端末内に保存したオンボーディング完了状態を読み込む。
Future<bool> loadOnboardingCompletion() async {
  // キーがない初回起動は、まだ完了していない状態として扱う。
  return await SharedPreferencesAsync().getBool(
        _onboardingCompletedPreferenceKey,
      ) ??
      false;
}

/// 端末内にオンボーディング完了状態を保存する。
///
/// 同じ値を繰り返し保存しても状態が変わらないため冪等。
Future<void> saveOnboardingCompletion() =>
    SharedPreferencesAsync().setBool(_onboardingCompletedPreferenceKey, true);

/// 初回起動時だけオンボーディングを表示する resolver。
class OnboardingResolver extends HookWidget {
  final Widget child;
  final LogAnalyticsEvent logAnalyticsEvent;
  final LoadOnboardingCompletion loadOnboardingCompletion;
  final SaveOnboardingCompletion saveOnboardingCompletion;
  final OpenOnboardingPaywall openOnboardingPaywall;

  const OnboardingResolver({
    required this.child,
    required this.logAnalyticsEvent,
    required this.loadOnboardingCompletion,
    required this.saveOnboardingCompletion,
    required this.openOnboardingPaywall,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final reloadCount = useState(0);
    final completedInCurrentSession = useState(false);
    final onboardingCompletionFuture = useMemoized(loadOnboardingCompletion, [
      reloadCount.value,
    ]);
    final onboardingCompletionSnapshot = useFuture(onboardingCompletionFuture);

    if (completedInCurrentSession.value ||
        onboardingCompletionSnapshot.data == true) {
      return child;
    }
    if (onboardingCompletionSnapshot.hasError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    onboardingCompletionSnapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () {
                      unawaited(
                        logAnalyticsEvent(name: 'onboarding_load_retry'),
                      );
                      reloadCount.value += 1;
                    },
                    child: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (onboardingCompletionSnapshot.connectionState != ConnectionState.done) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return OnboardingPage(
      logAnalyticsEvent: logAnalyticsEvent,
      completeOnboarding: () async {
        await saveOnboardingCompletion();
        try {
          await logAnalyticsEvent(name: 'onboarding_complete');
        } catch (_) {
          // 計測障害で初回の課金導線を失わないよう、完了イベントはベストエフォートにする。
        }
        if (!context.mounted) {
          return;
        }
        await openOnboardingPaywall(context: context);
        if (context.mounted) {
          completedInCurrentSession.value = true;
        }
      },
    );
  }
}

enum _OnboardingPain { recordingEffort, spendingVisibility, reviewTime }

enum _OnboardingSource { receipt, onlineStatement, both }

enum _OnboardingGoal { spendLess, understandSpending, saveTime }

enum _OnboardingFrequency { daily, weekly, occasionally }

enum _OnboardingStep {
  welcome,
  valueDetails,
  pain,
  source,
  frequency,
  goal,
  socialProof,
  commitment,
  generating,
  result,
}

/// 初回起動時の課金転換型オンボーディング。
class OnboardingPage extends HookWidget {
  final LogAnalyticsEvent logAnalyticsEvent;
  final Future<void> Function() completeOnboarding;

  const OnboardingPage({
    required this.logAnalyticsEvent,
    required this.completeOnboarding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 表示中のロケール変更でページ数が変わらないよう、開始時のファネル種別を固定する。
    final isLongFunnel = useMemoized(
      () => Localizations.localeOf(context).languageCode == 'en',
      const [],
    );
    final onboardingSteps = isLongFunnel
        ? _OnboardingStep.values
        : const [
            _OnboardingStep.welcome,
            _OnboardingStep.pain,
            _OnboardingStep.source,
            _OnboardingStep.goal,
            _OnboardingStep.socialProof,
            _OnboardingStep.generating,
            _OnboardingStep.result,
          ];
    final funnelVariant = isLongFunnel ? 'long' : 'short';
    final pageController = usePageController();
    final currentPageIndex = useState(0);
    final selectedPain = useState<_OnboardingPain?>(null);
    final selectedSource = useState<_OnboardingSource?>(null);
    final selectedGoal = useState<_OnboardingGoal?>(null);
    final selectedFrequency = useState<_OnboardingFrequency?>(null);
    final completionInProgress = useState(false);
    final completionError = useState<Object?>(null);

    // 初回表示だけ開始イベントと最初のステップ表示を記録する。
    // ファネル種別はロケールから決まり、Widget の生存中は変えないため空の依存配列にする。
    useEffect(() {
      unawaited(
        logAnalyticsEvent(
          name: 'onboarding_start',
          parameters: {'funnel_variant': funnelVariant},
        ),
      );
      unawaited(
        _logOnboardingStepView(
          logAnalyticsEvent: logAnalyticsEvent,
          onboardingStep: onboardingSteps.first,
          funnelVariant: funnelVariant,
        ),
      );
      return null;
    }, const []);

    final currentOnboardingStep = onboardingSteps[currentPageIndex.value];
    final canContinue = switch (currentOnboardingStep) {
      _OnboardingStep.pain => selectedPain.value != null,
      _OnboardingStep.source => selectedSource.value != null,
      _OnboardingStep.frequency => selectedFrequency.value != null,
      _OnboardingStep.goal => selectedGoal.value != null,
      _ => true,
    };

    Future<void> goToPage({required int pageIndex}) async {
      currentPageIndex.value = pageIndex;
      await pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      unawaited(
        _logOnboardingStepView(
          logAnalyticsEvent: logAnalyticsEvent,
          onboardingStep: onboardingSteps[pageIndex],
          funnelVariant: funnelVariant,
        ),
      );
    }

    Future<void> finishOnboarding() async {
      unawaited(
        logAnalyticsEvent(
          name: 'onboarding_finish_tap',
          parameters: {'funnel_variant': funnelVariant},
        ),
      );
      if (completionInProgress.value) {
        return;
      }
      completionInProgress.value = true;
      completionError.value = null;
      try {
        await completeOnboarding();
      } catch (error) {
        completionError.value = error;
      } finally {
        completionInProgress.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: currentPageIndex.value == 0
                        ? null
                        : IconButton(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                            onPressed: completionInProgress.value
                                ? null
                                : () {
                                    unawaited(
                                      logAnalyticsEvent(
                                        name: 'onboarding_back',
                                        parameters: {
                                          'step': currentOnboardingStep.name,
                                          'funnel_variant': funnelVariant,
                                        },
                                      ),
                                    );
                                    goToPage(
                                      pageIndex: currentPageIndex.value - 1,
                                    );
                                  },
                            icon: const BackButtonIcon(),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value:
                            (currentPageIndex.value + 1) /
                            onboardingSteps.length,
                        backgroundColor: context.appColors.surfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${currentPageIndex.value + 1}/${onboardingSteps.length}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption.copyWith(
                        color: context.appColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: onboardingSteps.length,
                itemBuilder: (context, pageIndex) => _OnboardingStepContent(
                  onboardingStep: onboardingSteps[pageIndex],
                  selectedPain: selectedPain.value,
                  selectedSource: selectedSource.value,
                  selectedGoal: selectedGoal.value,
                  selectedFrequency: selectedFrequency.value,
                  onPainSelected: (onboardingPain) {
                    unawaited(
                      _logOnboardingAnswer(
                        logAnalyticsEvent: logAnalyticsEvent,
                        onboardingStep: _OnboardingStep.pain,
                        answer: onboardingPain.name,
                        funnelVariant: funnelVariant,
                      ),
                    );
                    selectedPain.value = onboardingPain;
                  },
                  onSourceSelected: (onboardingSource) {
                    unawaited(
                      _logOnboardingAnswer(
                        logAnalyticsEvent: logAnalyticsEvent,
                        onboardingStep: _OnboardingStep.source,
                        answer: onboardingSource.name,
                        funnelVariant: funnelVariant,
                      ),
                    );
                    selectedSource.value = onboardingSource;
                  },
                  onGoalSelected: (onboardingGoal) {
                    unawaited(
                      _logOnboardingAnswer(
                        logAnalyticsEvent: logAnalyticsEvent,
                        onboardingStep: _OnboardingStep.goal,
                        answer: onboardingGoal.name,
                        funnelVariant: funnelVariant,
                      ),
                    );
                    selectedGoal.value = onboardingGoal;
                  },
                  onFrequencySelected: (onboardingFrequency) {
                    unawaited(
                      _logOnboardingAnswer(
                        logAnalyticsEvent: logAnalyticsEvent,
                        onboardingStep: _OnboardingStep.frequency,
                        answer: onboardingFrequency.name,
                        funnelVariant: funnelVariant,
                      ),
                    );
                    selectedFrequency.value = onboardingFrequency;
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (completionError.value != null) ...[
                    Text(
                      completionError.value.toString(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: context.appColors.destructive,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  FilledButton(
                    onPressed: !canContinue || completionInProgress.value
                        ? null
                        : () {
                            if (currentOnboardingStep ==
                                _OnboardingStep.result) {
                              finishOnboarding();
                              return;
                            }
                            unawaited(
                              logAnalyticsEvent(
                                name: 'onboarding_continue',
                                parameters: {
                                  'step': currentOnboardingStep.name,
                                  'funnel_variant': funnelVariant,
                                },
                              ),
                            );
                            goToPage(pageIndex: currentPageIndex.value + 1);
                          },
                    child: completionInProgress.value
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            currentOnboardingStep == _OnboardingStep.result
                                ? AppLocalizations.of(
                                    context,
                                  ).onboardingSeePremium
                                : AppLocalizations.of(
                                    context,
                                  ).onboardingContinue,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _logOnboardingStepView({
  required LogAnalyticsEvent logAnalyticsEvent,
  required _OnboardingStep onboardingStep,
  required String funnelVariant,
}) => logAnalyticsEvent(
  name: 'onboarding_step_view',
  parameters: {'step': onboardingStep.name, 'funnel_variant': funnelVariant},
);

Future<void> _logOnboardingAnswer({
  required LogAnalyticsEvent logAnalyticsEvent,
  required _OnboardingStep onboardingStep,
  required String answer,
  required String funnelVariant,
}) => logAnalyticsEvent(
  name: 'onboarding_answer',
  parameters: {
    'step': onboardingStep.name,
    'answer': answer,
    'funnel_variant': funnelVariant,
  },
);

class _OnboardingStepContent extends StatelessWidget {
  final _OnboardingStep onboardingStep;
  final _OnboardingPain? selectedPain;
  final _OnboardingSource? selectedSource;
  final _OnboardingGoal? selectedGoal;
  final _OnboardingFrequency? selectedFrequency;
  final ValueChanged<_OnboardingPain> onPainSelected;
  final ValueChanged<_OnboardingSource> onSourceSelected;
  final ValueChanged<_OnboardingGoal> onGoalSelected;
  final ValueChanged<_OnboardingFrequency> onFrequencySelected;

  const _OnboardingStepContent({
    required this.onboardingStep,
    required this.selectedPain,
    required this.selectedSource,
    required this.selectedGoal,
    required this.selectedFrequency,
    required this.onPainSelected,
    required this.onSourceSelected,
    required this.onGoalSelected,
    required this.onFrequencySelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, title, description) = switch (onboardingStep) {
      _OnboardingStep.welcome => (
        Icons.auto_awesome,
        l10n.onboardingWelcomeTitle,
        l10n.onboardingWelcomeDescription,
      ),
      _OnboardingStep.valueDetails => (
        Icons.photo_camera_outlined,
        l10n.onboardingValueTitle,
        l10n.onboardingValueDescription,
      ),
      _OnboardingStep.pain => (
        Icons.sentiment_dissatisfied_outlined,
        l10n.onboardingPainTitle,
        l10n.onboardingPainDescription,
      ),
      _OnboardingStep.source => (
        Icons.receipt_long_outlined,
        l10n.onboardingSourceTitle,
        l10n.onboardingSourceDescription,
      ),
      _OnboardingStep.frequency => (
        Icons.calendar_today_outlined,
        l10n.onboardingFrequencyTitle,
        l10n.onboardingFrequencyDescription,
      ),
      _OnboardingStep.goal => (
        Icons.flag_outlined,
        l10n.onboardingGoalTitle,
        l10n.onboardingGoalDescription,
      ),
      _OnboardingStep.socialProof => (
        Icons.savings_outlined,
        l10n.onboardingSocialProofTitle,
        l10n.paywallSavingsClaim,
      ),
      _OnboardingStep.commitment => (
        Icons.handshake_outlined,
        l10n.onboardingCommitmentTitle,
        l10n.onboardingCommitmentDescription,
      ),
      _OnboardingStep.generating => (
        Icons.tune,
        l10n.onboardingGeneratingTitle,
        l10n.onboardingGeneratingDescription,
      ),
      _OnboardingStep.result => (
        Icons.check_circle_outline,
        _resultTitle(l10n: l10n, selectedPain: selectedPain),
        l10n.onboardingResultDescription,
      ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.appColors.accent200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: context.appColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: context.appColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ...switch (onboardingStep) {
          _OnboardingStep.pain => _painOptions(
            l10n: l10n,
            selectedPain: selectedPain,
            onPainSelected: onPainSelected,
          ),
          _OnboardingStep.source => _sourceOptions(
            l10n: l10n,
            selectedSource: selectedSource,
            onSourceSelected: onSourceSelected,
          ),
          _OnboardingStep.frequency => _frequencyOptions(
            l10n: l10n,
            selectedFrequency: selectedFrequency,
            onFrequencySelected: onFrequencySelected,
          ),
          _OnboardingStep.goal => _goalOptions(
            l10n: l10n,
            selectedGoal: selectedGoal,
            onGoalSelected: onGoalSelected,
          ),
          _OnboardingStep.socialProof => [
            _InformationCard(
              icon: Icons.format_quote,
              text: l10n.paywallSavingsSource,
            ),
          ],
          _OnboardingStep.generating => [
            Center(
              child: SizedBox.square(
                dimension: 72,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: _planGenerationAnimationDuration,
                  builder: (context, progress, _) => CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                  ),
                ),
              ),
            ),
          ],
          _OnboardingStep.result => [
            _InformationCard(
              icon: Icons.auto_awesome,
              text: _resultPlan(
                l10n: l10n,
                selectedSource: selectedSource,
                selectedGoal: selectedGoal,
              ),
            ),
          ],
          _ => const <Widget>[],
        },
      ],
    );
  }
}

List<Widget> _painOptions({
  required AppLocalizations l10n,
  required _OnboardingPain? selectedPain,
  required ValueChanged<_OnboardingPain> onPainSelected,
}) => [
  _ChoiceCard(
    icon: Icons.edit_note,
    label: l10n.onboardingPainRecordingEffort,
    selected: selectedPain == _OnboardingPain.recordingEffort,
    onTap: () => onPainSelected(_OnboardingPain.recordingEffort),
  ),
  _ChoiceCard(
    icon: Icons.visibility_off_outlined,
    label: l10n.onboardingPainSpendingVisibility,
    selected: selectedPain == _OnboardingPain.spendingVisibility,
    onTap: () => onPainSelected(_OnboardingPain.spendingVisibility),
  ),
  _ChoiceCard(
    icon: Icons.schedule,
    label: l10n.onboardingPainReviewTime,
    selected: selectedPain == _OnboardingPain.reviewTime,
    onTap: () => onPainSelected(_OnboardingPain.reviewTime),
  ),
];

List<Widget> _sourceOptions({
  required AppLocalizations l10n,
  required _OnboardingSource? selectedSource,
  required ValueChanged<_OnboardingSource> onSourceSelected,
}) => [
  _ChoiceCard(
    icon: Icons.receipt_outlined,
    label: l10n.onboardingSourceReceipt,
    selected: selectedSource == _OnboardingSource.receipt,
    onTap: () => onSourceSelected(_OnboardingSource.receipt),
  ),
  _ChoiceCard(
    icon: Icons.language,
    label: l10n.onboardingSourceOnlineStatement,
    selected: selectedSource == _OnboardingSource.onlineStatement,
    onTap: () => onSourceSelected(_OnboardingSource.onlineStatement),
  ),
  _ChoiceCard(
    icon: Icons.collections_outlined,
    label: l10n.onboardingSourceBoth,
    selected: selectedSource == _OnboardingSource.both,
    onTap: () => onSourceSelected(_OnboardingSource.both),
  ),
];

List<Widget> _frequencyOptions({
  required AppLocalizations l10n,
  required _OnboardingFrequency? selectedFrequency,
  required ValueChanged<_OnboardingFrequency> onFrequencySelected,
}) => [
  _ChoiceCard(
    icon: Icons.today,
    label: l10n.onboardingFrequencyDaily,
    selected: selectedFrequency == _OnboardingFrequency.daily,
    onTap: () => onFrequencySelected(_OnboardingFrequency.daily),
  ),
  _ChoiceCard(
    icon: Icons.date_range,
    label: l10n.onboardingFrequencyWeekly,
    selected: selectedFrequency == _OnboardingFrequency.weekly,
    onTap: () => onFrequencySelected(_OnboardingFrequency.weekly),
  ),
  _ChoiceCard(
    icon: Icons.event_available_outlined,
    label: l10n.onboardingFrequencyOccasionally,
    selected: selectedFrequency == _OnboardingFrequency.occasionally,
    onTap: () => onFrequencySelected(_OnboardingFrequency.occasionally),
  ),
];

List<Widget> _goalOptions({
  required AppLocalizations l10n,
  required _OnboardingGoal? selectedGoal,
  required ValueChanged<_OnboardingGoal> onGoalSelected,
}) => [
  _ChoiceCard(
    icon: Icons.trending_down,
    label: l10n.onboardingGoalSpendLess,
    selected: selectedGoal == _OnboardingGoal.spendLess,
    onTap: () => onGoalSelected(_OnboardingGoal.spendLess),
  ),
  _ChoiceCard(
    icon: Icons.pie_chart_outline,
    label: l10n.onboardingGoalUnderstandSpending,
    selected: selectedGoal == _OnboardingGoal.understandSpending,
    onTap: () => onGoalSelected(_OnboardingGoal.understandSpending),
  ),
  _ChoiceCard(
    icon: Icons.more_time,
    label: l10n.onboardingGoalSaveTime,
    selected: selectedGoal == _OnboardingGoal.saveTime,
    onTap: () => onGoalSelected(_OnboardingGoal.saveTime),
  ),
];

String _resultTitle({
  required AppLocalizations l10n,
  required _OnboardingPain? selectedPain,
}) => switch (selectedPain) {
  _OnboardingPain.recordingEffort => l10n.onboardingResultRecordingEffort,
  _OnboardingPain.spendingVisibility => l10n.onboardingResultSpendingVisibility,
  _OnboardingPain.reviewTime => l10n.onboardingResultReviewTime,
  null => l10n.onboardingResultTitle,
};

String _resultPlan({
  required AppLocalizations l10n,
  required _OnboardingSource? selectedSource,
  required _OnboardingGoal? selectedGoal,
}) {
  final sourceText = switch (selectedSource) {
    _OnboardingSource.receipt => l10n.onboardingPlanReceipt,
    _OnboardingSource.onlineStatement => l10n.onboardingPlanOnlineStatement,
    _OnboardingSource.both || null => l10n.onboardingPlanBoth,
  };
  final goalText = switch (selectedGoal) {
    _OnboardingGoal.spendLess => l10n.onboardingPlanSpendLess,
    _OnboardingGoal.understandSpending => l10n.onboardingPlanUnderstandSpending,
    _OnboardingGoal.saveTime || null => l10n.onboardingPlanSaveTime,
  };
  return '$sourceText\n\n$goalText';
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Material(
      color: selected ? context.appColors.accent200 : context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected
                  ? context.appColors.primary
                  : context.appColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: context.appColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTextStyles.body)),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? context.appColors.primary
                    : context.appColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InformationCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InformationCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: context.appColors.sage100,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: context.appColors.sage300),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.appColors.secondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    ),
  );
}
