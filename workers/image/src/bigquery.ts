// BigQuery REST API (jobs.query・tables.insert・tabledata.insertAll) の呼び出しと、
// Google API 共通の access token の取得。監査ログの読み取り (GET /audit-logs)・画像削除の記録・
// アカウント削除時のパージ DML (scheduled) と、そのパージ前に行う Firebase Auth のアカウント確認がここを通る。
// Cloudflare Workers では Google 公式のクライアントライブラリを使えないため、サービスアカウントの JSON キーから
// RS256 の JWT (WebCrypto) を作り、OAuth2 で access token に交換してから REST API を直接呼ぶ。
// サービスアカウントキーは Worker の secret (BIGQUERY_SERVICE_ACCOUNT_KEY) にだけ置き、クライアントへ配布しない。

/** サービスアカウントの JSON キーのうち、access token の取得に使う項目 (JSON デコード用)。 */
interface BigQueryServiceAccountKey {
  /** サービスアカウントのメールアドレス。JWT の iss になる。 */
  client_email?: unknown;
  /** PKCS#8 (PEM) の秘密鍵。JWT の RS256 署名に使う。 */
  private_key?: unknown;
}

/** BigQuery REST API の QueryParameter (jobs.query の queryParameters の要素)。 */
export interface BigQueryQueryParameter {
  /** SQL 中の `@name` に対応する名前。 */
  name: string;
  /** パラメータの型。 */
  parameterType: { type: "STRING" | "TIMESTAMP" };
  /** パラメータの値 (型に依らず文字列で渡す)。 */
  parameterValue: { value: string };
}

/** BigQuery REST API の QueryResponse のうち、本 Worker が読む項目。 */
export interface BigQueryQueryResponse {
  /** 結果のスキーマ。rows の f[] は fields[] と同じ順序で並ぶ。 */
  schema?: { fields?: { name?: string }[] };
  /** 結果行。値は列の型に依らず文字列 (TIMESTAMP は Unix 秒の小数文字列) か null。 */
  rows?: { f?: { v?: string | null }[] }[];
  /** timeoutMs 内にジョブが完了したかどうか。false の場合は結果が揃っていない。 */
  jobComplete?: boolean;
}

/** BigQuery の呼び出し失敗 (認証・HTTP エラー・ジョブのタイムアウト)。 */
export class BigQueryRequestError extends Error {
  /** 失敗した応答の HTTP status。HTTP 応答を伴わない失敗 (接続失敗・ジョブのタイムアウト) では undefined。 */
  readonly httpStatus: number | undefined;

  constructor(message: string, httpStatus?: number) {
    super(message);
    this.name = "BigQueryRequestError";
    this.httpStatus = httpStatus;
  }
}

const googleOAuthTokenUrl = "https://oauth2.googleapis.com/token";
const bigQueryApiBaseUrl = "https://bigquery.googleapis.com/bigquery/v2";

// access token に要求するスコープ。BigQuery は読み取り (SELECT)・DML・テーブル作成と streaming insert に、
// identitytoolkit は監査ログのパージ前に Firebase Auth のアカウント削除完了を確かめる accounts:lookup に必要。
// 1 本の token に両方のスコープを載せ、用途ごとに token を取り直さない
const googleApiOAuthScopes = [
  "https://www.googleapis.com/auth/bigquery",
  "https://www.googleapis.com/auth/identitytoolkit",
].join(" ");

// クエリを実行するロケーション。jobs.query はデータセットと同じロケーションを指定しないとテーブルを解決できないため、
// Stream Firestore to BigQuery extension を導入したロケーション (Firestore と同じ asia-northeast1) を固定で渡す
const bigQueryDatasetLocation = "asia-northeast1";

const rs256SigningAlgorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" } as const;

// JWT の有効期間。Google が service account JWT に許す上限が 1 時間で、交換して得る access token の寿命もこれに揃う
const serviceAccountJwtLifetimeSeconds = 3600;

// キャッシュした access token を失効扱いにする、実際の期限からの前倒し幅。
// 期限ぎりぎりの token を使って呼び出しの途中で失効し 401 になることを防ぐ余裕
const accessTokenExpiryMarginMilliseconds = 60_000;

// jobs.query にジョブの完了を待たせる時間。監査ログのクエリ (LIMIT 200) もパージの DML も通常は数秒で終わるため、
// 完了を待ちきって jobComplete: false (結果が揃わない応答) を受け取らずに済む値にしている
const bigQueryQueryTimeoutMilliseconds = 30_000;

// fetch 自体のタイムアウト。Workers の fetch サブリクエストには既定のタイムアウトが無く、
// BigQuery 側の応答遅延がリクエスト全体のハングに波及するのを防ぐ。
// ジョブの待ち時間 (bigQueryQueryTimeoutMilliseconds) に応答の転送ぶんの余裕を足した値
const bigQueryRequestTimeoutMilliseconds = 45_000;

