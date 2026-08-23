// DEBUG (dev 環境) 限定の、今月のスキャン回数設定 (workers/image の POST /debug/scan-count) への Flutter クライアント。
// スキャン回数は Cloudflare の Durable Object の中にしか無く、firebase / gcloud / wrangler のどれからも
// 書き換えられないため、残量 0 の QA (残量 0 のペイウォールガード・402 からの購入 → 再解析) を作れない。
// その状態を開発者メニューから作るための経路で、Worker 側は dev 環境でだけこのエンドポイントを有効にする
// (prod は 404。workers/image/src/handler.ts の handleDebugScanCountSet)。
// 他のクライアントと同じく token の取得と HTTP クライアントの用意は lib/provider/image.dart が行う。
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

/// 今月のスキャン回数を [monthlyScanCount] に設定し、設定後の状態を返す (DEBUG 用)。
///
/// 変更できるのは ID token の uid 本人の回数だけ (Worker 側で JWT の uid のカウンターに強制される)。
/// 冪等: 同じ値で何度呼んでも結果は同じ。
Future<ScanQuota> setDebugScanCount({
  required int monthlyScanCount,
  required String firebaseIdToken,
  required String firebaseAppCheckToken,
  required http.Client httpClient,
  String? baseUrl,
}) async {
  final debugScanCountUri = Uri.parse(
    '${baseUrl ?? imageApiBaseUrl}/debug/scan-count',
  );
  final scanCountResponse = await httpClient.post(
    debugScanCountUri,
    headers: {
      'Authorization': 'Bearer $firebaseIdToken',
      firebaseAppCheckHeaderName: firebaseAppCheckToken,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'monthlyScanCount': monthlyScanCount}),
  );
  if (scanCountResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)。
    // prod の Worker では経路自体が無効なため 404 になる
    throw http.ClientException(
      'スキャン回数の設定に失敗しました (status=${scanCountResponse.statusCode}): ${utf8.decode(scanCountResponse.bodyBytes)}',
      debugScanCountUri,
    );
  }
  return ScanQuota.fromJson(
    jsonDecode(utf8.decode(scanCountResponse.bodyBytes))
        as Map<String, dynamic>,
  );
}
