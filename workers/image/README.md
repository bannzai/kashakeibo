# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスを一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、さらに Firebase App Check token を `src/app_check.ts` で検証して (公開鍵 JWKS は同じ KV に別キーでキャッシュ)、両方の検証を通ったリクエストだけが R2 を読み書きできる。

- ID token は「誰のリクエストか」(uid) を、App Check token は「正規のアプリからのリクエストか」を判定する。匿名認証の ID token は公開クライアント設定から誰でも取得できるため、ID token だけでは正規アプリ由来かを判定できない
- firebase-auth-cloudflare-workers (2.0.6) は App Check token の検証 API を持たないため、Firebase Admin SDK の AppCheckTokenVerifier と同じ手順 (alg / iss / aud / sub / exp / iat / RS256 署名) を `src/app_check.ts` に Web Crypto で実装している
- App Check は「量」の制限にはならないため、日次アップロード回数上限はそのまま併用する

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」を参照。

AI 画像解析 (Gemini) の呼び出しも、スキャン無料枠 (uid ごとの回数・entitlement 判定) をサーバー側で強制するため本 Worker に解析エンドポイントとして相乗りする設計 (同 ADR の「画像解析」の項)。解析エンドポイントの実装は issue #7 のスコープで、本 Worker は現時点でアップロード・取得のみを提供する。

## API

すべてのエンドポイントで `Authorization: Bearer <Firebase ID token>` と `X-Firebase-AppCheck: <Firebase App Check token>` の両方が必須。どちらかの欠落・検証失敗は 401 (両方通って初めて後続の処理に進む)。

### POST /images

multipart/form-data の `file` フィールドで画像をアップロードする。`X-Upload-Id` ヘッダーに、クライアントが論理アップロードごとに生成する UUID が必須 (欠落・UUID 形式外は 400)。

- オブジェクトキーは `users/{JWTのuid}/{X-Upload-Id}.{拡張子}` を Worker 側で組み立てる。uid プレフィックスは JWT から強制し、クライアント申告のパス・ファイル名は使わない
- 同じ `X-Upload-Id` での再試行は同じキーへの上書きになる (冪等)。レスポンスが届かなかった再試行でも孤児オブジェクトが残らない
- 対応 Content-Type・上限サイズ・日次アップロード回数上限 (uid 別・接続元 IP 別・全体の3層。超過は 429) は `src/handler.ts` の `imageContentTypeExtensions` / `maxImageBytes` / `maxDailyUploadCount*` を参照。空ファイルは 400。回数の判定と加算は日次シングルトンの Durable Object (`src/upload_counter.ts`) で直列化し、並行リクエストによる上限すり抜けを防ぐ。保存済みキーへの再試行はカウントを消費しない
- レスポンス: `201 {"imageObjectKey": "users/{uid}/{X-Upload-Id}.{拡張子}"}`。Firestore の明細にはこのキーを保存する (配信ドメインはデプロイ時に決まるため URL ではなくキーを保存する)

### GET /images/{imageObjectKey}

アップロード済み画像を取得する。オブジェクトキーが JWT の uid 配下 (`users/{uid}/`) でない場合は 403。存在しないキーは 404。

### DELETE /images

アカウント削除時に、JWT の uid 配下の全オブジェクトを削除する (docs/AccountDeletion.md の「画像は削除操作と同時に削除される」に対応)。クライアントは Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。冪等で、対象が無くても 200 を返す。

## 開発

```sh
cd workers/image
npm install
npm test        # vitest (@cloudflare/vitest-pool-workers)。R2/KV は miniflare、token 検証はスタブ
npm run typecheck
```

## デバッグビルドでの動作確認 (App Check debug token)

Flutter の debug ビルドは App Check の debug provider (`lib/utils/firebase_app_check/firebase_app_check.dart`) を使う。debug provider は端末ごとに生成した debug token を Firebase に登録しておくと、その端末からの App Check token が有効になる (未登録の debug token では App Check token が発行されず、Worker は 401 を返す)。