// 取得済み access token のメモリキャッシュ (サービスアカウントのメールアドレスごと)。
// Worker インスタンスが生きている間だけ再利用し、リクエストごとの RS256 署名と token 交換を省く
const cachedGoogleApiAccessTokens = new Map<string, { accessToken: string; expiresAtMilliseconds: number }>();

/** バイト列を JWT が要求する base64url (パディング無し) にする。 */
function encodeBase64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** JWT のヘッダー・クレームを base64url の JSON にする。 */
function encodeBase64UrlJson(value: object): string {
  return encodeBase64Url(new TextEncoder().encode(JSON.stringify(value)));
}

/** PEM (PKCS#8) の秘密鍵を WebCrypto の署名鍵にする。 */
async function importServiceAccountPrivateKey(privateKeyPem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(
      atob(privateKeyPem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "")),
      (base64Character) => base64Character.charCodeAt(0),
    ),
    rs256SigningAlgorithm,
    false,
    ["sign"],
  );
}

/**
 * サービスアカウントの JSON キーから Google API (BigQuery・Identity Toolkit) の access token を得る。
 * 有効期限内のキャッシュがあれば再利用し、無ければ RS256 の JWT を署名して OAuth2 で交換する。
 * 冪等 (副作用はメモリキャッシュの更新のみ)。
 */
export async function fetchGoogleApiAccessToken(serviceAccountKeyJson: string): Promise<string> {
  let serviceAccountKey: BigQueryServiceAccountKey;
  try {
    serviceAccountKey = JSON.parse(serviceAccountKeyJson) as BigQueryServiceAccountKey;
  } catch (error) {
    throw new BigQueryRequestError(`BigQuery のサービスアカウントキーを読み取れませんでした: ${String(error)}`);
  }
  const { client_email: serviceAccountEmail, private_key: serviceAccountPrivateKeyPem } = serviceAccountKey;
  if (typeof serviceAccountEmail !== "string" || typeof serviceAccountPrivateKeyPem !== "string") {
    throw new BigQueryRequestError("BigQuery のサービスアカウントキーに client_email / private_key がありません");
  }

  const cachedAccessToken = cachedGoogleApiAccessTokens.get(serviceAccountEmail);
  if (cachedAccessToken !== undefined && cachedAccessToken.expiresAtMilliseconds > Date.now()) {
    return cachedAccessToken.accessToken;
  }

  const issuedAtUnixSeconds = Math.floor(Date.now() / 1000);
  const jwtSigningInput = `${encodeBase64UrlJson({ alg: "RS256", typ: "JWT" })}.${encodeBase64UrlJson({
    iss: serviceAccountEmail,
    scope: googleApiOAuthScopes,
    aud: googleOAuthTokenUrl,
    iat: issuedAtUnixSeconds,
    exp: issuedAtUnixSeconds + serviceAccountJwtLifetimeSeconds,
  })}`;
  const jwtSignature = await crypto.subtle.sign(
    rs256SigningAlgorithm,
    await importServiceAccountPrivateKey(serviceAccountPrivateKeyPem),
    new TextEncoder().encode(jwtSigningInput),
  );

  let accessTokenResponse: Response;
  try {
    accessTokenResponse = await fetch(googleOAuthTokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: `${jwtSigningInput}.${encodeBase64Url(new Uint8Array(jwtSignature))}`,
      }),
      signal: AbortSignal.timeout(bigQueryRequestTimeoutMilliseconds),
    });
  } catch (error) {
    throw new BigQueryRequestError(`Google の token エンドポイントへの接続に失敗しました: ${String(error)}`);
  }
  if (!accessTokenResponse.ok) {
    // エラー本文にはサービスアカウントの情報が含まれ得るため、詳細はログにだけ残して status だけを返す
    console.warn(
      `Google API の access token の取得に失敗 (status=${accessTokenResponse.status}): ${await accessTokenResponse.text()}`,
    );
    throw new BigQueryRequestError(
      `Google API の access token を取得できませんでした (status=${accessTokenResponse.status})`,
      accessTokenResponse.status,
    );
  }
  const googleAccessToken = (await accessTokenResponse.json()) as { access_token?: unknown; expires_in?: unknown };
  if (typeof googleAccessToken.access_token !== "string") {
    throw new BigQueryRequestError("Google API の access token の応答に access_token がありません");
  }
  cachedGoogleApiAccessTokens.set(serviceAccountEmail, {
    accessToken: googleAccessToken.access_token,
    // expires_in が欠けた応答は、要求した JWT と同じ寿命として扱う (Google は常に返すため保険のフォールバック)
    expiresAtMilliseconds:
      Date.now() +
      (typeof googleAccessToken.expires_in === "number"
        ? googleAccessToken.expires_in
        : serviceAccountJwtLifetimeSeconds) *
        1000 -
      accessTokenExpiryMarginMilliseconds,
  });
  return googleAccessToken.access_token;
}

