// 共有 Extension から受け取った画像を撮影フローへ流し込む hook (useSharedImageImport) のテスト。
// 画像の取り出しは fake に差し替え、表示開始時と foreground 復帰時に取り込みが走ることを検証する。
// アップロード・解析・登録の Provider は撮影フロー画面のテストの fake 一式を再利用する。
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/capture/capture_image_picker.dart';
import 'package:kashakeibo/features/share_import/shared_image_import.dart';
import 'package:kashakeibo/features/share_import/shared_image_inbox.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

import '../capture/capture_page_test.dart'
    show
        CaptureFakes,
        buildImageAnalysisResult,
        pumpUntilAnalysisFinished,
        testImageBytes;

/// [useSharedImageImport] を呼ぶだけのホスト画面 (月次一覧の代わり)。
class _SharedImageImportHost extends HookWidget {
  /// 共有された画像を取り出す処理。
  final TakeSharedImages takeSharedImages;

  /// 「取り直す」で開くフォトライブラリの選択処理。
  final PickCaptureImage pickImageFromPhotoLibrary;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const _SharedImageImportHost({
    required this.takeSharedImages,
    required this.pickImageFromPhotoLibrary,
    required this.logAnalyticsEvent,
  });

  @override
  Widget build(BuildContext context) {
    useSharedImageImport(
      context: context,
      takeSharedImages: takeSharedImages,
      pickImageFromPhotoLibrary: pickImageFromPhotoLibrary,
      logAnalyticsEvent: logAnalyticsEvent,
    );
    return const Scaffold(body: SizedBox.shrink());
  }
}

void main() {
  testWidgets('共有された画像があると、表示開始時に取り込んで確認画面を開く', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    // ネイティブ側と同じく、取り出した画像は次の呼び出しでは返さない。
    final pendingSharedImages = <CapturedImage>[
      (imageBytes: testImageBytes, imageContentType: 'image/png'),
    ];
    final takeSharedImagesCalls = <int>[];
    final analyticsEvents = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: captureFakes.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SharedImageImportHost(
            takeSharedImages: () async {
              takeSharedImagesCalls.add(pendingSharedImages.length);
              final sharedImages = [...pendingSharedImages];
              pendingSharedImages.clear();
              return sharedImages;
            },
            pickImageFromPhotoLibrary: () async => null,
            logAnalyticsEvent: ({required name, parameters}) async {
              analyticsEvents.add(name);
            },
          ),
        ),
      ),
    );
    await pumpUntilAnalysisFinished(tester: tester);
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsOneWidget);
    expect(analyticsEvents, contains('capture_shared_image_received'));
    expect(captureFakes.uploadedImageContentTypes, ['image/png']);
    // 確認画面を表示している間は次の取り出しを行わない
    expect(takeSharedImagesCalls, [1]);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 1 巡した後に取り出し直し、空になったところで取り込みを終える
    expect(takeSharedImagesCalls, [1, 0]);
    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsNothing);
  });

  testWidgets('foreground 復帰時に共有された画像を取り込む', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final pendingSharedImages = <CapturedImage>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: captureFakes.overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SharedImageImportHost(
            takeSharedImages: () async {
              final sharedImages = [...pendingSharedImages];
              pendingSharedImages.clear();
              return sharedImages;
            },
            pickImageFromPhotoLibrary: () async => null,
            logAnalyticsEvent: ({required name, parameters}) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 起動時は共有された画像が無いので確認画面は開かない
    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsNothing);

    // 共有シートからアプリへ戻る間に共有された画像
    pendingSharedImages.add((
      imageBytes: testImageBytes,
      imageContentType: 'image/png',
    ));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpUntilAnalysisFinished(tester: tester);
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsOneWidget);
    expect(captureFakes.uploadedImageContentTypes, ['image/png']);
  });
}
