// handler.ts の認可ロジックのテスト。
// Firebase ID token / App Check token の検証はスタブ検証器 (トークン文字列の固定対応) で置き換え、
// R2 / KV は vitest-pool-workers (miniflare) の実 binding を使う。Gemini API は fetchMock で応答を差し替える。
// 実際の Google JWK 検証 (firebase-auth-cloudflare-workers) はライブラリ側の責務のためここでは検証しない。
// App Check token の実際の JWT 検証は test/app_check.test.ts で検証する。
import { env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import type { VerifyFirebaseAppCheckToken } from "../src/app_check";
import type { ImageWorkerEnv, TokenVerifiers, VerifyFirebaseIdToken } from "../src/handler";
import {
  firebaseAppCheckHeaderName,
  handleImageRequest,
  maxDailyAnalysisCountPerUser,
  maxDailyUploadCountPerIpAddress,
  maxDailyUploadCountPerUser,
  maxDailyUploadCountTotal,
} from "../src/handler";

declare module "cloudflare:test" {
  interface ProvidedEnv extends ImageWorkerEnv {}
}

// スタブ検証器: "valid-token-<uid>" 形式のトークンだけを受理し uid を返す
const stubVerifyFirebaseIdToken: VerifyFirebaseIdToken = async (firebaseIdToken) => {
  const validTokenPrefix = "valid-token-";
  if (!firebaseIdToken.startsWith(validTokenPrefix)) {
    throw new Error("invalid token (stub)");
  }
  return { uid: firebaseIdToken.slice(validTokenPrefix.length) };
};

// スタブ App Check 検証器: "valid-app-check-token" だけを受理する
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

const testUploadId = "11111111-2222-4333-8444-555555555555";

function buildUploadRequest({
  authorizationHeader,
  fileContentType,
  fileBytes,
  uploadId = testUploadId,
  appCheckToken = validAppCheckToken,
}: {
  authorizationHeader: string | null;
  fileContentType: string;
  fileBytes: Uint8Array;
  uploadId?: string | null;
  appCheckToken?: string | null;
}): Request {
  const uploadFormData = new FormData();
  uploadFormData.append(
    "file",
    // クライアント申告のファイル名がキーに影響しないことを検証するため、パス風のファイル名を渡す
    new File([fileBytes], "../../users/other-uid/evil.png", { type: fileContentType }),
  );
  const requestHeaders = new Headers();
  if (authorizationHeader !== null) {
    requestHeaders.set("Authorization", authorizationHeader);
  }
  if (uploadId !== null) {
    requestHeaders.set("X-Upload-Id", uploadId);
  }
  if (appCheckToken !== null) {
    requestHeaders.set(firebaseAppCheckHeaderName, appCheckToken);
  }
  return new Request(`${workerBaseUrl}/images`, {
    method: "POST",
    headers: requestHeaders,
    body: uploadFormData,
  });
}

function buildGetRequest({
  authorizationHeader,
  imageObjectKey,
  appCheckToken = validAppCheckToken,
}: {
  authorizationHeader: string | null;
  imageObjectKey: string;
  appCheckToken?: string | null;
}): Request {
  const requestHeaders = new Headers();
  if (authorizationHeader !== null) {
    requestHeaders.set("Authorization", authorizationHeader);
  }
  if (appCheckToken !== null) {
    requestHeaders.set(firebaseAppCheckHeaderName, appCheckToken);
  }
  return new Request(`${workerBaseUrl}/images/${imageObjectKey}`, {
    method: "GET",
    headers: requestHeaders,
  });
}

const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);

// 指定カウンターだけを count 回まで加算する (他のカウンターの上限判定に影響を与えないよう単独条件で回す)
async function seedUploadCount(counterKey: string, count: number): Promise<void> {
  const dailyUploadCounter = env.DAILY_UPLOAD_COUNTER.get(
    env.DAILY_UPLOAD_COUNTER.idFromName(new Date().toISOString().slice(0, 10)),
  );
  for (let seededCount = 0; seededCount < count; seededCount++) {
    await dailyUploadCounter.incrementIfWithinLimits([
      { counterKey, maxDailyUploadCount: Number.MAX_SAFE_INTEGER },
    ]);
  }
}

