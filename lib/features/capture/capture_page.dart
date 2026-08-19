import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/capture/receipt_camera.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/transaction_labels.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:uuid/uuid.dart';

/// 撮影フロー画面 ([CapturePage]) の終了理由。
enum CaptureFlowResult {
  /// 明細を登録して終了した。
  registered,

  /// 「取り直す」が選ばれた (呼び出し側はカメラを開き直す)。
  retake,

  /// 登録せずに閉じた。
  cancelled,
}

/// 撮影 → 解析 → 確認・修正 → 登録の一連のフローを実行する。
///
/// [captureReceiptImage] でレシートを撮影し、[CapturePage] を開く。「取り直す」が
/// 選ばれた場合は撮影からやり直す。登録完了時は「カシャッと記録!」トーストを表示する。
/// ユーザー操作ごとに実行する副作用のため冪等ではない。
Future<void> runReceiptCaptureFlow({
  required BuildContext context,
  required CaptureReceiptImage captureReceiptImage,
  required LogAnalyticsEvent logAnalyticsEvent,
}) async {
  while (true) {
    unawaited(logAnalyticsEvent(name: 'capture_camera_open'));
    final CapturedImage? capturedImage;
    try {
      capturedImage = await captureReceiptImage();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
    if (!context.mounted || capturedImage == null) {
      unawaited(logAnalyticsEvent(name: 'capture_camera_cancel'));
      return;
    }
    final captureFlowResult = await showCapturePage(
      context: context,
      imageBytes: capturedImage.imageBytes,
      imageContentType: capturedImage.imageContentType,
      logAnalyticsEvent: logAnalyticsEvent,
    );
    if (!context.mounted) {
      return;
    }
    switch (captureFlowResult) {
      case CaptureFlowResult.registered:
        showCaptureRegisteredToast(context: context);
        return;
      case CaptureFlowResult.retake:
        continue;
      case CaptureFlowResult.cancelled || null:
        return;
    }
  }
}

/// 撮影フロー画面を全画面ダイアログとして開き、終了理由を返す。
Future<CaptureFlowResult?> showCapturePage({
  required BuildContext context,
  required Uint8List imageBytes,
  required String imageContentType,
  required LogAnalyticsEvent logAnalyticsEvent,
}) => Navigator.of(context).push<CaptureFlowResult>(
  MaterialPageRoute<CaptureFlowResult>(
    fullscreenDialog: true,
    builder: (context) => CapturePage(
      imageBytes: imageBytes,
      imageContentType: imageContentType,
      logAnalyticsEvent: logAnalyticsEvent,
    ),
  ),
);

// 登録完了トーストの表示時間 (design_handoff_kashakeibo/README.md の取込フロー 6「2.4s で消える」)。
const _captureRegisteredToastDuration = Duration(milliseconds: 2400);

/// 登録完了トースト「カシャッと記録!」(sage-700 のピル) を表示する。
void showCaptureRegisteredToast({required BuildContext context}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppLocalizations.of(context).captureRegistered,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.sage700,
      shape: const StadiumBorder(),
      // 下部の extended FAB と重ならない位置に出す。
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 100),
      duration: _captureRegisteredToastDuration,
    ),
  );
}

/// 撮影フローの進行状態。
enum _CapturePhase {
  /// アップロードと Gemini 解析の実行中。
  analyzing,

  /// アップロードまたは解析に失敗した (再試行・手動入力・取り直しを選べる)。
  failed,

  /// 解析結果の確認・修正フォームを表示中。
  confirming,
}

/// 撮影した画像をアップロード → Gemini 解析 → 確認・修正 → 登録する画面
/// (design_handoff_kashakeibo/README.md の取込フロー 4「AI 解析中」・5「読み取り確認」)。
///
/// 解析に失敗した場合はエラーを表示し、再試行・手動入力 (画像付きの空フォーム)・
/// 取り直しへ進める (issue #7 の受け入れ条件)。
class CapturePage extends HookConsumerWidget {
  /// 撮影した画像のバイト列。
  final Uint8List imageBytes;

