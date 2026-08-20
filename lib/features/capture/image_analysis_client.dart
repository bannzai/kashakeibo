// 画像解析 (workers/image の POST /analyses) への Flutter クライアント。
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

/// アップロード済み画像を Worker 経由で Gemini 解析し、抽出した明細を返す。
/// [imageObjectKey] は uploadImage が返した本人の uid 配下のキー。
/// 冪等 (Worker 側の副作用は日次解析回数の加算のみ)。
Future<ImageAnalysisResult> analyzeImage({
  required String imageObjectKey,
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
    body: jsonEncode({'imageObjectKey': imageObjectKey}),
  );
  if (analysisResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '画像の解析に失敗しました (status=${analysisResponse.statusCode}): ${analysisResponse.body}',
      Uri.parse('${baseUrl ?? imageApiBaseUrl}/analyses'),
    );
  }
  return ImageAnalysisResult.fromJson(
    jsonDecode(utf8.decode(analysisResponse.bodyBytes)) as Map<String, dynamic>,
  );
}
