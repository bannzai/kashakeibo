// iOS 共有 Extension が App Group コンテナへ保存した画像を、ホストアプリ側で取り出す受け口。
// 保存・受け渡しのネイティブ実装は ios/ShareExtension/ と ios/Runner/SharedImageInbox.swift
// (MethodChannel の契約は lib/features/share_import/README.md)。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/capture/capture_image_picker.dart';

/// 共有 Extension が保存した画像を取り出す MethodChannel。
const sharedImageInboxMethodChannel = MethodChannel(
  'com.bannzai.kashakeibo/shared_image_inbox',
);

/// 共有された画像をまとめて取り出す操作。テストでは差し替える。
typedef TakeSharedImages = Future<List<CapturedImage>> Function();

/// 共有された画像の取り出し操作。
final takeSharedImagesProvider = Provider<TakeSharedImages>(
  (ref) => takeSharedImages,
);

/// 共有 Extension が保存した画像をすべて取り出して返す。共有が無ければ空リスト。
///
/// ネイティブ側は受け渡した画像ファイルを App Group コンテナから削除する (取り出し = take)
/// ため、同じ画像は 2 回目の呼び出しでは返らず冪等ではない。
/// 共有 Extension は iOS のみのため、他プラットフォームではチャネルを呼ばず空リストを返す。
Future<List<CapturedImage>> takeSharedImages() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    return const [];
  }
  final sharedImages = await sharedImageInboxMethodChannel
      .invokeListMethod<Map<Object?, Object?>>('takeSharedImages');
  return [
    for (final sharedImage in sharedImages ?? const <Map<Object?, Object?>>[])
      (
        imageBytes: sharedImage['imageBytes']! as Uint8List,
        imageContentType: sharedImage['imageContentType']! as String,
      ),
  ];
}
