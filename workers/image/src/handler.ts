// 画像アップロード (POST /images)・取得 (GET /images/{objectKey})・個別削除 (DELETE /images/{objectKey})・
// アカウント削除時の全消去 (DELETE /images)・Gemini による明細抽出 (POST /analyses)・
// 今月のスキャン回数と無料枠の取得 (GET /analyses/quota) のリクエスト処理本体。
// Firebase ID token と Firebase App Check token の検証手段を tokenVerifiers として注入する構造にし、
// テストでは実際の Google JWK / JWKS 取得を伴わないスタブ検証器で認可ロジックを検証できるようにしている
// (実際の検証器の組み立ては index.ts を参照)。
import type { ImageAnalysisResult } from "./analysis";
import { analyzeImageWithGemini, GeminiRequestError } from "./analysis";
import type { VerifyFirebaseAppCheckToken } from "./app_check";
import type { EntitlementEnv } from "./entitlement";
import { EntitlementVerificationError, hasPremiumEntitlement } from "./entitlement";
import type { UsageCounter } from "./usage_counter";
import { dailyCounterPurgeDelayMilliseconds, monthlyCounterPurgeDelayMilliseconds } from "./usage_counter";

/** Firebase ID token の検証を通ったユーザー。 */
export interface VerifiedFirebaseUser {
  /** Firebase Auth のユーザー ID。オブジェクトキーの `users/{uid}/` プレフィックスの強制に使う。 */
  uid: string;
}

// 検証失敗 (署名不正・期限切れ等) は例外を throw する契約
export type VerifyFirebaseIdToken = (firebaseIdToken: string) => Promise<VerifiedFirebaseUser>;

/** 全エンドポイントで要求する2種類の token 検証器。 */
export interface TokenVerifiers {
  /** Firebase ID token (誰のリクエストか) の検証。 */
  verifyFirebaseIdToken: VerifyFirebaseIdToken;
  /** Firebase App Check token (正規のアプリからのリクエストか) の検証。 */
  verifyFirebaseAppCheckToken: VerifyFirebaseAppCheckToken;
}

/** App Check token を載せるリクエストヘッダー名 (Firebase SDK が Firebase バックエンドへ送る時と同じ名前)。 */
export const firebaseAppCheckHeaderName = "X-Firebase-AppCheck";

/** Worker の binding (wrangler.jsonc で定義。各項目の説明もそちらを参照)。 */
export interface ImageWorkerEnv extends EntitlementEnv {
  /** 画像の保存先 R2 バケット。 */
  IMAGE_BUCKET: R2Bucket;
  /** JWK キャッシュを保存する KV。 */
  PUBLIC_JWK_CACHE_KV: KVNamespace;
  /** 日次 (アップロード・解析) と月次 (スキャン無料枠) の回数カウンターの Durable Object (判定と加算の直列化)。 */
  USAGE_COUNTER: DurableObjectNamespace<UsageCounter>;
  /** Firebase プロジェクト ID。 */
  FIREBASE_PROJECT_ID: string;
  /** JWK キャッシュの KV キー名。 */
  PUBLIC_JWK_CACHE_KEY: string;
  /** App Check の JWKS キャッシュの KV キー名 (PUBLIC_JWK_CACHE_KEY と別のキー)。 */
  APP_CHECK_JWKS_CACHE_KEY: string;
  /** Gemini API キー (wrangler secret。クライアントへ配布しない)。 */
  GEMINI_API_KEY: string;
  /** 明細抽出に使う Gemini のモデル ID。 */
  GEMINI_MODEL: string;
}

// アップロードを許可する画像形式と、オブジェクトキーに使う拡張子の対応。
// クライアント (iOS/Android の撮影・フォトライブラリ・スクショ) から実際に届く形式に限定し、
// それ以外 (SVG 等のスクリプト混入余地がある形式や任意ファイル) は 415 で拒否する
const imageContentTypeExtensions: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/heic": "heic",
};

