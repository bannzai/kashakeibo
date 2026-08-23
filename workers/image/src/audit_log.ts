// 明細 (Firestore の `users/{userId}/transactions`) の訂正・削除履歴 (監査ログ) の読み取り・記録と、
// アカウント削除時のパージ。
// 履歴は 2 つのテーブルから成り、どちらもクライアントに書き込み経路が無い (履歴自体の改ざんを構造的に防ぐ):
// - 明細の変更: Firebase Extension「Stream Firestore to BigQuery」が書き出す changelog テーブル。
//   スキーマ (timestamp / event_id / document_name / document_id / operation / data / old_data / path_params)
//   は extension が定める標準スキーマで、本 Worker はそのうち表示に使う列だけを読む
// - R2 の画像削除: 本 Worker が書き込む image_deletion_logs テーブル。画像だけを消す削除 (DELETE /images 系) は
//   Firestore の明細を変えないため changelog に痕跡が残らず、Worker 自身が記録しないと監査を迂回できてしまう
import type { BigQueryQueryParameter } from "./bigquery";
import {
  BigQueryRequestError,
  bigQueryRowsByFieldName,
  fetchGoogleApiAccessToken,
  postBigQueryApi,
  queryBigQuery,
} from "./bigquery";
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

// 本 Worker が R2 の画像削除を書き込むテーブル。changelog と同じデータセットに置き、
// アカウント削除時のパージが 2 つのテーブルを同じ手順 (同じ location・同じ DML) で消せるようにする
const imageDeletionLogTableId = "image_deletion_logs";

/**
 * image_deletion_logs のスキーマ (tables.insert に渡す定義)。
 * 削除したユーザー・削除した画像のオブジェクトキー (全画像の削除では NULL)・Worker が記録した削除時刻を持つ。
 */
const imageDeletionLogTableSchemaFields = [
  { name: "uid", type: "STRING", mode: "REQUIRED" },
  { name: "image_object_key", type: "STRING", mode: "NULLABLE" },
  { name: "deleted_at", type: "TIMESTAMP", mode: "REQUIRED" },
] as const;

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

// パージ要求を KV に残しておく期間。この期間が過ぎるまでは DML が成功しても要求を消さず、毎時の実行で消し直す。
// アカウント削除時の明細の DELETE イベントは extension が Cloud Tasks 経由で非同期に書き出し、
// 失敗した書き出しはリトライで数時間後に届くことがあるため、最初の DML の後から changelog に行が増える。
// 24 時間は extension のリトライとストリーミングバッファの滞留 (最大 90 分程度) のどちらも大きく上回る猶予で、
// この間の毎時の再実行で後着の行まで消し切る
export const auditLogPurgeRequestRetentionMilliseconds = 24 * 60 * 60 * 1000;

// Firebase Auth のアカウントが残ったままのパージ要求を取り下げるまでの期間。
// クライアントは DELETE /audit-logs → 明細・画像の削除 → Firebase Auth ユーザーの削除の順に呼ぶため、
// 削除が完了した要求では登録から数分で uid が消える。7 日は、通信断・アプリの終了で削除フローが中断した
// ユーザーが削除をやり直すのに十分な猶予で、これを過ぎても残っている要求は削除が完了しなかったものとして扱う
// (残し続けると毎時の cron が消えない要求の lookup を無期限に繰り返す)
export const auditLogPurgeAbandonedRequestExpiryMilliseconds = 7 * 24 * 60 * 60 * 1000;

// Firebase Auth のアカウントの有無を問い合わせる Identity Toolkit のエンドポイント。
// 本番の Firebase Auth を直接見るため、パージの可否をクライアントの申告に依存させない
const identityToolkitApiBaseUrl = "https://identitytoolkit.googleapis.com/v1";

// accounts:lookup の fetch タイムアウト。Workers の fetch サブリクエストには既定のタイムアウトが無く、
// Identity Toolkit の応答遅延で毎時の scheduled 全体がハングするのを防ぐ。
// uid を 1 件引くだけの軽い呼び出しのため、BigQuery のクエリ (bigquery.ts) より短い値で足りる
const firebaseAuthUserLookupTimeoutMilliseconds = 10_000;

