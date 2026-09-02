// 画像解析 (workers/image の POST /analyses) と今月のスキャン回数 (GET /analyses/quota) への Flutter クライアント。
// Worker が R2 のアップロード済み画像を Gemini に渡して明細を抽出する (API 仕様は workers/image/README.md)。
// Firebase ID token と App Check token は引数で受け取り、この feature は HTTP 通信と応答のデコードだけを担当する
// (token の取得と HTTP クライアントの用意は lib/provider/image.dart)。
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

part 'image_analysis_client.freezed.dart';
part 'image_analysis_client.g.dart';

/// Worker が画像から抽出した明細 1 件 (POST /analyses の `transactions[]` 要素)。
///
/// type / category は Worker が Flutter 側 Entity と同じ enum 名で返す契約
/// (workers/image/src/analysis.ts)。Worker 側に enum が追加された時に旧クライアントが
/// デコードに失敗しないよう、未知の値は other / expense として読む。
@freezed
abstract class AnalyzedTransaction with _$AnalyzedTransaction {
  const factory AnalyzedTransaction({
    /// 店名・サービス名 (摘要)。読み取れなかった場合は空文字。
    required String title,

    /// 金額 (日本円・税込・整数、1 以上)。
    required int amount,

    /// 取引日 ("YYYY-MM-DD")。年月日のいずれかが読み取れなかった場合は null。
    required String? transactionDate,

    /// 収入 / 支出。
    @JsonKey(unknownEnumValue: TransactionType.expense)
    required TransactionType type,

    /// カテゴリ。
    @JsonKey(unknownEnumValue: TransactionCategory.other)
    required TransactionCategory category,
  }) = _AnalyzedTransaction;

  factory AnalyzedTransaction.fromJson(Map<String, dynamic> json) =>
      _$AnalyzedTransactionFromJson(json);
}

/// ユーザーの追加指示による再解析の 1 往復 (POST /analyses のリクエスト `instructionTurns[]` の要素。issue #40)。
///
/// 解析はステートレスのため Gemini 側に対話は残らず、クライアントが往復の履歴を毎回送る
/// (Worker 側の契約: workers/image/src/analysis.ts の AnalysisInstructionTurn)。
@freezed
abstract class AnalysisInstructionTurn with _$AnalysisInstructionTurn {
  const factory AnalysisInstructionTurn({
    /// この指示を出した時点でユーザーに見えていた解析結果。
    required List<AnalyzedTransaction> previousTransactions,

    /// ユーザーの追加指示 (自由文)。
    required String instruction,
  }) = _AnalysisInstructionTurn;

  factory AnalysisInstructionTurn.fromJson(Map<String, dynamic> json) =>
      _$AnalysisInstructionTurnFromJson(json);
}

/// POST /analyses のレスポンス本体。
@freezed
abstract class ImageAnalysisResult with _$ImageAnalysisResult {
  const factory ImageAnalysisResult({
    /// 抽出した明細。レシートは 1 枚 1 件。明細が写っていない画像では空。
    required List<AnalyzedTransaction> transactions,
  }) = _ImageAnalysisResult;

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$ImageAnalysisResultFromJson(json);
}

/// 今月のスキャン (解析) 回数と無料枠の上限 (GET /analyses/quota のレスポンス本体)。
///
/// 残量は `monthlyFreeScanLimit - monthlyScanCount` (0 未満にはしない)。
/// プレミアムかどうかは含まれず、クライアントが RevenueCat SDK から得る (lib/provider/purchase.dart)。
@freezed
abstract class ScanQuota with _$ScanQuota {
  const factory ScanQuota({
    /// 今月 (UTC の暦月) の解析回数。プレミアムの解析も数える。
    required int monthlyScanCount,

    /// 無料プランの月あたり解析回数の上限。
    required int monthlyFreeScanLimit,
  }) = _ScanQuota;

  factory ScanQuota.fromJson(Map<String, dynamic> json) =>
      _$ScanQuotaFromJson(json);
}