// アップロード上限バイト数。iPhone の高解像度スクショ・レシート撮影 (HEIC/JPEG) の実測が数 MB 程度のため、
// 余裕を持たせつつ R2 への無制限アップロードを防ぐ値にしている
const maxImageBytes = 20 * 1024 * 1024;

// uid あたり1日のアップロード回数上限。正規の利用は無料枠が月50スキャン (documents/PROJECT.md の課金設計)、
// プレミアムでも1日数十枚が現実的な上限のため、正規ユーザーに影響せず
// 匿名 token を使った大量アップロードによるストレージ費用の増大を抑止できる値にしている
export const maxDailyUploadCountPerUser = 100;

// 接続元 IP あたり1日のアップロード回数上限。匿名認証では uid を作り直して uid 別上限を迂回できるため、
// uid のローテーションを跨ぐ制限として併用する。キャリア CGNAT では複数の正規ユーザーが
// 同一 IP を共有するため、uid 別上限の3倍に緩めて誤制限を避けている
export const maxDailyUploadCountPerIpAddress = 300;

// サービス全体の1日のアップロード回数上限。IP を分散させる攻撃への最後の砦として、
// 最悪ケースのストレージ増加を 5000回 × 20MB = 100GB/日 に固定する。
// MVP のユーザー規模 (無料枠 月50スキャン × リリース直後のユーザー数) では正規利用が到達しない値。
// 攻撃で上限に達すると正規ユーザーも 429 になるトレードオフは、機微画像ストレージの
// 費用暴走防止を可用性より優先して受け入れる (恒久対策は App Check 検証 issue #24)
export const maxDailyUploadCountTotal = 5000;

// 解析 1 回あたりの Gemini 呼び出し (LLM 原価) を、匿名 token の乱用から守る日次上限。
// 正規の利用は無料枠が月50スキャン (documents/PROJECT.md の課金設計) で、プレミアムでも 1 日数十回が現実的な上限のため、
// アップロードと同じ 3 層 (uid 別・接続元 IP 別・全体) の値をそのまま使う。月次の無料枠と entitlement の判定
// (monthlyFreeScanLimit) とは独立した費用暴走の歯止め
export const maxDailyAnalysisCountPerUser = maxDailyUploadCountPerUser;
export const maxDailyAnalysisCountPerIpAddress = maxDailyUploadCountPerIpAddress;
export const maxDailyAnalysisCountTotal = maxDailyUploadCountTotal;

// 無料プランの月あたりスキャン (解析) 回数の上限 (documents/PROJECT.md の課金設計「無料 = 月50スキャンまで」)。
// 月10ではアプリの価値 (撮るだけで家計簿になる体験) を感じる前に枠が尽きるため、原価削減とセットで月50へ引き上げた
// (issue #50。実測 約¥0.09/スキャン × 月50 = 約¥4.5/ユーザー。実測は workers/image/README.md の「スキャン原価」)。
// 月の区切りは UTC の暦月で、uid ごとに数える。上限に達した後の解析は、RevenueCat のプレミアム entitlement を
// 持つユーザーだけに許可する (持たない場合は 402 で、クライアントはペイウォールを表示する)。
// 手動入力は解析を呼ばないため消費しない
export const monthlyFreeScanLimit = 50;

// プレミアムの月あたりスキャン (解析) 回数の上限 (documents/PROJECT.md の課金設計)。プレミアムでも LLM 原価の
// 上限は固定する (issue #50/#51。実測 約¥0.09/スキャン × 月1000 = 約¥90/ユーザーで月額 ¥480 を下回る)。
// 毎日33回スキャンし続ける水準のため実利用では到達せず、乱用・暴走時だけ効く原価キャップ。
// 到達時は 429 を返す (プレミアム購入済みのためペイウォール誘導の 402 は使わない)
export const monthlyPremiumScanLimit = 1000;