  /// 撮影した画像の Content-Type。
  final String imageContentType;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const CapturePage({
    required this.imageBytes,
    required this.imageContentType,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadCapturedImage = ref.watch(uploadCapturedImageProvider);
    final analyzeUploadedImage = ref.watch(analyzeUploadedImageProvider);
    final deleteStoredImage = ref.watch(deleteStoredImageProvider);
    final addTransaction = ref.watch(addTransactionProvider);
    // 論理アップロード ID。再試行でも同じ ID を使い、Worker 側で同じキーに収束させる
    // (孤児画像を作らない。lib/features/image_upload/README.md)。
    final uploadImageID = useMemoized(() => const Uuid().v4());
    final uploadedImageObjectKey = useState<String?>(null);
    final analyzedTransaction = useState<AnalyzedTransaction?>(null);
    final capturePhase = useState(_CapturePhase.analyzing);
    final analysisError = useState<Object?>(null);
    // 再試行のたびに増やし、解析の再実行と確認フォームの初期値のリセットに使う。
    final analysisAttempt = useState(0);
    // 登録 (Firestore 書き込み) の実行中。閉じる・取り直すを無効にし、登録と画像削除が
    // 並行しないようにする。
    final isSubmitting = useState(false);
    // 登録せずに閉じる操作 (閉じる・取り直す・システムの戻る) が行われたか。
    // アップロード完了前に閉じられた場合、完了側がこのフラグを見て画像を消す。
    final discarded = useRef(false);
    final l10n = AppLocalizations.of(context);

    /// アップロード済み画像を消す。失敗しても登録されない画像が残るだけなので例外にしない。
    Future<void> deleteUploadedImage({required String imageObjectKey}) async {
      try {
        await deleteStoredImage(imageObjectKey: imageObjectKey);
      } catch (error) {
        debugPrint('撮影フローの中断時に画像を削除できませんでした: $error');
      }
    }

    Future<void> uploadAndAnalyze() async {
      capturePhase.value = _CapturePhase.analyzing;
      analysisError.value = null;
      try {
        final imageObjectKey =
            uploadedImageObjectKey.value ??
            await uploadCapturedImage(
              imageBytes: imageBytes,
              imageContentType: imageContentType,
              uploadImageID: uploadImageID,
            );
        if (discarded.value) {
          // アップロード中に閉じられた。画面はもう無いので、できたばかりの画像を消す。
          await deleteUploadedImage(imageObjectKey: imageObjectKey);
          return;
        }
        if (!context.mounted) {
          return;
        }
        uploadedImageObjectKey.value = imageObjectKey;
        final imageAnalysisResult = await analyzeUploadedImage(
          imageObjectKey: imageObjectKey,
        );
        if (!context.mounted) {
          return;
        }
        if (imageAnalysisResult.transactions.isEmpty) {
          throw StateError(l10n.captureAnalysisNoTransactions);
        }
        // レシートは 1 枚 1 明細で返る契約 (workers/image/src/analysis.ts)。
        // 複数明細のスクショ (issue #8) はこの画面のスコープ外のため先頭だけを使う。
        analyzedTransaction.value = imageAnalysisResult.transactions.first;
        capturePhase.value = _CapturePhase.confirming;
        unawaited(logAnalyticsEvent(name: 'capture_analysis_succeeded'));
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        analysisError.value = error;
        capturePhase.value = _CapturePhase.failed;
        unawaited(logAnalyticsEvent(name: 'capture_analysis_failed'));
      }
    }

    // 画面を開いた直後と「もう一度読み取る」のたびにアップロード → 解析を実行する。
    // 依存配列は再試行カウンタだけにし、画像バイト列 (画面生成時に固定) や
    // Provider の関数 (再ビルドで同一) を含めて二重実行しないようにする。
    useEffect(() {
      uploadAndAnalyze();
      return null;
    }, [analysisAttempt.value]);

    /// アップロード済みの画像を消してから画面を閉じる (登録しない終了)。
    /// 削除失敗は登録されない画像が残るだけなので、閉じる操作を妨げない。
    /// 登録の実行中と、既に閉じる処理が始まっている時は何もしない。
    Future<void> discardAndClose({required CaptureFlowResult result}) async {
      if (isSubmitting.value || discarded.value) {
        return;
      }
      discarded.value = true;
      final imageObjectKey = uploadedImageObjectKey.value;
      if (imageObjectKey != null) {
        await deleteUploadedImage(imageObjectKey: imageObjectKey);
      }
      if (context.mounted) {
        Navigator.of(context).pop(result);
      }
    }

    // システムの戻る操作 (Android の戻る等) でも閉じるボタンと同じ破棄処理を通す。
    // 登録中は pop 自体を受け付けない。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(logAnalyticsEvent(name: 'capture_cancel'));
        discardAndClose(result: CaptureFlowResult.cancelled);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(switch (capturePhase.value) {
            _CapturePhase.analyzing => l10n.captureAnalyzingTitle,
            _CapturePhase.failed => l10n.captureAnalysisFailedTitle,
            _CapturePhase.confirming => l10n.captureConfirmTitle,
          }, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: isSubmitting.value
                ? null
                : () {
                    unawaited(logAnalyticsEvent(name: 'capture_cancel'));
                    discardAndClose(result: CaptureFlowResult.cancelled);
                  },
          ),
        ),
        body: SafeArea(
          child: switch (capturePhase.value) {
            _CapturePhase.analyzing => const _AnalyzingView(),
            _CapturePhase.failed => _AnalysisFailedView(
              error: analysisError.value,
              onRetry: () {
                unawaited(logAnalyticsEvent(name: 'capture_analysis_retry'));
                analysisAttempt.value++;
              },
              onManualFallback: () {
                unawaited(logAnalyticsEvent(name: 'capture_manual_fallback'));
                analyzedTransaction.value = null;
                capturePhase.value = _CapturePhase.confirming;
              },
              onRetake: () {
                unawaited(logAnalyticsEvent(name: 'capture_retake'));
                discardAndClose(result: CaptureFlowResult.retake);
              },
            ),
            _CapturePhase.confirming => _CaptureConfirmForm(
              // 再試行で解析し直した時にフォームの初期値を作り直す。
              key: ValueKey(analysisAttempt.value),
              imageBytes: imageBytes,
              analyzedTransaction: analyzedTransaction.value,
              sourceImageObjectKey: uploadedImageObjectKey.value,
              addTransaction: addTransaction,
              logAnalyticsEvent: logAnalyticsEvent,
              onSubmittingChanged: (submitting) {
                isSubmitting.value = submitting;
              },
              onRegistered: () =>
                  Navigator.of(context).pop(CaptureFlowResult.registered),
              onRetake: () {
                unawaited(logAnalyticsEvent(name: 'capture_retake'));
                discardAndClose(result: CaptureFlowResult.retake);
              },
            ),
          },
        ),
      ),
    );
  }
}