/// 無料プランの月あたりスキャン回数を使い切っている (POST /analyses が 402 を返した)。
///
/// 呼び出し側 (撮影フロー) はペイウォールを表示し、プレミアムになれば再試行する。
class ScanQuotaExceededException implements Exception {
  /// Worker が返したエラーメッセージ (そのまま表示する)。
  final String message;

  /// 402 と一緒に返る今月のスキャン回数と無料枠。
  final ScanQuota scanQuota;

  const ScanQuotaExceededException({
    required this.message,
    required this.scanQuota,
  });

  @override
  String toString() => message;
}

/// アップロード済み画像を Worker 経由で Gemini 解析し、抽出した明細を返す。
/// [imageObjectKey] は uploadImage が返した本人の uid 配下のキー。
/// [instructionTurns] はユーザーの追加指示による再解析の履歴 (古い順)。空なら初回解析。
/// 無料枠を使い切っていてプレミアムでもない場合 (402) は [ScanQuotaExceededException]。
/// 冪等 (Worker 側の副作用は日次・月次の解析回数の加算のみ。再解析も同じく消費する)。
Future<ImageAnalysisResult> analyzeImage({
  required String imageObjectKey,
  required List<AnalysisInstructionTurn> instructionTurns,
  required String firebaseIdToken,
  required String firebaseAppCheckToken,
  required http.Client httpClient,
  String? baseUrl,
}) async {
  final analysisResponse = await httpClient.post(
    Uri.parse('${baseUrl ?? imageApiBaseUrl}/analyses'),
    headers: {
      'Authorization': 'Bearer $firebaseIdToken',
      firebaseAppCheckHeaderName: firebaseAppCheckToken,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'imageObjectKey': imageObjectKey,
      // 初回解析は指示なし (Worker は未指定を初回として扱う)
      if (instructionTurns.isNotEmpty)
        'instructionTurns': [
          for (final instructionTurn in instructionTurns)
            instructionTurn.toJson(),
        ],
    }),
  );
  if (analysisResponse.statusCode == 402) {
    final quotaExceededBody =
        jsonDecode(utf8.decode(analysisResponse.bodyBytes))
            as Map<String, dynamic>;
    throw ScanQuotaExceededException(
      message: quotaExceededBody['error'] as String,
      scanQuota: ScanQuota.fromJson(quotaExceededBody),
    );
  }
  if (analysisResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像の解析に失敗しました (status=${analysisResponse.statusCode}): ${utf8.decode(analysisResponse.bodyBytes)}',
      Uri.parse('${baseUrl ?? imageApiBaseUrl}/analyses'),
    );
  }
  return ImageAnalysisResult.fromJson(
    jsonDecode(utf8.decode(analysisResponse.bodyBytes)) as Map<String, dynamic>,
  );
}

/// 今月のスキャン回数と無料枠を Worker から取得する (GET /analyses/quota)。冪等 (読み取りのみ)。
Future<ScanQuota> fetchScanQuota({
  required String firebaseIdToken,
  required String firebaseAppCheckToken,
  required http.Client httpClient,
  String? baseUrl,
}) async {
  final quotaResponse = await httpClient.get(
    Uri.parse('${baseUrl ?? imageApiBaseUrl}/analyses/quota'),
    headers: {
      'Authorization': 'Bearer $firebaseIdToken',
      firebaseAppCheckHeaderName: firebaseAppCheckToken,
    },
  );
  if (quotaResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      'スキャン回数の取得に失敗しました (status=${quotaResponse.statusCode}): ${utf8.decode(quotaResponse.bodyBytes)}',
      Uri.parse('${baseUrl ?? imageApiBaseUrl}/analyses/quota'),
    );
  }
  return ScanQuota.fromJson(
    jsonDecode(utf8.decode(quotaResponse.bodyBytes)) as Map<String, dynamic>,
  );
}
