// 撮影フローへ渡す 1 枚の画像を選ぶ操作。image_picker のネイティブ UI (カメラ /
// フォトライブラリ) を使い、選ばれた画像を Worker へ送れる形 (バイト列 + Content-Type) にして返す。
import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 撮影・選択した 1 枚の画像 (Worker へのアップロードに必要なバイト列と Content-Type)。
typedef CapturedImage = ({Uint8List imageBytes, String imageContentType});

/// 撮影フローへ渡す画像を 1 枚選ぶ操作 (カメラ撮影・フォトライブラリ選択に共通)。
/// ユーザーがキャンセルした場合は null。テストでは差し替える。
typedef PickCaptureImage = Future<CapturedImage?> Function();

/// レシート撮影操作 (端末カメラ)。
final captureReceiptImageProvider = Provider<PickCaptureImage>(
  (ref) => captureReceiptImageWithCamera,
);

/// フォトライブラリからの画像選択操作。
final pickCaptureImageFromPhotoLibraryProvider = Provider<PickCaptureImage>(
  (ref) => pickCaptureImageFromPhotoLibrary,
);

// 撮影画像の長辺の上限 (px)。レシートの文字を Gemini が読める解像度を保ちつつ、
// アップロード・解析 (インライン画像は 20MB 上限) のサイズを数百 KB に抑える値。
// image_picker は maxWidth / maxHeight を縦横それぞれの上限として扱うため、
// 縦長・横長のどちらでも長辺が収まるように両方へ同じ値を渡す。
const _capturedImageMaxLongSide = 1600.0;

// JPEG 再圧縮の品質。文字の可読性を落とさない範囲でサイズを抑える一般的な値。
const _capturedImageQuality = 85;

/// 端末カメラでレシートを撮影し、縮小・JPEG 化した画像を返す。
///
/// カメラの起動はユーザーの操作ごとに行う副作用のため冪等ではない。
Future<CapturedImage?> captureReceiptImageWithCamera() async {
  final pickedFile = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: _capturedImageMaxLongSide,
    maxHeight: _capturedImageMaxLongSide,
    imageQuality: _capturedImageQuality,
  );
  if (pickedFile == null) {
    return null;
  }
  return (
    imageBytes: await pickedFile.readAsBytes(),
    imageContentType:
        pickedFile.mimeType ??
        _imageContentTypeFromPath(imagePath: pickedFile.path),
  );
}

/// フォトライブラリから画像 (カード明細・購入履歴のスクショ等) を 1 枚選び、
/// カメラ撮影と同じ縮小・JPEG 化をして返す。
///
/// フォトライブラリの起動はユーザーの操作ごとに行う副作用のため冪等ではない。
Future<CapturedImage?> pickCaptureImageFromPhotoLibrary() async {
  final pickedFile = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: _capturedImageMaxLongSide,
    maxHeight: _capturedImageMaxLongSide,
    imageQuality: _capturedImageQuality,
  );
  if (pickedFile == null) {
    return null;
  }
  return (
    imageBytes: await pickedFile.readAsBytes(),
    imageContentType:
        pickedFile.mimeType ??
        _imageContentTypeFromPath(imagePath: pickedFile.path),
  );
}

/// ファイル拡張子から Content-Type を推定する。
///
/// image_picker は iOS で mimeType を返さないことがあるため、拡張子で補う。
/// maxWidth / maxHeight / imageQuality を指定した撮影・選択は JPEG で保存されるため、既定は image/jpeg。
String _imageContentTypeFromPath({required String imagePath}) {
  final lowerCasePath = imagePath.toLowerCase();
  if (lowerCasePath.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerCasePath.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lowerCasePath.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
