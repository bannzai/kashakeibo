// Gemini vision による画像 (レシート・明細スクショ) の明細抽出。
// 呼び出しは generateContent のステートレスな 1 リクエストで完結させ、画像・結果とも Gemini 側に永続化しない
// (documents/adr/0001-tech-stack.md の「画像解析」。Interactions API は既定で対話を保存するため使わない)。
// API キーは Worker の secret (GEMINI_API_KEY) にだけ置き、クライアントへ配布しない。

/** 明細の種別。Flutter 側 Entity (lib/entity/transaction.dart) の TransactionType と同じ enum 名。 */
export const analyzedTransactionTypes = ["income", "expense"] as const;
export type AnalyzedTransactionType = (typeof analyzedTransactionTypes)[number];

/** 明細のカテゴリ。Flutter 側 Entity の TransactionCategory と同じ enum 名で返し、クライアントはそのまま enum に読む。 */
export const analyzedTransactionCategories = [
  "food",
  "eatingOut",
  "dailyGoods",
  "transportation",
  "subscription",
  "salary",
  "other",
] as const;
export type AnalyzedTransactionCategory = (typeof analyzedTransactionCategories)[number];

/** 画像から抽出した明細 1 件。POST /analyses のレスポンス `transactions[]` の要素。 */
export interface AnalyzedTransaction {
  /** 店名・サービス名 (摘要)。読み取れない場合は空文字。 */
  title: string;
  /** 金額 (日本円・税込・整数、1 以上)。 */
  amount: number;
  /** 取引日 (YYYY-MM-DD)。年月日のいずれかが読み取れない場合は null。 */
  transactionDate: string | null;
  /** 収入 / 支出。 */
  type: AnalyzedTransactionType;
  /** カテゴリ。 */
  category: AnalyzedTransactionCategory;
}

/** POST /analyses のレスポンス本体。 */
export interface ImageAnalysisResult {
  /** 抽出した明細。レシートは 1 枚 1 件、スクショは取引ごとに 1 件。明細が写っていなければ空配列。 */
  transactions: AnalyzedTransaction[];
}

// Gemini に強制する出力スキーマ (generationConfig.responseSchema。OpenAPI 3.0 のサブセット)。
// AnalyzedTransaction と 1 対 1 に対応させ、enum はクライアント Entity の enum 名と一致させる
const analysisResponseSchema = {
  type: "OBJECT",
  properties: {
    transactions: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          title: { type: "STRING", description: "店名・サービス名 (摘要)。読み取れない場合は空文字" },
          amount: { type: "INTEGER", description: "金額 (日本円・税込の整数)。通貨記号と桁区切りは含めない" },
          transactionDate: {
            type: "STRING",
            nullable: true,
            description: "取引日 (YYYY-MM-DD)。年月日のいずれかが読み取れない場合は null",
          },
          type: { type: "STRING", enum: [...analyzedTransactionTypes] },
          category: { type: "STRING", enum: [...analyzedTransactionCategories] },
        },
        required: ["title", "amount", "transactionDate", "type", "category"],
      },
    },
  },
  required: ["transactions"],
};

const analysisPrompt = [
  "あなたは家計簿アプリの明細抽出エンジンです。画像は紙のレシート、またはクレジットカード明細・EC 購入履歴などのスクリーンショットです。",
  "画像から家計簿の明細を抽出し、指定のスキーマの JSON だけを返してください。",
  "- 紙のレシートは 1 枚につき 1 明細とし、amount はレシートの支払総額 (税込の合計) を使います。商品行ごとに分割しません",
  "- カード明細・購入履歴のスクリーンショットは、取引 1 件ごとに 1 明細にします",
  "- title は店名・サービス名 (摘要)。読み取れない場合は空文字にします",
  "- amount は日本円の整数 (税込)。通貨記号・桁区切りは含めません。金額が読み取れない明細は含めません",
  "- transactionDate は取引日 (YYYY-MM-DD)。年・月・日のいずれかが読み取れない場合は null にします。時刻は不要です",
  "- type は支払いなら expense、入金・給与・返金なら income にします",
  "- category は次から選びます: food (食料品・スーパー・コンビニ), eatingOut (外食・カフェ・居酒屋), dailyGoods (洗剤・トイレットペーパー等の消耗品・ドラッグストア), transportation (鉄道・バス・タクシー・ガソリン), subscription (定額サービス), salary (給与), other (上記以外。家電・ガジェット・EC の雑貨など)",
  "- 家計簿の明細が写っていない画像の場合は transactions を空配列にします",
].join("\n");

// 取引日として受け付ける形式。YYYY-MM-DD 以外 (時刻付き・和暦・全角) は null に落とす
const transactionDatePattern = /^\d{4}-\d{2}-\d{2}$/;

