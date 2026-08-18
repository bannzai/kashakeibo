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

  test('日本語サブセットフォントに掲載文言の字形がすべて含まれる', () async {
    final source = await File(
      'lib/features/appstore_screenshot/appstore_screenshot.dart',
    ).readAsString();
    final requiredCodePoints = RegExp(r"""'((?:\\.|[^'\\])*)'""")
        .allMatches(source)
        .expand((match) => match.group(1)!.runes)
        .where((codePoint) => codePoint > 0x7f);
    final fontData = await _readFontFile(
      path: 'assets/fonts/NotoSansJP-AppStoreSubset.ttf',
    );
    final missingCharacters =
        requiredCodePoints
            .where((codePoint) => !_fontHasGlyph(fontData, codePoint))
            .map(String.fromCharCode)
            .toSet()
            .toList()
          ..sort();

    expect(
      missingCharacters,
      isEmpty,
      reason:
          '日本語サブセットフォントに未収録の文字があります: '
          '${missingCharacters.join()}',
    );
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

    testWidgets(
      '${locale.fastlaneDirectoryName} の Product Page Header が描画できる',
      (tester) async {
        await _pumpAsset(
          tester: tester,
          logicalSize: const Size(1920, 823),
          child: ProductPageHeaderCreative(locale: locale),
        );

        expect(tester.takeException(), isNull);
      },
    );
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

/// TrueType/OpenType の Unicode cmap に指定文字の字形があるかを返す。
bool _fontHasGlyph(ByteData fontData, int codePoint) {
  final tableCount = fontData.getUint16(4);
  int? cmapOffset;
  for (var tableIndex = 0; tableIndex < tableCount; tableIndex += 1) {
    final recordOffset = 12 + (tableIndex * 16);
    final tag = String.fromCharCodes([
      for (var byteIndex = 0; byteIndex < 4; byteIndex += 1)
        fontData.getUint8(recordOffset + byteIndex),
    ]);
    if (tag == 'cmap') {
      cmapOffset = fontData.getUint32(recordOffset + 8);
      break;
    }
  }
  if (cmapOffset == null) {
    throw const FormatException('フォントに cmap テーブルがありません');
  }

  final subtableCount = fontData.getUint16(cmapOffset + 2);
  for (
    var subtableIndex = 0;
    subtableIndex < subtableCount;
    subtableIndex += 1
  ) {
    final recordOffset = cmapOffset + 4 + (subtableIndex * 8);
    final platformId = fontData.getUint16(recordOffset);
    final encodingId = fontData.getUint16(recordOffset + 2);
    final isUnicodeTable =
        platformId == 0 ||
        (platformId == 3 && (encodingId == 1 || encodingId == 10));
    if (!isUnicodeTable) {
      continue;
    }

    final subtableOffset = cmapOffset + fontData.getUint32(recordOffset + 4);
    final format = fontData.getUint16(subtableOffset);
    if (format == 4 && _format4HasGlyph(fontData, subtableOffset, codePoint)) {
      return true;
    }
    if (format == 12 &&
        _format12HasGlyph(fontData, subtableOffset, codePoint)) {
      return true;
    }
  }
  return false;
}

/// BMP 用 cmap format 4 から指定文字の glyph ID を探す。
bool _format4HasGlyph(ByteData fontData, int offset, int codePoint) {
  if (codePoint > 0xffff) {
    return false;
  }
  final segmentCount = fontData.getUint16(offset + 6) ~/ 2;
  final endCodesOffset = offset + 14;
  final startCodesOffset = endCodesOffset + (segmentCount * 2) + 2;
  final deltasOffset = startCodesOffset + (segmentCount * 2);
  final rangeOffsetsOffset = deltasOffset + (segmentCount * 2);

  for (var segmentIndex = 0; segmentIndex < segmentCount; segmentIndex += 1) {
    final endCode = fontData.getUint16(endCodesOffset + (segmentIndex * 2));
    final startCode = fontData.getUint16(startCodesOffset + (segmentIndex * 2));
    if (codePoint < startCode || codePoint > endCode) {
      continue;
    }

    final delta = fontData.getInt16(deltasOffset + (segmentIndex * 2));
    final rangeOffsetPosition = rangeOffsetsOffset + (segmentIndex * 2);
    final rangeOffset = fontData.getUint16(rangeOffsetPosition);
    if (rangeOffset == 0) {
      return ((codePoint + delta) & 0xffff) != 0;
    }
    final glyphPosition =
        rangeOffsetPosition + rangeOffset + ((codePoint - startCode) * 2);
    final glyphId = fontData.getUint16(glyphPosition);
    return glyphId != 0 && ((glyphId + delta) & 0xffff) != 0;
  }
  return false;
}

/// 補助平面対応の cmap format 12 から指定文字の glyph ID を探す。
bool _format12HasGlyph(ByteData fontData, int offset, int codePoint) {
  final groupCount = fontData.getUint32(offset + 12);
  for (var groupIndex = 0; groupIndex < groupCount; groupIndex += 1) {
    final groupOffset = offset + 16 + (groupIndex * 12);
    final startCode = fontData.getUint32(groupOffset);
    final endCode = fontData.getUint32(groupOffset + 4);
    if (codePoint < startCode || codePoint > endCode) {
      continue;
    }
    final startGlyphId = fontData.getUint32(groupOffset + 8);
    return startGlyphId + codePoint - startCode != 0;
  }
  return false;
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