// 解析中のステップ文言を切り替える間隔 (design_handoff_kashakeibo/README.md の「約 950ms 間隔で切替」)。
const _analyzingStepInterval = Duration(milliseconds: 950);

/// AI 解析中の表示。脈打つ accent-200 の円にスパークル、ステップ文言を順に切り替える。
class _AnalyzingView extends HookWidget {
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final analyzingSteps = [
      l10n.captureAnalyzingStepLoading,
      l10n.captureAnalyzingStepReading,
      l10n.captureAnalyzingStepCategory,
    ];
    final currentStepIndex = useState(0);
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 表示中はステップ文言を一定間隔で進める。最後のステップで止め、
    // 解析が終わるまで「カテゴリを推定しています」を表示し続ける。
    // 依存配列は空にし、Timer を画面の表示中に 1 つだけ持つ。
    useEffect(() {
      final stepTimer = Timer.periodic(_analyzingStepInterval, (_) {
        if (currentStepIndex.value < analyzingSteps.length - 1) {
          currentStepIndex.value++;
        }
      });
      return stepTimer.cancel;
    }, const []);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.06).animate(
              CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.accent200,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            analyzingSteps[currentStepIndex.value],
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var dotIndex = 0;
                dotIndex < analyzingSteps.length;
                dotIndex++
              )
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: dotIndex <= currentStepIndex.value
                        ? AppColors.primary
                        : AppColors.neutral300,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// アップロード・解析の失敗表示。エラー文をそのまま示し、再試行・手動入力・取り直しを選べる。
