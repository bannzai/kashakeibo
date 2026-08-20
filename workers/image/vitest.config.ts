import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

// wrangler.jsonc を参照せず miniflare の binding をここで直接定義する。
// wrangler.jsonc の KV namespace ID はデプロイ時に置き換えるプレースホルダのため、
// テストが設定ファイルの実 ID に依存しないようにしている
export default defineWorkersConfig({
  test: {
    // 日次上限のテストは Durable Object を上限回数 (最大 5000 回) 呼んでカウンターを埋めるため、
    // 負荷の高いマシン・CI では既定の 5 秒を超えることがある
    testTimeout: 30_000,
    poolOptions: {
      workers: {
        main: "./src/index.ts",
        miniflare: {
          compatibilityDate: "2025-09-06",
          r2Buckets: ["IMAGE_BUCKET"],
          kvNamespaces: ["PUBLIC_JWK_CACHE_KV"],
          durableObjects: {
            USAGE_COUNTER: "UsageCounter",
          },
          bindings: {
            FIREBASE_PROJECT_ID: "kashakeibo-test",
            PUBLIC_JWK_CACHE_KEY: "firebase-public-jwk-cache",
            APP_CHECK_JWKS_CACHE_KEY: "firebase-app-check-jwks-cache",
            GEMINI_API_KEY: "test-gemini-api-key",
            GEMINI_MODEL: "gemini-test-model",
            REVENUECAT_SECRET_API_KEY: "test-revenuecat-secret-api-key",
            REVENUECAT_PROJECT_ID: "projtest",
            REVENUECAT_PREMIUM_ENTITLEMENT_ID: "entltestpremium",
          },
        },
      },
    },
  },
});
