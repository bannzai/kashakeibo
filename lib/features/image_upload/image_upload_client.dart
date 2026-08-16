// 画像アップロード基盤 (workers/image の Cloudflare Worker) への Flutter クライアント。
// Worker の API 仕様は workers/image/README.md を参照。
// Firebase ID token は引数で受け取る (firebase_auth への依存は issue #3 の Firebase 接続基盤が担うため、
// この feature は認証済みトークンを渡される前提で HTTP 通信だけを担当する)。
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// 画像アップロード Worker のベース URL。
/// Worker のデプロイ (workers/image/README.md) でドメインが確定してから
/// --dart-define=IMAGE_API_BASE_URL=https://... で注入するため、既定値は空文字にしている。
const imageApiBaseUrl = String.fromEnvironment('IMAGE_API_BASE_URL');

/// 画像を multipart/form-data で Worker にアップロードし、
/// R2 のオブジェクトキー (`users/{uid}/{UUID}.{拡張子}`) を返す。
/// 返されたキーを Firestore の明細に保存することで画像と明細を紐づけられる (紐付け自体は issue #9)。
/// 冪等ではない: 同じ画像を2回アップロードすると Worker が別のオブジェクトキーを採番して2つ保存される
/// (キーの採番を Worker 側の UUID に一任する設計のため。重複画像の整理は明細との紐付け側で扱う)。
Future<String> uploadImage({
  required Uint8List imageBytes,
  required String imageContentType,
  required String firebaseIdToken,
  required http.Client httpClient,
  // 呼び出し側が dart-define の設定値をそのまま使う通常経路のため
  String baseUrl = imageApiBaseUrl,
}) async {
  final uploadRequest =
      http.MultipartRequest('POST', Uri.parse('$baseUrl/images'))
        ..headers['Authorization'] = 'Bearer $firebaseIdToken'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            // Worker はキー生成にファイル名を使わない (uid + UUID で採番する) ため固定名でよい
            filename: 'image',
            contentType: MediaType.parse(imageContentType),
          ),
        );

  final uploadResponse = await http.Response.fromStream(
    await httpClient.send(uploadRequest),
  );
  if (uploadResponse.statusCode != 201) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像のアップロードに失敗しました (status=${uploadResponse.statusCode}): ${uploadResponse.body}',
      uploadRequest.url,
    );
  }
  return (jsonDecode(uploadResponse.body)
          as Map<String, dynamic>)['imageObjectKey']
      as String;
}

/// アップロード済み画像をオブジェクトキーで取得し、画像のバイト列を返す。
/// Worker は Authorization ヘッダー必須のため、Image.network ではなくこの関数で取得して Image.memory で表示する。
Future<Uint8List> fetchImage({
  required String imageObjectKey,
  required String firebaseIdToken,
  required http.Client httpClient,
  // 呼び出し側が dart-define の設定値をそのまま使う通常経路のため
  String baseUrl = imageApiBaseUrl,
}) async {
  final fetchResponse = await httpClient.get(
    Uri.parse('$baseUrl/images/$imageObjectKey'),
    headers: {'Authorization': 'Bearer $firebaseIdToken'},
  );
  if (fetchResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像の取得に失敗しました (status=${fetchResponse.statusCode}): ${fetchResponse.body}',
      Uri.parse('$baseUrl/images/$imageObjectKey'),
    );
  }
  return fetchResponse.bodyBytes;
}
