// 共有 Extension から受け取った画像を撮影フロー (features/capture) へ流し込む取り込み処理。
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kashakeibo/features/capture/capture_image_picker.dart';
import 'package:kashakeibo/features/capture/capture_page.dart';
import 'package:kashakeibo/features/share_import/shared_image_inbox.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 共有された画像を取り出し、1 枚ずつ撮影フロー (確認 → 登録) を開く取り込みを、
/// 画面の表示開始時と foreground 復帰時に実行する hook。
///
/// 共有 Extension は画像を保存してからホストアプリを開くため、アプリが起動していれば
/// 復帰時に、起動していなければ表示開始時に取り込みが走る。
void useSharedImageImport({
  required BuildContext context,
  required TakeSharedImages takeSharedImages,
  required PickCaptureImage pickImageFromPhotoLibrary,
  required LogAnalyticsEvent logAnalyticsEvent,
}) {
  // 取り込みの実行中フラグ。撮影フローの表示中に foreground 復帰が起きても、
  // 同じ画像で確認画面が二重に開かないようにする。
  final isImporting = useRef(false);

  Future<void> importSharedImages() async {
    if (isImporting.value) {
      return;
    }
    isImporting.value = true;
    try {
      // 撮影フローの実行中に共有された画像も拾うため、取り出しが空になるまで繰り返す。
      while (context.mounted) {
        final sharedImages = await takeSharedImages();
        if (sharedImages.isEmpty) {
          return;
        }
        for (final sharedImage in sharedImages) {
          if (!context.mounted) {
            return;
          }
          await runCaptureFlow(
            context: context,
            initialImage: sharedImage,
            pickImage: pickImageFromPhotoLibrary,
            entryPoint: CaptureEntryPoint.sharedImage,
            logAnalyticsEvent: logAnalyticsEvent,
          );
        }
      }
    } finally {
      isImporting.value = false;
    }
  }

  // 画面の表示開始時に、共有 Extension 経由の起動で溜まっている画像を取り込む。
  // 依存配列は空にして画面の生存中に 1 回だけ開始する (取り込み対象が増えた時は
  // 下の foreground 復帰と、取り込みループの再取り出しで拾う)。
  useEffect(() {
    importSharedImages();
    return null;
  }, const []);

  // 共有シートから戻った時など、foreground へ復帰したタイミングでも取り込む。
  useOnAppLifecycleStateChange((previousState, currentState) {
    if (currentState == AppLifecycleState.resumed) {
      importSharedImages();
    }
  });
}
