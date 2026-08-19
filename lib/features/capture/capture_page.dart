import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/capture_image_picker.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
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

  /// 「取り直す」が選ばれた (呼び出し側は画像を選び直す)。
  retake,

  /// 登録せずに閉じた。
  cancelled,
}

/// 撮影フローの入口。登録する明細の出所と Analytics イベント名を決める。
enum CaptureEntryPoint {
  /// 端末カメラでレシートを撮影した。
  camera,

  /// フォトライブラリから画像を選択した。
  photoLibrary,

  /// iOS 共有 Extension から画像を受け取った。「取り直す」はフォトライブラリを開く。
  sharedImage,
}

extension CaptureEntryPointBehavior on CaptureEntryPoint {
  /// この入口から登録される明細の出所。
  TransactionSource get transactionSource => switch (this) {
    CaptureEntryPoint.camera => TransactionSource.receipt,
    CaptureEntryPoint.photoLibrary ||
    CaptureEntryPoint.sharedImage => TransactionSource.screenshot,
  };

  /// 画像を選ぶ操作を開いた時の Analytics イベント名。共有 Extension 経由でも
  /// 「取り直す」以降はフォトライブラリを開くため、写真選択と同じ名前を使う。
  String get pickImageAnalyticsEventName => switch (this) {
    CaptureEntryPoint.camera => 'capture_camera_open',
    CaptureEntryPoint.photoLibrary ||
    CaptureEntryPoint.sharedImage => 'capture_photo_library_open',
  };

  /// 画像を選ばずにキャンセルした時の Analytics イベント名。
  String get pickImageCancelAnalyticsEventName => switch (this) {
    CaptureEntryPoint.camera => 'capture_camera_cancel',
    CaptureEntryPoint.photoLibrary ||
    CaptureEntryPoint.sharedImage => 'capture_photo_library_cancel',
  };
}

