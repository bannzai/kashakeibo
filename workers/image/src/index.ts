// Worker のエントリポイント。firebase-auth-cloudflare-workers による実際の Firebase ID token 検証と、
// app_check.ts による Firebase App Check token 検証を handler.ts の handleImageRequest に注入する。
// Google の公開 JWK (ID token) と App Check の JWKS は Workers KV にそれぞれ別キーでキャッシュされる。
// 認可ロジック本体とそのテストは handler.ts / test/handler.test.ts、App Check 検証は app_check.ts / test/app_check.test.ts を参照。
import type { EmulatorEnv } from "firebase-auth-cloudflare-workers";
import { Auth, WorkersKVStoreSingle } from "firebase-auth-cloudflare-workers";
import { createFirebaseAppCheckTokenVerifier } from "./app_check";
import { purgeRequestedAuditLogs } from "./audit_log";
import type { ImageWorkerEnv } from "./handler";
import { handleImageRequest } from "./handler";

// Durable Object は Worker のエントリポイントから export する必要がある (wrangler.jsonc の durable_objects 参照)
export { UsageCounter } from "./usage_counter";

// FIREBASE_AUTH_EMULATOR_HOST が設定されている場合はエミュレータの ID token を受け付ける (EmulatorEnv)。
// App Check にはエミュレータが無いため、App Check token の検証は常に実際の JWKS で行う
// (debug ビルドは App Check の debug provider で本物の token を得る。README の「デバッグビルドでの動作確認」参照)
type ImageWorkerBindings = ImageWorkerEnv & EmulatorEnv;

export default {
  async fetch(request: Request, env: ImageWorkerBindings): Promise<Response> {
    return handleImageRequest(request, env, {
      verifyFirebaseIdToken: async (firebaseIdToken) => {
        const firebaseAuth = Auth.getOrInitialize(
          env.FIREBASE_PROJECT_ID,
          WorkersKVStoreSingle.getOrInitialize(env.PUBLIC_JWK_CACHE_KEY, env.PUBLIC_JWK_CACHE_KV),
        );
        // checkRevoked=false: revoke 判定には service account credential が必要で、
        // 失効反映の即時性よりサーバー側に credential を持たないシンプルさを優先する (ID token は最長1時間で失効する)
        const firebaseIdTokenPayload = await firebaseAuth.verifyIdToken(firebaseIdToken, false, env);
        return { uid: firebaseIdTokenPayload.uid };
      },
      verifyFirebaseAppCheckToken: createFirebaseAppCheckTokenVerifier({
        firebaseProjectId: env.FIREBASE_PROJECT_ID,
        jwksCache: { kvNamespace: env.PUBLIC_JWK_CACHE_KV, cacheKey: env.APP_CHECK_JWKS_CACHE_KEY },
      }),
    });
  },

  // アカウント削除で予約された監査ログのパージを実行する (wrangler.jsonc の triggers.crons で毎時起動)。
  // 予約から実行までを分ける理由と、失敗した予約の再試行は src/audit_log.ts を参照
  async scheduled(_scheduledController: ScheduledController, env: ImageWorkerBindings): Promise<void> {
    await purgeRequestedAuditLogs(env);
  },
} satisfies ExportedHandler<ImageWorkerBindings>;