// Gemini にインラインで渡せるリクエスト全体の上限は 20MB で、base64 化で 4/3 倍になるため、
// 元画像はその範囲に収まるサイズまでしか解析しない (クライアントは撮影時に長辺を縮小してから送る)
export const maxAnalysisImageBytes = 14 * 1024 * 1024;

const imageObjectPathPrefix = "/images/";

// X-Upload-Id ヘッダーに要求する UUID 形式。オブジェクトキーの一部になるため、
// パス区切りや ".." を構造的に含められない形式だけを受け付ける
const uploadIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * 全エンドポイント共通の入口。App Check token と Firebase ID token の両方の検証を通してからルーティングする。
 * App Check は「正規のアプリからか」、ID token は「誰のリクエストか」を判定するもので、
 * 片方だけでは通さない (匿名認証の ID token は公開クライアント設定から誰でも取得できるため)。
 */
export async function handleImageRequest(
  request: Request,
  env: ImageWorkerEnv,
  tokenVerifiers: TokenVerifiers,
): Promise<Response> {
  const firebaseAppCheckToken = request.headers.get(firebaseAppCheckHeaderName);
  if (firebaseAppCheckToken === null || firebaseAppCheckToken === "") {
    return jsonResponse(401, { error: `${firebaseAppCheckHeaderName}: <Firebase App Check token> ヘッダーが必要です` });
  }
  try {
    await tokenVerifiers.verifyFirebaseAppCheckToken(firebaseAppCheckToken);
  } catch (error) {
    // 検証失敗の詳細 (期限切れ・署名不正等) はクライアントに漏らさずログにだけ残す
    console.warn("Firebase App Check token の検証に失敗", error);
    return jsonResponse(401, { error: "Firebase App Check token が無効です" });
  }

  const authorizationHeader = request.headers.get("Authorization");
  if (authorizationHeader === null || !/^Bearer\s+\S+$/i.test(authorizationHeader)) {
    return jsonResponse(401, { error: "Authorization: Bearer <Firebase ID token> ヘッダーが必要です" });
  }
  const firebaseIdToken = authorizationHeader.replace(/^Bearer\s+/i, "");

  let verifiedFirebaseUser: VerifiedFirebaseUser;
  try {
    verifiedFirebaseUser = await tokenVerifiers.verifyFirebaseIdToken(firebaseIdToken);
  } catch (error) {
    // 検証失敗の詳細 (期限切れ・署名不正等) はクライアントに漏らさずログにだけ残す
    console.warn("Firebase ID token の検証に失敗", error);
    return jsonResponse(401, { error: "Firebase ID token が無効です" });
  }

  const requestUrl = new URL(request.url);

  if (request.method === "POST" && requestUrl.pathname === "/images") {
    return handleImageUpload(request, env, verifiedFirebaseUser);
  }
  if (request.method === "GET" && requestUrl.pathname.startsWith(imageObjectPathPrefix)) {
    return handleImageGet(requestUrl, env, verifiedFirebaseUser);
  }
  if (request.method === "DELETE" && requestUrl.pathname === "/images") {
    return handleAllImagesDelete(env, verifiedFirebaseUser);
  }
  if (request.method === "DELETE" && requestUrl.pathname.startsWith(imageObjectPathPrefix)) {
    return handleImageDelete(requestUrl, env, verifiedFirebaseUser);
  }
  if (request.method === "POST" && requestUrl.pathname === "/analyses") {
    return handleImageAnalysis(request, env, verifiedFirebaseUser);
  }
  if (request.method === "GET" && requestUrl.pathname === "/analyses/quota") {
    return handleScanQuotaGet(env, verifiedFirebaseUser);
  }
  return jsonResponse(404, { error: "not found" });
}

