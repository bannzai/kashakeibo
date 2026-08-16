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

// 日次カウンターは翌日以降不要になるため、2日で KV から自動削除してゴミを残さない
const uploadCountExpirationSeconds = 60 * 60 * 24 * 2;

const imageObjectPathPrefix = "/images/";

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

// 冪等ではない: 同じ画像を2回 POST すると別のオブジェクトキーで2つ保存される。
// キーをクライアント申告やコンテンツハッシュにせずサーバー生成の UUID にするのは、
// 他ユーザーのキーの推測・上書きを構造的に不可能にするため (重複画像の整理は明細との紐付け側 issue #9 で扱う)
async function handleImageUpload(
  request: Request,
  env: ImageWorkerEnv,
  verifiedFirebaseUser: VerifiedFirebaseUser,
): Promise<Response> {
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

  // uid 別の日次アップロード回数制限。カウンターは JWK キャッシュと同じ KV namespace に
  // "upload-count:" プレフィックスで同居させる (キー空間が重ならず、デプロイ時に作る namespace を増やさないため)。
  // KV の get/put はアトミックでないため並行リクエストで上限を数件超え得るが、
  // 費用増大攻撃の抑止が目的のため厳密な保証は不要
  const uploadCountKey = `upload-count:${verifiedFirebaseUser.uid}:${new Date().toISOString().slice(0, 10)}`;
  const todayUploadCount = Number((await env.PUBLIC_JWK_CACHE_KV.get(uploadCountKey)) ?? "0");
  if (todayUploadCount >= maxDailyUploadCountPerUser) {
    return jsonResponse(429, { error: "1日のアップロード回数の上限に達しました" });
  }
  await env.PUBLIC_JWK_CACHE_KV.put(uploadCountKey, String(todayUploadCount + 1), {
    expirationTtl: uploadCountExpirationSeconds,
  });

  // オブジェクトキーは JWT の uid から Worker 側で強制する。
  // クライアントが申告したパス・ファイル名は一切キーに使わない (他人の uid 配下への書き込みを構造的に防ぐ)
  const imageObjectKey = `users/${verifiedFirebaseUser.uid}/${crypto.randomUUID()}.${imageObjectExtension}`;

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
