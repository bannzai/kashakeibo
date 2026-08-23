// 明細 (Firestore の `users/{userId}/transactions`) の訂正・削除履歴 (監査ログ) の読み取りと、
// アカウント削除時のパージ。
// 履歴の実体は Firebase Extension「Stream Firestore to BigQuery」が書き出す changelog テーブルで、
// クライアントは履歴を書き込まない (書き込み経路を持たせないことで、履歴自体の改ざんを構造的に防ぐ)。
// changelog のスキーマ (timestamp / event_id / document_name / document_id / operation / data / old_data / path_params)
// は extension が定める標準スキーマで、本 Worker はそのうち表示に使う列だけを読む。
import type { BigQueryQueryParameter } from "./bigquery";
import { bigQueryRowsByFieldName, queryBigQuery } from "./bigquery";
// 型だけの参照 (実行時には import されないため、handler.ts との循環参照にならない)
import type { ImageWorkerEnv } from "./handler";

/** 監査ログの操作種別。Flutter 側 (lib/features/audit_log) が enum 名でそのまま読む。 */
export const auditLogOperations = [
  "transactionCreated",
  "transactionUpdated",
  "transactionDeleted",
  "transactionImageDeleted",
] as const;
export type AuditLogOperation = (typeof auditLogOperations)[number];

/** 明細 1 件に対する変更 1 回 (GET /audit-logs のレスポンス `auditLogs[]` の要素)。 */
export interface AuditLog {
  /** 変更が起きた時刻 (ISO 8601)。 */
  occurredAt: string;
  /** 何をした変更か。 */
  operation: AuditLogOperation;
  /** 変更された明細のドキュメント ID。 */
  transactionID: string;
  /** 変更時点の明細の表示名。読み取れない場合は null。 */
  transactionTitle: string | null;
  /** 変更時点の明細の金額。読み取れない場合は null。 */
  transactionAmount: number | null;
  /** 更新で値が変わったフィールド名 (更新以外は空配列)。 */
  changedFieldNames: string[];
}

// Stream Firestore to BigQuery extension が明細の全変更を書き出す changelog テーブル。
// データセット・テーブル名は extension の導入時に指定した設定と一致させる
const firestoreExportDatasetId = "firestore_export";
const transactionsChangelogTableId = "transactions_raw_changelog";

// 一度に返す監査ログの件数上限。履歴画面が一度に表示する上限であり、全期間を遡る導線 (ページング) を
// 持たない設計のためこれ以上は返さない (従来の Firestore subcollection 実装と同じ値)
export const maxAuditLogCount = 200;

/**
 * 無料プランで遡れる履歴の月数 (当月を含む)。
 *
 * アプリ側の `lib/features/paywall/free_plan_history_limit.dart` の `freePlanHistoryMonthCount` と同じ値にし、
 * 画面のガード (月送り・検索・操作履歴) と Worker の絞り込みで見える範囲を一致させる。
 * 月の境界はアプリが端末ローカル、Worker が UTC のため最大で数時間ずれる近似で、
 * 境界付近の数時間ぶん見え方が食い違うことは許容する (履歴は LLM 原価が発生しない経路のため厳密には強制しない)。
 */
export const freePlanAuditLogHistoryMonthCount = 3;

/** 無料プランが遡れる最古の時刻 (今の月を含む直近 [freePlanAuditLogHistoryMonthCount] ヶ月の先頭。UTC の月初)。 */
export function oldestFreePlanAuditLogTimestamp(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (freePlanAuditLogHistoryMonthCount - 1), 1));
}

// 変更点 (changedFieldNames) の比較から除くメタフィールド。
// Flutter 側 Entity (lib/entity/transaction.dart) の @ServerCreatedTimestamp / @ServerUpdatedTimestamp は
// 明細を更新すると必ず書き換わるため、含めると「ユーザーが何を直したか」が読めなくなる
const excludedChangedFieldNames = new Set(["serverCreatedDateTime", "serverUpdatedDateTime"]);