// 冪等: 同じ X-Upload-Id (クライアントが論理アップロードごとに生成する UUID) での再試行は
// 同じオブジェクトキーへの上書きになる。201 レスポンスの消失後にクライアントが再試行しても、
// どこからも参照されない孤児オブジェクトが残らない。
// uploadId はキーの uid プレフィックスを Worker が JWT から強制し UUID 形式に検証するため、
// 他ユーザーのキーの推測・上書きは構造的に不可能 (重複画像の整理は明細との紐付け側 issue #9 で扱う)
async function handleImageUpload(
  request: Request,
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
  const uploadId = request.headers.get("X-Upload-Id");
  if (uploadId === null || !uploadIdPattern.test(uploadId)) {
    return jsonResponse(400, { error: "X-Upload-Id ヘッダーに UUID が必要です" });
  }

  let requestFormData: FormData;
  try {
    requestFormData = await request.formData();
  } catch (error) {
    return jsonResponse(400, { error: "multipart/form-data のリクエストボディが必要です" });
  }

  // workers-types の FormData.get は string | null と型定義されるが、
  // 実行時は multipart の file パートで File を返すため unknown を経由して判定する
  const uploadedFile = requestFormData.get("file") as unknown;
  if (!(uploadedFile instanceof File)) {
    return jsonResponse(400, { error: "file フィールドに画像ファイルが必要です" });
  }

  const imageObjectExtension = imageContentTypeExtensions[uploadedFile.type];
  if (imageObjectExtension === undefined) {
    return jsonResponse(415, {
      error: `未対応の Content-Type です: ${uploadedFile.type}。対応形式: ${Object.keys(imageContentTypeExtensions).join(", ")}`,
    });
  }

  if (uploadedFile.size === 0) {
    // 空ファイルを保存すると明細に紐づけた後の Gemini 解析・表示で初めて失敗する壊れた画像が残るため、ここで拒否する
    return jsonResponse(400, { error: "空のファイルはアップロードできません" });
  }

  if (uploadedFile.size > maxImageBytes) {
    return jsonResponse(413, { error: `ファイルサイズ上限 (${maxImageBytes} bytes) を超えています` });
  }

  // オブジェクトキーの uid プレフィックスは JWT の uid から Worker 側で強制する
  // (他人の uid 配下への書き込みを構造的に防ぐ)。ファイル名部分は UUID 形式に検証済みの
  // X-Upload-Id を使い、同じ論理アップロードの再試行が同じキーに収束するようにする
  const imageObjectKey = `users/${verifiedFirebaseUser.uid}/${uploadId.toLowerCase()}.${imageObjectExtension}`;

  // 保存済みキーへの再試行 (201 レスポンスだけが消失したケース) は、回数制限より先に判定して
  // カウントせずに成功を返す。制限は新規の X-Upload-Id だけを数えるため、
  // 上限間際の再試行が 429 になって保存済みキーを回収できなくなることがない
  if ((await env.IMAGE_BUCKET.head(imageObjectKey)) !== null) {
    return jsonResponse(201, { imageObjectKey });
  }

  // 日次アップロード回数制限を uid 別・接続元 IP 別・全体の3層で判定する
  const withinUploadLimits = await incrementDailyCountIfWithinLimits({
    request,
    env,
    verifiedFirebaseUser,
    counterKeyPrefix: "",
    maxDailyCountPerUser: maxDailyUploadCountPerUser,
    maxDailyCountPerIpAddress: maxDailyUploadCountPerIpAddress,
    maxDailyCountTotal: maxDailyUploadCountTotal,
  });
  if (!withinUploadLimits) {
    return jsonResponse(429, { error: "1日のアップロード回数の上限に達しました" });
  }

  await env.IMAGE_BUCKET.put(imageObjectKey, await uploadedFile.arrayBuffer(), {
    httpMetadata: { contentType: uploadedFile.type },
  });

  // URL ではなくオブジェクトキーを返す。配信ドメインはデプロイ時に決まるため、
  // Firestore にはキーを保存し、取得 URL はクライアント側で {baseUrl}/images/{key} を組み立てる
  return jsonResponse(201, { imageObjectKey });
}

