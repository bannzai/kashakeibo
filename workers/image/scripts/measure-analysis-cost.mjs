// スキャン 1 回あたりの Gemini 原価 (トークン数・円) と抽出精度を実測する (issue #50)。
// 本番と同じリクエスト組み立て (src/analysis.ts の buildGeminiAnalysisRequestBody) で
// scripts/generate-analysis-fixtures.py が生成したテスト画像を解析し、
// usageMetadata と正解データ (ground-truth.json) との突き合わせ結果を表示する。
//
// 実行 (workers/image で):
//   python3 scripts/generate-analysis-fixtures.py
//   node --experimental-strip-types scripts/measure-analysis-cost.mjs [設定キー ...]
// 設定キー省略時は全設定を実行する。API キーは .dev.vars の GEMINI_API_KEY を使う。
// 冪等: 読み取り専用の Gemini 呼び出しと結果ファイルの上書き出力のみ。
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildGeminiAnalysisRequestBody, toImageAnalysisResult } from "../src/analysis.ts";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const fixturesDirectory = process.env.FIXTURES_DIR ?? path.join(scriptDirectory, "..", "tmp", "analysis-fixtures");

// 単価 (USD / 100万トークン、standard tier)。出典: https://ai.google.dev/gemini-api/docs/pricing (2026-09-01 取得)。
// gemini-3.7-flash は 2026-12-31 までの単価で、2027-01-01 から input $1.50 / output $7.50 に倍増する。
// thinking トークンは output 単価で課金される
const modelPricesUsdPerMillionTokens = {
  "gemini-3.7-flash": { input: 0.75, output: 3.75 },
  "gemini-3.5-flash-lite": { input: 0.3, output: 2.5 },
  "gemini-3.1-flash-lite": { input: 0.25, output: 1.5 },
};

// 円換算の概算レート。原価の桁感の把握が目的のため固定値でよい (2026-08 時点の概算)
const jpyPerUsd = 150;

/** 実測する設定の一覧。キーが CLI 引数で指定する設定キー。 */
const measurementConfigs = {
  "3.7-flash-baseline": { model: "gemini-3.7-flash", costTuningConfig: {} },
  "3.7-flash-think-low": { model: "gemini-3.7-flash", costTuningConfig: { thinkingLevel: "low" } },
  "3.7-flash-think-low-media-low": {
    model: "gemini-3.7-flash",
    costTuningConfig: { thinkingLevel: "low", mediaResolution: "MEDIA_RESOLUTION_LOW" },
  },
  "3.7-flash-think-low-media-medium": {
    model: "gemini-3.7-flash",
    costTuningConfig: { thinkingLevel: "low", mediaResolution: "MEDIA_RESOLUTION_MEDIUM" },
  },
  "3.5-flash-lite-baseline": { model: "gemini-3.5-flash-lite", costTuningConfig: {} },
  "3.5-flash-lite-think-low": { model: "gemini-3.5-flash-lite", costTuningConfig: { thinkingLevel: "low" } },
  "3.1-flash-lite-baseline": { model: "gemini-3.1-flash-lite", costTuningConfig: {} },
  "3.1-flash-lite-media-low": { model: "gemini-3.1-flash-lite", costTuningConfig: { mediaResolution: "MEDIA_RESOLUTION_LOW" } },
  "3.1-flash-lite-think-low": { model: "gemini-3.1-flash-lite", costTuningConfig: { thinkingLevel: "low" } },
  "3.1-flash-lite-think-low-media-low": {
    model: "gemini-3.1-flash-lite",
    costTuningConfig: { thinkingLevel: "low", mediaResolution: "MEDIA_RESOLUTION_LOW" },
  },
};

/** .dev.vars から GEMINI_API_KEY を読む。 */
function readGeminiApiKey() {
  for (const devVarsLine of readFileSync(path.join(scriptDirectory, "..", ".dev.vars"), "utf8").split("\n")) {
    const [devVarsKey, ...devVarsValueParts] = devVarsLine.split("=");
    if (devVarsKey === "GEMINI_API_KEY") {
      return devVarsValueParts.join("=").trim().replace(/^"|"$/g, "");
    }
  }
  throw new Error(".dev.vars に GEMINI_API_KEY がありません");
}

