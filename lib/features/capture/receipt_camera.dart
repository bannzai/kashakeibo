// 端末カメラでのレシート撮影。image_picker のネイティブカメラ UI を使い、
// 撮影した画像を Worker へ送れる形 (バイト列 + Content-Type) にして返す。
import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 撮影・選択した 1 枚の画像 (Worker へのアップロードに必要なバイト列と Content-Type)。
typedef CapturedImage = ({Uint8List imageBytes, String imageContentType});

/// レシートを撮影して返す操作。ユーザーがキャンセルした場合は null。テストでは差し替える。
typedef CaptureReceiptImage = Future<CapturedImage?> Function();

/// レシート撮影操作。
final captureReceiptImageProvider = Provider<CaptureReceiptImage>(
  (ref) => captureReceiptImageWithCamera,
);

// 撮影画像の長辺の上限 (px)。レシートの文字を Gemini が読める解像度を保ちつつ、
// アップロード・解析 (インライン画像は 20MB 上限) のサイズを数百 KB に抑える値。
const _capturedImageMaxWidth = 1600.0;

// JPEG 再圧縮の品質。文字の可読性を落とさない範囲でサイズを抑える一般的な値。
const _capturedImageQuality = 85;

/// 端末カメラでレシートを撮影し、縮小・JPEG 化した画像を返す。
///
/// カメラの起動はユーザーの操作ごとに行う副作用のため冪等ではない。
Future<CapturedImage?> captureReceiptImageWithCamera() async {
  final pickedFile = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: _capturedImageMaxWidth,
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
/// maxWidth / imageQuality を指定した撮影は JPEG で保存されるため、既定は image/jpeg。
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
