// 監査ログ (GET /audit-logs・DELETE /audit-logs・画像削除の記録・毎時の scheduled パージ) のテスト。
// Firebase ID token / App Check token の検証は handler.test.ts と同じスタブ検証器で置き換え、
// KV と Durable Object は vitest-pool-workers (miniflare) の実 binding を使う。
// BigQuery・Identity Toolkit と Google の token エンドポイントは fetchMock で応答を差し替え、
// JWT の署名はテスト内で生成した RSA 鍵を持つサービスアカウントキーで実際に通す。
import { env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import type { VerifyFirebaseAppCheckToken } from "../src/app_check";
import {
  auditLogPurgeAbandonedRequestExpiryMilliseconds,
  auditLogPurgeMinimumWaitMilliseconds,
  auditLogPurgeRequestRetentionMilliseconds,
  freePlanAuditLogHistoryMonthCount,
} from "../src/audit_log";
import type { ImageWorkerEnv, TokenVerifiers, VerifyFirebaseIdToken } from "../src/handler";
import {
  auditLogsPath,
  firebaseAppCheckHeaderName,
  handleImageRequest,
  maxDailyAuditLogCountPerUser,
} from "../src/handler";
import workerEntrypoint from "../src/index";
import { dailyCounterPurgeDelayMilliseconds } from "../src/usage_counter";

declare module "cloudflare:test" {
  interface ProvidedEnv extends ImageWorkerEnv {}
}

// スタブ検証器: handler.test.ts と同じ "valid-token-<uid>" / "valid-app-check-token" だけを受理する
const stubVerifyFirebaseIdToken: VerifyFirebaseIdToken = async (firebaseIdToken) => {
  const validTokenPrefix = "valid-token-";
  if (!firebaseIdToken.startsWith(validTokenPrefix)) {
    throw new Error("invalid token (stub)");
  }
  return { uid: firebaseIdToken.slice(validTokenPrefix.length) };
};

const validAppCheckToken = "valid-app-check-token";
const stubVerifyFirebaseAppCheckToken: VerifyFirebaseAppCheckToken = async (firebaseAppCheckToken) => {
  if (firebaseAppCheckToken !== validAppCheckToken) {
    throw new Error("invalid app check token (stub)");
  }
  return { appId: "1:000000000000:ios:stub" };
};

const stubTokenVerifiers: TokenVerifiers = {
  verifyFirebaseIdToken: stubVerifyFirebaseIdToken,
  verifyFirebaseAppCheckToken: stubVerifyFirebaseAppCheckToken,
};

const workerBaseUrl = "https://image-worker.test";
const googleOAuthOrigin = "https://oauth2.googleapis.com";
const bigQueryApiOrigin = "https://bigquery.googleapis.com";
const bigQueryQueriesPath = `/bigquery/v2/projects/${env.FIREBASE_PROJECT_ID}/queries`;
const imageDeletionLogInsertAllPath = `/bigquery/v2/projects/${env.FIREBASE_PROJECT_ID}/datasets/firestore_export/tables/image_deletion_logs/insertAll`;
const imageDeletionLogTablesPath = `/bigquery/v2/projects/${env.FIREBASE_PROJECT_ID}/datasets/firestore_export/tables`;
const identityToolkitApiOrigin = "https://identitytoolkit.googleapis.com";
const accountsLookupPath = `/v1/projects/${env.FIREBASE_PROJECT_ID}/accounts:lookup`;
const revenueCatApiOrigin = "https://api.revenuecat.com";

let testServiceAccountPrivateKeyPem: string;

beforeAll(async () => {
  const testKeyPair = (await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256", modulusLength: 2048, publicExponent: new Uint8Array([0x01, 0x00, 0x01]) },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
  const pkcs8Bytes = new Uint8Array(await crypto.subtle.exportKey("pkcs8", testKeyPair.privateKey));
  testServiceAccountPrivateKeyPem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...pkcs8Bytes)).replace(/(.{64})/g, "$1\n")}\n-----END PRIVATE KEY-----\n`;

  fetchMock.activate();
  // BigQuery / Google token / RevenueCat 以外への実通信を伴わないことを保証する
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

/**
 * テスト用の env。サービスアカウントのメールアドレスをテストごとに変えることで、
 * bigquery.ts のメモリキャッシュ済み access token をテスト間で共有せず、
 * token 取得の fetch がテストごとにちょうど 1 回起きる状態にする。
 * RevenueCat の設定は既定で外し、プレミアム判定を外部通信なしで「無料プラン」に固定する。
 */
function buildAuditLogEnv({
  serviceAccountName,
  revenueCatConfigured = false,
}: {
  serviceAccountName: string;
  revenueCatConfigured?: boolean;
}): ImageWorkerEnv {
  return {
    ...env,
    BIGQUERY_SERVICE_ACCOUNT_KEY: JSON.stringify({
      client_email: `${serviceAccountName}@kashakeibo-test.iam.gserviceaccount.com`,
      private_key: testServiceAccountPrivateKeyPem,
    }),
    ...(revenueCatConfigured
      ? {}
      : { REVENUECAT_SECRET_API_KEY: undefined, REVENUECAT_PROJECT_ID: "", REVENUECAT_PREMIUM_ENTITLEMENT_ID: "" }),
  };
}

/** access token の取得 (JWT の交換) を 1 回ぶん受け付ける。 */
function interceptGoogleAccessToken(): void {
  fetchMock
    .get(googleOAuthOrigin)
    .intercept({ path: "/token", method: "POST" })
    .reply(200, JSON.stringify({ access_token: "test-bigquery-access-token", expires_in: 3599 }));
}

/** BigQuery の jobs.query を 1 回ぶん受け付け、受け取ったリクエスト本体を記録する。 */
function interceptBigQueryQuery({
  responseBody,
  status = 200,
}: {
  responseBody: unknown;
  status?: number;
}): { query?: string; queryParameters?: { name: string; parameterValue: { value: string } }[] }[] {
  const capturedQueryRequests: { query?: string; queryParameters?: { name: string; parameterValue: { value: string } }[] }[] = [];
  fetchMock
    .get(bigQueryApiOrigin)
    .intercept({ path: bigQueryQueriesPath, method: "POST" })
    .reply(status, (request) => {
      capturedQueryRequests.push(JSON.parse(String(request.body)));
      return JSON.stringify(responseBody);
    });
  return capturedQueryRequests;
}

/** changelog テーブルの SELECT 結果 (BigQuery REST API の QueryResponse) を組み立てる。 */
function buildChangelogQueryResponse(
  transactionChangelogRows: {
    timestamp: string;
    document_id: string;
    operation: string;
    data: string | null;
    old_data: string | null;
  }[],
): object {
  const changelogFieldNames = ["timestamp", "document_id", "operation", "data", "old_data"] as const;
  return {
    jobComplete: true,
    schema: { fields: changelogFieldNames.map((fieldName) => ({ name: fieldName })) },
    rows: transactionChangelogRows.map((transactionChangelogRow) => ({
      f: changelogFieldNames.map((fieldName) => ({ v: transactionChangelogRow[fieldName] })),
    })),
  };
}

/** image_deletion_logs の SELECT 結果 (BigQuery REST API の QueryResponse) を組み立てる。 */
function buildImageDeletionLogQueryResponse(
  imageDeletionLogRows: { image_object_key: string | null; deleted_at: string }[],
): object {
  const imageDeletionLogFieldNames = ["image_object_key", "deleted_at"] as const;
  return {
    jobComplete: true,
    schema: { fields: imageDeletionLogFieldNames.map((fieldName) => ({ name: fieldName })) },
    rows: imageDeletionLogRows.map((imageDeletionLogRow) => ({
      f: imageDeletionLogFieldNames.map((fieldName) => ({ v: imageDeletionLogRow[fieldName] })),
    })),
  };
}

/** image_deletion_logs への streaming insert (tabledata.insertAll) を 1 回ぶん受け付け、受け取った行を記録する。 */
function interceptImageDeletionLogInsert({
  status = 200,
}: { status?: number } = {}): { rows?: { json: { uid: string; image_object_key: string | null; deleted_at: string } }[] }[] {
  const capturedInsertRequests: {
    rows?: { json: { uid: string; image_object_key: string | null; deleted_at: string } }[];
  }[] = [];
  fetchMock
    .get(bigQueryApiOrigin)
    .intercept({ path: imageDeletionLogInsertAllPath, method: "POST" })
    .reply(status, (request) => {
      capturedInsertRequests.push(JSON.parse(String(request.body)));
      return JSON.stringify(status === 200 ? {} : { error: { message: "insert error" } });
    });
  return capturedInsertRequests;
}

/** image_deletion_logs テーブルの作成 (tables.insert) を 1 回ぶん受け付け、受け取った定義を記録する。 */
function interceptImageDeletionLogTableCreate(): { tableReference?: { tableId: string }; schema?: unknown }[] {
  const capturedCreateTableRequests: { tableReference?: { tableId: string }; schema?: unknown }[] = [];
  fetchMock
    .get(bigQueryApiOrigin)
    .intercept({ path: imageDeletionLogTablesPath, method: "POST" })
    .reply(200, (request) => {
      capturedCreateTableRequests.push(JSON.parse(String(request.body)));
      return JSON.stringify({});
    });
  return capturedCreateTableRequests;
}

/**
 * Firebase Auth の accounts:lookup を 1 回ぶん受け付ける。
 * 削除済みの uid に Identity Toolkit が返す応答には users 自体が含まれないため、存在しない場合はそれを再現する。
 */
function interceptFirebaseAuthAccountsLookup({
  firebaseAuthUserExists,
  status = 200,
}: {
  firebaseAuthUserExists: boolean;
  status?: number;
}): { localId?: string[] }[] {
  const capturedLookupRequests: { localId?: string[] }[] = [];
  fetchMock
    .get(identityToolkitApiOrigin)
    .intercept({ path: accountsLookupPath, method: "POST" })
    .reply(status, (request) => {
      capturedLookupRequests.push(JSON.parse(String(request.body)));
      return JSON.stringify(
        firebaseAuthUserExists
          ? { kind: "identitytoolkit#GetAccountInfoResponse", users: [{ localId: "existing-user" }] }
          : { kind: "identitytoolkit#GetAccountInfoResponse" },
      );
    });
  return capturedLookupRequests;
}

/** BigQuery の TIMESTAMP 列の返り値 (Unix 秒の文字列)。 */
function toBigQueryTimestampValue(isoDateTimeText: string): string {
  return String(Date.parse(isoDateTimeText) / 1000);
}

function buildAuditLogsRequest({
  uid,
  method = "GET",
  authorizationHeader,
  appCheckToken = validAppCheckToken,
}: {
  uid: string;
  method?: "GET" | "DELETE";
  authorizationHeader?: string | null;
  appCheckToken?: string | null;
}): Request {
  const requestHeaders = new Headers();
  const resolvedAuthorizationHeader =
    authorizationHeader === undefined ? `Bearer valid-token-${uid}` : authorizationHeader;
  if (resolvedAuthorizationHeader !== null) {
    requestHeaders.set("Authorization", resolvedAuthorizationHeader);
  }
  if (appCheckToken !== null) {
    requestHeaders.set(firebaseAppCheckHeaderName, appCheckToken);
  }
  return new Request(`${workerBaseUrl}${auditLogsPath}`, { method, headers: requestHeaders });
}

/** 指定カウンターだけを count 回まで加算する (他のカウンターの上限判定に影響を与えないよう単独条件で回す)。 */
async function seedDailyCount(counterKey: string, count: number): Promise<void> {
  const dailyUsageCounter = env.USAGE_COUNTER.get(env.USAGE_COUNTER.idFromName(new Date().toISOString().slice(0, 10)));
  for (let seededCount = 0; seededCount < count; seededCount++) {
    await dailyUsageCounter.incrementIfWithinLimits(
      [{ counterKey, maxCount: Number.MAX_SAFE_INTEGER }],
      dailyCounterPurgeDelayMilliseconds,
    );
  }
}

describe("監査ログの取得 (GET /audit-logs)", () => {
  it("Authorization ヘッダーなし・App Check token なしを 401 で拒否し、BigQuery を呼ばない", async () => {
    const responseWithoutAuthorization = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-a", authorizationHeader: null }),
      buildAuditLogEnv({ serviceAccountName: "unauthorized" }),
      stubTokenVerifiers,
    );
    expect(responseWithoutAuthorization.status).toBe(401);

    const responseWithoutAppCheckToken = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-a", appCheckToken: null }),
      buildAuditLogEnv({ serviceAccountName: "unauthorized" }),
      stubTokenVerifiers,
    );
    expect(responseWithoutAppCheckToken.status).toBe(401);
  });

  it("changelog の行を操作種別・変更フィールド付きの監査ログに変換する", async () => {
    const occurredAtText = "2026-08-23T01:23:45.678Z";
    interceptGoogleAccessToken();
    interceptBigQueryQuery({
      responseBody: buildChangelogQueryResponse([
        {
          timestamp: toBigQueryTimestampValue(occurredAtText),
          document_id: "transaction-created",
          operation: "CREATE",
          data: JSON.stringify({
            title: "スーパーマーケット",
            amount: 3480,
            excludedFromAggregation: false,
            serverCreatedDateTime: "2026-08-23T01:23:45.678Z",
          }),
          old_data: null,
        },
        {
          timestamp: toBigQueryTimestampValue(occurredAtText),
          document_id: "transaction-updated",
          operation: "UPDATE",
          data: JSON.stringify({
            title: "スーパーマーケット",
            amount: 3480,
            excludedFromAggregation: true,
            confirmedDistinctTransactionIDs: ["other-transaction"],
            serverUpdatedDateTime: "2026-08-23T02:00:00.000Z",
          }),
          old_data: JSON.stringify({
            title: "スーパーマーケット",
            amount: 3480,
            excludedFromAggregation: false,
            confirmedDistinctTransactionIDs: ["other-transaction"],
            serverUpdatedDateTime: "2026-08-23T01:23:45.678Z",
          }),
        },
        {
          timestamp: toBigQueryTimestampValue(occurredAtText),
          document_id: "transaction-image-deleted",
          operation: "UPDATE",
          data: JSON.stringify({ title: "カフェ", amount: 520, sourceImageObjectKey: null }),
          old_data: JSON.stringify({
            title: "カフェ",
            amount: 520,
            sourceImageObjectKey: "users/uid-audit-convert/11111111-2222-4333-8444-555555555555.png",
          }),
        },
        {
          timestamp: toBigQueryTimestampValue(occurredAtText),
          document_id: "transaction-deleted",
          operation: "DELETE",
          data: null,
          old_data: JSON.stringify({ title: "書店", amount: 1980 }),
        },
        {
          timestamp: toBigQueryTimestampValue(occurredAtText),
          document_id: "transaction-broken",
          operation: "UPDATE",
          data: "{ 壊れた JSON",
          old_data: JSON.stringify({ title: "壊れた行", amount: 100 }),
        },
      ]),
    });
    interceptBigQueryQuery({ responseBody: buildImageDeletionLogQueryResponse([]) });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-convert" }),
      buildAuditLogEnv({ serviceAccountName: "convert" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      auditLogs: [
        {
          occurredAt: occurredAtText,
          operation: "transactionCreated",
          transactionID: "transaction-created",
          transactionTitle: "スーパーマーケット",
          transactionAmount: 3480,
          changedFieldNames: [],
        },
        {
          occurredAt: occurredAtText,
          operation: "transactionUpdated",
          transactionID: "transaction-updated",
          transactionTitle: "スーパーマーケット",
          transactionAmount: 3480,
          // 値が同じ配列フィールドは変更に数えず、更新のたびに変わるタイムスタンプ系メタフィールドは除外する
          changedFieldNames: ["excludedFromAggregation"],
        },
        {
          occurredAt: occurredAtText,
          operation: "transactionImageDeleted",
          transactionID: "transaction-image-deleted",
          transactionTitle: "カフェ",
          transactionAmount: 520,
          changedFieldNames: ["sourceImageObjectKey"],
        },
        {
          occurredAt: occurredAtText,
          operation: "transactionDeleted",
          transactionID: "transaction-deleted",
          // 削除は変更後のドキュメントが無いため、削除直前の内容を表示に使う
          transactionTitle: "書店",
          transactionAmount: 1980,
          changedFieldNames: [],
        },
        {
          occurredAt: occurredAtText,
          operation: "transactionUpdated",
          transactionID: "transaction-broken",
          transactionTitle: null,
          transactionAmount: null,
          changedFieldNames: [],
        },
      ],
    });
  });

  it("無料プランのクエリは直近数ヶ月の月初 (UTC) で絞り込む", async () => {
    interceptGoogleAccessToken();
    const capturedQueryRequests = interceptBigQueryQuery({ responseBody: buildChangelogQueryResponse([]) });
    const capturedImageDeletionQueryRequests = interceptBigQueryQuery({
      responseBody: buildImageDeletionLogQueryResponse([]),
    });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-free" }),
      buildAuditLogEnv({ serviceAccountName: "free-plan" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedQueryRequests[0].query).toContain("AND timestamp >= @oldestTimestamp");
    const oldestFreePlanTimestampParameter = {
      name: "oldestTimestamp",
      parameterType: { type: "TIMESTAMP" },
      parameterValue: {
        value: new Date(
          Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - (freePlanAuditLogHistoryMonthCount - 1), 1),
        ).toISOString(),
      },
    };
    // uid はクライアント申告ではなく検証済み token の uid で、SQL への埋め込みではなくパラメータで渡す
    expect(capturedQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: "uid-audit-free" } },
      oldestFreePlanTimestampParameter,
    ]);
    // 画像削除の履歴 (image_deletion_logs) にも同じユーザー・同じ期間の下限を適用する
    expect(capturedImageDeletionQueryRequests[0].query).toContain("AND deleted_at >= @oldestTimestamp");
    expect(capturedImageDeletionQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: "uid-audit-free" } },
      oldestFreePlanTimestampParameter,
    ]);
  });

  it("changelog と image_deletion_logs の履歴を時刻の新しい順に統合して返す", async () => {
    interceptGoogleAccessToken();
    interceptBigQueryQuery({
      responseBody: buildChangelogQueryResponse([
        {
          timestamp: toBigQueryTimestampValue("2026-08-23T03:00:00.000Z"),
          document_id: "transaction-newest",
          operation: "CREATE",
          data: JSON.stringify({ title: "カフェ", amount: 520 }),
          old_data: null,
        },
        {
          timestamp: toBigQueryTimestampValue("2026-08-23T01:00:00.000Z"),
          document_id: "transaction-oldest",
          operation: "DELETE",
          data: null,
          old_data: JSON.stringify({ title: "書店", amount: 1980 }),
        },
      ]),
    });
    interceptBigQueryQuery({
      responseBody: buildImageDeletionLogQueryResponse([
        {
          image_object_key: "users/uid-audit-merge/11111111-2222-4333-8444-555555555555.png",
          deleted_at: toBigQueryTimestampValue("2026-08-23T02:00:00.000Z"),
        },
      ]),
    });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-merge" }),
      buildAuditLogEnv({ serviceAccountName: "merge" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect((await response.json()) as { auditLogs: unknown[] }).toEqual({
      auditLogs: [
        {
          occurredAt: "2026-08-23T03:00:00.000Z",
          operation: "transactionCreated",
          transactionID: "transaction-newest",
          transactionTitle: "カフェ",
          transactionAmount: 520,
          changedFieldNames: [],
        },
        {
          occurredAt: "2026-08-23T02:00:00.000Z",
          operation: "transactionImageDeleted",
          // 画像削除は明細のドキュメントに紐付かないため、明細の情報を持たない
          transactionID: "",
          transactionTitle: null,
          transactionAmount: null,
          changedFieldNames: [],
        },
        {
          occurredAt: "2026-08-23T01:00:00.000Z",
          operation: "transactionDeleted",
          transactionID: "transaction-oldest",
          transactionTitle: "書店",
          transactionAmount: 1980,
          changedFieldNames: [],
        },
      ],
    });
  });

  it("image_deletion_logs テーブルがまだ無い環境 (404) でも明細の履歴を返す", async () => {
    interceptGoogleAccessToken();
    interceptBigQueryQuery({
      responseBody: buildChangelogQueryResponse([
        {
          timestamp: toBigQueryTimestampValue("2026-08-23T01:00:00.000Z"),
          document_id: "transaction-created",
          operation: "CREATE",
          data: JSON.stringify({ title: "カフェ", amount: 520 }),
          old_data: null,
        },
      ]),
    });
    // テーブルは最初の画像削除の記録時に作られるため、それまでは Not found (404) になる
    interceptBigQueryQuery({ responseBody: { error: { message: "Not found: Table" } }, status: 404 });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-no-image-table" }),
      buildAuditLogEnv({ serviceAccountName: "no-image-table" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(((await response.json()) as { auditLogs: unknown[] }).auditLogs).toHaveLength(1);
  });

  it("プレミアム entitlement を持つユーザーのクエリは期間で絞り込まない", async () => {
    const uid = "uid-audit-premium";
    fetchMock
      .get(revenueCatApiOrigin)
      .intercept({
        path: `/v2/projects/${env.REVENUECAT_PROJECT_ID}/customers/${uid}/active_entitlements`,
        method: "GET",
      })
      .reply(
        200,
        JSON.stringify({
          object: "list",
          items: [
            {
              object: "customer.active_entitlement",
              entitlement_id: env.REVENUECAT_PREMIUM_ENTITLEMENT_ID,
              expires_at: 4102444800000,
            },
          ],
        }),
      );
    interceptGoogleAccessToken();
    const capturedQueryRequests = interceptBigQueryQuery({ responseBody: buildChangelogQueryResponse([]) });
    const capturedImageDeletionQueryRequests = interceptBigQueryQuery({
      responseBody: buildImageDeletionLogQueryResponse([]),
    });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid }),
      buildAuditLogEnv({ serviceAccountName: "premium-plan", revenueCatConfigured: true }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedQueryRequests[0].query).not.toContain("@oldestTimestamp");
    expect(capturedQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } },
    ]);
    expect(capturedImageDeletionQueryRequests[0].query).not.toContain("@oldestTimestamp");
  });

  it("uid の日次取得回数が上限に達している場合は 429 を返し、BigQuery を呼ばない", async () => {
    const uid = "uid-audit-limit";
    await seedDailyCount(`auditlogs:uid:${uid}`, maxDailyAuditLogCountPerUser);

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid }),
      buildAuditLogEnv({ serviceAccountName: "daily-limit" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(429);
  });

  it("BigQuery がエラーを返した場合は 502 を返す", async () => {
    interceptGoogleAccessToken();
    interceptBigQueryQuery({ responseBody: { error: { message: "Access Denied" } }, status: 403 });

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-bigquery-error" }),
      buildAuditLogEnv({ serviceAccountName: "bigquery-error" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(502);
    // BigQuery のエラー本文 (テーブル名等の内部情報を含み得る) はクライアントへ返さず、status だけを返す
    const responseBody = (await response.json()) as { error: string };
    expect(responseBody.error).toContain("status=403");
    expect(responseBody.error).not.toContain("Access Denied");
  });
});

describe("画像削除の監査ログ記録 (DELETE /images)", () => {
  /** 画像 1 件の削除、または uid 配下の全消去のリクエスト。 */
  function buildImageDeleteRequest({ uid, imageObjectKey }: { uid: string; imageObjectKey?: string }): Request {
    return new Request(`${workerBaseUrl}/images${imageObjectKey === undefined ? "" : `/${imageObjectKey}`}`, {
      method: "DELETE",
      headers: {
        Authorization: `Bearer valid-token-${uid}`,
        [firebaseAppCheckHeaderName]: validAppCheckToken,
      },
    });
  }

  it("画像 1 件の削除で uid とオブジェクトキーを記録する", async () => {
    const uid = "uid-image-deletion-single";
    const imageObjectKey = `users/${uid}/11111111-2222-4333-8444-555555555555.png`;
    interceptGoogleAccessToken();
    const capturedInsertRequests = interceptImageDeletionLogInsert();

    const response = await handleImageRequest(
      buildImageDeleteRequest({ uid, imageObjectKey }),
      buildAuditLogEnv({ serviceAccountName: "image-deletion-single" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedInsertRequests[0].rows).toHaveLength(1);
    expect(capturedInsertRequests[0].rows?.[0].json.uid).toBe(uid);
    expect(capturedInsertRequests[0].rows?.[0].json.image_object_key).toBe(imageObjectKey);
    // 削除時刻は端末時計ではなく Worker の時刻で記録する
    expect(Date.parse(capturedInsertRequests[0].rows?.[0].json.deleted_at ?? "")).not.toBeNaN();
  });

  it("全消去はオブジェクトキーを持たない 1 行として記録する", async () => {
    const uid = "uid-image-deletion-all";
    interceptGoogleAccessToken();
    const capturedInsertRequests = interceptImageDeletionLogInsert();

    const response = await handleImageRequest(
      buildImageDeleteRequest({ uid }),
      buildAuditLogEnv({ serviceAccountName: "image-deletion-all" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedInsertRequests[0].rows?.[0].json).toMatchObject({ uid, image_object_key: null });
  });

  it("テーブルが無い環境 (404) ではテーブルを作ってから記録し直す", async () => {
    const uid = "uid-image-deletion-create-table";
    interceptGoogleAccessToken();
    interceptImageDeletionLogInsert({ status: 404 });
    const capturedCreateTableRequests = interceptImageDeletionLogTableCreate();
    const capturedInsertRequests = interceptImageDeletionLogInsert();

    const response = await handleImageRequest(
      buildImageDeleteRequest({ uid, imageObjectKey: `users/${uid}/11111111-2222-4333-8444-555555555555.png` }),
      buildAuditLogEnv({ serviceAccountName: "image-deletion-create-table" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedCreateTableRequests[0].tableReference?.tableId).toBe("image_deletion_logs");
    expect(capturedInsertRequests[0].rows?.[0].json.uid).toBe(uid);
  });

  it("記録に失敗しても画像の削除は成功として返す (ベストエフォート)", async () => {
    const uid = "uid-image-deletion-insert-error";
    interceptGoogleAccessToken();
    // 500 はテーブルの有無と関係ない BigQuery 側の障害。テーブル作成へは回さず、記録だけを諦める
    interceptImageDeletionLogInsert({ status: 500 });

    const response = await handleImageRequest(
      buildImageDeleteRequest({ uid, imageObjectKey: `users/${uid}/11111111-2222-4333-8444-555555555555.png` }),
      buildAuditLogEnv({ serviceAccountName: "image-deletion-insert-error" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
  });

  it("他人の uid 配下のキーの削除 (403) は記録しない", async () => {
    const response = await handleImageRequest(
      buildImageDeleteRequest({
        uid: "uid-image-deletion-forbidden",
        imageObjectKey: "users/uid-image-deletion-other/11111111-2222-4333-8444-555555555555.png",
      }),
      buildAuditLogEnv({ serviceAccountName: "image-deletion-forbidden" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(403);
  });
});

describe("パージ予約 (DELETE /audit-logs)", () => {
  it("パージを予約して 202 を返し、再実行しても 202 のまま予約が 1 件に収束する (冪等)", async () => {
    const uid = "uid-audit-purge-register";
    const auditLogEnv = buildAuditLogEnv({ serviceAccountName: "purge-register" });

    const firstResponse = await handleImageRequest(
      buildAuditLogsRequest({ uid, method: "DELETE" }),
      auditLogEnv,
      stubTokenVerifiers,
    );
    expect(firstResponse.status).toBe(202);
    const firstPurgeRequestedAt = await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`);
    expect(firstPurgeRequestedAt).not.toBeNull();
    expect(((await firstResponse.json()) as { purgeRequestedAt: string }).purgeRequestedAt).toBe(firstPurgeRequestedAt);

    const retryResponse = await handleImageRequest(
      buildAuditLogsRequest({ uid, method: "DELETE" }),
      auditLogEnv,
      stubTokenVerifiers,
    );
    expect(retryResponse.status).toBe(202);
    expect((await env.PUBLIC_JWK_CACHE_KV.list({ prefix: "audit-log-purge:" })).keys.map((key) => key.name)).toEqual([
      `audit-log-purge:${uid}`,
    ]);
  });

  it("Authorization ヘッダーなしの DELETE を 401 で拒否し、予約しない", async () => {
    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-purge-unauthorized", method: "DELETE", authorizationHeader: null }),
      buildAuditLogEnv({ serviceAccountName: "purge-unauthorized" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(401);
    expect((await env.PUBLIC_JWK_CACHE_KV.list({ prefix: "audit-log-purge:" })).keys).toHaveLength(0);
  });
});