/** アップロード済み画像の取得。本人の uid 配下のオブジェクトキーだけを許可する。 */
async function handleImageGet(
  requestUrl: URL,
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
  const resolvedKey = resolveOwnImageObjectKey(requestUrl, verifiedFirebaseUser);
  if ("errorResponse" in resolvedKey) {
    return resolvedKey.errorResponse;
  }

  const imageObject = await env.IMAGE_BUCKET.get(resolvedKey.imageObjectKey);
  if (imageObject === null) {
    return jsonResponse(404, { error: "not found" });
  }

  const imageResponseHeaders = new Headers();
  imageObject.writeHttpMetadata(imageResponseHeaders);
  imageResponseHeaders.set("etag", imageObject.httpEtag);
  // 認証付き私的コンテンツのため共有キャッシュに載せない
  imageResponseHeaders.set("Cache-Control", "private, max-age=0, must-revalidate");
  return new Response(imageObject.body, { status: 200, headers: imageResponseHeaders });
}

/**
 * アカウント削除時の全画像消去。JWT の uid 配下 (`users/{uid}/`) のオブジェクトを全削除する。
 * docs/AccountDeletion.md の「撮影・アップロードした画像は削除操作と同時に削除される」を満たすため、
 * クライアントは Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。
 * 冪等: 対象が既に無い場合も 200 を返す。
 */
async function handleAllImagesDelete(
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
  const userObjectKeyPrefix = `users/${verifiedFirebaseUser.uid}/`;
  let deletedImageCount = 0;
  // list は最大1000件ずつ返るため、無くなるまで削除を繰り返す
  for (;;) {
    const listedImageObjects = await env.IMAGE_BUCKET.list({ prefix: userObjectKeyPrefix });
    if (listedImageObjects.objects.length === 0) {
      return jsonResponse(200, { deletedImageCount: String(deletedImageCount) });
    }
    await env.IMAGE_BUCKET.delete(listedImageObjects.objects.map((imageObject) => imageObject.key));
    deletedImageCount += listedImageObjects.objects.length;
  }
}

/**
 * 日次回数制限を uid 別・接続元 IP 別・全体の3層で判定し、すべて上限未満なら加算して true を返す。
 * uid 別だけでは匿名認証の uid 作り直しで迂回できるため、uid を跨ぐ IP 別・全体上限を併用する。
 * 判定と加算は日次シングルトンの Durable Object で直列化し、並行リクエストが同じ旧値を読んで
 * 上限判定をすり抜けることを防ぐ。CF-Connecting-IP は Cloudflare が付与する接続元 IP で、
 * 本番では常に存在する (存在しない実行環境ではひとつのバケットにまとめて数える)。
 * counterKeyPrefix でアップロード (空文字) と解析 ("analysis:") のカウンターを分ける。
 */
async function incrementDailyCountIfWithinLimits({
  request,
  env,
  verifiedFirebaseUser,
  counterKeyPrefix,
  maxDailyCountPerUser,
  maxDailyCountPerIpAddress,
  maxDailyCountTotal,
}: {
  request: Request;
  env: ImageWorkerEnv;
  verifiedFirebaseUser: VerifiedFirebaseUser;
  counterKeyPrefix: string;
  maxDailyCountPerUser: number;
  maxDailyCountPerIpAddress: number;
  maxDailyCountTotal: number;
}): Promise<boolean> {
  const dateText = new Date().toISOString().slice(0, 10);
  const clientIpAddress = request.headers.get("CF-Connecting-IP") ?? "unknown";
  return env.USAGE_COUNTER.get(env.USAGE_COUNTER.idFromName(dateText)).incrementIfWithinLimits(
    [
      { counterKey: `${counterKeyPrefix}uid:${verifiedFirebaseUser.uid}`, maxCount: maxDailyCountPerUser },
      { counterKey: `${counterKeyPrefix}ip:${clientIpAddress}`, maxCount: maxDailyCountPerIpAddress },
      { counterKey: `${counterKeyPrefix}total`, maxCount: maxDailyCountTotal },
    ],
    dailyCounterPurgeDelayMilliseconds,
  );
}