/** generationConfig のうち 1 スキャンあたりの原価 (トークン数) に効く設定。実測は scripts/measure-analysis-cost.mjs (issue #50)。 */
export interface GeminiCostTuningConfig {
  /** thinking の強さ (generationConfig.thinkingConfig.thinkingLevel)。未指定はモデル既定。 */
  thinkingLevel?: "low" | "medium" | "high";
  /** 画像入力へのトークン割当 (generationConfig.mediaResolution)。未指定はモデル既定。 */
  mediaResolution?: "MEDIA_RESOLUTION_LOW" | "MEDIA_RESOLUTION_MEDIUM" | "MEDIA_RESOLUTION_HIGH";
}

/** Gemini generateContent の呼び出しに必要な設定。 */
export interface GeminiAnalysisOptions {
  /** 解析する画像のバイト列。 */
  imageBytes: ArrayBuffer;
  /** 画像の Content-Type (image/jpeg など)。 */
  imageContentType: string;
  /** Gemini API キー (Worker の secret)。 */
  geminiApiKey: string;
  /** モデル ID (wrangler.jsonc の GEMINI_MODEL)。 */
  geminiModel: string;
  /** Gemini API のベース URL。テストでは差し替える。 */
  geminiApiBaseUrl?: string;
  /** 原価チューニング設定。未指定は本番採用値 (adoptedCostTuningConfig)。 */
  costTuningConfig?: GeminiCostTuningConfig;
}

/**
 * 本番で採用している原価チューニング設定。値の根拠 (実測) は workers/image/README.md の「スキャン原価」を参照。
 */
export const adoptedCostTuningConfig: GeminiCostTuningConfig = {};

/**
 * generateContent のリクエスト本体を組み立てる。
 * 本番 (analyzeImageWithGemini) と原価実測スクリプト (scripts/measure-analysis-cost.mjs) で同じ組み立てを使う。
 */
export function buildGeminiAnalysisRequestBody({
  imageBytes,
  imageContentType,
  costTuningConfig,
}: {
  imageBytes: ArrayBuffer;
  imageContentType: string;
  costTuningConfig: GeminiCostTuningConfig;
}): object {
  return {
    contents: [
      {
        role: "user",
        parts: [
          { inline_data: { mime_type: imageContentType, data: arrayBufferToBase64(imageBytes) } },
          { text: analysisPrompt },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: analysisResponseSchema,
      // 抽出タスクなので出力の揺れを抑える
      temperature: 0,
      ...(costTuningConfig.mediaResolution === undefined ? {} : { mediaResolution: costTuningConfig.mediaResolution }),
      ...(costTuningConfig.thinkingLevel === undefined
        ? {}
        : { thinkingConfig: { thinkingLevel: costTuningConfig.thinkingLevel } }),
    },
  };
}

/** generateContent レスポンスの usageMetadata (原価の記録に使うトークン数)。 */
export interface GeminiUsageMetadata {
  /** 入力 (プロンプト + 画像) のトークン数。 */
  promptTokenCount?: number;
  /** thinking のトークン数 (出力単価で課金される)。 */
  thoughtsTokenCount?: number;
  /** 出力本文のトークン数。 */
  candidatesTokenCount?: number;
  /** 合計トークン数。 */
  totalTokenCount?: number;
}

/** Gemini API の呼び出し失敗 (HTTP エラー・空応答)。 */
export class GeminiRequestError extends Error {
  /** Gemini API の HTTP ステータス。ネットワーク到達前の失敗では undefined。 */
  readonly geminiStatus: number | undefined;

  constructor(message: string, geminiStatus: number | undefined) {
    super(message);
    this.name = "GeminiRequestError";
    this.geminiStatus = geminiStatus;
  }
}

/**
 * 画像を Gemini に渡して明細を抽出する。
 * 冪等 (副作用のない読み取り専用の呼び出し。同じ画像でもモデル出力は完全一致しない場合がある)。
 * モデル出力はスキーマ強制後も信用せず、[toImageAnalysisResult] で型・範囲を検証してから返す。
 */
export async function analyzeImageWithGemini({
  imageBytes,
  imageContentType,
  geminiApiKey,
  geminiModel,
  geminiApiBaseUrl = "https://generativelanguage.googleapis.com",
  costTuningConfig = adoptedCostTuningConfig,
}: GeminiAnalysisOptions): Promise<ImageAnalysisResult> {
  const geminiResponse = await fetch(`${geminiApiBaseUrl}/v1beta/models/${geminiModel}:generateContent`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      // API キーは URL クエリではなくヘッダーで渡し、アクセスログ等に残さない
      "x-goog-api-key": geminiApiKey,
    },
    body: JSON.stringify(buildGeminiAnalysisRequestBody({ imageBytes, imageContentType, costTuningConfig })),
  });

  if (!geminiResponse.ok) {
    // エラー本文はクライアントへそのまま伝える (API キーは含まれない)
    throw new GeminiRequestError(
      `Gemini API がエラーを返しました (status=${geminiResponse.status}): ${await geminiResponse.text()}`,
      geminiResponse.status,
    );
  }

  const geminiResponseBody = (await geminiResponse.json()) as {
    candidates?: { content?: { parts?: { text?: string; thought?: boolean }[] } }[];
    usageMetadata?: GeminiUsageMetadata;
  };
  // 1 スキャンあたりの原価を継続的に実測できるよう、トークン数を構造化ログに残す
  // (Workers のログで集計する。issue #50 の受け入れ条件「原価が実測値で記録されている」)
  console.log(
    JSON.stringify({
      event: "gemini_usage",
      model: geminiModel,
      promptTokenCount: geminiResponseBody.usageMetadata?.promptTokenCount ?? 0,
      thoughtsTokenCount: geminiResponseBody.usageMetadata?.thoughtsTokenCount ?? 0,
      candidatesTokenCount: geminiResponseBody.usageMetadata?.candidatesTokenCount ?? 0,
      totalTokenCount: geminiResponseBody.usageMetadata?.totalTokenCount ?? 0,
    }),
  );
  // thinking 対応モデルは thought パートを含み得るため、本文パートだけを結合する
  const outputText = (geminiResponseBody.candidates?.[0]?.content?.parts ?? [])
    .filter((part) => part.thought !== true && typeof part.text === "string")
    .map((part) => part.text)
    .join("");
  if (outputText === "") {
    throw new GeminiRequestError("Gemini API の応答に本文が含まれていません", geminiResponse.status);
  }
  return toImageAnalysisResult(JSON.parse(outputText));
}

