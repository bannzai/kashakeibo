// Firebase App Check token の検証。
// firebase-auth-cloudflare-workers (2.0.6) は ID token / session cookie の検証だけを提供し
// App Check token の検証 API を持たない (JWT デコーダも "aud" を文字列に限定しており、
// App Check token の配列 "aud" を受け付けない) ため、Firebase Admin SDK の
// AppCheckTokenVerifier (firebase-admin-node/src/app-check/token-verifier.ts) と同じ手順を
// Web Crypto で実装している。公開鍵 (JWKS) は ID token の JWK と同じ Workers KV に別キーでキャッシュする。
//
// 検証手順 (Admin SDK と同一):
// 1. ヘッダー: alg が RS256、kid が文字列
// 2. ペイロード: iss が "https://firebaseappcheck.googleapis.com/" で始まる、
//    aud (配列) に "projects/{FIREBASE_PROJECT_ID}" を含む、sub (App ID) が空でない文字列、
//    exp が未来、iat が過去
// 3. 署名: JWKS (https://firebaseappcheck.googleapis.com/v1/jwks) の kid 一致鍵で RSASSA-PKCS1-v1_5 / SHA-256 検証
//
// App Check は「正規のアプリからのリクエストか」を判定するもので、ID token 検証 (誰のリクエストか) と
// 役割が異なるため両方を要求する。量の制限にはならないため、日次アップロード上限も併用する (handler.ts)。

/** App Check token の検証を通ったアプリ。 */
export interface VerifiedFirebaseApp {
  /** Firebase の App ID (token の sub claim)。 */
  appId: string;
}

// 検証失敗 (署名不正・期限切れ・別プロジェクト宛て等) は例外を throw する契約 (VerifyFirebaseIdToken と同じ)
export type VerifyFirebaseAppCheckToken = (firebaseAppCheckToken: string) => Promise<VerifiedFirebaseApp>;

/** Firebase App Check の公開鍵 (JWKS) 配信 URL。 */
export const firebaseAppCheckJwksUrl = "https://firebaseappcheck.googleapis.com/v1/jwks";

// App Check token の発行者プレフィックス。末尾にプロジェクト番号が付くが、Admin SDK と同様に
// プロジェクトの一致は aud (プロジェクト ID) で判定し、iss はプレフィックスだけを確認する
const firebaseAppCheckIssuerPrefix = "https://firebaseappcheck.googleapis.com/";

// JWKS の Cache-Control に max-age が無い場合のキャッシュ秒数 (実測の max-age=21600 と同じ 6 時間)。
// max-age がある場合はその値を優先し、60 秒未満なら KV に書かない (findPublicJwk 参照)
const defaultJwksCacheTtlSeconds = 21600;

// RSASSA-PKCS1-v1_5 / SHA-256 (RS256)
const rs256Algorithm: SubtleCryptoImportKeyAlgorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };

/** JWKS のキャッシュ先。 */
export interface FirebaseAppCheckJwksCache {
  /** キャッシュ用の KV。 */
  kvNamespace: KVNamespace;
  /** KV のキー名。ID token の JWK キャッシュ (PUBLIC_JWK_CACHE_KEY) と別のキーにする。 */
  cacheKey: string;
}

/** テストで差し替えるための依存。省略時は実 fetch と現在時刻を使う。 */
export interface FirebaseAppCheckTokenVerifierDependencies {
  /** JWKS を取得する fetch。 */
  fetchJwks?: () => Promise<Response>;
  /** 現在時刻 (Unix 秒)。 */
  currentUnixSeconds?: () => number;
}

/**
 * App Check token の検証器を組み立てる。
 * 検証器は token 文字列を受け取り、検証を通れば App ID を返し、失敗すれば例外を throw する。
 */
export function createFirebaseAppCheckTokenVerifier({
  firebaseProjectId,
  jwksCache,
  dependencies = {},
}: {
  firebaseProjectId: string;
  jwksCache: FirebaseAppCheckJwksCache;
  dependencies?: FirebaseAppCheckTokenVerifierDependencies;
}): VerifyFirebaseAppCheckToken {
  const fetchJwks = dependencies.fetchJwks ?? (() => fetch(firebaseAppCheckJwksUrl));
  const currentUnixSeconds = dependencies.currentUnixSeconds ?? (() => Math.floor(Date.now() / 1000));

  return async (firebaseAppCheckToken) => {
    const tokenParts = firebaseAppCheckToken.split(".");
    if (tokenParts.length !== 3) {
      throw new Error("App Check token は3パートの JWT である必要があります");
    }
    const [encodedHeader, encodedPayload, encodedSignature] = tokenParts;

    const header = decodeBase64UrlJson(encodedHeader);
    if (header === null || header.alg !== "RS256" || typeof header.kid !== "string") {
      throw new Error("App Check token のヘッダーが不正です (alg=RS256 と kid が必要)");
    }

    const payload = decodeBase64UrlJson(encodedPayload);
    if (payload === null) {
      throw new Error("App Check token のペイロードが不正です");
    }
    if (typeof payload.iss !== "string" || !payload.iss.startsWith(firebaseAppCheckIssuerPrefix)) {
      throw new Error(`App Check token の iss が不正です: ${String(payload.iss)}`);
    }
    if (!Array.isArray(payload.aud) || !payload.aud.includes(`projects/${firebaseProjectId}`)) {
      throw new Error(`App Check token の aud にプロジェクト ${firebaseProjectId} が含まれていません`);
    }
    if (typeof payload.sub !== "string" || payload.sub === "") {
      throw new Error("App Check token の sub (App ID) が空です");
    }
    const now = currentUnixSeconds();
    if (typeof payload.exp !== "number" || payload.exp <= now) {
      throw new Error("App Check token の有効期限が切れています");
    }
    if (typeof payload.iat !== "number" || payload.iat > now) {
      throw new Error("App Check token の iat が未来です");
    }

    const publicJwk = await findPublicJwk(header.kid, jwksCache, fetchJwks, now);
    if (publicJwk === null) {
      throw new Error(`App Check token の kid に一致する公開鍵がありません: ${header.kid}`);
    }
    const publicKey = await crypto.subtle.importKey("jwk", publicJwk, rs256Algorithm, false, ["verify"]);
    const isSignatureValid = await crypto.subtle.verify(
      rs256Algorithm,
      publicKey,
      decodeBase64Url(encodedSignature),
      new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
    );
    if (!isSignatureValid) {
      throw new Error("App Check token の署名が不正です");
    }
    return { appId: payload.sub };
  };
}