class _AnalysisFailedView extends StatelessWidget {
  /// 発生したエラー。
  final Object? error;

  /// 「もう一度読み取る」の処理。
  final VoidCallback onRetry;

  /// 「手動で入力する」の処理。
  final VoidCallback onManualFallback;

  /// 「取り直す」の処理。
  final VoidCallback onRetake;

  const _AnalysisFailedView({
    required this.error,
    required this.onRetry,
    required this.onManualFallback,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.error_outline, size: 48, color: AppColors.accent700),
          const SizedBox(height: 16),
          // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.neutral700),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: Text(l10n.captureRetry),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onManualFallback,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.onSurface,
              side: const BorderSide(color: AppColors.divider),
            ),
            child: Text(l10n.captureManualFallback),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetake,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.neutral700,
            ),
            child: Text(l10n.captureRetake),
          ),
        ],
      ),
    );
  }
}

/// 読み取り確認フォーム。解析結果を初期値に全項目を修正でき、「登録する」で明細を保存する。
///
/// [analyzedTransaction] が null の場合は解析失敗からの手動入力フォールバックで、
/// 空のフォームを表示する。登録時は初期値からの変更有無を出所記録
/// (Transaction.analysisAdjustedByUser) として保存する。
class _CaptureConfirmForm extends HookWidget {
  /// 撮影した画像 (サムネイル表示用)。
  final Uint8List imageBytes;

  /// Gemini の解析結果。手動入力フォールバックでは null。
  final AnalyzedTransaction? analyzedTransaction;

  /// アップロード済み画像のオブジェクトキー。アップロードに失敗した場合は null。
  final String? sourceImageObjectKey;

  /// 明細の登録機能。
  final AddTransaction addTransaction;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  /// 登録処理の開始・終了を親へ通知する処理 (登録中は閉じる操作を無効にするため)。
  final ValueChanged<bool> onSubmittingChanged;

  /// 登録完了時の処理。
  final VoidCallback onRegistered;

  /// 「取り直す」の処理。
  final VoidCallback onRetake;