/** アカウント削除時のパージ要求を記録する KV キーのプレフィックス。 */
const auditLogPurgeKeyPrefix = "audit-log-purge:";

// パージの登録から実際に DML を実行するまで待つ時間。
// 明細の一括削除で生まれる DELETE イベントが changelog に届くのは非同期 (数秒〜数分) で、
// さらに extension のストリーミング挿入でバッファに乗っている行は DML で削除できない (最大 90 分程度)。
// 到着を待たずに実行すると必ず取りこぼすため、登録直後の要求は次回の実行に回す
// (バッファ解消前に失敗した場合も、キーを残して毎時のリトライで消し切る)
export const auditLogPurgeMinimumWaitMilliseconds = 60 * 60 * 1000;

/**
 * 監査ログを新しい順に取得する。
 * uid は呼び出し側が検証済み ID token から取り出したものを渡す (クライアント申告のユーザー ID は使わない)。
 * 冪等 (読み取りのみ)。
 */
export async function fetchAuditLogs({
  env,
  uid,
  oldestTimestamp,
}: {
  env: ImageWorkerEnv;
  /** 履歴を取得するユーザーの Firebase Auth uid。 */
  uid: string;
  /** これより古い変更を返さない下限 (無料プランの履歴制限)。制限しない場合は null。 */
  oldestTimestamp: Date | null;
}): Promise<AuditLog[]> {
  return bigQueryRowsByFieldName(
    await queryBigQuery({
      projectId: env.FIREBASE_PROJECT_ID,
      serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
      query: [
        "SELECT timestamp, document_id, operation, data, old_data",
        `FROM \`${env.FIREBASE_PROJECT_ID}.${firestoreExportDatasetId}.${transactionsChangelogTableId}\``,
        "WHERE JSON_EXTRACT_SCALAR(path_params, '$.userId') = @uid",
        // IMPORT は extension 導入時に既存ドキュメントを取り込んだ行で、ユーザーの操作ではない
        "  AND operation != 'IMPORT'",
        ...(oldestTimestamp === null ? [] : ["  AND timestamp >= @oldestTimestamp"]),
        "ORDER BY timestamp DESC",
        `LIMIT ${maxAuditLogCount}`,
      ].join("\n"),
      queryParameters: [
        { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } },
        ...(oldestTimestamp === null
          ? []
          : [
              {
                name: "oldestTimestamp",
                parameterType: { type: "TIMESTAMP" },
                parameterValue: { value: oldestTimestamp.toISOString() },
              } satisfies BigQueryQueryParameter,
            ]),
      ],
    }),
  ).map(toAuditLog);
}

/**
 * changelog の 1 行をレスポンスの監査ログにする。
 * data / old_data の JSON を読めなかった行も落とさず、操作種別だけを返す
 * (履歴の件数が実際の操作回数と食い違うことを避けるため)。
 */
function toAuditLog(transactionChangelogRow: Record<string, string | null>): AuditLog {
  const newDocumentFields = parseChangelogDocumentJson(transactionChangelogRow.data);
  const oldDocumentFields = parseChangelogDocumentJson(transactionChangelogRow.old_data);
  // 削除は変更後のドキュメントが無いため、削除直前の内容を明細の表示に使う
  const displayedDocumentFields =
    transactionChangelogRow.operation === "DELETE" ? oldDocumentFields : newDocumentFields;
  return {
    occurredAt: toIsoDateTimeText(transactionChangelogRow.timestamp),
    operation: toAuditLogOperation({
      changelogOperation: transactionChangelogRow.operation,
      newDocumentFields,
      oldDocumentFields,
    }),
    // extension は常に document_id を書き込むが、欠けた行も落とさずに返す
    transactionID: transactionChangelogRow.document_id ?? "",
    transactionTitle: typeof displayedDocumentFields?.title === "string" ? displayedDocumentFields.title : null,
    transactionAmount: typeof displayedDocumentFields?.amount === "number" ? displayedDocumentFields.amount : null,
    changedFieldNames:
      transactionChangelogRow.operation === "UPDATE"
        ? changedFieldNamesBetween({ newDocumentFields, oldDocumentFields })
        : [],
  };
}