/**
 * Gemini の JSON 出力を検証し、不正な明細 (金額が正の整数でない・enum 外・型不一致) を取り除いた結果を返す。
 * 取引日は YYYY-MM-DD として妥当な日付だけを残し、それ以外は null にする。
 */
export function toImageAnalysisResult(geminiOutput: unknown): ImageAnalysisResult {
  const rawTransactions =
    typeof geminiOutput === "object" && geminiOutput !== null && Array.isArray((geminiOutput as { transactions?: unknown }).transactions)
      ? ((geminiOutput as { transactions: unknown[] }).transactions)
      : [];
  const transactions: AnalyzedTransaction[] = [];
  for (const rawTransaction of rawTransactions) {
    if (typeof rawTransaction !== "object" || rawTransaction === null) {
      continue;
    }
    const { title, amount, transactionDate, type, category } = rawTransaction as Record<string, unknown>;
    if (
      typeof amount !== "number" ||
      !Number.isInteger(amount) ||
      amount <= 0 ||
      !analyzedTransactionTypes.includes(type as AnalyzedTransactionType) ||
      !analyzedTransactionCategories.includes(category as AnalyzedTransactionCategory)
    ) {
      continue;
    }
    transactions.push({
      title: typeof title === "string" ? title.trim() : "",
      amount,
      transactionDate: normalizeTransactionDate(transactionDate),
      type: type as AnalyzedTransactionType,
      category: normalizeCategoryForType(type as AnalyzedTransactionType, category as AnalyzedTransactionCategory),
    });
  }
  return { transactions };
}

// type ごとに許されるカテゴリの組み合わせをクライアントの選択体系
// (lib/features/capture/capture_page.dart の _availableCategories: income は salary / other のみ、
// expense は salary 以外) と揃え、外れた組み合わせは other に落とす。
// スキーマ強制は type と category を個別にしか検証できないため、組み合わせはここで正規化する
function normalizeCategoryForType(
  type: AnalyzedTransactionType,
  category: AnalyzedTransactionCategory,
): AnalyzedTransactionCategory {
  if (type === "income") {
    return category === "salary" || category === "other" ? category : "other";
  }
  return category === "salary" ? "other" : category;
}

// YYYY-MM-DD 形式かつ実在する日付だけを残す ("2026-02-30" のような日付は Date が繰り上げるため文字列比較で弾く)
function normalizeTransactionDate(transactionDate: unknown): string | null {
  if (typeof transactionDate !== "string" || !transactionDatePattern.test(transactionDate)) {
    return null;
  }
  const parsedDate = new Date(`${transactionDate}T00:00:00Z`);
  return Number.isNaN(parsedDate.getTime()) || parsedDate.toISOString().slice(0, 10) !== transactionDate
    ? null
    : transactionDate;
}

// Workers には Buffer が無いため、バイト列を分割しながら btoa で base64 化する
// (String.fromCharCode に一度に渡すと引数上限で失敗するため 8KB ずつ処理する)
function arrayBufferToBase64(arrayBuffer: ArrayBuffer): string {
  const bytes = new Uint8Array(arrayBuffer);
  let binaryText = "";
  const chunkSize = 8 * 1024;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binaryText += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binaryText);
}
