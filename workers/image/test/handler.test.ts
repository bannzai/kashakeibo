// handler.ts の認可ロジックのテスト。
// Firebase ID token の検証はスタブ検証器 (トークン文字列 → uid の固定対応) で置き換え、
// R2 / KV は vitest-pool-workers (miniflare) の実 binding を使う。
// 実際の Google JWK 検証 (firebase-auth-cloudflare-workers) はライブラリ側の責務のためここでは検証しない。
import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import type { ImageWorkerEnv, VerifyFirebaseIdToken } from "../src/handler";
import {
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

const workerBaseUrl = "https://image-worker.test";

const testUploadId = "11111111-2222-4333-8444-555555555555";

function buildUploadRequest({
  authorizationHeader,
  fileContentType,
  fileBytes,
  uploadId = testUploadId,
}: {
  authorizationHeader: string | null;
  fileContentType: string;
  fileBytes: Uint8Array;
  uploadId?: string | null;
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
  return new Request(`${workerBaseUrl}/images`, {
    method: "POST",
    headers: requestHeaders,
    body: uploadFormData,
  });
}

function buildGetRequest({
  authorizationHeader,
  imageObjectKey,
}: {
  authorizationHeader: string | null;
  imageObjectKey: string;
}): Request {
  const requestHeaders = new Headers();
  if (authorizationHeader !== null) {
    requestHeaders.set("Authorization", authorizationHeader);
  }
  return new Request(`${workerBaseUrl}/images/${imageObjectKey}`, {
    method: "GET",
    headers: requestHeaders,
  });
}

const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);

describe("認証", () => {
  it("Authorization ヘッダーなしの POST を 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({ authorizationHeader: null, fileContentType: "image/png", fileBytes: pngBytes }),
      env,
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(401);
  });

  it("Authorization ヘッダーなしの GET を 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildGetRequest({ authorizationHeader: null, imageObjectKey: "users/uid-a/x.png" }),
      env,
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(401);
  });

  it("検証に失敗するトークンを 401 で拒否する", async () => {
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer broken-token",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(400);
  });

  it("uid の日次アップロード回数が上限に達している場合は 429 を返し、他の uid には影響しない", async () => {
    await env.PUBLIC_JWK_CACHE_KV.put(
      `upload-count:uid-a:${new Date().toISOString().slice(0, 10)}`,
      String(maxDailyUploadCountPerUser),
    );
    const responseOfLimitedUser = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
    );
    expect(responseOfLimitedUser.status).toBe(429);

    const responseOfOtherUser = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-b",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
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
        stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
    );
    const retryResponse = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
    );
    const { imageObjectKey: firstImageObjectKey } = (await firstResponse.json()) as { imageObjectKey: string };
    const { imageObjectKey: retryImageObjectKey } = (await retryResponse.json()) as { imageObjectKey: string };
    expect(retryResponse.status).toBe(201);
    expect(retryImageObjectKey).toBe(firstImageObjectKey);
    expect((await env.IMAGE_BUCKET.list({ prefix: "users/uid-a/" })).objects).toHaveLength(1);
  });

  it("接続元 IP の日次アップロード回数が上限に達している場合は 429 を返す", async () => {
    // buildUploadRequest は CF-Connecting-IP を付けないため "unknown" バケットで数えられる
    await env.PUBLIC_JWK_CACHE_KV.put(
      `upload-count:ip:unknown:${new Date().toISOString().slice(0, 10)}`,
      String(maxDailyUploadCountPerIpAddress),
    );
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(429);
  });

  it("サービス全体の日次アップロード回数が上限に達している場合は 429 を返す", async () => {
    await env.PUBLIC_JWK_CACHE_KV.put(
      `upload-count:total:${new Date().toISOString().slice(0, 10)}`,
      String(maxDailyUploadCountTotal),
    );
    const response = await handleImageRequest(
      buildUploadRequest({
        authorizationHeader: "Bearer valid-token-uid-a",
        fileContentType: "image/png",
        fileBytes: pngBytes,
      }),
      env,
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(429);
  });

  it("file フィールドが無いリクエストを 400 で拒否する", async () => {
    const emptyFormData = new FormData();
    const response = await handleImageRequest(
      new Request(`${workerBaseUrl}/images`, {
        method: "POST",
        headers: { Authorization: "Bearer valid-token-uid-a", "X-Upload-Id": testUploadId },
        body: emptyFormData,
      }),
      env,
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
    );
    const { imageObjectKey } = (await response.json()) as { imageObjectKey: string };
    return imageObjectKey;
  }

  it("本人はアップロードした画像を同じバイト列・Content-Type で取得できる", async () => {
    const imageObjectKey = await uploadImageAsUser("uid-a");
    const response = await handleImageRequest(
      buildGetRequest({ authorizationHeader: "Bearer valid-token-uid-a", imageObjectKey }),
      env,
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
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
      stubVerifyFirebaseIdToken,
    );
    expect(response.status).toBe(404);
  });
});
