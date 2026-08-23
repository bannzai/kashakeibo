// debug_scan_count_client の HTTP リクエスト組み立てとレスポンスのデコードのテスト。
// dev 限定の経路であることの保証 (prod で 404 になること) は workers/image のテストが検証するため、
// ここでは MockClient でクライアント側の責務 (URL・ヘッダー・JSON body・デコード・エラー伝播) だけを検証する。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kashakeibo/features/debug/debug_scan_count_client.dart';
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

void main() {
  const testBaseUrl = 'https://image-worker.test';

  test(
    'POST /debug/scan-count に Bearer トークンと monthlyScanCount を送り、設定後の残量をデコードする',
    () async {
      late http.Request capturedRequest;
      final scanQuota = await setDebugScanCount(
        monthlyScanCount: 50,
        firebaseIdToken: 'test-id-token',
        firebaseAppCheckToken: 'test-app-check-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'monthlyScanCount': 50, 'monthlyFreeScanLimit': 50}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUrl: testBaseUrl,
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.toString(), '$testBaseUrl/debug/scan-count');
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
      expect(
        capturedRequest.headers[firebaseAppCheckHeaderName],
        'test-app-check-token',
      );
      expect(jsonDecode(capturedRequest.body), {'monthlyScanCount': 50});

      expect(scanQuota.monthlyScanCount, 50);
      expect(scanQuota.monthlyFreeScanLimit, 50);
    },
  );

  test('経路が無効な環境 (prod の 404) はエラー本文をそのまま含めて例外にする', () async {
    await expectLater(
      setDebugScanCount(
        monthlyScanCount: 50,
        firebaseIdToken: 'test-id-token',
        firebaseAppCheckToken: 'test-app-check-token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'error': 'not found'}),
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
          allOf(contains('status=404'), contains('not found')),
        ),
      ),
    );
  });
}
