import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:kashakeibo/features/capture/image_analysis_client.dart'
    as image_analysis;
import 'package:kashakeibo/features/image_upload/image_upload_client.dart'
    as image_upload;
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image.g.dart';

/// 撮影・選択した画像を Worker 経由で R2 にアップロードし、オブジェクトキーを返す操作。
typedef UploadCapturedImage =
    Future<String> Function({
      required Uint8List imageBytes,
      required String imageContentType,
      required String uploadImageID,
    });

/// アップロード済み画像を Worker 経由で Gemini 解析し、抽出した明細を返す操作。
typedef AnalyzeUploadedImage =
    Future<image_analysis.ImageAnalysisResult> Function({
      required String imageObjectKey,
    });

/// アップロード済み画像のバイト列を Worker 経由で取得する操作。
typedef FetchStoredImage =
    Future<Uint8List> Function({required String imageObjectKey});

/// アップロード済み画像 1 件を Worker 経由で削除する操作。
typedef DeleteStoredImage =
    Future<void> Function({required String imageObjectKey});

/// 今月のスキャン回数と無料枠を Worker から取得する操作。
typedef FetchScanQuota = Future<image_analysis.ScanQuota> Function();

/// 撮影・選択した画像のアップロード操作。テストでは差し替える。
final uploadCapturedImageProvider = Provider<UploadCapturedImage>(
  (ref) => uploadCapturedImage,
);

/// アップロード済み画像の Gemini 解析操作。テストでは差し替える。
final analyzeUploadedImageProvider = Provider<AnalyzeUploadedImage>(
  (ref) => analyzeUploadedImage,
);

/// アップロード済み画像の取得操作。テストでは差し替える。
final fetchStoredImageProvider = Provider<FetchStoredImage>(
  (ref) => fetchStoredImage,
);

/// アップロード済み画像 1 件の削除操作。テストでは差し替える。
final deleteStoredImageProvider = Provider<DeleteStoredImage>(
  (ref) => deleteStoredImage,
);

/// 今月のスキャン回数と無料枠の取得操作。テストでは差し替える。
final fetchScanQuotaProvider = Provider<FetchScanQuota>(
  (ref) => fetchScanQuota,
);

/// 今月のスキャン回数と無料枠 (残量チップ・ペイウォールの表示判定に使う)。
///
/// サインイン中のユーザーが変わると取り直す。解析のたびに Worker 側の回数が進むため、
/// 撮影フローの終了後などに [refresh] で取り直す (画面が unmount され得るコールバックから
/// 呼べるよう keepAlive にし、notifier を build 時に確保して使う。`.claude/rules/riverpod-rules.md`)。
@Riverpod(keepAlive: true)
class MonthlyScanQuota extends _$MonthlyScanQuota {
  @override
  Future<image_analysis.ScanQuota> build() {
    // サインイン中の uid が変わった時 (アカウント切替・削除後の匿名再サインイン) だけ取り直す。
    // token 更新などの他の userChanges イベントでは取り直さない
    ref.watch(
      firebaseUserChangesProvider.select(
        (firebaseUserAsync) => firebaseUserAsync.valueOrNull?.uid,
      ),
    );
    return ref.watch(fetchScanQuotaProvider)();
  }

  /// Worker から取り直す。取得中も直前の値を保持する (AsyncValue の previous 値)。
  void refresh() => ref.invalidateSelf();
}

/// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
///
/// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
/// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
@riverpod
Future<Uint8List> storedImage(Ref ref, {required String imageObjectKey}) =>
    ref.watch(fetchStoredImageProvider)(imageObjectKey: imageObjectKey);

/// 現在のユーザーの Firebase ID token を返す。
///
/// Firebase Auth SDK が期限切れ時に自動更新するため、呼び出しの都度取得する
/// (lib/features/image_upload/README.md の「有効期限・制約」)。
Future<String> _currentUserIdToken() async {
  final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (firebaseIdToken == null) {
    throw StateError('サインイン前に画像 API は利用できない');
  }
  return firebaseIdToken;
}

/// 現在のユーザーの ID token と使い捨ての HTTP クライアントで Worker API を 1 回呼ぶ。
Future<T> _callImageApi<T>({
  required Future<T> Function({
    required String firebaseIdToken,
    required http.Client httpClient,
  })
  imageApiCall,
}) async {
  final firebaseIdToken = await _currentUserIdToken();
  final httpClient = http.Client();
  try {
    return await imageApiCall(
      firebaseIdToken: firebaseIdToken,
      httpClient: httpClient,
    );
  } finally {
    httpClient.close();
  }
}

/// 撮影・選択した画像を現在のユーザーの uid 配下へアップロードする。
/// 冪等: 同じ [uploadImageID] での再試行は同じオブジェクトキーへの上書きになる (Worker 側の契約)。
Future<String> uploadCapturedImage({
  required Uint8List imageBytes,
  required String imageContentType,
  required String uploadImageID,
}) => _callImageApi(
  imageApiCall: ({required firebaseIdToken, required httpClient}) =>
      image_upload.uploadImage(
        imageBytes: imageBytes,
        imageContentType: imageContentType,
        uploadImageID: uploadImageID,
        firebaseIdToken: firebaseIdToken,
        httpClient: httpClient,
      ),
);

/// アップロード済み画像を Gemini で解析する。
/// 冪等 (副作用は Worker 側の日次解析回数の加算のみ)。
Future<image_analysis.ImageAnalysisResult> analyzeUploadedImage({
  required String imageObjectKey,
}) => _callImageApi(
  imageApiCall: ({required firebaseIdToken, required httpClient}) =>
      image_analysis.analyzeImage(
        imageObjectKey: imageObjectKey,
        firebaseIdToken: firebaseIdToken,
        httpClient: httpClient,
      ),
);

/// アップロード済み画像のバイト列を取得する。冪等。
Future<Uint8List> fetchStoredImage({required String imageObjectKey}) =>
    _callImageApi(
      imageApiCall: ({required firebaseIdToken, required httpClient}) =>
          image_upload.fetchImage(
            imageObjectKey: imageObjectKey,
            firebaseIdToken: firebaseIdToken,
            httpClient: httpClient,
          ),
    );

/// 今月のスキャン回数と無料枠を取得する。冪等 (読み取りのみ)。
Future<image_analysis.ScanQuota> fetchScanQuota() => _callImageApi(
  imageApiCall: ({required firebaseIdToken, required httpClient}) =>
      image_analysis.fetchScanQuota(
        firebaseIdToken: firebaseIdToken,
        httpClient: httpClient,
      ),
);

/// アップロード済み画像 1 件を削除する。冪等 (対象が無くても成功する。Worker 側の契約)。
Future<void> deleteStoredImage({required String imageObjectKey}) =>
    _callImageApi(
      imageApiCall: ({required firebaseIdToken, required httpClient}) =>
          image_upload.deleteImage(
            imageObjectKey: imageObjectKey,
            firebaseIdToken: firebaseIdToken,
            httpClient: httpClient,
          ),
    );