1. debug ビルドを起動し、コンソールに出力される debug token を控える
   - iOS: `xcrun simctl spawn <UDID> log show --last 2m --predicate 'process == "Runner"' | grep "App Check debug token"` で出る `App Check debug token: '<UUID>'` (Xcode / `flutter run` のログでも同じ行が出る)
   - Android: logcat の `DebugAppCheckProvider: Enter this debug secret into the allow list in the Firebase Console for your project: <UUID>`
   - debug ビルドの bundle ID は `com.bannzai.kashakeibo.dev` なので、`ios/Firebase/dev/GoogleService-Info.plist` は kashakeibo-dev の「kashakeibo dev」iOS アプリ (`BUNDLE_ID` が `com.bannzai.kashakeibo.dev`) のものを置く。`com.bannzai.kashakeibo` 用の古い plist だと API key の bundle ID 制限で `API_KEY_IOS_APP_BLOCKED` になり、Firebase Auth も App Check の debug token 交換も失敗する (2026-08-19 の疎通確認で実際に踏んだ)
2. debug token を **kashakeibo-dev にだけ** 登録する。App Check REST API (`projects.apps.debugTokens.create`) で登録できる (Firebase Console の App Check → アプリ → デバッグトークンを管理、でも可)。`<appId>` は dev の Firebase App ID (`ios/Firebase/dev/GoogleService-Info.plist` の `GOOGLE_APP_ID` / `android/app/src/debug/google-services.json` の `mobilesdk_app_id`)

   ```sh
   DEBUG_TOKEN='<手順1で控えた UUID>'
   [ -n "$DEBUG_TOKEN" ] || { echo "DEBUG_TOKEN is empty" >&2; exit 1; }
   curl -X POST \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     "https://firebaseappcheck.googleapis.com/v1/projects/kashakeibo-dev/apps/<appId>/debugTokens" \
     -d "{\"displayName\": \"<端末名など>\", \"token\": \"$DEBUG_TOKEN\"}"
   ```

   - kashakeibo-prod には debug token を登録しない。本番に登録すると、DeviceCheck / Play Integrity の attest を通らなくても端末ログに出力される静的な debug secret だけで本番向け App Check token を発行できるようになり、secret がログや共有資料から漏れた時に「正規アプリ由来」の制限を任意のスクリプトから迂回できる。debug ビルドは kashakeibo-dev に接続する構成 (`lib/main.dart`) なので、dev への登録だけで動作確認は足りる

3. アプリを再起動すると debug provider が有効な App Check token を取得し、Worker へのリクエスト (`X-Firebase-AppCheck` ヘッダー) が通る

- Emulator ビルド (`--dart-define=USE_FIREBASE_EMULATOR=true`) は App Check を有効化しないため Worker を呼び出せない (App Check にはエミュレータが無く、Worker 側にも検証のバイパスを設けていない)。Worker の動作確認は debug ビルド (kashakeibo-dev) で行う
- Worker 単体の確認は `npm test` (App Check token の検証は `test/app_check.test.ts` でテスト内生成の RSA 鍵と JWT で検証。handler の認可は `test/handler.test.ts` でスタブ検証器を注入)

## デプロイ

Cloudflare 側のリソースは作成済み (2026-08-17):

- R2 バケット: `kashakeibo-images-dev` / `kashakeibo-images-prod`
- KV namespace: `PUBLIC_JWK_CACHE_KV_DEV` / `PUBLIC_JWK_CACHE_KV_PROD` (ID は wrangler.jsonc に記載済み)
- Durable Object (`DailyUploadCounter`) は初回デプロイ時に wrangler.jsonc の migrations から自動作成される

デプロイは environment 必須 (トップレベルに binding を置いていないため、env 指定なしの誤デプロイは失敗する):

```sh
cd workers/image
npx wrangler deploy --env dev    # → kashakeibo-image-worker-dev
npx wrangler deploy --env prod   # → kashakeibo-image-worker-prod
```

- デプロイ後に表示される `*.workers.dev` URL を Flutter の `--dart-define=IMAGE_API_BASE_URL=...` に渡す。dev は `https://kashakeibo-image-worker-dev.star-kojiki.workers.dev`、prod は `https://kashakeibo-image-worker-prod.star-kojiki.workers.dev` (どちらも 2026-08-19 に初回デプロイ済み)
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
