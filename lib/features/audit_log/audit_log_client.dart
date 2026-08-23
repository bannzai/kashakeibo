// 操作履歴 (workers/image の GET /audit-logs・DELETE /audit-logs) への Flutter クライアント。
// 履歴の正は「Stream Firestore to BigQuery extension」が users/{uid}/transactions の変更から
// 自動生成する BigQuery の changelog で、Worker がそれを読んでこの API の形に整形する。
// Firebase ID token と App Check token は引数で受け取り、この feature は HTTP 通信と応答のデコードだけを担当する
// (token の取得と HTTP クライアントの用意は lib/provider/audit_log.dart)。
// ベース URL と App Check ヘッダー名は画像 API と同じ Worker のものを使う。
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:kashakeibo/features/image_upload/image_upload_client.dart';

part 'audit_log_client.freezed.dart';
part 'audit_log_client.g.dart';

/// 監査ログが記録する操作の種別。
///
/// Worker が返す文字列と同じ名前にする。Worker 側に種別が追加された時に旧クライアントが
/// デコードに失敗しないよう、未知の値は [AuditLogOperation.unknown] として読む。
enum AuditLogOperation {
  /// 明細を新規作成した。
  transactionCreated,

  /// 明細の内容を訂正した。
  transactionUpdated,

  /// 明細を削除した。
  transactionDeleted,

  /// 明細の元画像 (R2) を削除した。
  transactionImageDeleted,

  /// 旧バージョンの記録、または将来追加された未知の種別。
  unknown,
}

/// 明細と元画像に対する訂正・削除の履歴 1 件
/// (documents/adr/0004-audit-log-bigquery-extension.md の訂正削除履歴)。
///
/// 「いつ・どの操作が・何に対して行われたか」を後から確認するための記録で、明細の
/// 現在の状態からは復元できない情報を持つ (削除された明細の店名・金額など)。
/// GET /audit-logs のレスポンスの `auditLogs[]` 要素そのもので、API スキーマを SSOT とする。
@freezed
abstract class AuditLog with _$AuditLog {
  const factory AuditLog({
    /// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
    required DateTime occurredAt,

    /// 記録した操作の種別。
    @JsonKey(
      defaultValue: AuditLogOperation.unknown,
      unknownEnumValue: AuditLogOperation.unknown,
    )
    required AuditLogOperation operation,

    /// 操作の対象になった明細の ID。
    required String transactionID,

    /// 操作時点の明細の表示名 (店名・摘要)。読み取れない記録では null。
    required String? transactionTitle,

    /// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
    required int? transactionAmount,

    /// 訂正で値が変わった Transaction のフィールド名
    /// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。訂正以外の操作では空。
    @Default(<String>[]) List<String> changedFieldNames,
  }) = _AuditLog;

  factory AuditLog.fromJson(Map<String, dynamic> json) =>
      _$AuditLogFromJson(json);
}

/// 本人 (JWT の uid) の操作履歴を新しい順に取得する (GET /audit-logs)。冪等 (読み取りのみ)。
///
/// 件数の上限と、無料プランで遡れる期間の制限は Worker 側で適用済みで、
/// クライアントは返ってきた履歴をそのまま表示する。
/// 回数上限 (429) やサーバーエラー (5xx) の本文は加工せずそのまま例外に載せる。
Future<List<AuditLog>> fetchAuditLogs({
  required String firebaseIdToken,
  required String firebaseAppCheckToken,
  required http.Client httpClient,
  String? baseUrl,
}) async {
  final auditLogsResponse = await httpClient.get(
    Uri.parse('${baseUrl ?? imageApiBaseUrl}/audit-logs'),
    headers: {
      'Authorization': 'Bearer $firebaseIdToken',
      firebaseAppCheckHeaderName: firebaseAppCheckToken,
    },
  );
  if (auditLogsResponse.statusCode != 200) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '操作履歴の取得に失敗しました (status=${auditLogsResponse.statusCode}): ${utf8.decode(auditLogsResponse.bodyBytes)}',
      Uri.parse('${baseUrl ?? imageApiBaseUrl}/audit-logs'),
    );
  }
  return [
    for (final auditLogJson
        in (jsonDecode(utf8.decode(auditLogsResponse.bodyBytes))
                as Map<String, dynamic>)['auditLogs']
            as List<dynamic>)
      AuditLog.fromJson(auditLogJson as Map<String, dynamic>),
  ];
}

/// アカウント削除時に、本人 (JWT の uid) の操作履歴のパージを Worker へ依頼する
/// (DELETE /audit-logs)。
///
/// 履歴の実体は BigQuery にあり即時削除ではないため、Worker はパージの登録を受け付けた
/// 時点で 202 を返す。冪等 (登録済みでも 202)。
/// Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。
Future<void> deleteAuditLogs({
  required String firebaseIdToken,
  required String firebaseAppCheckToken,
  required http.Client httpClient,
  String? baseUrl,
}) async {
  final deleteResponse = await httpClient.delete(
    Uri.parse('${baseUrl ?? imageApiBaseUrl}/audit-logs'),
    headers: {
      'Authorization': 'Bearer $firebaseIdToken',
      firebaseAppCheckHeaderName: firebaseAppCheckToken,
    },
  );
  if (deleteResponse.statusCode != 202) {
    // エラーメッセージは加工せずそのまま伝える (コーディング規約)
    throw http.ClientException(
      '操作履歴の削除に失敗しました (status=${deleteResponse.statusCode}): ${utf8.decode(deleteResponse.bodyBytes)}',
      Uri.parse('${baseUrl ?? imageApiBaseUrl}/audit-logs'),
    );
  }
}