/** changelog の data / old_data (ドキュメントの JSON 文字列) を読む。列が null・JSON として読めない場合は null。 */
function parseChangelogDocumentJson(documentJson: string | null): Record<string, unknown> | null {
  if (documentJson === null) {
    return null;
  }
  try {
    const documentFields = JSON.parse(documentJson) as unknown;
    return typeof documentFields === "object" && documentFields !== null && !Array.isArray(documentFields)
      ? (documentFields as Record<string, unknown>)
      : null;
  } catch (error) {
    console.warn("監査ログのドキュメント JSON を読み取れませんでした", error);
    return null;
  }
}

/** changelog の operation 列と変更内容から、表示上の操作種別を決める。 */
function toAuditLogOperation({
  changelogOperation,
  newDocumentFields,
  oldDocumentFields,
}: {
  changelogOperation: string | null;
  newDocumentFields: Record<string, unknown> | null;
  oldDocumentFields: Record<string, unknown> | null;
}): AuditLogOperation {
  if (changelogOperation === "CREATE") {
    return "transactionCreated";
  }
  if (changelogOperation === "DELETE") {
    return "transactionDeleted";
  }
  // 明細を残したまま元画像だけを外した更新は、金額・内容の訂正とは意味が違うため別の操作として見せる
  if (
    newDocumentFields !== null &&
    oldDocumentFields !== null &&
    typeof oldDocumentFields.sourceImageObjectKey === "string" &&
    (newDocumentFields.sourceImageObjectKey === null || newDocumentFields.sourceImageObjectKey === undefined)
  ) {
    return "transactionImageDeleted";
  }
  return "transactionUpdated";
}

/** 更新前後のドキュメントを比べ、値が変わったトップレベルのフィールド名を返す。 */
function changedFieldNamesBetween({
  newDocumentFields,
  oldDocumentFields,
}: {
  newDocumentFields: Record<string, unknown> | null;
  oldDocumentFields: Record<string, unknown> | null;
}): string[] {
  if (newDocumentFields === null || oldDocumentFields === null) {
    return [];
  }
  return [...new Set([...Object.keys(newDocumentFields), ...Object.keys(oldDocumentFields)])].filter(
    (fieldName) =>
      !excludedChangedFieldNames.has(fieldName) &&
      !isDeepEqualJsonValue(newDocumentFields[fieldName], oldDocumentFields[fieldName]),
  );
}

/** JSON の値どうしを構造で比較する (配列・オブジェクトの中身が同じなら等しい)。 */
function isDeepEqualJsonValue(leftValue: unknown, rightValue: unknown): boolean {
  if (leftValue === rightValue) {
    return true;
  }
  if (Array.isArray(leftValue) && Array.isArray(rightValue)) {
    return (
      leftValue.length === rightValue.length &&
      leftValue.every((leftElement, elementIndex) => isDeepEqualJsonValue(leftElement, rightValue[elementIndex]))
    );
  }
  if (
    typeof leftValue !== "object" ||
    typeof rightValue !== "object" ||
    leftValue === null ||
    rightValue === null ||
    Array.isArray(leftValue) ||
    Array.isArray(rightValue)
  ) {
    return false;
  }
  const leftFields = leftValue as Record<string, unknown>;
  const rightFields = rightValue as Record<string, unknown>;
  return (
    Object.keys(leftFields).length === Object.keys(rightFields).length &&
    Object.keys(leftFields).every(
      (fieldName) =>
        Object.prototype.hasOwnProperty.call(rightFields, fieldName) &&
        isDeepEqualJsonValue(leftFields[fieldName], rightFields[fieldName]),
    )
  );
}

/**
 * BigQuery の TIMESTAMP 列を ISO 8601 の文字列にする。
 * REST API の TIMESTAMP は Unix 秒 (小数付き) の文字列で返るため、そのままでは日時として読めない。
 */
