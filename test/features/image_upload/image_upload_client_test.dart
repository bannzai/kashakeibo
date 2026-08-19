// image_upload_client の HTTP リクエスト組み立てとレスポンス処理のテスト。
// Worker 側の認可ロジック (uid 強制・未認証拒否) は workers/image/test/handler.test.ts が検証するため、
// ここでは MockClient でクライアント側の責務 (multipart 組み立て・ヘッダー・エラー伝播) だけを検証する。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

void main() {
  const testBaseUrl = 'https://image-worker.test';
  final testImageBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

  group('uploadImage', () {
    test(
      'multipart/form-data の POST /images に Bearer トークン付きで送信し、オブジェクトキーを返す',
      () async {
        late http.Request capturedRequest;
        final uploadedImageObjectKey = await uploadImage(
          imageBytes: testImageBytes,
          imageContentType: 'image/png',
          uploadImageID: '11111111-2222-4333-8444-555555555555',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({'imageObjectKey': 'users/uid-a/uuid.png'}),
              201,
            );
          }),
          baseUrl: testBaseUrl,
        );

        expect(uploadedImageObjectKey, 'users/uid-a/uuid.png');
        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.toString(), '$testBaseUrl/images');
        expect(
          capturedRequest.headers['Authorization'],
          'Bearer test-id-token',
        );
        expect(
          capturedRequest.headers['X-Upload-Id'],
          '11111111-2222-4333-8444-555555555555',
        );
        expect(
          capturedRequest.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        // multipart ボディに file フィールドと画像バイト列が含まれる
        expect(
          latin1.decode(capturedRequest.bodyBytes),
          contains('name="file"'),
        );
        expect(
          latin1.decode(capturedRequest.bodyBytes),
          contains('content-type: image/png'),
        );
      },
    );

    test('201 以外のレスポンスはボディを加工せず例外として伝える', () async {
      expect(
        () => uploadImage(
          imageBytes: testImageBytes,
          imageContentType: 'image/png',
          uploadImageID: '11111111-2222-4333-8444-555555555555',
          firebaseIdToken: 'expired-token',
          httpClient: MockClient(
            (request) async => http.Response(
              '{"error":"Firebase ID token が無効です"}',
              401,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            allOf(contains('status=401'), contains('Firebase ID token が無効です')),
          ),
        ),
      );
    });
  });

  group('deleteAllImages', () {
    test('DELETE /images に Bearer トークン付きで送信する', () async {
      late http.Request capturedRequest;
      await deleteAllImages(
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"deletedImageCount":"2"}', 200);
        }),
        baseUrl: testBaseUrl,
      );

      expect(capturedRequest.method, 'DELETE');
      expect(capturedRequest.url.toString(), '$testBaseUrl/images');
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
    });

    test('200 以外のレスポンスはボディを加工せず例外として伝える', () async {
      expect(
        () => deleteAllImages(
          firebaseIdToken: 'expired-token',
          httpClient: MockClient(
            (request) async => http.Response(
              '{"error":"Firebase ID token が無効です"}',
              401,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            contains('status=401'),
          ),
        ),
      );
    });
  });

  group('fetchImage', () {
    test('GET /images/{オブジェクトキー} に Bearer トークン付きで送信し、バイト列を返す', () async {
      late http.Request capturedRequest;
      final fetchedImageBytes = await fetchImage(
        imageObjectKey: 'users/uid-a/uuid.png',
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response.bytes(testImageBytes, 200);
        }),
        baseUrl: testBaseUrl,
      );

      expect(fetchedImageBytes, testImageBytes);
      expect(capturedRequest.method, 'GET');
      expect(
        capturedRequest.url.toString(),
        '$testBaseUrl/images/users/uid-a/uuid.png',
      );
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
    });

    test('200 以外のレスポンスはボディを加工せず例外として伝える', () async {
      expect(
        () => fetchImage(
          imageObjectKey: 'users/other-uid/uuid.png',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient(
            (request) async => http.Response(
              '{"error":"このオブジェクトキーへのアクセス権限がありません"}',
              403,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            allOf(contains('status=403'), contains('アクセス権限がありません')),
          ),
        ),
      );
    });
  });

  group('deleteImage', () {
    test('DELETE /images/{オブジェクトキー} に Bearer トークン付きで送信する', () async {
      late http.Request capturedRequest;
      await deleteImage(
        imageObjectKey: 'users/uid-a/uuid.png',
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"deleted":true}', 200);
        }),
        baseUrl: testBaseUrl,
      );

      expect(capturedRequest.method, 'DELETE');
      expect(
        capturedRequest.url.toString(),
        '$testBaseUrl/images/users/uid-a/uuid.png',
      );
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
    });

    test('200 以外のレスポンスはボディを加工せず例外として伝える', () async {
      await expectLater(
        deleteImage(
          imageObjectKey: 'users/uid-a/missing.png',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient(
            (request) async => http.Response(
              '{"error":"画像が見つかりません"}',
              404,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            allOf(contains('status=404'), contains('画像が見つかりません')),
          ),
        ),
      );
    });
  });
}