/** 今月 (UTC の暦月) のスキャン回数カウンターの Durable Object インスタンス。日次インスタンスとは名前空間 (`month:` プレフィックス) で分ける。 */
function monthlyUsageCounter(env: ImageWorkerEnv): DurableObjectStub<UsageCounter> {
  return env.USAGE_COUNTER.get(env.USAGE_COUNTER.idFromName(`month:${new Date().toISOString().slice(0, 7)}`));
}

/** 月次スキャン回数カウンターの uid 別キー。 */
function monthlyScanCounterKey(verifiedFirebaseUser: VerifiedFirebaseUser): string {
  return `scan:uid:${verifiedFirebaseUser.uid}`;
}

/** 今月のスキャン回数の消費判定の結果。 */
type MonthlyScanQuotaResult =
  /** 消費できた (解析へ進む)。 */
  | "consumed"
  /** 無料枠を使い切っていてプレミアムでもない (呼び出し側は 402 でペイウォールへ誘導する)。 */
  | "freeQuotaExceeded"
  /** プレミアムの月次上限 (monthlyPremiumScanLimit) に達した (呼び出し側は 429 を返す)。 */
  | "premiumLimitExceeded";

/**
 * 今月のスキャン回数を枠の範囲で 1 つ消費する。無料枠 (monthlyFreeScanLimit) 内なら加算して consumed。
 * 無料枠を使い切っていれば RevenueCat のプレミアム entitlement を確認し、プレミアムなら
 * プレミアム上限 (monthlyPremiumScanLimit) の範囲で加算して consumed (上限到達時は premiumLimitExceeded)、
 * プレミアムでなければ加算せず freeQuotaExceeded を返す。
 * 判定と加算は月次の Durable Object で直列化され、並行リクエストでも枠を超えて消費されない。
 * RevenueCat の判定に失敗した場合は EntitlementVerificationError を投げる。
 */