/** 1 画像を 1 設定で解析し、usageMetadata・原価・抽出結果を返す。 */
async function measureSingleAnalysis({ geminiApiKey, model, costTuningConfig, imageFileName }) {
  const imageBytes = readFileSync(path.join(fixturesDirectory, imageFileName));
  const requestStartedAt = Date.now();
  const geminiResponse = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": geminiApiKey },
    body: JSON.stringify(
      buildGeminiAnalysisRequestBody({
        imageBytes: imageBytes.buffer.slice(imageBytes.byteOffset, imageBytes.byteOffset + imageBytes.byteLength),
        imageContentType: "image/jpeg",
        costTuningConfig,
      }),
    ),
  });
  const latencyMs = Date.now() - requestStartedAt;
  if (!geminiResponse.ok) {
    return { imageFileName, error: `status=${geminiResponse.status}: ${await geminiResponse.text()}` };
  }
  const geminiResponseBody = await geminiResponse.json();
  const outputText = (geminiResponseBody.candidates?.[0]?.content?.parts ?? [])
    .filter((part) => part.thought !== true && typeof part.text === "string")
    .map((part) => part.text)
    .join("");
  const usageMetadata = geminiResponseBody.usageMetadata ?? {};
  const promptTokenCount = usageMetadata.promptTokenCount ?? 0;
  const thoughtsTokenCount = usageMetadata.thoughtsTokenCount ?? 0;
  const candidatesTokenCount = usageMetadata.candidatesTokenCount ?? 0;
  const modelPrice = modelPricesUsdPerMillionTokens[model];
  const costUsd =
    (promptTokenCount * modelPrice.input + (thoughtsTokenCount + candidatesTokenCount) * modelPrice.output) / 1_000_000;
  return {
    imageFileName,
    latencyMs,
    promptTokenCount,
    thoughtsTokenCount,
    candidatesTokenCount,
    costUsd,
    costJpy: costUsd * jpyPerUsd,
    analysisResult: toImageAnalysisResult(JSON.parse(outputText)),
  };
}

/** タイトル一致判定用の正規化 (空白除去・小文字化)。 */
function normalizeTitle(title) {
  return (title ?? "").replace(/\s+/g, "").toLowerCase();
}

/** 抽出結果を正解データと突き合わせ、正解明細ごとの一致状況を返す。金額で突き合わせる (同一画像内で金額は一意)。 */
function scoreAgainstGroundTruth({ expectedTransactions, analysisResult }) {
  return {
    expectedCount: expectedTransactions.length,
    extractedCount: analysisResult.transactions.length,
    matches: expectedTransactions.map((expectedTransaction) => {
      const extractedTransaction = analysisResult.transactions.find(
        (transaction) => transaction.amount === expectedTransaction.amount,
      );
      // タイトルは正解の title と titleAliases (レシート上に併記される別表記。例: ローマ字ロゴとカタカナ店名) の
      // いずれかに一致すればよい。抽出側は「Amazon.co.jp ワイヤレスイヤホン…」のようにサイト名等の前置きが
      // 付くことがあるため包含を一致とみなす。正解タイトル全体が抽出側に含まれる場合は長さ不問
      // (「王将」のような短い正式店名を構造的に落とさない)。逆方向 (抽出側が正解の一部だけ) は、
      // 1〜2文字の偶然の部分一致を合格させないよう 4文字以上かつ正解の半分以上の長さであることを要求する
      const normalizedExtractedTitle = normalizeTitle(extractedTransaction?.title);
      const titleMatched =
        extractedTransaction !== undefined &&
        ((expectedTransaction.title === "" && normalizedExtractedTitle === "") ||
          [expectedTransaction.title, ...(expectedTransaction.titleAliases ?? [])].some((candidateTitle) => {
            const normalizedCandidateTitle = normalizeTitle(candidateTitle);
            if (normalizedCandidateTitle === "" || normalizedExtractedTitle === "") {
              return false;
            }
            if (normalizedExtractedTitle.includes(normalizedCandidateTitle)) {
              return true;
            }
            return (
              normalizedCandidateTitle.includes(normalizedExtractedTitle) &&
              normalizedExtractedTitle.length >= 4 &&
              normalizedExtractedTitle.length * 2 >= normalizedCandidateTitle.length
            );
          }));
      return {
        expectedTitle: expectedTransaction.title,
        amountMatched: extractedTransaction !== undefined,
        titleMatched,
        dateMatched: extractedTransaction?.transactionDate === expectedTransaction.transactionDate,
        typeMatched: extractedTransaction?.type === expectedTransaction.type,
        // categoryAliases は正解が一意に決まらない境界ケース (例: ベーカリーの food / eatingOut) の許容値
        categoryMatched: [expectedTransaction.category, ...(expectedTransaction.categoryAliases ?? [])].includes(
          extractedTransaction?.category,
        ),
        extractedTitle: extractedTransaction?.title ?? null,
        extractedCategory: extractedTransaction?.category ?? null,
      };
    }),
  };
}

