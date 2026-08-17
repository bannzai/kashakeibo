import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/appstore_screenshot/appstore_screenshot.dart';
import 'package:kashakeibo/style/tokens.dart';

/// 通常の `flutter test` では画像を書き出さず、明示的な生成時だけ有効にする。
const _generateAppStoreAssets = bool.fromEnvironment(
  'GENERATE_APPSTORE_ASSETS',
);

/// 生成スクリプトが必ず指定する対象アセット種別。
const _generationKind = String.fromEnvironment('APPSTORE_ASSET_KIND');

/// 生成スクリプトが必ず指定する fastlane ロケール名。
const _generationLanguage = String.fromEnvironment('APPSTORE_ASSET_LANGUAGE');

/// 0 は全ページ生成を表し、ヘッダー生成ではページ指定が不要なため既定値にする。
const _generationPageNumber = int.fromEnvironment(
  'APPSTORE_SCREENSHOT_PAGE',
  defaultValue: 0,
);

/// 中間生成物を置くルート。シェル側を単一ソースにするため必須指定とする。
const _screenshotOutputRoot = String.fromEnvironment(
  'APPSTORE_SCREENSHOT_OUTPUT_ROOT',
);

/// ヘッダー成果物を置くルート。シェル側を単一ソースにするため必須指定とする。
const _headerOutputRoot = String.fromEnvironment('APPSTORE_HEADER_OUTPUT_ROOT');

/// ストア素材の描画検証と生成テストを登録する。
void main() {
  setUpAll(_loadFigtreeFont);

  test('全ページに日本語と英語のキャッチコピーがある', () {
    for (final pageNumber in appStoreScreenshotPageNumbers) {
      for (final locale in AppStoreScreenshotLocale.values) {
        final copy = appStoreScreenshotCopy(
          pageNumber: pageNumber,
          locale: locale,
        );
        expect(copy.eyebrow, isNotEmpty);
        expect(copy.headline, isNotEmpty);
        expect(copy.supportingText, isNotEmpty);
      }
    }
  });

  for (final locale in AppStoreScreenshotLocale.values) {
    for (final device in AppStoreScreenshotDevice.values) {
      for (final pageNumber in appStoreScreenshotPageNumbers) {
        testWidgets('${locale.fastlaneDirectoryName} ${device.fileNameLabel} の '
            '$pageNumber 枚目が描画できる', (tester) async {
          await _pumpAsset(
            tester: tester,
            logicalSize: device.logicalSize,
            child: AppStoreScreenshotPage(
              pageNumber: pageNumber,
              locale: locale,
              device: device,
            ),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('App Store assets を生成する', (tester) async {
    final locales = _selectedLocales();
    if (_generationKind == 'screenshots') {
      final pageNumbers = _generationPageNumber == 0
          ? appStoreScreenshotPageNumbers
          : [_generationPageNumber];
      for (final locale in locales) {
        for (final device in AppStoreScreenshotDevice.values) {
          for (final pageNumber in pageNumbers) {
            await _writeRenderedAsset(
              tester: tester,
              logicalSize: device.logicalSize,
              pixelRatio: device.pixelRatio,
              child: AppStoreScreenshotPage(
                pageNumber: pageNumber,
                locale: locale,
                device: device,
              ),
              outputPath:
                  '$_screenshotOutputRoot/${locale.fastlaneDirectoryName}/'
                  '${appStoreScreenshotFileName(pageNumber: pageNumber, device: device)}',
              expectedPixelWidth: device.expectedPixelWidth,
              expectedPixelHeight: device.expectedPixelHeight,
            );
          }
        }
      }
      return;
    }
    if (_generationKind == 'header') {
      for (final locale in locales) {
        await _writeRenderedAsset(
          tester: tester,
          logicalSize: const Size(1920, 823),
          pixelRatio: 2,
          child: ProductPageHeaderCreative(locale: locale),
          outputPath: '$_headerOutputRoot/${locale.fastlaneDirectoryName}.png',
          expectedPixelWidth: 3840,
          expectedPixelHeight: 1646,
        );
      }
      return;
    }
    throw ArgumentError.value(
      _generationKind,
      'APPSTORE_ASSET_KIND',
      'screenshots または header を指定してください',
    );
  }, skip: !_generateAppStoreAssets);
}

/// 生成対象のロケール名を enum へ変換する。
List<AppStoreScreenshotLocale> _selectedLocales() {
  if (_generationLanguage == 'all') {
    return AppStoreScreenshotLocale.values;
  }
  return [
    AppStoreScreenshotLocale.fromFastlaneDirectoryName(
      fastlaneDirectoryName: _generationLanguage,
    ),
  ];
}

/// ストア素材専用フォントを Widget test の FontLoader へ登録する。
Future<void> _loadFigtreeFont() async {
  final fontLoader = FontLoader('Figtree')
    ..addFont(rootBundle.load('assets/fonts/Figtree-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Figtree-ExtraBold.ttf'));
  await fontLoader.load();
  final japaneseFontLoader = FontLoader(
    'NotoSansJPAppStore',
  )..addFont(_readFontFile(path: 'assets/fonts/NotoSansJP-AppStoreSubset.ttf'));
  await japaneseFontLoader.load();
  final materialIconsFontLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await materialIconsFontLoader.load();
}

/// pubspec に含めない日本語サブセットをテスト用 ByteData として読む。
Future<ByteData> _readFontFile({required String path}) async {
  return ByteData.sublistView(await File(path).readAsBytes());
}

/// 指定論理サイズで素材 Widget を描画し、画像化対象の key を返す。
Future<GlobalKey> _pumpAsset({
  required WidgetTester tester,
  required Size logicalSize,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final repaintBoundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Figtree',
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: RepaintBoundary(
        key: repaintBoundaryKey,
        child: SizedBox.fromSize(size: logicalSize, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repaintBoundaryKey;
}

/// Widget を PNG 化し、期待ピクセル寸法を検証して保存する。
Future<void> _writeRenderedAsset({
  required WidgetTester tester,
  required Size logicalSize,
  required double pixelRatio,
  required Widget child,
  required String outputPath,
  required int expectedPixelWidth,
  required int expectedPixelHeight,
}) async {
  final repaintBoundaryKey = await _pumpAsset(
    tester: tester,
    logicalSize: logicalSize,
    child: child,
  );
  final renderObject = repaintBoundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('スクリーンショット対象の RepaintBoundary が見つかりません');
  }

  await tester.runAsync(() async {
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    if (image.width != expectedPixelWidth ||
        image.height != expectedPixelHeight) {
      final actualPixelWidth = image.width;
      final actualPixelHeight = image.height;
      image.dispose();
      throw StateError(
        '生成画像の寸法が不正です: '
        '${actualPixelWidth}x$actualPixelHeight '
        '(expected: ${expectedPixelWidth}x$expectedPixelHeight)',
      );
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('PNG のエンコードに失敗しました');
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  });
}
