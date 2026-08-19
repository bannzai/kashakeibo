// app_check.ts の App Check token 検証のテスト。
// テスト内で生成した RSA 鍵で署名した JWT と、その公開鍵を返すスタブ JWKS 配信で、
// Firebase Admin SDK と同じ検証手順 (alg / iss / aud / sub / exp / iat / 署名) と KV キャッシュの挙動を検証する。
// KV は vitest-pool-workers (miniflare) の実 binding を使う。
import { env } from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import { createFirebaseAppCheckTokenVerifier } from "../src/app_check";
import type { ImageWorkerEnv } from "../src/handler";

declare module "cloudflare:test" {
  interface ProvidedEnv extends ImageWorkerEnv {}
}

const testFirebaseProjectId = "kashakeibo-test";
const testAppId = "1:000000000000:ios:0123456789abcdef";
const testKid = "test-kid";
const currentUnixSeconds = 1_800_000_000;

const rs256Algorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };

let signingKeyPair: CryptoKeyPair;
let otherKeyPair: CryptoKeyPair;
let publicJwks: JsonWebKey[];

beforeAll(async () => {
  signingKeyPair = await generateRsaKeyPair();
  otherKeyPair = await generateRsaKeyPair();
  const signingPublicJwk = await crypto.subtle.exportKey("jwk", signingKeyPair.publicKey);
  publicJwks = [{ ...signingPublicJwk, kid: testKid, use: "sig", alg: "RS256" }];
});