const geminiApiKey = readGeminiApiKey();
const groundTruth = JSON.parse(readFileSync(path.join(fixturesDirectory, "ground-truth.json"), "utf8"));
const configKeysToRun = process.argv.slice(2).length > 0 ? process.argv.slice(2) : Object.keys(measurementConfigs);

const allResults = {};
for (const configKey of configKeysToRun) {
  const measurementConfig = measurementConfigs[configKey];
  if (measurementConfig === undefined) {
    console.error(`未知の設定キー: ${configKey} (候補: ${Object.keys(measurementConfigs).join(", ")})`);
    process.exit(1);
  }
  console.log(`\n=== ${configKey} (model=${measurementConfig.model}) ===`);
  const configResults = [];
  for (const imageFileName of Object.keys(groundTruth)) {
    const measurement = await measureSingleAnalysis({ geminiApiKey, imageFileName, ...measurementConfig });
    if (measurement.error !== undefined) {
      console.log(`${imageFileName}: ERROR ${measurement.error}`);
      configResults.push(measurement);
      continue;
    }
    const score = scoreAgainstGroundTruth({
      expectedTransactions: groundTruth[imageFileName],
      analysisResult: measurement.analysisResult,
    });
    // 正解に無い明細を水増しした構成を合格扱いしないよう、件数一致 (extractedCount === expectedCount) を全項目一致の必須条件にする
    const extractedCountMatched = score.extractedCount === score.expectedCount;
    const fieldMatchCount = extractedCountMatched
      ? score.matches.filter(
          (match) => match.amountMatched && match.titleMatched && match.dateMatched && match.typeMatched && match.categoryMatched,
        ).length
      : 0;
    if (!extractedCountMatched) {
      console.log(`  件数不一致: 抽出 ${score.extractedCount} 件 / 正解 ${score.expectedCount} 件 (全項目一致 0 扱い)`);
    }
    console.log(
      `${imageFileName}: in=${measurement.promptTokenCount} think=${measurement.thoughtsTokenCount} out=${measurement.candidatesTokenCount}` +
        ` cost=¥${measurement.costJpy.toFixed(4)} (${measurement.latencyMs}ms)` +
        ` 明細 ${score.extractedCount}/${score.expectedCount}件 全項目一致 ${fieldMatchCount}/${score.expectedCount}件`,
    );
    for (const match of score.matches) {
      if (!(match.amountMatched && match.titleMatched && match.dateMatched && match.typeMatched && match.categoryMatched)) {
        console.log(`  不一致: ${match.expectedTitle} -> ${JSON.stringify(match)}`);
      }
    }
    configResults.push({ ...measurement, score });
  }
  const successfulResults = configResults.filter((result) => result.error === undefined);
  if (successfulResults.length > 0) {
    const averageCostJpy = successfulResults.reduce((total, result) => total + result.costJpy, 0) / successfulResults.length;
    console.log(
      `平均: ¥${averageCostJpy.toFixed(4)}/スキャン | 月50スキャン=¥${(averageCostJpy * 50).toFixed(2)}/ユーザー | 月1000スキャン=¥${(averageCostJpy * 1000).toFixed(2)}/ユーザー`,
    );
  }
  allResults[configKey] = configResults;
}

// 完了報告・PR に載せる証拠として結果全体を書き出す
const resultsFilePath = path.join(fixturesDirectory, "measurement-results.json");
writeFileSync(resultsFilePath, JSON.stringify(allResults, null, 2));
console.log(`\n結果を書き出しました: ${resultsFilePath}`);
