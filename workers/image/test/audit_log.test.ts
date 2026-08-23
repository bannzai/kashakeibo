// 監査ログ (GET /audit-logs・DELETE /audit-logs・毎時の scheduled パージ) のテスト。
// Firebase ID token / App Check token の検証は handler.test.ts と同じスタブ検証器で置き換え、
// KV と Durable Object は vitest-pool-workers (miniflare) の実 binding を使う。
// BigQuery と Google の token エンドポイントは fetchMock で応答を差し替え、
// JWT の署名はテスト内で生成した RSA 鍵を持つサービスアカウントキーで実際に通す。
import { env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import type { VerifyFirebaseAppCheckToken } from "../src/app_check";
import { auditLogPurgeMinimumWaitMilliseconds, freePlanAuditLogHistoryMonthCount } from "../src/audit_log";
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

    const response = await handleImageRequest(
      buildAuditLogsRequest({ uid: "uid-audit-free" }),
      buildAuditLogEnv({ serviceAccountName: "free-plan" }),
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(capturedQueryRequests[0].query).toContain("AND timestamp >= @oldestTimestamp");
    // uid はクライアント申告ではなく検証済み token の uid で、SQL への埋め込みではなくパラメータで渡す
    expect(capturedQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: "uid-audit-free" } },
      {
        name: "oldestTimestamp",
        parameterType: { type: "TIMESTAMP" },
        parameterValue: {
          value: new Date(
            Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - (freePlanAuditLogHistoryMonthCount - 1), 1),
          ).toISOString(),
        },
      },
    ]);
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

  /** 待ち時間を満たす (登録から 1 時間以上経過した) パージ予約を作る。 */
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

  it("待ち時間を過ぎた予約は DELETE の DML を実行して予約が消える", async () => {
    const uid = "uid-audit-purge-done";
    await seedPurgeRequest(uid, auditLogPurgeMinimumWaitMilliseconds + 60_000);
    interceptGoogleAccessToken();
    const capturedQueryRequests = interceptBigQueryQuery({ responseBody: { jobComplete: true } });

    await runScheduled(buildAuditLogEnv({ serviceAccountName: "purge-done" }));

    expect(capturedQueryRequests[0].query).toContain("DELETE FROM");
    expect(capturedQueryRequests[0].queryParameters).toEqual([
      { name: "uid", parameterType: { type: "STRING" }, parameterValue: { value: uid } },
    ]);
    expect(await env.PUBLIC_JWK_CACHE_KV.get(`audit-log-purge:${uid}`)).toBeNull();
  });

  it("DML に失敗した予約は残り、次回の実行で再試行できる", async () => {
    const uid = "uid-audit-purge-failed";
    await seedPurgeRequest(uid, auditLogPurgeMinimumWaitMilliseconds + 60_000);
    interceptGoogleAccessToken();
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