  const _CaptureConfirmForm({
    required this.imageBytes,
    required this.analyzedTransaction,
    required this.sourceImageObjectKey,
    required this.addTransaction,
    required this.logAnalyticsEvent,
    required this.onSubmittingChanged,
    required this.onRegistered,
    required this.onRetake,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // フォームの初期値。解析で得られなかった項目は手動入力と同じ既定値
    // (今日・支出・食費) を使う。
    final initialTitle = analyzedTransaction?.title ?? '';
    final initialAmount = analyzedTransaction?.amount;
    final initialType = analyzedTransaction?.type ?? TransactionType.expense;
    final initialCategory =
        analyzedTransaction?.category ?? TransactionCategory.food;
    final initialDate =
        _parseAnalyzedDate(dateText: analyzedTransaction?.transactionDate) ??
        DateUtils.dateOnly(DateTime.now());

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final amountController = useTextEditingController(
      text: initialAmount?.toString() ?? '',
    );
    final titleController = useTextEditingController(text: initialTitle);
    final transactionType = useState(initialType);
    final transactionCategory = useState(initialCategory);
    final transactionDate = useState(initialDate);
    final submitting = useState(false);
    final registrationError = useState<Object?>(null);
    final availableCategories = _availableCategories(
      transactionType: transactionType.value,
    );

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  imageBytes,
                  width: 92,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.sage100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l10n.captureSourceImageNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.sage800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: l10n.manualEntryStore,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.manualEntryAmount,
              prefixText: '¥ ',
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            validator: (value) {
              final amount = int.tryParse(value ?? '');
              if (amount == null || amount <= 0) {
                return l10n.manualEntryAmountRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          Text(
            l10n.manualEntryType,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SegmentedButton<TransactionType>(
            segments: [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text(l10n.monthlyExpense),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text(l10n.monthlyIncome),
              ),
            ],
            selected: {transactionType.value},
            onSelectionChanged: submitting.value
                ? null
                : (selection) {
                    transactionType.value = selection.single;
                    // 切替後の種別で選べないカテゴリなら、その種別の既定カテゴリへ寄せる。
                    if (!_availableCategories(
                      transactionType: selection.single,
                    ).contains(transactionCategory.value)) {
                      transactionCategory.value = switch (selection.single) {
                        TransactionType.expense => TransactionCategory.food,
                        TransactionType.income => TransactionCategory.salary,
                      };
                    }
                  },
          ),
          const SizedBox(height: 18),
          Text(
            l10n.manualEntryCategory,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in availableCategories)
                ChoiceChip(
                  label: Text(categoryLabel(category: category, l10n: l10n)),
                  selected: transactionCategory.value == category,
                  onSelected: submitting.value
                      ? null
                      : (_) {
                          transactionCategory.value = category;
                        },
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.manualEntryDate,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: submitting.value
                ? null
                : () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: transactionDate.value,
                      // 手動入力と同じ範囲 (過去100年〜未来1年) を選択可能にする。
                      firstDate: DateTime(DateTime.now().year - 100),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                    );
                    if (context.mounted && selectedDate != null) {
                      transactionDate.value = selectedDate;
                    }
                  },
            icon: const Icon(Icons.calendar_today),
            label: Text(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(transactionDate.value),
            ),
          ),
          if (registrationError.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
              child: Text(
                registrationError.value.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting.value
                ? null
                : () async {
                    unawaited(logAnalyticsEvent(name: 'capture_register'));
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    submitting.value = true;
                    onSubmittingChanged(true);
                    registrationError.value = null;
                    final inputTitle = titleController.text.trim();
                    final title = inputTitle.isEmpty
                        ? l10n.manualEntryDefaultTitle
                        : inputTitle;
                    final amount = int.parse(amountController.text);
                    // 解析結果 (初期値) から 1 項目でも変わっていれば「手調整」として記録する。
                    // 店名は既定タイトルへの補完前の入力値で比較し、解析で店名が取れず
                    // 空のまま登録した場合を手調整にしない。
                    // 解析に失敗して手動入力した場合は、全項目がユーザー入力のため常に手調整。
                    final analysisAdjustedByUser =
                        analyzedTransaction == null ||
                        inputTitle != initialTitle ||
                        amount != initialAmount ||
                        transactionType.value != initialType ||
                        transactionCategory.value != initialCategory ||
                        transactionDate.value != initialDate;
                    try {
                      await addTransaction.call(
                        type: transactionType.value,
                        source: TransactionSource.receipt,
                        amount: amount,
                        category: transactionCategory.value,
                        title: title,
                        transactionDate: transactionDate.value,
                        excludedFromAggregation: false,
                        sourceImageObjectKey: sourceImageObjectKey,
                        analysisAdjustedByUser: analysisAdjustedByUser,
                      );
                      if (context.mounted) {
                        onRegistered();
                      }
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      registrationError.value = error;
                      submitting.value = false;
                      onSubmittingChanged(false);
                    }
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: submitting.value
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.onPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(l10n.captureRegister),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: submitting.value ? null : onRetake,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.neutral700,
            ),
            child: Text(l10n.captureRetake),
          ),
        ],
      ),
    );
  }
}

/// Worker が返す取引日 ("YYYY-MM-DD") をローカルの日付 (時刻 0:00) として読む。
/// null・形式外の値は null を返し、呼び出し側が既定値 (今日) を使う。
DateTime? _parseAnalyzedDate({required String? dateText}) {
  if (dateText == null) {
    return null;
  }
  final parsedDate = DateTime.tryParse(dateText);
  return parsedDate == null ? null : DateUtils.dateOnly(parsedDate);
}

/// 収支種別ごとに選べるカテゴリ (手動入力と同じ体系)。
List<TransactionCategory> _availableCategories({
  required TransactionType transactionType,
}) => switch (transactionType) {
  TransactionType.expense => const [
    TransactionCategory.food,
    TransactionCategory.eatingOut,
    TransactionCategory.dailyGoods,
    TransactionCategory.transportation,
    TransactionCategory.subscription,
    TransactionCategory.other,
  ],
  TransactionType.income => const [
    TransactionCategory.salary,
    TransactionCategory.other,
  ],
};