/** KV にキャッシュする JWKS。取得時刻は未知の kid による再取得の抑制に使う。 */
interface CachedFirebaseAppCheckJwks {
  /** JWKS の公開鍵一覧。 */
  keys: JsonWebKeyWithKid[];
  /** JWKS を取得した時刻 (Unix 秒)。 */
  fetchedAtUnixSeconds: number;
}

// キャッシュに無い kid を理由に JWKS を取り直す最短間隔 (秒)。
// App Check 検証は認証より前に行うため、正しい形式で未知の kid を持つ未署名 JWT を送るだけで
// 未認証のまま外部 fetch を誘発できる。取得時刻からこの秒数以内の再取得は行わず、
// リクエストごとの JWKS 取得 (Worker のサブリクエスト枠・Google 側への負荷) を colo あたり毎分1回に抑える。
// 正規の鍵ローテーションは新しい鍵が JWKS に事前公開されるため、この抑制で正規 token を弾くことは通常ない
const minJwksRefetchIntervalSeconds = 60;

// kid に一致する公開鍵を KV キャッシュから探し、無ければ JWKS を取り直して探す。
// 鍵のローテーション直後はキャッシュに新しい kid が無いため取り直すが、
// 直近 minJwksRefetchIntervalSeconds 以内に取得済みなら取り直さない (未知の kid による fetch 誘発の抑制)
async function findPublicJwk(
  kid: string,
  jwksCache: FirebaseAppCheckJwksCache,
  fetchJwks: () => Promise<Response>,
  now: number,
): Promise<JsonWebKeyWithKid | null> {
  const cachedJwks = await jwksCache.kvNamespace.get<CachedFirebaseAppCheckJwks>(jwksCache.cacheKey, "json");
  const cachedJwk = cachedJwks?.keys.find((jwk) => jwk.kid === kid);
  if (cachedJwk !== undefined) {
    return cachedJwk;
  }
  if (cachedJwks !== null && now - cachedJwks.fetchedAtUnixSeconds < minJwksRefetchIntervalSeconds) {
    return null;
  }

  const jwksResponse = await fetchJwks();
  if (!jwksResponse.ok) {
    throw new Error(`App Check の JWKS 取得に失敗しました: HTTP ${jwksResponse.status}`);
  }
  const jwksBody = (await jwksResponse.json()) as { keys?: unknown };
  if (!Array.isArray(jwksBody.keys)) {
    throw new Error("App Check の JWKS の形式が不正です (keys 配列がありません)");
  }
  const fetchedJwks = jwksBody.keys as JsonWebKeyWithKid[];
  const cacheTtlSeconds = parseCacheMaxAgeSeconds(jwksResponse.headers.get("Cache-Control")) ?? defaultJwksCacheTtlSeconds;
  // KV の expirationTtl は 60 秒以上が必要。Google が鍵の緊急ローテーション等で 60 秒未満の max-age を返した場合は、
  // 削除済みの鍵を既定 TTL で信頼し続けないよう KV に書かず、毎回取得する
  if (cacheTtlSeconds >= 60) {
    const cachedJwksToStore: CachedFirebaseAppCheckJwks = { keys: fetchedJwks, fetchedAtUnixSeconds: now };
    await jwksCache.kvNamespace.put(jwksCache.cacheKey, JSON.stringify(cachedJwksToStore), {
      expirationTtl: cacheTtlSeconds,
    });
  }
  return fetchedJwks.find((jwk) => jwk.kid === kid) ?? null;
}

// Cache-Control ヘッダーの max-age (秒) を返す。無い・数値でない場合は null
function parseCacheMaxAgeSeconds(cacheControlHeader: string | null): number | null {
  const maxAgeMatch = cacheControlHeader?.match(/(?:^|,)\s*max-age=(\d+)/i);
  return maxAgeMatch === null || maxAgeMatch === undefined ? null : Number(maxAgeMatch[1]);
}

function decodeBase64UrlJson(encodedText: string): Record<string, unknown> | null {
  try {
    const decodedJson: unknown = JSON.parse(new TextDecoder().decode(decodeBase64Url(encodedText)));
    return typeof decodedJson === "object" && decodedJson !== null ? (decodedJson as Record<string, unknown>) : null;
  } catch (error) {
    return null;
  }
}

function decodeBase64Url(encodedText: string): Uint8Array {
  const base64Text = encodedText.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(encodedText.length / 4) * 4, "=");
  const binaryText = atob(base64Text);
  const decodedBytes = new Uint8Array(binaryText.length);
  for (let byteIndex = 0; byteIndex < binaryText.length; byteIndex++) {
    decodedBytes[byteIndex] = binaryText.charCodeAt(byteIndex);
  }
  return decodedBytes;
}
