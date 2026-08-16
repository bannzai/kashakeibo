// 画像アップロード (POST /images)・取得 (GET /images/{objectKey}) のリクエスト処理本体。
// Firebase ID token の検証手段を verifyFirebaseIdToken として注入する構造にし、
// テストでは実際の Google JWK 取得を伴わないスタブ検証器で認可ロジックを検証できるようにしている
// (実際の検証器の組み立ては index.ts を参照)。

/** Firebase ID token の検証を通ったユーザー。 */
export interface VerifiedFirebaseUser {
  /** Firebase Auth のユーザー ID。オブジェクトキーの `users/{uid}/` プレフィックスの強制に使う。 */
  uid: string;
}

// 検証失敗 (署名不正・期限切れ等) は例外を throw する契約
export type VerifyFirebaseIdToken = (firebaseIdToken: string) => Promise<VerifiedFirebaseUser>;

/** Worker の binding (wrangler.jsonc で定義。各項目の説明もそちらを参照)。 */
export interface ImageWorkerEnv {
  /** 画像の保存先 R2 バケット。 */
  IMAGE_BUCKET: R2Bucket;
  /** JWK キャッシュと日次アップロードカウンターを保存する KV。 */
  PUBLIC_JWK_CACHE_KV: KVNamespace;
  /** Firebase プロジェクト ID。 */
  FIREBASE_PROJECT_ID: string;
  /** JWK キャッシュの KV キー名。 */
  PUBLIC_JWK_CACHE_KEY: string;
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

// uid あたり1日のアップロード回数上限。正規の利用は無料枠が月10スキャン (documents/PROJECT.md の課金設計)、
// プレミアムでも1日数十枚が現実的な上限のため、正規ユーザーに影響せず
// 匿名 token を使った大量アップロードによるストレージ費用の増大を抑止できる値にしている
export const maxDailyUploadCountPerUser = 100;

// 接続元 IP あたり1日のアップロード回数上限。匿名認証では uid を作り直して uid 別上限を迂回できるため、
// uid のローテーションを跨ぐ制限として併用する。キャリア CGNAT では複数の正規ユーザーが
// 同一 IP を共有するため、uid 別上限の3倍に緩めて誤制限を避けている
export const maxDailyUploadCountPerIpAddress = 300;

// サービス全体の1日のアップロード回数上限。IP を分散させる攻撃への最後の砦として、
// 最悪ケースのストレージ増加を 5000回 × 20MB = 100GB/日 に固定する。
// MVP のユーザー規模 (無料枠 月10スキャン × リリース直後のユーザー数) では正規利用が到達しない値。
// 攻撃で上限に達すると正規ユーザーも 429 になるトレードオフは、機微画像ストレージの
// 費用暴走防止を可用性より優先して受け入れる (恒久対策は App Check 検証 issue #24)
export const maxDailyUploadCountTotal = 5000;

// 日次カウンターは翌日以降不要になるため、2日で KV から自動削除してゴミを残さない
const uploadCountExpirationSeconds = 60 * 60 * 24 * 2;

const imageObjectPathPrefix = "/images/";

// X-Upload-Id ヘッダーに要求する UUID 形式。オブジェクトキーの一部になるため、
// パス区切りや ".." を構造的に含められない形式だけを受け付ける
const uploadIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** 全エンドポイント共通の入口。Firebase ID token の検証を通してからルーティングする。 */
export async function handleImageRequest(
  request: Request,
  env: ImageWorkerEnv,
  verifyFirebaseIdToken: VerifyFirebaseIdToken,
): Promise<Response> {
  const authorizationHeader = request.headers.get("Authorization");
  if (authorizationHeader === null || !/^Bearer\s+\S+$/i.test(authorizationHeader)) {
    return jsonResponse(401, { error: "Authorization: Bearer <Firebase ID token> ヘッダーが必要です" });
  }
  const firebaseIdToken = authorizationHeader.replace(/^Bearer\s+/i, "");

  let verifiedFirebaseUser: VerifiedFirebaseUser;
  try {
    verifiedFirebaseUser = await verifyFirebaseIdToken(firebaseIdToken);
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

  // 日次アップロード回数制限を uid 別・接続元 IP 別・全体の3層で判定する。
  // uid 別だけでは匿名認証の uid 作り直しで迂回できるため、uid を跨ぐ IP 別・全体上限を併用する。
  // CF-Connecting-IP は Cloudflare が付与する接続元 IP で、本番では常に存在する
  // (存在しない実行環境ではひとつのバケットにまとめて数える)
  const uploadDateText = new Date().toISOString().slice(0, 10);
  const clientIpAddress = request.headers.get("CF-Connecting-IP") ?? "unknown";
  for (const { uploadCountKey, maxDailyUploadCount } of [
    { uploadCountKey: `upload-count:${verifiedFirebaseUser.uid}:${uploadDateText}`, maxDailyUploadCount: maxDailyUploadCountPerUser },
    { uploadCountKey: `upload-count:ip:${clientIpAddress}:${uploadDateText}`, maxDailyUploadCount: maxDailyUploadCountPerIpAddress },
    { uploadCountKey: `upload-count:total:${uploadDateText}`, maxDailyUploadCount: maxDailyUploadCountTotal },
  ]) {
    // KV の get/put はアトミックでないため並行リクエストで上限を数件超え得るが、
    // 費用増大攻撃の抑止が目的のため厳密な保証は不要。カウンターは JWK キャッシュと同じ
    // KV namespace に "upload-count:" プレフィックスで同居させる (デプロイ時に作る namespace を増やさないため)
    const todayUploadCount = Number((await env.PUBLIC_JWK_CACHE_KV.get(uploadCountKey)) ?? "0");
    if (todayUploadCount >= maxDailyUploadCount) {
      return jsonResponse(429, { error: "1日のアップロード回数の上限に達しました" });
    }
    await env.PUBLIC_JWK_CACHE_KV.put(uploadCountKey, String(todayUploadCount + 1), {
      expirationTtl: uploadCountExpirationSeconds,
    });
  }

  // オブジェクトキーの uid プレフィックスは JWT の uid から Worker 側で強制する
  // (他人の uid 配下への書き込みを構造的に防ぐ)。ファイル名部分は UUID 形式に検証済みの
  // X-Upload-Id を使い、同じ論理アップロードの再試行が同じキーに収束するようにする
  const imageObjectKey = `users/${verifiedFirebaseUser.uid}/${uploadId.toLowerCase()}.${imageObjectExtension}`;

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
  let imageObjectKey: string;
  try {
    imageObjectKey = decodeURIComponent(requestUrl.pathname.slice(imageObjectPathPrefix.length));
  } catch (error) {
    // 不正な percent-encoding ("%GG" 等) は URIError になるため 500 にせず 400 で返す
    return jsonResponse(400, { error: "不正なオブジェクトキーです" });
  }

  // URL クラスが正規化しない percent-encoding 経由の ".." もここで拒否する
  if (imageObjectKey.includes("..")) {
    return jsonResponse(400, { error: "不正なオブジェクトキーです" });
  }
  // 本人の uid 配下以外のキーは、存在有無を問わず拒否する (他人のレシート画像への横アクセス防止)
  if (!imageObjectKey.startsWith(`users/${verifiedFirebaseUser.uid}/`)) {
    return jsonResponse(403, { error: "このオブジェクトキーへのアクセス権限がありません" });
  }

  const imageObject = await env.IMAGE_BUCKET.get(imageObjectKey);
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

/** エラー・結果を application/json で返すためのレスポンス組み立て。 */
function jsonResponse(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
