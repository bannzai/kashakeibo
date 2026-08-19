// image_analysis_client の HTTP リクエスト組み立てとレスポンスのデコードのテスト。
// Worker 側の解析ロジック・無料枠判定は workers/image のテストが検証するため、
// ここでは MockClient でクライアント側の責務 (URL・ヘッダー・JSON body・デコード・エラー伝播) だけを検証する。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';

void main() {
  const testBaseUrl = 'https://image-worker.test';

  group('analyzeImage', () {
    test(
      'POST /analyses に Bearer トークンと imageObjectKey の JSON を送り、明細をデコードする',
      () async {
        late http.Request capturedRequest;
        final imageAnalysisResult = await analyzeImage(
          imageObjectKey: 'users/uid-a/uuid.png',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode({
                'transactions': [
                  {
                    'title': 'スーパーマーケット',
                    'amount': 1280,
                    'transactionDate': '2026-08-16',
                    'type': 'expense',
                    'category': 'food',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          baseUrl: testBaseUrl,
        );

        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.toString(), '$testBaseUrl/analyses');
        expect(
          capturedRequest.headers['Authorization'],
          'Bearer test-id-token',
        );
        expect(
          capturedRequest.headers['content-type'],
          startsWith('application/json'),
        );
        expect(jsonDecode(capturedRequest.body), {
          'imageObjectKey': 'users/uid-a/uuid.png',
        });

        expect(imageAnalysisResult.transactions, hasLength(1));
        final analyzedTransaction = imageAnalysisResult.transactions.first;
        expect(analyzedTransaction.title, 'スーパーマーケット');
        expect(analyzedTransaction.amount, 1280);
        expect(analyzedTransaction.transactionDate, '2026-08-16');
        expect(analyzedTransaction.type, TransactionType.expense);
        expect(analyzedTransaction.category, TransactionCategory.food);
      },
    );

    test('取引日が読み取れなかった明細は transactionDate が null になる', () async {
      final imageAnalysisResult = await analyzeImage(
        imageObjectKey: 'users/uid-a/uuid.png',
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'transactions': [
                {
                  'title': '',
                  'amount': 500,
                  'transactionDate': null,
                  'type': 'income',
                  'category': 'salary',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: testBaseUrl,
      );

      final analyzedTransaction = imageAnalysisResult.transactions.first;
      expect(analyzedTransaction.title, '');
      expect(analyzedTransaction.transactionDate, isNull);
      expect(analyzedTransaction.type, TransactionType.income);
      expect(analyzedTransaction.category, TransactionCategory.salary);
    });

    test('明細が写っていない画像では transactions が空で返る', () async {
      final imageAnalysisResult = await analyzeImage(
        imageObjectKey: 'users/uid-a/uuid.png',
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'transactions': <Map<String, dynamic>>[]}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: testBaseUrl,
      );

      expect(imageAnalysisResult.transactions, isEmpty);
    });

    test('Worker が返した未知の type / category は expense / other として読む', () async {
      final imageAnalysisResult = await analyzeImage(
        imageObjectKey: 'users/uid-a/uuid.png',
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'transactions': [
                {
                  'title': '未知の出費',
                  'amount': 300,
                  'transactionDate': '2026-08-16',
                  'type': 'refund',
                  'category': 'entertainment',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        baseUrl: testBaseUrl,
      );

      final analyzedTransaction = imageAnalysisResult.transactions.first;
      expect(analyzedTransaction.type, TransactionType.expense);
      expect(analyzedTransaction.category, TransactionCategory.other);
    });

    test('200 以外のレスポンスはボディを加工せず例外として伝える', () async {
      await expectLater(
        analyzeImage(
          imageObjectKey: 'users/uid-a/uuid.png',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient(
            (request) async => http.Response(
              '{"error":"1日の解析回数の上限に達しました"}',
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
            allOf(contains('status=429'), contains('1日の解析回数の上限に達しました')),
          ),
        ),
      );
    });

    test('402 (無料枠超過) は ScanQuotaExceededException として、回数と上限を添えて伝える', () async {
      await expectLater(
        analyzeImage(
          imageObjectKey: 'users/uid-a/uuid.png',
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'error': '今月の無料スキャン (10回) を使い切りました',
                'monthlyScanCount': 10,
                'monthlyFreeScanLimit': 10,
              }),
              402,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: testBaseUrl,
        ),
        throwsA(
          isA<ScanQuotaExceededException>()
              .having(
                (exception) => exception.toString(),
                'toString',
                '今月の無料スキャン (10回) を使い切りました',
              )
              .having(
                (exception) => exception.scanQuota,
                'scanQuota',
                const ScanQuota(monthlyScanCount: 10, monthlyFreeScanLimit: 10),
              ),
        ),
      );
    });
  });

  group('fetchScanQuota', () {
    test('GET /analyses/quota に Bearer トークンを送り、回数と上限をデコードする', () async {
      late http.Request capturedRequest;
      final scanQuota = await fetchScanQuota(
        firebaseIdToken: 'test-id-token',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'monthlyScanCount': 3, 'monthlyFreeScanLimit': 10}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUrl: testBaseUrl,
      );
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.toString(), '$testBaseUrl/analyses/quota');
      expect(capturedRequest.headers['Authorization'], 'Bearer test-id-token');
      expect(
        scanQuota,
        const ScanQuota(monthlyScanCount: 3, monthlyFreeScanLimit: 10),
      );
    });

    test('200 以外のレスポンスはボディを加工せず例外として伝える', () async {
      await expectLater(
        fetchScanQuota(
          firebaseIdToken: 'test-id-token',
          httpClient: MockClient(
            (request) async => http.Response('{"error":"not found"}', 404),
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
  });
}
