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
/// R2 のオブジェクトキー (`users/{uid}/{uploadImageID}.{拡張子}`) を返す。
/// 返されたキーを Firestore の明細に保存することで画像と明細を紐づけられる (紐付け自体は issue #9)。
/// 冪等: [uploadImageID] は呼び出し側が論理アップロードごとに一意な UUID を生成して渡し、
/// 通信エラー等の再試行では同じ値を使う。Worker が同じオブジェクトキーに上書きするため、
/// レスポンスが届かなかった再試行でも孤児オブジェクトが残らない。
Future<String> uploadImage({
  required Uint8List imageBytes,
  required String imageContentType,
  required String uploadImageID,
  required String firebaseIdToken,
  required http.Client httpClient,
  // 呼び出し側が dart-define の設定値をそのまま使う通常経路のため
  String baseUrl = imageApiBaseUrl,
}) async {
  final uploadRequest =
      http.MultipartRequest('POST', Uri.parse('$baseUrl/images'))
        ..headers['Authorization'] = 'Bearer $firebaseIdToken'
        ..headers['X-Upload-Id'] = uploadImageID
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            // Worker はキー生成にファイル名を使わない (JWT の uid + X-Upload-Id で決まる) ため固定名でよい
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

/// アカウント削除時に、本人 (JWT の uid) の全画像を Worker 経由で削除する。
/// docs/AccountDeletion.md の「撮影・アップロードした画像は削除操作と同時に削除される」を満たすため、
/// Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。冪等 (対象が無くても成功する)。
Future<void> deleteAllImages({
  required String firebaseIdToken,
  required http.Client httpClient,
  // 呼び出し側が dart-define の設定値をそのまま使う通常経路のため
  String baseUrl = imageApiBaseUrl,
}) async {
  final deleteResponse = await httpClient.delete(
    Uri.parse('$baseUrl/images'),
    headers: {'Authorization': 'Bearer $firebaseIdToken'},
  );
  if (deleteResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像の削除に失敗しました (status=${deleteResponse.statusCode}): ${deleteResponse.body}',
      Uri.parse('$baseUrl/images'),
    );
  }
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

/// アップロード済み画像 1 件をオブジェクトキーで削除する。
/// 明細から画像だけを外す・明細ごと削除する時に使う (features/transaction_detail)。
/// 冪等: Worker は対象が既に無い場合も 200 を返す。
Future<void> deleteImage({
  required String imageObjectKey,
  required String firebaseIdToken,
  required http.Client httpClient,
  // 呼び出し側が dart-define の設定値をそのまま使う通常経路のため
  String baseUrl = imageApiBaseUrl,
}) async {
  final deleteResponse = await httpClient.delete(
    Uri.parse('$baseUrl/images/$imageObjectKey'),
    headers: {'Authorization': 'Bearer $firebaseIdToken'},
  );
  if (deleteResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像の削除に失敗しました (status=${deleteResponse.statusCode}): ${deleteResponse.body}',
      Uri.parse('$baseUrl/images/$imageObjectKey'),
    );
  }
}