async function consumeMonthlyScanQuota(
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<MonthlyScanQuotaResult> {
  const monthlyCounter = monthlyUsageCounter(env);
  const counterKey = monthlyScanCounterKey(verifiedFirebaseUser);
  if (
    await monthlyCounter.incrementIfWithinLimits(
      [{ counterKey, maxCount: monthlyFreeScanLimit }],
      monthlyCounterPurgeDelayMilliseconds,
    )
  ) {
    return "consumed";
  }
  // 無料枠を使い切ったユーザーだけ RevenueCat に問い合わせる (無料枠内の解析では課金 API を呼ばない)
  if (!(await hasPremiumEntitlement({ appUserId: verifiedFirebaseUser.uid, env }))) {
    return "freeQuotaExceeded";
  }
  return (await monthlyCounter.incrementIfWithinLimits(
    [{ counterKey, maxCount: monthlyPremiumScanLimit }],
    monthlyCounterPurgeDelayMilliseconds,
  ))
    ? "consumed"
    : "premiumLimitExceeded";
}

/**
 * 今月のスキャン回数と無料枠の上限を返す (GET /analyses/quota)。クライアントは残量表示とペイウォールの表示判定に使う。
 * プレミアムかどうかはクライアントが RevenueCat SDK から直接得るため含めない。冪等 (読み取りのみ)。
 */
async function handleScanQuotaGet(env: ImageWorkerEnv, verifiedFirebaseUser: VerifiedFirebaseUser): Promise<Response> {
  return jsonResponse(200, {
    monthlyScanCount: await monthlyUsageCounter(env).getCount(monthlyScanCounterKey(verifiedFirebaseUser)),
    monthlyFreeScanLimit,
  });
}

/**
 * URL パスからオブジェクトキーを取り出し、本人の uid 配下のキーだけを返す。
 * 不正な percent-encoding・".." を含むキーは 400、他人の uid 配下は 403 のレスポンスを返す。
 */
function resolveOwnImageObjectKey(
  requestUrl: URL,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): { imageObjectKey: string } | { errorResponse: Response } {
  let imageObjectKey: string;
  try {
    imageObjectKey = decodeURIComponent(requestUrl.pathname.slice(imageObjectPathPrefix.length));
  } catch (error) {
    // 不正な percent-encoding ("%GG" 等) は URIError になるため 500 にせず 400 で返す
    return { errorResponse: jsonResponse(400, { error: "不正なオブジェクトキーです" }) };
  }
  return validateOwnImageObjectKey(imageObjectKey, verifiedFirebaseUser);
}

// GET / DELETE / POST /analyses に共通する、本人の uid 配下のキーかどうかの判定
function validateOwnImageObjectKey(
  imageObjectKey: string,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): { imageObjectKey: string } | { errorResponse: Response } {
  // URL クラスが正規化しない percent-encoding 経由の ".." もここで拒否する
  if (imageObjectKey.includes("..")) {
    return { errorResponse: jsonResponse(400, { error: "不正なオブジェクトキーです" }) };
  }
  // 本人の uid 配下以外のキーは、存在有無を問わず拒否する (他人のレシート画像への横アクセス防止)
  if (!imageObjectKey.startsWith(`users/${verifiedFirebaseUser.uid}/`)) {
    return { errorResponse: jsonResponse(403, { error: "このオブジェクトキーへのアクセス権限がありません" }) };
  }
  return { imageObjectKey };
}

/**
 * 画像 1 件の削除 (明細から画像だけを外す・明細ごと削除する時に使う)。本人の uid 配下のキーだけを許可する。
 * 冪等: 対象が既に無い場合も 200 を返す。
 */
async function handleImageDelete(
  requestUrl: URL,
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
  const resolvedKey = resolveOwnImageObjectKey(requestUrl, verifiedFirebaseUser);
  if ("errorResponse" in resolvedKey) {
    return resolvedKey.errorResponse;
  }
  await env.IMAGE_BUCKET.delete(resolvedKey.imageObjectKey);
  return jsonResponse(200, { imageObjectKey: resolvedKey.imageObjectKey });
}

/**
 * アップロード済み画像を Gemini で解析し、抽出した明細を返す (POST /analyses)。
 * リクエスト本体は `{"imageObjectKey": "users/{uid}/..."}`。画像はクライアントから再送させず R2 から読む。
 * 本人の uid 配下のキーだけを許可し、解析回数は日次上限 (maxDailyAnalysisCount*) と
 * 月次の無料枠 (monthlyFreeScanLimit。超過時はプレミアム entitlement が必要) で守る。
 * 冪等 (副作用は日次・月次カウンターの加算のみ)。
 */
async function handleImageAnalysis(
  request: Request,
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
  let requestBody: { imageObjectKey?: unknown };
  try {
    requestBody = (await request.json()) as { imageObjectKey?: unknown };
  } catch (error) {
    return jsonResponse(400, { error: "JSON のリクエストボディが必要です" });
  }
  if (typeof requestBody.imageObjectKey !== "string" || requestBody.imageObjectKey === "") {
    return jsonResponse(400, { error: "imageObjectKey が必要です" });
  }
  const resolvedKey = validateOwnImageObjectKey(requestBody.imageObjectKey, verifiedFirebaseUser);
  if ("errorResponse" in resolvedKey) {
    return resolvedKey.errorResponse;
  }

  // 本文は Gemini 呼び出しの直前まで読まず、メタデータ (head) だけで事前検査する
  const imageObjectMetadata = await env.IMAGE_BUCKET.head(resolvedKey.imageObjectKey);
  if (imageObjectMetadata === null) {
    return jsonResponse(404, { error: "not found" });
  }
  if (imageObjectMetadata.size > maxAnalysisImageBytes) {
    return jsonResponse(413, { error: `解析できる画像サイズの上限 (${maxAnalysisImageBytes} bytes) を超えています` });
  }
  const imageContentType = imageObjectMetadata.httpMetadata?.contentType;
  if (imageContentType === undefined) {
    return jsonResponse(415, { error: "画像の Content-Type が不明なため解析できません" });
  }

  // 上限判定は Gemini 呼び出し (課金) の直前で行い、上限超過時に LLM 原価を発生させない
  const withinAnalysisLimits = await incrementDailyCountIfWithinLimits({
    request,
    env,
    verifiedFirebaseUser,
    counterKeyPrefix: "analysis:",
    maxDailyCountPerUser: maxDailyAnalysisCountPerUser,
    maxDailyCountPerIpAddress: maxDailyAnalysisCountPerIpAddress,
    maxDailyCountTotal: maxDailyAnalysisCountTotal,
  });
  if (!withinAnalysisLimits) {
    return jsonResponse(429, { error: "1日の解析回数の上限に達しました" });
  }

  // 月次の無料枠 (monthlyFreeScanLimit)・プレミアム上限 (monthlyPremiumScanLimit) と、
  // 無料枠超過時のプレミアム entitlement を判定する。
  // 日次上限の後に置くことで、429 (混雑・乱用) で弾かれるリクエストが無料枠を消費しない
  let monthlyScanQuotaResult: MonthlyScanQuotaResult;
  try {
    monthlyScanQuotaResult = await consumeMonthlyScanQuota(env, verifiedFirebaseUser);
  } catch (error) {
    if (!(error instanceof EntitlementVerificationError)) {
      throw error;
    }
    // 課金状態を判定できない一時的な失敗は、無料枠超過 (402) と区別して 503 で返す (クライアントは再試行できる)
    console.warn("RevenueCat の entitlement 判定に失敗", error);
    return jsonResponse(503, { error: error.message });
  }
  if (monthlyScanQuotaResult === "freeQuotaExceeded") {
    return jsonResponse(402, {
      error: `今月の無料スキャン (${monthlyFreeScanLimit}回) を使い切りました`,
      monthlyScanCount: await monthlyUsageCounter(env).getCount(monthlyScanCounterKey(verifiedFirebaseUser)),
      monthlyFreeScanLimit,
    });
  }
  if (monthlyScanQuotaResult === "premiumLimitExceeded") {
    // プレミアム購入済みのためペイウォール誘導 (402) ではなく、上限到達として 429 を返す
    return jsonResponse(429, { error: `今月のスキャン回数の上限 (${monthlyPremiumScanLimit}回) に達しました` });
  }

  const imageObject = await env.IMAGE_BUCKET.get(resolvedKey.imageObjectKey);
  if (imageObject === null) {
    // head の直後に削除された競合。カウンターは消費済みだが、稀なケースとして許容する
    return jsonResponse(404, { error: "not found" });
  }
  let imageAnalysisResult: ImageAnalysisResult;
  try {
    imageAnalysisResult = await analyzeImageWithGemini({
      imageBytes: await imageObject.arrayBuffer(),
      imageContentType,
      geminiApiKey: env.GEMINI_API_KEY,
      geminiModel: env.GEMINI_MODEL,
    });
  } catch (error) {
    // 解析失敗の詳細はログに残しつつ、クライアントには 502 として伝える (クライアントは手動入力へフォールバックする)
    console.warn("Gemini による画像解析に失敗", error);
    const errorMessage = error instanceof GeminiRequestError ? error.message : `画像の解析に失敗しました: ${String(error)}`;
    return jsonResponse(502, { error: errorMessage });
  }
  return jsonResponse(200, imageAnalysisResult);
}

/** エラー・結果を application/json で返すためのレスポンス組み立て。 */
function jsonResponse(status: number, body: object): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