/**
 * 監査ログを新しい順に取得する。明細の変更 (changelog) と画像の削除 (image_deletion_logs) の
 * 両方を同じ uid・同じ期間で読み、時刻の新しい順に統合して返す。
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
  const transactionChangelogAuditLogs = bigQueryRowsByFieldName(
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
      queryParameters: auditLogQueryParameters({ uid, oldestTimestamp }),
    }),
  ).map(toAuditLog);

  return [...transactionChangelogAuditLogs, ...(await fetchImageDeletionAuditLogs({ env, uid, oldestTimestamp }))]
    // 2 つのテーブルの行を 1 本の履歴にする。occurredAt は同じ形式の UTC の ISO 8601 のため文字列比較で並ぶ
    .sort((leftAuditLog, rightAuditLog) => rightAuditLog.occurredAt.localeCompare(leftAuditLog.occurredAt))
    .slice(0, maxAuditLogCount);
}

/** changelog・image_deletion_logs に共通の絞り込みパラメータ (対象ユーザーと期間の下限)。 */
function auditLogQueryParameters({
  uid,
  oldestTimestamp,
}: {
  uid: string;
  oldestTimestamp: Date | null;
}): BigQueryQueryParameter[] {
  return [
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
  ];
}

/**
 * image_deletion_logs から画像削除の履歴を読む。
 * テーブルはこの Worker が最初の画像削除を記録する時に作るため、まだ削除が一度も起きていない環境では
 * 存在せず 404 になる。その場合は履歴なしとして扱い、明細の変更履歴まで 502 にしない。
 * 冪等 (読み取りのみ)。
 */
async function fetchImageDeletionAuditLogs({
  env,
  uid,
  oldestTimestamp,
}: {
  env: ImageWorkerEnv;
  uid: string;
  oldestTimestamp: Date | null;
}): Promise<AuditLog[]> {
  try {
    return bigQueryRowsByFieldName(
      await queryBigQuery({
        projectId: env.FIREBASE_PROJECT_ID,
        serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
        query: [
          "SELECT image_object_key, deleted_at",
          `FROM \`${env.FIREBASE_PROJECT_ID}.${firestoreExportDatasetId}.${imageDeletionLogTableId}\``,
          "WHERE uid = @uid",
          ...(oldestTimestamp === null ? [] : ["  AND deleted_at >= @oldestTimestamp"]),
          "ORDER BY deleted_at DESC",
          `LIMIT ${maxAuditLogCount}`,
        ].join("\n"),
        queryParameters: auditLogQueryParameters({ uid, oldestTimestamp }),
      }),
    ).map(toImageDeletionAuditLog);
  } catch (error) {
    if (!isMissingBigQueryTableError(error)) {
      throw error;
    }
    return [];
  }
}

/** テーブルがまだ作られていない (BigQuery が 404 を返した) 失敗かどうか。 */
function isMissingBigQueryTableError(error: unknown): boolean {
  return error instanceof BigQueryRequestError && error.httpStatus === 404;
}

/**
 * image_deletion_logs の 1 行を監査ログにする。
 * R2 のオブジェクト単位の削除で明細のドキュメントに紐付かないため、明細の情報 (ID・表示名・金額) は持たない。
 */