describe("認証", () => {
  it("Authorization ヘッダーなしの POST を 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({ authorizationHeader: null, fileContentType: "image/png", fileBytes: pngBytes }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(401);
  });

  it("Authorization ヘッダーなしの GET を 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildGetRequest({ authorizationHeader: null, imageObjectKey: "users/uid-a/x.png" }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(401);
  });

  it("App Check token ヘッダーなしの POST / GET を 401 で拒否し、画像を保存しない", async () => {
    const uploadResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
        appCheckToken: null,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(uploadResponse.status).toBe(401);
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-a/" })).objects).toHaveLength(0);

    const getResponse = await handleImageRequest(
      buildGetRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        imageObjectKey: "users/uid-a/x.png",
        appCheckToken: null,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(getResponse.status).toBe(401);
  });

  it("検証に失敗する App Check token の POST / GET を、有効な ID token があっても 401 で拒否する", async () => {
    const uploadResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
        appCheckToken: "forged-app-check-token",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(uploadResponse.status).toBe(401);
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-a/" })).objects).toHaveLength(0);

    const getResponse = await handleImageRequest(
      buildGetRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        imageObjectKey: "users/uid-a/x.png",
        appCheckToken: "forged-app-check-token",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(getResponse.status).toBe(401);
  });

  it("有効な App Check token があっても Authorization ヘッダーが無い・不正なら 401 で拒否する (両方の検証が必要)", async () => {
    const responseWithoutAuthorization = await handleImageRequest(
      buildGetRequest({ authorizationHeader: null, imageObjectKey: "users/uid-a/x.png" }),
      env,
      stubTokenVerifiers,
    );
    expect(responseWithoutAuthorization.status).toBe(401);
    const responseWithBrokenIdToken = await handleImageRequest(
      buildGetRequest({ authorizationHeader: "Bearer broken-token", imageObjectKey: "users/uid-a/x.png" }),
      env,
      stubTokenVerifiers,
    );
    expect(responseWithBrokenIdToken.status).toBe(401);
  });

  it("検証に失敗するトークンを 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer broken-token",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(401);
  });
});

