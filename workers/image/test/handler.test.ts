// handler.ts の認可ロジックのテスト。
// Firebase ID token / App Check token の検証はスタブ検証器 (トークン文字列の固定対応) で置き換え、
// R2 / KV は vitest-pool-workers (miniflare) の実 binding を使う。
// 実際の Google JWK 検証 (firebase-auth-cloudflare-workers) はライブラリ側の責務のためここでは検証しない。
// App Check token の実際の JWT 検証は test/app_check.test.ts で検証する。
import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import type { VerifyFirebaseAppCheckToken } from "../src/app_check";
import type { ImageWorkerEnv, TokenVerifiers, VerifyFirebaseIdToken } from "../src/handler";
import {
  firebaseAppCheckHeaderName,
  handleImageRequest,
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
