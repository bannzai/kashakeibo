// 共有 Extension が保存した画像を取り出す MethodChannel (SharedImageInbox) のテスト。
// ネイティブ側は mock ハンドラで差し替え、iOS でのみチャネルを呼ぶことと、
// 戻り値が CapturedImage に変換されることを検証する。
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/share_import/shared_image_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// MethodChannel を mock し、呼ばれたメソッド名を [invokedMethodNames] に記録する。
  void mockSharedImageInbox({
    required List<String> invokedMethodNames,
    required List<Map<Object?, Object?>> sharedImages,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedImageInboxMethodChannel, (
          methodCall,
        ) async {
          invokedMethodNames.add(methodCall.method);
          return sharedImages;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sharedImageInboxMethodChannel, null);
    });
  }

  test('iOS: ネイティブが返した画像を CapturedImage に変換する', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final invokedMethodNames = <String>[];
    mockSharedImageInbox(
      invokedMethodNames: invokedMethodNames,
      sharedImages: [
        {
          'imageBytes': Uint8List.fromList([1, 2, 3]),
          'imageContentType': 'image/png',
        },
        {
          'imageBytes': Uint8List.fromList([4, 5]),
          'imageContentType': 'image/jpeg',
        },
      ],
    );

    final sharedImages = await takeSharedImages();

    expect(invokedMethodNames, ['takeSharedImages']);
    expect(sharedImages.map((sharedImage) => sharedImage.imageContentType), [
      'image/png',
      'image/jpeg',
    ]);
    expect(sharedImages.first.imageBytes, Uint8List.fromList([1, 2, 3]));
  });

  test('iOS: 共有された画像が無ければ空リストを返す', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final invokedMethodNames = <String>[];
    mockSharedImageInbox(
      invokedMethodNames: invokedMethodNames,
      sharedImages: [],
    );

    expect(await takeSharedImages(), isEmpty);
    expect(invokedMethodNames, ['takeSharedImages']);
  });

  test('iOS 以外ではチャネルを呼ばずに空リストを返す', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final invokedMethodNames = <String>[];
    mockSharedImageInbox(
      invokedMethodNames: invokedMethodNames,
      sharedImages: [
        {
          'imageBytes': Uint8List.fromList([1, 2, 3]),
          'imageContentType': 'image/png',
        },
      ],
    );

    expect(await takeSharedImages(), isEmpty);
    expect(invokedMethodNames, isEmpty);
  });
}