function toImageDeletionAuditLog(imageDeletionLogRow: Record<string, string | null>): AuditLog {
  return {
    occurredAt: toIsoDateTimeText(imageDeletionLogRow.deleted_at),
    operation: "transactionImageDeleted",
    transactionID: "",
    transactionTitle: null,
    transactionAmount: null,
    changedFieldNames: [],
  };
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
 * R2 の画像削除を監査ログに記録する (DELETE /images/{objectKey} と DELETE /images の成功時)。
 *
 * 記録に失敗しても例外にせず警告だけを残す。画像削除の応答を BigQuery 障害に巻き込まないためのベストエフォートで、
 * 呼び出し側は記録の成否によらず削除の成功を返す。
 * 冪等ではない: 同じ画像の削除を 2 回呼べば 2 行増える (削除操作が行われた回数をそのまま履歴に残すため)。
 */
export async function recordImageDeletionLog({
  env,
  uid,
  imageObjectKey,
}: {
  env: ImageWorkerEnv;
  /** 削除を行ったユーザーの Firebase Auth uid (検証済み ID token の uid)。 */
  uid: string;
  /** 削除した画像のオブジェクトキー。アカウント削除時の全画像の削除は null。 */
  imageObjectKey: string | null;
}): Promise<void> {
  try {
    let insertResponse = await insertImageDeletionLogRow({ env, uid, imageObjectKey });
    if (insertResponse.status === 404) {
      // テーブルがまだ無い環境 (新しい環境の最初の画像削除) では、作ってから入れ直す
      await createImageDeletionLogTable(env);
      insertResponse = await insertImageDeletionLogRow({ env, uid, imageObjectKey });
    }
    const insertFailureText = await imageDeletionLogInsertFailureText(insertResponse);
    if (insertFailureText !== null) {
      console.warn(`画像削除の監査ログを記録できませんでした (画像の削除自体は成功しています): ${insertFailureText}`);
    }
  } catch (error) {
    console.warn("画像削除の監査ログを記録できませんでした (画像の削除自体は成功しています)", error);
  }
}

/** image_deletion_logs に 1 行を streaming insert する (tabledata.insertAll)。時刻はクライアント申告を使わず Worker の時刻で記録する。 */
function insertImageDeletionLogRow({
  env,
  uid,
  imageObjectKey,
}: {
  env: ImageWorkerEnv;
  uid: string;
  imageObjectKey: string | null;
}): Promise<Response> {
  return postBigQueryApi({
    serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
    apiPath: `/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/datasets/${firestoreExportDatasetId}/tables/${imageDeletionLogTableId}/insertAll`,
    requestBody: {
      rows: [{ json: { uid, image_object_key: imageObjectKey, deleted_at: new Date().toISOString() } }],
    },
  });
}

/**
 * image_deletion_logs テーブルを作る (tables.insert)。既に作られている場合 (409) は成功として扱う。
 * 冪等: 何度呼んでもテーブルが 1 つある状態に収束する。
 */
async function createImageDeletionLogTable(env: ImageWorkerEnv): Promise<void> {
  const createTableResponse = await postBigQueryApi({
    serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
    apiPath: `/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/datasets/${firestoreExportDatasetId}/tables`,
    requestBody: {
      tableReference: {
        projectId: env.FIREBASE_PROJECT_ID,
        datasetId: firestoreExportDatasetId,
        tableId: imageDeletionLogTableId,
      },
      schema: { fields: imageDeletionLogTableSchemaFields },
    },
  });
  if (!createTableResponse.ok && createTableResponse.status !== 409) {
    throw new BigQueryRequestError(
      `image_deletion_logs テーブルを作成できませんでした (status=${createTableResponse.status}): ${await createTableResponse.text()}`,
      createTableResponse.status,
    );
  }
}

/**
 * insertAll の応答から失敗の理由を読む (成功なら null)。
 * 行ごとの失敗は HTTP 200 の本文 (insertErrors) で返るため、status だけでは成否を判定できない。
 */
async function imageDeletionLogInsertFailureText(insertResponse: Response): Promise<string | null> {
  if (!insertResponse.ok) {
    return `status=${insertResponse.status}: ${await insertResponse.text()}`;
  }
  const insertResult = (await insertResponse.json()) as { insertErrors?: unknown[] };
  return insertResult.insertErrors === undefined || insertResult.insertErrors.length === 0
    ? null
    : JSON.stringify(insertResult.insertErrors);
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
 * 待ち時間に満たない要求と、Firebase Auth のアカウントがまだ残っている要求はスキップし、
 * DML に失敗した要求と猶予期間中の要求は KV に残して次回の実行で消し直す。
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

/**
 * パージ要求 1 件を処理する。Firebase Auth のアカウントが消えていることを確かめてから DML を実行し、
 * DML が成功し、かつ猶予期間を過ぎている場合だけ KV の要求を消す。
 */
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
  // 登録時刻を読めない要求 (Date.parse が NaN) は比較が偽になり、待たずにパージへ進み、成功したらそのまま消える
  // (ユーザーが要求済みの削除であり、経過時間を判定できないまま待ち続けるより実行して終わらせる側に倒す)
  const purgeRequestElapsedMilliseconds = Date.now() - Date.parse(purgeRequestedAt);
  if (purgeRequestElapsedMilliseconds < auditLogPurgeMinimumWaitMilliseconds) {
    return;
  }

  const uid = purgeRequestKeyName.slice(auditLogPurgeKeyPrefix.length);
  let firebaseAuthUserExists: boolean;
  try {
    firebaseAuthUserExists = await existsFirebaseAuthUser({ env, uid });
  } catch (error) {
    // 一時的な失敗と履歴が消える判断を取り違えないよう、確認できない間はパージしない
    console.warn("Firebase Auth のアカウント削除の確認に失敗しました (次回の scheduled で再試行します)", error);
    return;
  }
  if (firebaseAuthUserExists) {
    // アカウントが残っている = 利用中のユーザーの要求 (有効な token での DELETE /audit-logs の直接呼び出しを含む)。
    // 監査証跡を本人の操作で消せてしまわないよう、アカウントの削除が完了するまでパージしない
    if (purgeRequestElapsedMilliseconds >= auditLogPurgeAbandonedRequestExpiryMilliseconds) {
      console.warn(
        "アカウントが削除されないまま予約の期限を過ぎたため、監査ログのパージ予約を取り下げます (履歴は残ります)",
      );
      await env.PUBLIC_JWK_CACHE_KV.delete(purgeRequestKeyName);
    }
    return;
  }

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
    await purgeImageDeletionLogs({ env, uid });
  } catch (error) {
    // ストリーミングバッファに残った行は DML で削除できないため、この段階の失敗は異常ではない。
    // 要求を KV に残し、次回 (1時間後) 以降の実行で再試行する
    // (2 つのテーブルのうち片方だけ成功した場合も、次回に両方を消し直す)
    console.warn("監査ログのパージに失敗しました (次回の scheduled で再試行します)", error);
    return;
  }
  // 猶予期間中は DML が成功しても要求を残し、後から changelog に届いた行を次回以降の実行で消し切る
  // ([auditLogPurgeRequestRetentionMilliseconds] を参照)
  if (purgeRequestElapsedMilliseconds < auditLogPurgeRequestRetentionMilliseconds) {
    return;
  }
  await env.PUBLIC_JWK_CACHE_KV.delete(purgeRequestKeyName);
}