function toIsoDateTimeText(bigQueryTimestamp: string | null): string {
  const unixSeconds = bigQueryTimestamp === null || bigQueryTimestamp === "" ? Number.NaN : Number(bigQueryTimestamp);
  // extension は必ず timestamp を書き込むため通常は起きない。値が壊れた行も落とさずに返すためのフォールバック
  return Number.isFinite(unixSeconds) ? new Date(unixSeconds * 1000).toISOString() : new Date(0).toISOString();
}

/**
 * アカウント削除時の履歴パージを予約する (DELETE /audit-logs)。登録した時刻を返す。
 *
 * 即時に DML を実行しない理由は [auditLogPurgeMinimumWaitMilliseconds] を参照。
 * 冪等: 同じ uid で何度呼んでも登録が 1 件あるだけの状態に収束する (再登録すると、その時刻から待ち直す)。
 */
export async function registerAuditLogPurge({ env, uid }: { env: ImageWorkerEnv; uid: string }): Promise<string> {
  const purgeRequestedAt = new Date().toISOString();
  await env.PUBLIC_JWK_CACHE_KV.put(`${auditLogPurgeKeyPrefix}${uid}`, purgeRequestedAt);
  return purgeRequestedAt;
}

/**
 * 予約済みの履歴パージをまとめて実行する (毎時の scheduled から呼ぶ)。
 * 待ち時間に満たない要求はスキップし、DML に失敗した要求は KV に残して次回の実行で再試行する。
 * 冪等: 同じ状態で何度実行しても、消えるべき履歴が消えた状態に収束する。
 */
export async function purgeRequestedAuditLogs(env: ImageWorkerEnv): Promise<void> {
  let purgeRequestListCursor: string | undefined;
  do {
    const purgeRequestList = await env.PUBLIC_JWK_CACHE_KV.list({
      prefix: auditLogPurgeKeyPrefix,
      cursor: purgeRequestListCursor,
    });
    for (const purgeRequestKey of purgeRequestList.keys) {
      await purgeAuditLogsOfPurgeRequest({ env, purgeRequestKeyName: purgeRequestKey.name });
    }
    purgeRequestListCursor = purgeRequestList.list_complete ? undefined : purgeRequestList.cursor;
  } while (purgeRequestListCursor !== undefined);
}

/** パージ要求 1 件を処理する。実行できた場合だけ KV の要求を消す。 */
async function purgeAuditLogsOfPurgeRequest({
  env,
  purgeRequestKeyName,
}: {
  env: ImageWorkerEnv;
  purgeRequestKeyName: string;
}): Promise<void> {
  const purgeRequestedAt = await env.PUBLIC_JWK_CACHE_KV.get(purgeRequestKeyName);
  if (purgeRequestedAt === null) {
    // list と get の間に別の実行が処理を終えた要求
    return;
  }
  // 登録時刻を読めない要求 (Date.parse が NaN) は比較が偽になり、待たずにパージへ進む
  // (ユーザーが要求済みの削除であり、待ち直すより実行する側に倒す)
  if (Date.now() - Date.parse(purgeRequestedAt) < auditLogPurgeMinimumWaitMilliseconds) {
    return;
  }

  const uid = purgeRequestKeyName.slice(auditLogPurgeKeyPrefix.length);
  try {
    await queryBigQuery({
      projectId: env.FIREBASE_PROJECT_ID,
      serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
      query: [
        `DELETE FROM \`${env.FIREBASE_PROJECT_ID}.${firestoreExportDatasetId}.${transactionsChangelogTableId}\``,
        "WHERE JSON_EXTRACT_SCALAR(path_params, '$.userId') = @uid",
      ].join("\n"),
      queryParameters: [{ name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } }],
    });
  } catch (error) {
    // ストリーミングバッファに残った行は DML で削除できないため、この段階の失敗は異常ではない。
    // 要求を KV に残し、次回 (1時間後) 以降の実行で再試行する
    console.warn("監査ログのパージに失敗しました (次回の scheduled で再試行します)", error);
    return;
  }
  await env.PUBLIC_JWK_CACHE_KV.delete(purgeRequestKeyName);
}
