import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/appstore_screenshot/appstore_screenshot.dart';
import 'package:kashakeibo/style/tokens.dart';

const _generateAppStoreAssets = bool.fromEnvironment(
  'GENERATE_APPSTORE_ASSETS',
);
const _generationKind = String.fromEnvironment(
  'APPSTORE_ASSET_KIND',
  defaultValue: 'screenshots',
);
const _generationLanguage = String.fromEnvironment(
  'APPSTORE_ASSET_LANGUAGE',
  defaultValue: 'all',
);
const _generationPageNumber = int.fromEnvironment(
  'APPSTORE_SCREENSHOT_PAGE',
  defaultValue: 0,
);
const _screenshotOutputRoot = String.fromEnvironment(
  'APPSTORE_SCREENSHOT_OUTPUT_ROOT',
  defaultValue: 'scripts/generate_screenshots/artifacts',
);
const _headerOutputRoot = String.fromEnvironment(
  'APPSTORE_HEADER_OUTPUT_ROOT',
  defaultValue: 'fastlane/creative_assets/product_page_header',
);

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
    for (final pageNumber in appStoreScreenshotPageNumbers) {
      testWidgets('${locale.fastlaneDirectoryName} の $pageNumber 枚目が描画できる', (
        tester,
      ) async {
        await _pumpAsset(
          tester: tester,
          logicalSize: const Size(430, 932),
          child: AppStoreScreenshotPage(pageNumber: pageNumber, locale: locale),
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('App Store assets を生成する', (tester) async {
    final locales = _selectedLocales();
    if (_generationKind == 'screenshots') {
      final pageNumbers = _generationPageNumber == 0
          ? appStoreScreenshotPageNumbers
          : [_generationPageNumber];
      for (final locale in locales) {
        for (final pageNumber in pageNumbers) {
          await _writeRenderedAsset(
            tester: tester,
            logicalSize: const Size(430, 932),
            pixelRatio: 3,
            child: AppStoreScreenshotPage(
              pageNumber: pageNumber,
              locale: locale,
            ),
            outputPath:
                '$_screenshotOutputRoot/${locale.fastlaneDirectoryName}/${_screenshotFileName(pageNumber: pageNumber)}',
            expectedPixelWidth: 1290,
            expectedPixelHeight: 2796,
          );
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

String _screenshotFileName({required int pageNumber}) {
  return switch (pageNumber) {
    1 => '01_snap_to_budget.png',
    2 => '02_receipt_scan.png',
    3 => '03_duplicate_detection.png',
    4 => '04_source_image.png',
    5 => '05_monthly_report.png',
    _ => throw ArgumentError.value(pageNumber, 'pageNumber'),
  };
}

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

Future<ByteData> _readFontFile({required String path}) async {
  return ByteData.sublistView(await File(path).readAsBytes());
}

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
