import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

// wrangler.jsonc を参照せず miniflare の binding をここで直接定義する。
// wrangler.jsonc の KV namespace ID はデプロイ時に置き換えるプレースホルダのため、
// テストが設定ファイルの実 ID に依存しないようにしている
export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        miniflare: {
          compatibilityDate: "2025-09-06",
          r2Buckets: ["IMAGE_BUCKET"],
          kvNamespaces: ["PUBLIC_JWK_CACHE_KV"],
          bindings: {
            FIREBASE_PROJECT_ID: "kashakeibo-test",
            PUBLIC_JWK_CACHE_KEY: "firebase-public-jwk-cache",
          },
        },
      },
    },
  },
});