describe("アップロード", () => {
  it("オブジェクトキーを JWT の uid 配下に強制し、クライアント申告のファイル名を使わない", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(201);
    const { imageObjectKey } = (await response.json()) as { imageObjectKey: string };
    // ファイル名 "../../users/other-uid/evil.png" はキーに現れず、uid + X-Upload-Id + 拡張子のみで構成される
    expect(imageObjectKey).toBe(`users/uid-a/${testUploadId}.png`);
  });

  it("対応形式外の Content-Type を 415 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "application/pdf",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(415);
  });

  it("空のファイルを 400 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: new Uint8Array(0),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(400);
  });

  it("uid の日次アップロード回数が上限に達している場合は 429 を返し、他の uid には影響しない", async () => {
    await seedUploadCount(`uid:uid-a`, maxDailyUploadCountPerUser);
    const responseOfLimitedUser = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(responseOfLimitedUser.status).toBe(429);

    const responseOfOtherUser = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-b",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(responseOfOtherUser.status).toBe(201);
  });

  it("X-Upload-Id ヘッダーが無い・UUID 形式でないリクエストを 400 で拒否する", async () => {
    for (const invalidUploadId of [null, "../../users/uid-b/evil", "not-a-uuid"]) {
      const response = await handleImageRequest(
        buildUploadRequest({
          authorizationHeader: "Bearer valid-token-uid-a",
          fileContentType: "image/png",
          fileBytes: pngBytes,
          uploadId: invalidUploadId,
        }),
        env,
        stubTokenVerifiers,
      );
      expect(response.status, `uploadId=${invalidUploadId}`).toBe(400);
    }
  });

  it("同じ X-Upload-Id での再試行は同じオブジェクトキーに上書きされ、孤児オブジェクトを作らない", async () => {
    const firstResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    const retryResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    const { imageObjectKey: firstImageObjectKey } = (await firstResponse.json()) as { imageObjectKey: string };
    const { imageObjectKey: retryImageObjectKey } = (await retryResponse.json()) as { imageObjectKey: string };
    expect(retryResponse.status).toBe(201);
    expect(retryImageObjectKey).toBe(firstImageObjectKey);
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-a/" })).objects).toHaveLength(1);
  });

  it("接続元 IP の日次アップロード回数が上限に達している場合は 429 を返す", async () => {
    // buildUploadRequest は CF-Connecting-IP を付けないため "unknown" バケットで数えられる
    await seedUploadCount(`ip:unknown`, maxDailyUploadCountPerIpAddress);
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(429);
  });

  it("サービス全体の日次アップロード回数が上限に達している場合は 429 を返す", async () => {
    await seedUploadCount("total", maxDailyUploadCountTotal);
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(429);
  });

  it("保存済みキーへの再試行は上限に達していてもカウントを消費せず 201 を返す", async () => {
    // 上限の1件手前で最初のアップロードが成功し (これで上限到達)、201 が消失したと想定する
    await seedUploadCount("uid:uid-retry", maxDailyUploadCountPerUser - 1);
    const firstResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-retry",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(firstResponse.status).toBe(201);

    // 同じ X-Upload-Id の再試行は上限到達後でも 429 にならず、保存済みキーを回収できる
    const retryResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-retry",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(retryResponse.status).toBe(201);
    const { imageObjectKey: firstImageObjectKey } = (await firstResponse.json()) as { imageObjectKey: string };
    const { imageObjectKey: retryImageObjectKey } = (await retryResponse.json()) as { imageObjectKey: string };
    expect(retryImageObjectKey).toBe(firstImageObjectKey);
  });

  it("並行アップロードでも上限を超えて保存されない", async () => {
    await seedUploadCount("uid:uid-parallel", maxDailyUploadCountPerUser - 1);
    // 残り1枠に対して、異なる X-Upload-Id の並行リクエストを4本送る
    const parallelResponses = await Promise.all(
      ["aaaaaaaa-0000-4000-8000-000000000001", "aaaaaaaa-0000-4000-8000-000000000002", "aaaaaaaa-0000-4000-8000-000000000003", "aaaaaaaa-0000-4000-8000-000000000004"].map(
        (parallelUploadId) =>
          handleImageRequest(
            buildUploadRequest({
              authorizationHeader: "Bearer valid-token-uid-parallel",
              fileContentType: "image/png",
              fileBytes: pngBytes,
              uploadId: parallelUploadId,
            }),
            env,
            stubTokenVerifiers,
          ),
      ),
    );
    expect(parallelResponses.filter((response) => response.status === 201)).toHaveLength(1);
    expect(parallelResponses.filter((response) => response.status === 429)).toHaveLength(3);
  });

  it("file フィールドが無いリクエストを 400 で拒否する", async () => {
    const emptyFormData = new FormData();
    const response = await handleImageRequest(
      new Request(`${workerBaseUrl}/images`, {
        method: "POST",
        headers: {
          Authorization: "Bearer valid-token-uid-a",
          "X-Upload-Id": testUploadId,
          [firebaseAppCheckHeaderName]: validAppCheckToken,
        },
        body: emptyFormData,
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(400);
  });
});

describe("取得", () => {
  async function uploadImageAsUser(uid: string): Promise<string> {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: `Bearer valid-token-${uid}`,
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubTokenVerifiers,
    );
    const { imageObjectKey } = (await response.json()) as { imageObjectKey: string };
    return imageObjectKey;
  }

  it("本人はアップロードした画像を同じバイト列・Content-Type で取得できる", async () => {
    const imageObjectKey = await uploadImageAsUser("uid-a");
    const response = await handleImageRequest(
      buildGetRequest({ authorizationHeader: "Bearer valid-token-uid-a", imageObjectKey }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toBe("image/png");
    expect(new Uint8Array(await response.arrayBuffer())).toEqual(pngBytes);
  });

  it("他人の uid 配下のオブジェクトキーへのアクセスを 403 で拒否する", async () => {
    const imageObjectKeyOfUserA = await uploadImageAsUser("uid-a");
    const response = await handleImageRequest(
      buildGetRequest({ authorizationHeader: "Bearer valid-token-uid-b", imageObjectKey: imageObjectKeyOfUserA }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(403);
  });

  it("percent-encoding の `..` によるパストラバーサルで他人の uid 配下へ到達できない", async () => {
    // WHATWG URL のパス正規化は "%2E%2E" セグメントも ".." として collapse するため、
    // このリクエストのキーは "users/uid-b/x.png" になり、uid プレフィックス検査が 403 で拒否する
    const response = await handleImageRequest(
      buildGetRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        imageObjectKey: "users/uid-a/%2E%2E/uid-b/x.png",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(403);
  });

  it("不正な percent-encoding を含むキーを 400 で拒否する", async () => {
    const response = await handleImageRequest(
      buildGetRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        imageObjectKey: "users/uid-a/%GG.png",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(400);
  });

  it("存在しないオブジェクトキーは 404 を返す", async () => {
    const response = await handleImageRequest(
      buildGetRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        imageObjectKey: "users/uid-a/00000000-0000-0000-0000-000000000000.png",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(404);
  });
});

describe("アカウント削除時の全消去", () => {
  function buildDeleteAllRequest(authorizationHeader: string, appCheckToken: string | null = validAppCheckToken): Request {
    const requestHeaders = new Headers({ Authorization: authorizationHeader });
    if (appCheckToken !== null) {
      requestHeaders.set(firebaseAppCheckHeaderName, appCheckToken);
    }
    return new Request(`${workerBaseUrl}/images`, { method: "DELETE", headers: requestHeaders });
  }

  async function uploadImageWithUploadId(uid: string, uploadId: string): Promise<void> {
    await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: `Bearer valid-token-${uid}`,
        fileContentType: "image/png",
        fileBytes: pngBytes,
        uploadId,
      }),
      env,
      stubTokenVerifiers,
    );
  }

  it("本人の uid 配下の全オブジェクトを削除し、他人のオブジェクトには影響しない", async () => {
    await uploadImageWithUploadId("uid-delete-a", "bbbbbbbb-0000-4000-8000-000000000001");
    await uploadImageWithUploadId("uid-delete-a", "bbbbbbbb-0000-4000-8000-000000000002");
    await uploadImageWithUploadId("uid-delete-b", "bbbbbbbb-0000-4000-8000-000000000003");

    const deleteResponse = await handleImageRequest(
      buildDeleteAllRequest("Bearer valid-token-uid-delete-a"),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(200);
    expect(((await deleteResponse.json()) as { deletedImageCount: string }).deletedImageCount).toBe("2");
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-delete-a/" })).objects).toHaveLength(0);
    // 他人 (uid-delete-b) のオブジェクトは残る
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-delete-b/" })).objects).toHaveLength(1);
  });

  it("削除対象が無い場合も 200 を返す (冪等)", async () => {
    const deleteResponse = await handleImageRequest(
      buildDeleteAllRequest("Bearer valid-token-uid-delete-empty"),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(200);
    expect(((await deleteResponse.json()) as { deletedImageCount: string }).deletedImageCount).toBe("0");
  });

  it("Authorization ヘッダーなしの DELETE を 401 で拒否する", async () => {
    const deleteResponse = await handleImageRequest(
      new Request(`${workerBaseUrl}/images`, {
        method: "DELETE",
        headers: { [firebaseAppCheckHeaderName]: validAppCheckToken },
      }),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(401);
  });

  it("App Check token なし・不正な DELETE を 401 で拒否し、画像を削除しない", async () => {
    await uploadImageWithUploadId("uid-delete-app-check", "bbbbbbbb-0000-4000-8000-000000000004");
    for (const invalidAppCheckToken of [null, "forged-app-check-token"]) {
      const deleteResponse = await handleImageRequest(
        buildDeleteAllRequest("Bearer valid-token-uid-delete-app-check", invalidAppCheckToken),
        env,
        stubTokenVerifiers,
      );
      expect(deleteResponse.status, `appCheckToken=${invalidAppCheckToken}`).toBe(401);
    }
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-delete-app-check/" })).objects).toHaveLength(1);
  });
});

describe("画像 1 件の削除", () => {
  async function uploadImageWithUploadId(uid: string, uploadId: string): Promise<string> {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: `Bearer valid-token-${uid}`,
        fileContentType: "image/png",
        fileBytes: pngBytes,
        uploadId,
      }),
      env,
      stubTokenVerifiers,
    );
    return ((await response.json()) as { imageObjectKey: string }).imageObjectKey;
  }

  function buildDeleteRequest({
    authorizationHeader,
    imageObjectKey,
  }: {
    authorizationHeader: string;
    imageObjectKey: string;
  }): Request {
    return new Request(`${workerBaseUrl}/images/${imageObjectKey}`, {
      method: "DELETE",
      headers: { Authorization: authorizationHeader, [firebaseAppCheckHeaderName]: validAppCheckToken },
    });
  }

  it("本人の uid 配下のオブジェクトだけを削除し、同じ uid の他のオブジェクトは残す", async () => {
    const deletedKey = await uploadImageWithUploadId("uid-single-a", "cccccccc-0000-4000-8000-000000000001");
    const keptKey = await uploadImageWithUploadId("uid-single-a", "cccccccc-0000-4000-8000-000000000002");

    const deleteResponse = await handleImageRequest(
      buildDeleteRequest({ authorizationHeader: "Bearer valid-token-uid-single-a", imageObjectKey: deletedKey }),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(200);
    expect(await env.IMAGE_BUCKET.head(deletedKey)).toBeNull();
    expect(await env.IMAGE_BUCKET.head(keptKey)).not.toBeNull();
  });

  it("他人の uid 配下のオブジェクトキーの削除を 403 で拒否し、オブジェクトを残す", async () => {
    const imageObjectKeyOfUserA = await uploadImageWithUploadId("uid-single-a", "cccccccc-0000-4000-8000-000000000003");
    const deleteResponse = await handleImageRequest(
      buildDeleteRequest({ authorizationHeader: "Bearer valid-token-uid-single-b", imageObjectKey: imageObjectKeyOfUserA }),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(403);
    expect(await env.IMAGE_BUCKET.head(imageObjectKeyOfUserA)).not.toBeNull();
  });

  it("削除対象が無い場合も 200 を返す (冪等)", async () => {
    const deleteResponse = await handleImageRequest(
      buildDeleteRequest({
        authorizationHeader: "Bearer valid-token-uid-single-a",
        imageObjectKey: "users/uid-single-a/00000000-0000-0000-0000-000000000000.png",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(deleteResponse.status).toBe(200);
  });
});

describe("画像解析", () => {
  const geminiApiOrigin = "https://generativelanguage.googleapis.com";
  const geminiGenerateContentPath = `/v1beta/models/${env.GEMINI_MODEL}:generateContent`;

  beforeAll(() => {
    fetchMock.activate();
    // Gemini 以外への実通信を伴わないことを保証する
    fetchMock.disableNetConnect();
  });

  afterEach(() => {
    fetchMock.assertNoPendingInterceptors();
  });

  async function uploadImageWithUploadId(uid: string, uploadId: string): Promise<string> {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: `Bearer valid-token-${uid}`,
        fileContentType: "image/png",
        fileBytes: pngBytes,
        uploadId,
      }),
      env,
      stubTokenVerifiers,
    );
    return ((await response.json()) as { imageObjectKey: string }).imageObjectKey;
  }

  function buildAnalysisRequest({
    authorizationHeader,
    body,
  }: {
    authorizationHeader: string;
    body: string;
  }): Request {
    return new Request(`${workerBaseUrl}/analyses`, {
      method: "POST",
      headers: {
        Authorization: authorizationHeader,
        "Content-Type": "application/json",
        [firebaseAppCheckHeaderName]: validAppCheckToken,
      },
      body,
    });
  }

  // Gemini generateContent の応答 (candidates[0].content.parts[0].text に構造化出力の JSON 文字列) を組み立てる
  function buildGeminiResponseBody(outputJson: unknown): string {
    return JSON.stringify({
      candidates: [{ content: { role: "model", parts: [{ text: JSON.stringify(outputJson) }] } }],
    });
  }

  it("本人の画像を Gemini に渡し、抽出した明細を返す", async () => {
    const imageObjectKey = await uploadImageWithUploadId("uid-analysis-a", "dddddddd-0000-4000-8000-000000000001");
    let capturedGeminiRequest: { headers: Record<string, string>; body: string } | undefined;
    fetchMock
      .get(geminiApiOrigin)
      .intercept({ path: geminiGenerateContentPath, method: "POST" })
      .reply(200, (request) => {
        capturedGeminiRequest = { headers: request.headers as Record<string, string>, body: String(request.body) };
        return buildGeminiResponseBody({
          transactions: [
            { title: "セブンイレブン 三軒茶屋店", amount: 1234, transactionDate: "2026-08-16", type: "expense", category: "food" },
          ],
        });
      });

    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-a",
        body: JSON.stringify({ imageObjectKey }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      transactions: [
        { title: "セブンイレブン 三軒茶屋店", amount: 1234, transactionDate: "2026-08-16", type: "expense", category: "food" },
      ],
    });
    // API キーはヘッダーで渡し、画像は R2 のバイト列を base64 化して inline_data で渡す
    expect(capturedGeminiRequest?.headers["x-goog-api-key"]).toBe(env.GEMINI_API_KEY);
    const geminiRequestBody = JSON.parse(capturedGeminiRequest!.body) as {
      contents: { parts: { inline_data?: { mime_type: string; data: string } }[] }[];
      generationConfig: { responseMimeType: string };
    };
    expect(geminiRequestBody.contents[0].parts[0].inline_data).toEqual({
      mime_type: "image/png",
      data: btoa(String.fromCharCode(...pngBytes)),
    });
    expect(geminiRequestBody.generationConfig.responseMimeType).toBe("application/json");
  });

  it("Gemini の出力のうち不正な明細 (金額が正の整数でない・enum 外) を取り除き、不正な日付は null にする", async () => {
    const imageObjectKey = await uploadImageWithUploadId("uid-analysis-a", "dddddddd-0000-4000-8000-000000000002");
    fetchMock
      .get(geminiApiOrigin)
      .intercept({ path: geminiGenerateContentPath, method: "POST" })
      .reply(
        200,
        buildGeminiResponseBody({
          transactions: [
            { title: "  スーパー  ", amount: 980, transactionDate: "2026-02-30", type: "expense", category: "food" },
            { title: "金額なし", amount: 0, transactionDate: "2026-08-16", type: "expense", category: "food" },
            { title: "小数", amount: 12.5, transactionDate: "2026-08-16", type: "expense", category: "food" },
            { title: "未知カテゴリ", amount: 100, transactionDate: "2026-08-16", type: "expense", category: "travel" },
            { title: "未知種別", amount: 100, transactionDate: "2026-08-16", type: "transfer", category: "other" },
            { title: 42, amount: 500, transactionDate: "2026/08/16", type: "income", category: "salary" },
          ],
        }),
      );

    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-a",
        body: JSON.stringify({ imageObjectKey }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      transactions: [
        { title: "スーパー", amount: 980, transactionDate: null, type: "expense", category: "food" },
        { title: "", amount: 500, transactionDate: null, type: "income", category: "salary" },
      ],
    });
  });

  it("Gemini がエラーを返した場合は 502 とエラー本文を返す", async () => {
    const imageObjectKey = await uploadImageWithUploadId("uid-analysis-a", "dddddddd-0000-4000-8000-000000000003");
    fetchMock
      .get(geminiApiOrigin)
      .intercept({ path: geminiGenerateContentPath, method: "POST" })
      .reply(503, JSON.stringify({ error: { message: "The model is overloaded." } }));

    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-a",
        body: JSON.stringify({ imageObjectKey }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(502);
    expect(((await response.json()) as { error: string }).error).toContain("status=503");
  });

  it("他人の uid 配下のオブジェクトキーの解析を 403 で拒否し、Gemini を呼ばない", async () => {
    const imageObjectKeyOfUserA = await uploadImageWithUploadId("uid-analysis-a", "dddddddd-0000-4000-8000-000000000004");
    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-b",
        body: JSON.stringify({ imageObjectKey: imageObjectKeyOfUserA }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(403);
  });

  it("存在しないオブジェクトキーは 404 を返し、Gemini を呼ばない", async () => {
    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-a",
        body: JSON.stringify({ imageObjectKey: "users/uid-analysis-a/00000000-0000-0000-0000-000000000000.png" }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(404);
  });

  it("imageObjectKey の無いリクエスト・JSON でないリクエストを 400 で拒否する", async () => {
    const missingKeyResponse = await handleImageRequest(
      buildAnalysisRequest({ authorizationHeader: "Bearer valid-token-uid-analysis-a", body: JSON.stringify({}) }),
      env,
      stubTokenVerifiers,
    );
    expect(missingKeyResponse.status).toBe(400);

    const invalidJsonResponse = await handleImageRequest(
      buildAnalysisRequest({ authorizationHeader: "Bearer valid-token-uid-analysis-a", body: "not json" }),
      env,
      stubTokenVerifiers,
    );
    expect(invalidJsonResponse.status).toBe(400);
  });

  it("uid の日次解析回数が上限に達している場合は 429 を返し Gemini を呼ばない。アップロードの回数とは独立に数える", async () => {
    const imageObjectKey = await uploadImageWithUploadId("uid-analysis-limit", "dddddddd-0000-4000-8000-000000000005");
    await seedUploadCount("analysis:uid:uid-analysis-limit", maxDailyAnalysisCountPerUser);

    const response = await handleImageRequest(
      buildAnalysisRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-limit",
        body: JSON.stringify({ imageObjectKey }),
      }),
      env,
      stubTokenVerifiers,
    );
    expect(response.status).toBe(429);

    // 解析の上限に達していても、同じ uid のアップロードは別カウンターのため成功する
    const uploadResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-analysis-limit",
        fileContentType: "image/png",
        fileBytes: pngBytes,
        uploadId: "dddddddd-0000-4000-8000-000000000006",
      }),
      env,
      stubTokenVerifiers,
    );
    expect(uploadResponse.status).toBe(201);
  });
});
