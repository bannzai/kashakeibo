// Worker のエントリポイント。firebase-auth-cloudflare-workers による実際の Firebase ID token 検証を
// handler.ts の handleImageRequest に注入する。Google の公開 JWK は Workers KV にキャッシュされる。
// 認可ロジック本体とそのテストは handler.ts / test/handler.test.ts を参照。
import type { EmulatorEnv } from "firebase-auth-cloudflare-workers";
import { Auth, WorkersKVStoreSingle } from "firebase-auth-cloudflare-workers";
import type { ImageWorkerEnv } from "./handler";
import { handleImageRequest } from "./handler";

// FIREBASE_AUTH_EMULATOR_HOST が設定されている場合はエミュレータの token を受け付ける (EmulatorEnv)
type ImageWorkerBindings = ImageWorkerEnv & EmulatorEnv;

export default {
  async fetch(request: Request, env: ImageWorkerBindings): Promise<Response> {
    return handleImageRequest(request, env, async (firebaseIdToken) => {
      const firebaseAuth = Auth.getOrInitialize(
        env.FIREBASE_PROJECT_ID,
        WorkersKVStoreSingle.getOrInitialize(env.PUBLIC_JWK_CACHE_KEY, env.PUBLIC_JWK_CACHE_KV),
      );
      // checkRevoked=false: revoke 判定には service account credential が必要で、
      // 失効反映の即時性よりサーバー側に credential を持たないシンプルさを優先する (ID token は最長1時間で失効する)
      const firebaseIdTokenPayload = await firebaseAuth.verifyIdToken(firebaseIdToken, false, env);
      return { uid: firebaseIdTokenPayload.uid };
    });
  },
} satisfies ExportedHandler<ImageWorkerBindings>;
