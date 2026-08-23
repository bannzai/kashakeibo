// audit_log_client の HTTP リクエスト組み立てとレスポンスのデコードのテスト。
// 件数の上限・無料プランの期間制限・BigQuery からの整形は Worker 側の責務のため、
// ここでは MockClient でクライアント側の責務 (URL・ヘッダー・デコード・エラー伝播) だけを検証する。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kashakeibo/features/audit_log/audit_log_client.dart';
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

void main() {
  const testBaseUrl = 'https://image-worker.test';

  group('fetchAuditLogs', () {
    test(
      'GET /audit-logs に Bearer トークンと App Check トークン付きで送信し、履歴をデコードする',
      () async {
        late http.Request capturedRequest;
        final auditLogs = await fetchAuditLogs(
          firebaseIdToken: 'test-id-token',
          firebaseAppCheckToken: 'test-app-check-token',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'auditLogs': [
                  {
                    'occurredAt': '2026-08-23T01:23:45.678Z',
                    'operation': 'transactionUpdated',
                    'transactionID': 'abc123',
                    'transactionTitle': 'スーパーマーケット',
                    'transactionAmount': 3480,
                    'changedFieldNames': ['excludedFromAggregation'],
                  },
                  {
                    'occurredAt': '2026-08-22T10:00:00.000Z',
                    'operation': 'transactionDeleted',
                    'transactionID': 'def456',
                    'transactionTitle': null,
                    'transactionAmount': null,
                    'changedFieldNames': <String>[],
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          baseUrl: testBaseUrl,
        );

        expect(capturedRequest.method, 'GET');
        expect(capturedRequest.url.toString(), '$testBaseUrl/audit-logs');
        expect(
          capturedRequest.headers['Authorization'],
          'Bearer test-id-token',
        );
        expect(
          capturedRequest.headers[firebaseAppCheckHeaderName],
          'test-app-check-token',
        );

        expect(auditLogs, hasLength(2));
        expect(
          auditLogs.first.occurredAt,
          DateTime.utc(2026, 8, 23, 1, 23, 45, 678),
        );
        expect(auditLogs.first.operation, AuditLogOperation.transactionUpdated);
        expect(auditLogs.first.transactionID, 'abc123');
        expect(auditLogs.first.transactionTitle, 'スーパーマーケット');
        expect(auditLogs.first.transactionAmount, 3480);
        expect(auditLogs.first.changedFieldNames, ['excludedFromAggregation']);
        // 明細に紐づく情報を持たない履歴も落とさずに読む。
        expect(auditLogs.last.transactionTitle, isNull);
        expect(auditLogs.last.transactionAmount, isNull);
        expect(auditLogs.last.changedFieldNames, isEmpty);
      },
    );

    test('Worker が追加した未知の操作種別は unknown として読む', () async {
      final auditLogs = await fetchAuditLogs(
        firebaseIdToken: 'test-id-token',
        firebaseAppCheckToken: 'test-app-check-token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'auditLogs': [
                {
                  'occurredAt': '2026-08-23T01:23:45.678Z',
                  'operation': 'transactionArchived',
                  'transactionID': 'abc123',
                  'transactionTitle': null,
                  'transactionAmount': null,
                  'changedFieldNames': <String>[],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: testBaseUrl,
      );

      expect(auditLogs.single.operation, AuditLogOperation.unknown);
    });

    test('履歴が 1 件も無い場合は空のリストを返す', () async {
      expect(
        await fetchAuditLogs(
          firebaseIdToken: 'test-id-token',
          firebaseAppCheckToken: 'test-app-check-token',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'auditLogs': <dynamic>[]}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        isEmpty,
      );
    });

    test('回数上限 (429) はエラー本文を加工せず例外として伝える', () async {
      await expectLater(
        fetchAuditLogs(
          firebaseIdToken: 'test-id-token',
          firebaseAppCheckToken: 'test-app-check-token',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'error': '操作履歴の取得回数の上限に達しました'}),
              429,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            allOf(contains('status=429'), contains('上限に達しました')),
          ),
        ),
      );
    });

    test('サーバーエラー (5xx) はエラー本文を加工せず例外として伝える', () async {
      await expectLater(
        fetchAuditLogs(
          firebaseIdToken: 'test-id-token',
          firebaseAppCheckToken: 'test-app-check-token',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'error': 'BigQuery のクエリに失敗しました'}),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<http.ClientException>().having(
            (clientException) => clientException.message,
            'message',
            allOf(contains('status=500'), contains('BigQuery のクエリに失敗しました')),
          ),
        ),
      );
    });
  });

  group('deleteAuditLogs', () {
    test('DELETE /audit-logs に Bearer トークンと App Check トークン付きで送信する', () async {
      late http.Request capturedRequest;
      await deleteAuditLogs(
        firebaseIdToken: 'test-id-token',
        firebaseAppCheckToken: 'test-app-check-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"accepted":true}', 202);
        }),
        baseUrl: testBaseUrl,
      );

      expect(capturedRequest.method, 'DELETE');
      expect(capturedRequest.url.toString(), '$testBaseUrl/audit-logs');
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
      expect(
        capturedRequest.headers[firebaseAppCheckHeaderName],
        'test-app-check-token',
      );
    });

    test('202 以外のレスポンスはボディを加工せず例外として伝える', () async {
      await expectLater(
        deleteAuditLogs(
          firebaseIdToken: 'expired-token',
          firebaseAppCheckToken: 'test-app-check-token',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'error': 'Firebase ID token が無効です'}),
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
}