/**
 * BigQuery REST API を POST で呼び、応答をそのまま返す。
 * status ごとの扱い (テーブルが無い 404 で作成へ回す・作成済みの 409 を成功扱いにする) は呼び出し側が決めるため、
 * HTTP エラーでも例外にせず、接続自体に失敗した場合だけ BigQueryRequestError を投げる。
 * 冪等性は呼び出すエンドポイント次第。
 */
export async function postBigQueryApi({
  serviceAccountKeyJson,
  apiPath,
  requestBody,
}: {
  /** サービスアカウントの JSON キー (Worker の secret BIGQUERY_SERVICE_ACCOUNT_KEY)。 */
  serviceAccountKeyJson: string;
  /** bigquery/v2 以下のパス (例: `/projects/{projectId}/datasets/{datasetId}/tables`)。 */
  apiPath: string;
  /** POST する JSON のリクエスト本体。 */
  requestBody: object;
}): Promise<Response> {
  const googleApiAccessToken = await fetchGoogleApiAccessToken(serviceAccountKeyJson);
  try {
    return await fetch(`${bigQueryApiBaseUrl}${apiPath}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${googleApiAccessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify(requestBody),
      signal: AbortSignal.timeout(bigQueryRequestTimeoutMilliseconds),
    });
  } catch (error) {
    throw new BigQueryRequestError(`BigQuery への接続に失敗しました: ${String(error)}`);
  }
}

/**
 * BigQuery でクエリ (SELECT・DML) を実行する。SQL に埋め込む値は必ず queryParameters (NAMED) で渡し、
 * 文字列連結による SQL 組み立てをしない。
 * ジョブが timeoutMs 内に完了しなかった場合は、揃っていない結果を返さず BigQueryRequestError にする。
 * 冪等性は渡す SQL 次第 (SELECT は読み取りのみ、パージの DELETE は同じ条件で何度実行しても結果が同じ)。
 */
export async function queryBigQuery({
  projectId,
  serviceAccountKeyJson,
  query,
  queryParameters,
}: {
  /** クエリを実行する GCP プロジェクト ID (Firebase プロジェクトと同一)。 */
  projectId: string;
  /** サービスアカウントの JSON キー (Worker の secret BIGQUERY_SERVICE_ACCOUNT_KEY)。 */
  serviceAccountKeyJson: string;
  /** 実行する標準 SQL。 */
  query: string;
  /** SQL 中の `@name` に対応する名前付きパラメータ。 */
  queryParameters: BigQueryQueryParameter[];
}): Promise<BigQueryQueryResponse> {
  const queryResponse = await postBigQueryApi({
    serviceAccountKeyJson,
    apiPath: `/projects/${encodeURIComponent(projectId)}/queries`,
    requestBody: {
      query,
      useLegacySql: false,
      parameterMode: "NAMED",
      queryParameters,
      location: bigQueryDatasetLocation,
      timeoutMs: bigQueryQueryTimeoutMilliseconds,
    },
  });
  if (!queryResponse.ok) {
    // エラー本文にはプロジェクト ID・テーブル名などの内部情報が含まれるため、詳細はログにだけ残して status だけを返す
    console.warn(`BigQuery のクエリに失敗 (status=${queryResponse.status}): ${await queryResponse.text()}`);
    throw new BigQueryRequestError(
      `BigQuery のクエリに失敗しました (status=${queryResponse.status})`,
      queryResponse.status,
    );
  }

  const bigQueryQueryResponse = (await queryResponse.json()) as BigQueryQueryResponse;
  if (bigQueryQueryResponse.jobComplete !== true) {
    throw new BigQueryRequestError(
      `BigQuery のクエリが ${bigQueryQueryTimeoutMilliseconds} ms 以内に完了しませんでした`,
    );
  }
  return bigQueryQueryResponse;
}

/**
 * クエリ結果を「列名 → 値」の行に変換する。
 * BigQuery の rows は列名を持たない値の配列 (schema.fields と同じ順序) で返るため、
 * 呼び出し側が列の順序に依存せず読めるようにする。
 */
export function bigQueryRowsByFieldName(
  bigQueryQueryResponse: BigQueryQueryResponse,
): Record<string, string | null>[] {
  const bigQueryFieldNames = (bigQueryQueryResponse.schema?.fields ?? []).map((field) => field.name ?? "");
  return (bigQueryQueryResponse.rows ?? []).map((row) =>
    Object.fromEntries(
      bigQueryFieldNames.map((fieldName, fieldIndex) => [fieldName, row.f?.[fieldIndex]?.v ?? null]),
    ),
  );
}