async function generateRsaKeyPair(): Promise<CryptoKeyPair> {
  return (await crypto.subtle.generateKey(
    { ...rs256Algorithm, modulusLength: 2048, publicExponent: new Uint8Array([0x01, 0x00, 0x01]) },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
}

function encodeBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function encodeBase64UrlJson(value: unknown): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

// 正常な App Check token を基準に、header / payload の一部を上書きした JWT を署名して返す
async function signAppCheckToken({
  headerOverrides = {},
  payloadOverrides = {},
  privateKey = signingKeyPair.privateKey,
}: {
  headerOverrides?: Record<string, unknown>;
  payloadOverrides?: Record<string, unknown>;
  privateKey?: CryptoKey;
} = {}): Promise<string> {
  const header = { alg: "RS256", typ: "JWT", kid: testKid, ...headerOverrides };
  const payload = {
    iss: "https://firebaseappcheck.googleapis.com/000000000000",
    aud: ["projects/000000000000", `projects/${testFirebaseProjectId}`],
    sub: testAppId,
    provider: "debug",
    iat: currentUnixSeconds - 60,
    exp: currentUnixSeconds + 3600,
    ...payloadOverrides,
  };
  const signingInput = `${encodeBase64UrlJson(header)}.${encodeBase64UrlJson(payload)}`;
  const signature = await crypto.subtle.sign(rs256Algorithm, privateKey, new TextEncoder().encode(signingInput));
  return `${signingInput}.${encodeBase64Url(new Uint8Array(signature))}`;
}

// スタブ JWKS 配信。呼び出し回数を数えて KV キャッシュの効き方を検証する
function createJwksFetcher(jwks: () => JsonWebKey[] = () => publicJwks) {
  const fetcher = {
    callCount: 0,
    fetchJwks: async () => {
      fetcher.callCount++;
      return new Response(JSON.stringify({ keys: jwks() }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=21600" },
      });
    },
  };
  return fetcher;
}

function createVerifier(fetcher = createJwksFetcher(), cacheKey = env.APP_CHECK_JWKS_CACHE_KEY) {
  return createFirebaseAppCheckTokenVerifier({
    firebaseProjectId: testFirebaseProjectId,
    jwksCache: { kvNamespace: env.PUBLIC_JWK_CACHE_KV, cacheKey },
    dependencies: { fetchJwks: fetcher.fetchJwks, currentUnixSeconds: () => currentUnixSeconds },
  });
}

describe("App Check token の検証", () => {
  it("有効な token を受理し、sub の App ID を返す", async () => {
    const verifiedFirebaseApp = await createVerifier()(await signAppCheckToken());
    expect(verifiedFirebaseApp.appId).toBe(testAppId);
  });

  it("3パートの JWT でない文字列を拒否する", async () => {
    const verifyFirebaseAppCheckToken = createVerifier();
    await expect(verifyFirebaseAppCheckToken("not-a-jwt")).rejects.toThrow();
    await expect(verifyFirebaseAppCheckToken("a.b")).rejects.toThrow();
    await expect(verifyFirebaseAppCheckToken("!!!.!!!.!!!")).rejects.toThrow();
  });

  it("alg が RS256 以外の token を拒否する (alg=none / HS256 の署名すり替えを防ぐ)", async () => {
    const verifyFirebaseAppCheckToken = createVerifier();
    await expect(
      verifyFirebaseAppCheckToken(await signAppCheckToken({ headerOverrides: { alg: "none" } })),
    ).rejects.toThrow();
    await expect(
      verifyFirebaseAppCheckToken(await signAppCheckToken({ headerOverrides: { alg: "HS256" } })),
    ).rejects.toThrow();
  });

  it("iss が App Check の発行者でない token を拒否する", async () => {
    await expect(
      createVerifier()(
        await signAppCheckToken({ payloadOverrides: { iss: "https://securetoken.google.com/kashakeibo-test" } }),
      ),
    ).rejects.toThrow();
  });

  it("aud に自プロジェクトを含まない token (別プロジェクト向け) を拒否する", async () => {
    const verifyFirebaseAppCheckToken = createVerifier();
    await expect(
      verifyFirebaseAppCheckToken(
        await signAppCheckToken({ payloadOverrides: { aud: ["projects/999999999999", "projects/other-project"] } }),
      ),
    ).rejects.toThrow();
    // aud が文字列 (配列でない) の場合も拒否する
    await expect(
      verifyFirebaseAppCheckToken(await signAppCheckToken({ payloadOverrides: { aud: `projects/${testFirebaseProjectId}` } })),
    ).rejects.toThrow();
  });

  it("sub (App ID) が空の token を拒否する", async () => {
    await expect(createVerifier()(await signAppCheckToken({ payloadOverrides: { sub: "" } }))).rejects.toThrow();
  });

  it("有効期限切れ・iat が未来の token を拒否する", async () => {
    const verifyFirebaseAppCheckToken = createVerifier();
    await expect(
      verifyFirebaseAppCheckToken(await signAppCheckToken({ payloadOverrides: { exp: currentUnixSeconds - 1 } })),
    ).rejects.toThrow();
    await expect(
      verifyFirebaseAppCheckToken(await signAppCheckToken({ payloadOverrides: { iat: currentUnixSeconds + 60 } })),
    ).rejects.toThrow();
  });

  it("別の鍵で署名された token (署名不正) を拒否する", async () => {
    await expect(createVerifier()(await signAppCheckToken({ privateKey: otherKeyPair.privateKey }))).rejects.toThrow();
  });

  it("ペイロード改ざん (署名と一致しない) を拒否する", async () => {
    const [encodedHeader, , encodedSignature] = (await signAppCheckToken()).split(".");
    const tamperedPayload = encodeBase64UrlJson({
      iss: "https://firebaseappcheck.googleapis.com/000000000000",
      aud: [`projects/${testFirebaseProjectId}`],
      sub: "1:000000000000:ios:tampered",
      iat: currentUnixSeconds - 60,
      exp: currentUnixSeconds + 3600,
    });
    await expect(createVerifier()(`${encodedHeader}.${tamperedPayload}.${encodedSignature}`)).rejects.toThrow();
  });

  it("JWKS に無い kid の token を拒否する", async () => {
    await expect(createVerifier()(await signAppCheckToken({ headerOverrides: { kid: "unknown-kid" } }))).rejects.toThrow();
  });

  it("JWKS を KV にキャッシュし、2回目以降の検証では取得しない", async () => {
    const jwksFetcher = createJwksFetcher();
    const verifyFirebaseAppCheckToken = createVerifier(jwksFetcher);
    await verifyFirebaseAppCheckToken(await signAppCheckToken());
    await verifyFirebaseAppCheckToken(await signAppCheckToken());
    expect(jwksFetcher.callCount).toBe(1);
    expect(await env.PUBLIC_JWK_CACHE_KV.get(env.APP_CHECK_JWKS_CACHE_KEY, "json")).toEqual(publicJwks);
  });

  it("キャッシュに無い kid はJWKS を取り直して検証する (鍵ローテーション)", async () => {
    // 古い JWKS (別鍵) がキャッシュされている状態から、新しい鍵で署名された token が来るケース
    const otherPublicJwk = { ...(await crypto.subtle.exportKey("jwk", otherKeyPair.publicKey)), kid: "old-kid" };
    await env.PUBLIC_JWK_CACHE_KV.put(env.APP_CHECK_JWKS_CACHE_KEY, JSON.stringify([otherPublicJwk]));
    const jwksFetcher = createJwksFetcher();
    const verifiedFirebaseApp = await createVerifier(jwksFetcher)(await signAppCheckToken());
    expect(verifiedFirebaseApp.appId).toBe(testAppId);
    expect(jwksFetcher.callCount).toBe(1);
  });

  it("JWKS の取得に失敗した場合は token を拒否する", async () => {
    const failingFetcher = {
      fetchJwks: async () => new Response("unavailable", { status: 503 }),
    };
    await expect(createVerifier(failingFetcher)(await signAppCheckToken())).rejects.toThrow();
  });
});