/// 画像の取得 → 解析 → 確認・修正 → 登録の一連のフローを実行する。
///
/// [initialImage] があればそれを最初の画像として使い (共有 Extension 経由)、無ければ
/// [pickImage] で選ぶところから始める。「取り直す」が選ばれた場合は [pickImage] からやり直す。
/// 登録完了時は「カシャッと記録!」トーストを表示する。
/// ユーザー操作ごとに実行する副作用のため冪等ではない。
Future<void> runCaptureFlow({
  required BuildContext context,
  required CapturedImage? initialImage,
  required PickCaptureImage pickImage,
  required CaptureEntryPoint entryPoint,
  required LogAnalyticsEvent logAnalyticsEvent,
}) async {
  var pendingImage = initialImage;
  if (pendingImage != null) {
    unawaited(logAnalyticsEvent(name: 'capture_shared_image_received'));
  }
  while (true) {
    final CapturedImage capturedImage;
    if (pendingImage != null) {
      capturedImage = pendingImage;
      pendingImage = null;
    } else {
      unawaited(
        logAnalyticsEvent(name: entryPoint.pickImageAnalyticsEventName),
      );
      final CapturedImage? pickedImage;
      try {
        pickedImage = await pickImage();
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
      // キャンセルの記録は画像が選ばれなかった時だけにする (unmount で抜ける場合は
      // ユーザーがキャンセルしたとは限らないため、両者を分けて判定する)。
      if (pickedImage == null) {
        unawaited(
          logAnalyticsEvent(name: entryPoint.pickImageCancelAnalyticsEventName),
        );
        return;
      }
      if (!context.mounted) {
        return;
      }
      capturedImage = pickedImage;
    }
    if (!context.mounted) {
      return;
    }
    final captureFlowResult = await showCapturePage(
      context: context,
      imageBytes: capturedImage.imageBytes,
      imageContentType: capturedImage.imageContentType,
      transactionSource: entryPoint.transactionSource,
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
  required TransactionSource transactionSource,
  required LogAnalyticsEvent logAnalyticsEvent,
}) => Navigator.of(context).push<CaptureFlowResult>(
  MaterialPageRoute<CaptureFlowResult>(
    fullscreenDialog: true,
    builder: (context) => CapturePage(
      imageBytes: imageBytes,
      imageContentType: imageContentType,
      transactionSource: transactionSource,
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

/// 撮影・選択した画像をアップロード → Gemini 解析 → 確認・修正 → 登録する画面
/// (design_handoff_kashakeibo/README.md の取込フロー 4「AI 解析中」・5「読み取り確認」)。
///
/// 解析に失敗した場合はエラーを表示し、再試行・手動入力 (画像付きの空フォーム)・
/// 取り直しへ進める (issue #7 の受け入れ条件)。1 枚の画像から複数の明細が読み取れた
/// 場合は候補リストを表示し、採用・破棄・修正を選んでまとめて登録する (issue #8)。
class CapturePage extends HookConsumerWidget {
  /// 撮影・選択した画像のバイト列。
  final Uint8List imageBytes;

  /// 撮影・選択した画像の Content-Type。
  final String imageContentType;

  /// この画像から登録する明細の出所。
  final TransactionSource transactionSource;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const CapturePage({
    required this.imageBytes,
    required this.imageContentType,
    required this.transactionSource,
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
    final analyzedTransactions = useState<List<AnalyzedTransaction>>(const []);
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
    // 候補リストの一括登録が途中で失敗し、一部の明細が元画像キー付きで登録済みか。
    // その状態で閉じても、登録済み明細が参照する画像は消さない。
    final hasRegisteredTransaction = useRef(false);
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
        analyzedTransactions.value = imageAnalysisResult.transactions;
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
    /// 一部の候補が登録済みなら画像はその明細の元画像として残す。
    Future<void> discardAndClose({required CaptureFlowResult result}) async {
      if (isSubmitting.value || discarded.value) {
        return;
      }
      discarded.value = true;
      final imageObjectKey = uploadedImageObjectKey.value;
      if (imageObjectKey != null && !hasRegisteredTransaction.value) {
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
                analyzedTransactions.value = const [];
                capturePhase.value = _CapturePhase.confirming;
              },
              onRetake: () {
                unawaited(logAnalyticsEvent(name: 'capture_retake'));
                discardAndClose(result: CaptureFlowResult.retake);
              },
            ),
            // 複数明細のスクショは候補リストで採用・破棄を選び、レシート (1 件) と
            // 手動入力フォールバック (0 件) は単一の確認フォームで登録する。
            _CapturePhase.confirming =>
              analyzedTransactions.value.length >= 2
                  ? _CaptureCandidateListView(
                      // 再試行で解析し直した時に候補の編集状態を作り直す。
                      key: ValueKey(analysisAttempt.value),
                      imageBytes: imageBytes,
                      analyzedTransactions: analyzedTransactions.value,
                      sourceImageObjectKey: uploadedImageObjectKey.value,
                      transactionSource: transactionSource,
                      addTransaction: addTransaction,
                      logAnalyticsEvent: logAnalyticsEvent,
                      onSubmittingChanged: (submitting) {
                        isSubmitting.value = submitting;
                      },
                      onCandidateRegistered: () {
                        hasRegisteredTransaction.value = true;
                      },
                      onRegistered: () => Navigator.of(
                        context,
                      ).pop(CaptureFlowResult.registered),
                      onRetake: () {
                        unawaited(logAnalyticsEvent(name: 'capture_retake'));
                        discardAndClose(result: CaptureFlowResult.retake);
                      },
                    )
                  : _CaptureConfirmForm(
                      // 再試行で解析し直した時にフォームの初期値を作り直す。
                      key: ValueKey(analysisAttempt.value),
                      imageBytes: imageBytes,
                      analyzedTransaction: analyzedTransactions.value.isEmpty
                          ? null
                          : analyzedTransactions.value.first,
                      sourceImageObjectKey: uploadedImageObjectKey.value,
                      transactionSource: transactionSource,
                      addTransaction: addTransaction,
                      logAnalyticsEvent: logAnalyticsEvent,
                      onSubmittingChanged: (submitting) {
                        isSubmitting.value = submitting;
                      },
                      onRegistered: () => Navigator.of(
                        context,
                      ).pop(CaptureFlowResult.registered),
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

/// 元画像サムネイル (92×120) と sage-100 の説明カードを並べた確認画面のヘッダー。
class _SourceImageHeader extends StatelessWidget {
  /// 読み取りに使った画像。
  final Uint8List imageBytes;

  /// 説明カードの文言。
  final String note;

  const _SourceImageHeader({required this.imageBytes, required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
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
              note,
              style: const TextStyle(fontSize: 12, color: AppColors.sage800),
            ),
          ),
        ),
      ],
    );
  }
}

/// 読み取り確認フォーム。解析結果を初期値に全項目を修正でき、「登録する」で明細を保存する。
///
/// [analyzedTransaction] が null の場合は解析失敗からの手動入力フォールバックで、
/// 空のフォームを表示する。登録時は初期値からの変更有無を出所記録
/// (Transaction.analysisAdjustedByUser) として保存する。
class _CaptureConfirmForm extends HookWidget {
  /// 読み取りに使った画像 (サムネイル表示用)。
  final Uint8List imageBytes;

  /// Gemini の解析結果。手動入力フォールバックでは null。
  final AnalyzedTransaction? analyzedTransaction;

  /// アップロード済み画像のオブジェクトキー。アップロードに失敗した場合は null。
  final String? sourceImageObjectKey;

  /// 登録する明細の出所。
  final TransactionSource transactionSource;

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
    required this.transactionSource,
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
    final firstSelectableDate = firstSelectableTransactionDate();
    final lastSelectableDate = lastSelectableTransactionDate();
    final initialDate =
        _parseAnalyzedDate(
          dateText: analyzedTransaction?.transactionDate,
          firstSelectableDate: firstSelectableDate,
          lastSelectableDate: lastSelectableDate,
        ) ??
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

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SourceImageHeader(
            imageBytes: imageBytes,
            note: l10n.captureSourceImageNote,
          ),
          const SizedBox(height: 18),
          _TransactionFields(
            titleController: titleController,
            amountController: amountController,
            transactionType: transactionType,
            transactionCategory: transactionCategory,
            transactionDate: transactionDate,
            firstSelectableDate: firstSelectableDate,
            lastSelectableDate: lastSelectableDate,
            enabled: !submitting.value,
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
                        source: transactionSource,
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

/// 1 枚の画像から複数の明細が読み取れた時の候補リスト (issue #8 のカード明細・購入履歴のスクショ)。
///
/// 候補ごとに採用・破棄を選び、「修正する」で個別に内容を直してから、採用した候補を
/// まとめて登録する。登録の途中で失敗した場合は登録済みの候補をリストから外し、
/// 残りだけを再登録できる状態にする。
class _CaptureCandidateListView extends HookWidget {
  /// 読み取りに使った画像 (サムネイル表示用)。
  final Uint8List imageBytes;

  /// Gemini が読み取った明細の候補。
  final List<AnalyzedTransaction> analyzedTransactions;

  /// アップロード済み画像のオブジェクトキー。アップロードに失敗した場合は null。
  /// 候補はすべて同じ元画像を共有する。
  final String? sourceImageObjectKey;

  /// 登録する明細の出所。
  final TransactionSource transactionSource;

  /// 明細の登録機能。
  final AddTransaction addTransaction;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  /// 登録処理の開始・終了を親へ通知する処理 (登録中は閉じる操作を無効にするため)。
  final ValueChanged<bool> onSubmittingChanged;

  /// 候補 1 件の登録が成功するたびに親へ通知する処理 (途中で失敗して閉じても、
  /// 登録済み明細が参照する元画像を消さないため)。
  final VoidCallback onCandidateRegistered;

  /// 全件の登録完了時の処理。
  final VoidCallback onRegistered;

  /// 「取り直す」の処理。
  final VoidCallback onRetake;

  const _CaptureCandidateListView({
    required this.imageBytes,
    required this.analyzedTransactions,
    required this.sourceImageObjectKey,
    required this.transactionSource,
    required this.addTransaction,
    required this.logAnalyticsEvent,
    required this.onSubmittingChanged,
    required this.onCandidateRegistered,
    required this.onRegistered,
    required this.onRetake,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 修正シートで書き換えた後の候補。[analyzedTransactions] と同じ並び・同じ長さを保ち、
    // 解析結果との差分 (手調整の判定) を index で対応づける。解析をやり直した時は
    // 親が ValueKey を変えてこの状態ごと作り直す。
    final editedTransactions = useState(analyzedTransactions);
    // チェックを外して破棄した候補の index。既定は全件採用。
    final discardedIndexes = useState(const <int>{});
    // 登録に成功した候補の index。リストから外し、失敗後の再登録で二重登録しない。
    final registeredIndexes = useState(const <int>{});
    final submitting = useState(false);
    final registrationError = useState<Object?>(null);

    final adoptedIndexes = [
      for (var index = 0; index < editedTransactions.value.length; index++)
        if (!discardedIndexes.value.contains(index) &&
            !registeredIndexes.value.contains(index))
          index,
    ];

    /// 採用した候補を先頭から順に登録する。1 件でも失敗したらそこで止め、
    /// 登録済みの候補をリストから外してエラーを表示する。
    Future<void> registerAdoptedCandidates() async {
      unawaited(logAnalyticsEvent(name: 'capture_register'));
      submitting.value = true;
      onSubmittingChanged(true);
      registrationError.value = null;
      final registeredIndexesInThisRun = {...registeredIndexes.value};
      for (final index in adoptedIndexes) {
        final candidate = editedTransactions.value[index];
        final candidateTitle = candidate.title.trim();
        try {
          await addTransaction.call(
            type: candidate.type,
            source: transactionSource,
            amount: candidate.amount,
            category: candidate.category,
            title: candidateTitle.isEmpty
                ? l10n.manualEntryDefaultTitle
                : candidateTitle,
            transactionDate:
                _parseAnalyzedDate(
                  dateText: candidate.transactionDate,
                  firstSelectableDate: firstSelectableTransactionDate(),
                  lastSelectableDate: lastSelectableTransactionDate(),
                ) ??
                DateUtils.dateOnly(DateTime.now()),
            excludedFromAggregation: false,
            sourceImageObjectKey: sourceImageObjectKey,
            analysisAdjustedByUser: candidate != analyzedTransactions[index],
          );
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          registeredIndexes.value = registeredIndexesInThisRun;
          registrationError.value = error;
          submitting.value = false;
          onSubmittingChanged(false);
          return;
        }
        registeredIndexesInThisRun.add(index);
        onCandidateRegistered();
      }
      if (!context.mounted) {
        return;
      }
      registeredIndexes.value = registeredIndexesInThisRun;
      onRegistered();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _SourceImageHeader(
          imageBytes: imageBytes,
          note: l10n.captureCandidatesNote(
            editedTransactions.value.length - registeredIndexes.value.length,
          ),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < editedTransactions.value.length; index++)
          if (!registeredIndexes.value.contains(index))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CaptureCandidateCard(
                candidate: editedTransactions.value[index],
                isAdopted: !discardedIndexes.value.contains(index),
                onAdoptedChanged: submitting.value
                    ? null
                    : (adopted) {
                        unawaited(
                          logAnalyticsEvent(name: 'capture_candidate_toggle'),
                        );
                        discardedIndexes.value = {
                          for (final discardedIndex in discardedIndexes.value)
                            if (discardedIndex != index) discardedIndex,
                          if (!adopted) index,
                        };
                      },
                onEdit: submitting.value
                    ? null
                    : () async {
                        unawaited(
                          logAnalyticsEvent(name: 'capture_candidate_edit'),
                        );
                        final editedCandidate =
                            await showModalBottomSheet<AnalyzedTransaction>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (context) => _CaptureCandidateEditSheet(
                                candidate: editedTransactions.value[index],
                              ),
                            );
                        if (editedCandidate == null) {
                          return;
                        }
                        editedTransactions.value = [
                          for (
                            var candidateIndex = 0;
                            candidateIndex < editedTransactions.value.length;
                            candidateIndex++
                          )
                            candidateIndex == index
                                ? editedCandidate
                                : editedTransactions.value[candidateIndex],
                        ];
                      },
              ),
            ),
        if (registrationError.value != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
            child: Text(
              registrationError.value.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: submitting.value || adoptedIndexes.isEmpty
              ? null
              : registerAdoptedCandidates,
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
              : Text(l10n.captureRegisterCount(adoptedIndexes.length)),
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
    );
  }
}

/// 候補リストの 1 枚 (採用チェック + 明細の内容 + 「修正する」)。破棄した候補は opacity 0.45。
class _CaptureCandidateCard extends StatelessWidget {
  /// 表示する候補 (修正済みなら修正後の値)。
  final AnalyzedTransaction candidate;

  /// 登録対象として採用しているか。
  final bool isAdopted;

  /// 採用・破棄の切替。登録中は null (操作不可)。
  final ValueChanged<bool>? onAdoptedChanged;

  /// 「修正する」の処理。登録中は null (操作不可)。
  final VoidCallback? onEdit;

  const _CaptureCandidateCard({
    required this.candidate,
    required this.isAdopted,
    required this.onAdoptedChanged,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidateTitle = candidate.title.trim();
    return Opacity(
      opacity: isAdopted ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        decoration: BoxDecoration(
          // カード面はデザインの surface (neutral-100)。
          color: AppColors.neutral100,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isAdopted,
              onChanged: onAdoptedChanged == null
                  ? null
                  : (adopted) => onAdoptedChanged!(adopted ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidateTitle.isEmpty
                              ? l10n.manualEntryDefaultTitle
                              : candidateTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            // 店名を読み取れなかった候補は、既定タイトルであることが
                            // わかるように薄い色で表示する。
                            color: candidateTitle.isEmpty
                                ? AppColors.neutral600
                                : AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '¥${NumberFormat.decimalPattern().format(candidate.amount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(
                        _parseAnalyzedDate(
                              dateText: candidate.transactionDate,
                              firstSelectableDate:
                                  firstSelectableTransactionDate(),
                              lastSelectableDate:
                                  lastSelectableTransactionDate(),
                            ) ??
                            DateUtils.dateOnly(DateTime.now()),
                      ),
                      categoryLabel(category: candidate.category, l10n: l10n),
                      switch (candidate.type) {
                        TransactionType.expense => l10n.monthlyExpense,
                        TransactionType.income => l10n.monthlyIncome,
                      },
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.captureCandidateEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppColors.neutral700,
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

/// 候補 1 件の修正シート。単一の確認フォームと同じ入力項目を表示し、
/// 「変更を反映」で修正後の [AnalyzedTransaction] を pop で返す (閉じた場合は null)。
class _CaptureCandidateEditSheet extends HookWidget {
  /// 修正する候補。
  final AnalyzedTransaction candidate;

  const _CaptureCandidateEditSheet({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstSelectableDate = firstSelectableTransactionDate();
    final lastSelectableDate = lastSelectableTransactionDate();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final titleController = useTextEditingController(text: candidate.title);
    final amountController = useTextEditingController(
      text: candidate.amount.toString(),
    );
    final transactionType = useState(candidate.type);
    final transactionCategory = useState(candidate.category);
    final transactionDate = useState(
      _parseAnalyzedDate(
            dateText: candidate.transactionDate,
            firstSelectableDate: firstSelectableDate,
            lastSelectableDate: lastSelectableDate,
          ) ??
          DateUtils.dateOnly(DateTime.now()),
    );

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.captureCandidateEdit,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _TransactionFields(
              titleController: titleController,
              amountController: amountController,
              transactionType: transactionType,
              transactionCategory: transactionCategory,
              transactionDate: transactionDate,
              firstSelectableDate: firstSelectableDate,
              lastSelectableDate: lastSelectableDate,
              enabled: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(
                  candidate.copyWith(
                    title: titleController.text.trim(),
                    amount: int.parse(amountController.text),
                    type: transactionType.value,
                    category: transactionCategory.value,
                    transactionDate: DateFormat(
                      'yyyy-MM-dd',
                    ).format(transactionDate.value),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text(l10n.captureCandidateApplyEdit),
            ),
          ],
        ),
      ),
    );
  }
}

/// 明細の入力項目 (店名 / 金額 / 収支種別 / カテゴリ / 日付)。
/// 単一の確認フォームと候補の修正シートで同じ入力体験にするため共有する。
///
/// 値は呼び出し側が持つ controller・[ValueNotifier] を通じて読み書きする。
class _TransactionFields extends StatelessWidget {
  /// 店名・メモの入力。
  final TextEditingController titleController;

  /// 金額の入力。
  final TextEditingController amountController;

  /// 収支種別の選択状態。
  final ValueNotifier<TransactionType> transactionType;

  /// カテゴリの選択状態。
  final ValueNotifier<TransactionCategory> transactionCategory;

  /// 取引日の選択状態。
  final ValueNotifier<DateTime> transactionDate;

  /// 日付ピッカーで選べる下限。
  final DateTime firstSelectableDate;

  /// 日付ピッカーで選べる上限。
  final DateTime lastSelectableDate;

  /// 入力を受け付けるか (登録の実行中は false)。
  final bool enabled;

  const _TransactionFields({
    required this.titleController,
    required this.amountController,
    required this.transactionType,
    required this.transactionCategory,
    required this.transactionDate,
    required this.firstSelectableDate,
    required this.lastSelectableDate,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onSelectionChanged: enabled
              ? (selection) {
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
                }
              : null,
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
            for (final category in _availableCategories(
              transactionType: transactionType.value,
            ))
              ChoiceChip(
                label: Text(categoryLabel(category: category, l10n: l10n)),
                selected: transactionCategory.value == category,
                onSelected: enabled
                    ? (_) {
                        transactionCategory.value = category;
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          l10n.manualEntryDate,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: enabled
                ? () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: transactionDate.value,
                      firstDate: firstSelectableDate,
                      lastDate: lastSelectableDate,
                    );
                    if (context.mounted && selectedDate != null) {
                      transactionDate.value = selectedDate;
                    }
                  }
                : null,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              DateFormat.yMMMd(
                Localizations.localeOf(context).toString(),
              ).format(transactionDate.value),
            ),
          ),
        ),
      ],
    );
  }
}

/// 日付ピッカーで選べる下限 (手動入力と同じ過去 100 年)。
DateTime firstSelectableTransactionDate() =>
    DateTime(DateTime.now().year - 100);

/// 日付ピッカーで選べる上限 (手動入力と同じ未来 1 年)。
DateTime lastSelectableTransactionDate() =>
    DateTime(DateTime.now().year + 1, 12, 31);

/// Worker が返す取引日 ("YYYY-MM-DD") をローカルの日付 (時刻 0:00) として読む。
/// null・形式外の値・日付ピッカーで選べる範囲外の値 (誤読した年など) は null を返し、
/// 呼び出し側が既定値 (今日) を使う (範囲外の initialDate は showDatePicker が受け付けない)。
DateTime? _parseAnalyzedDate({
  required String? dateText,
  required DateTime firstSelectableDate,
  required DateTime lastSelectableDate,
}) {
  if (dateText == null) {
    return null;
  }
  final parsedDate = DateTime.tryParse(dateText);
  if (parsedDate == null) {
    return null;
  }
  final analyzedDate = DateUtils.dateOnly(parsedDate);
  if (analyzedDate.isBefore(firstSelectableDate) ||
      analyzedDate.isAfter(lastSelectableDate)) {
    return null;
  }
  return analyzedDate;
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