/**
 * image_deletion_logs から uid の行を消す (アカウント削除時のパージ)。
 * 画像削除が一度も起きておらずテーブルが無い環境では消す行も無いため、404 は成功として扱う。
 * 冪等: 同じ uid で何度実行しても、行が無い状態に収束する。
 */
async function purgeImageDeletionLogs({ env, uid }: { env: ImageWorkerEnv; uid: string }): Promise<void> {
  try {
    await queryBigQuery({
      projectId: env.FIREBASE_PROJECT_ID,
      serviceAccountKeyJson: env.BIGQUERY_SERVICE_ACCOUNT_KEY,
      query: [
        `DELETE FROM \`${env.FIREBASE_PROJECT_ID}.${firestoreExportDatasetId}.${imageDeletionLogTableId}\``,
        "WHERE uid = @uid",
      ].join("\n"),
      queryParameters: [{ name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } }],
    });
  } catch (error) {
    if (!isMissingBigQueryTableError(error)) {
      throw error;
    }
  }
}

/**
 * Firebase Auth に uid のアカウントがまだ存在するかを Identity Toolkit の accounts:lookup で確かめる。
 * 一時的な失敗 (HTTP エラー・接続失敗) は例外にし、呼び出し側が「削除済み」と取り違えないようにする。
 * 冪等 (読み取りのみ)。
 */
async function existsFirebaseAuthUser({ env, uid }: { env: ImageWorkerEnv; uid: string }): Promise<boolean> {
  let accountsLookupResponse: Response;
  try {
    accountsLookupResponse = await fetch(
      `${identityToolkitApiBaseUrl}/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/accounts:lookup`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await fetchGoogleApiAccessToken(env.BIGQUERY_SERVICE_ACCOUNT_KEY)}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ localId: [uid] }),
        signal: AbortSignal.timeout(firebaseAuthUserLookupTimeoutMilliseconds),
      },
    );
  } catch (error) {
    throw new Error(`Firebase Auth の accounts:lookup への接続に失敗しました: ${String(error)}`);
  }
  if (!accountsLookupResponse.ok) {
    throw new Error(
      `Firebase Auth の accounts:lookup に失敗しました (status=${accountsLookupResponse.status}): ${await accountsLookupResponse.text()}`,
    );
  }
  // 削除済みの uid では users 自体が返らない (Identity Toolkit は空配列ではなく項目の省略で表す)
  const accountsLookupResult = (await accountsLookupResponse.json()) as { users?: unknown[] };
  return Array.isArray(accountsLookupResult.users) && accountsLookupResult.users.length > 0;
}