describe("予約済みパージの実行 (scheduled)", () => {
  const scheduledController = { scheduledTime: Date.now(), cron: "0 * * * *", noRetry: () => {} } as ScheduledController;

  /** 指定した時間だけ過去に登録されたパージ予約を作る。 */
  async function seedPurgeRequest(uid: string, registeredAtMillisecondsAgo: number): Promise<void> {
    await env.PUBLIC_JWK_CACHE_KV.put(
      `audit-log-purge:${uid}`,
      new Date(Date.now() - registeredAtMillisecondsAgo).toISOString(),
    );
  }

  function runScheduled(auditLogEnv: ImageWorkerEnv): Promise<void> {
    return workerEntrypoint.scheduled(scheduledController, {
      ...auditLogEnv,
      FIREBASE_AUTH_EMULATOR_HOST: undefined,
    });
  }

  it("待ち時間を過ぎた予約は 2 つのテーブルへ DELETE の DML を実行するが、猶予期間中は予約が残る", async () => {
    const uid = "uid-audit-purge-retained";
    await seedPurgeRequest(uid, auditLogPurgeMinimumWaitMilliseconds + 60_000);
    interceptGoogleAccessToken();
    const capturedLookupRequests = interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: false });
    const capturedQueryRequests = interceptBigQueryQuery({ responseBody: { jobComplete: true } });
    const capturedImageDeletionQueryRequests = interceptBigQueryQuery({ responseBody: { jobComplete: true } });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-retained" }));

    // パージ前に、その uid の Firebase Auth アカウントが消えていることをサーバー側で確かめる
    expect(capturedLookupRequests[0].localId).toEqual([uid]);
    expect(capturedQueryRequests[0].query).toContain("DELETE FROM");
    expect(capturedQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } },
    ]);
    // 画像削除の履歴 (image_deletion_logs) も同じ uid で消す
    expect(capturedImageDeletionQueryRequests[0].query).toContain("image_deletion_logs");
    expect(capturedImageDeletionQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } },
    ]);
    // 最初の DML より後に届いた削除イベントを消し切るため、猶予期間が過ぎるまでは毎時の実行を続ける
    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).not.toBeNull();
  });

  it("猶予期間を過ぎた予約は DML の成功で予約が消える", async () => {
    const uid = "uid-audit-purge-done";
    await seedPurgeRequest(uid, auditLogPurgeRequestRetentionMilliseconds + 60_000);
    interceptGoogleAccessToken();
    interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: false });
    const capturedQueryRequests = interceptBigQueryQuery({ responseBody: { jobComplete: true } });
    interceptBigQueryQuery({ responseBody: { jobComplete: true } });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-done" }));

    expect(capturedQueryRequests[0].query).toContain("DELETE FROM");
    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).toBeNull();
  });

  it("Firebase Auth のアカウントが残っている予約は DML を実行せず、予約を残す", async () => {
    const uid = "uid-audit-purge-account-alive";
    await seedPurgeRequest(uid, auditLogPurgeRequestRetentionMilliseconds + 60_000);
    interceptGoogleAccessToken();
    // 有効な token を持つ利用中のユーザーが DELETE /audit-logs を直接呼んだ状況
    interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: true });
    // BigQuery の interceptor を置かないため、DML を試みればその失敗が警告に残る。
    // 「実行しなかった」ことを「実行して失敗した」と取り違えないよう、警告の有無まで見る
    const consoleWarnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-account-alive" }));

    expect(consoleWarnSpy.mock.calls.flat().join(" ")).not.toContain("監査ログのパージに失敗");
    consoleWarnSpy.mockRestore();
    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).not.toBeNull();
  });

  it("アカウントが残ったまま予約の期限を過ぎた予約は、履歴を消さずに予約だけが消える", async () => {
    const uid = "uid-audit-purge-abandoned";
    await seedPurgeRequest(uid, auditLogPurgeAbandonedRequestExpiryMilliseconds + 60_000);
    interceptGoogleAccessToken();
    interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: true });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-abandoned" }));

    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).toBeNull();
  });

  it("アカウント削除の確認に失敗した予約は DML を実行せず、次回の実行で再試行できる", async () => {
    const uid = "uid-audit-purge-lookup-failed";
    await seedPurgeRequest(uid, auditLogPurgeRequestRetentionMilliseconds + 60_000);
    interceptGoogleAccessToken();
    interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: false, status: 503 });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-lookup-failed" }));

    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).not.toBeNull();
  });

  it("DML に失敗した予約は猶予期間を過ぎていても残り、次回の実行で再試行できる", async () => {
    const uid = "uid-audit-purge-failed";
    await seedPurgeRequest(uid, auditLogPurgeRequestRetentionMilliseconds + 60_000);
    interceptGoogleAccessToken();
    interceptFirebaseAuthAccountsLookup({ firebaseAuthUserExists: false });
    // ストリーミングバッファ中の行を DML で消せない時に BigQuery が返すエラーに相当する
    interceptBigQueryQuery({ responseBody: { error: { message: "streaming buffer" } }, status: 400 });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-failed" }));

    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).not.toBeNull();
  });

  it("待ち時間に満たない予約はスキップし、BigQuery を呼ばない", async () => {
    const uid = "uid-audit-purge-waiting";
    await seedPurgeRequest(uid, auditLogPurgeMinimumWaitMilliseconds - 60_000);

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-waiting" }));

    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).not.toBeNull();
  });
});
