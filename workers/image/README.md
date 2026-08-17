# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスを一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、検証を通ったリクエストだけが R2 を読み書きできる。

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」を参照。

AI 画像解析 (Gemini) の呼び出しも、スキャン無料枠 (uid ごとの回数・entitlement 判定) をサーバー側で強制するため本 Worker に解析エンドポイントとして相乗りする設計 (同 ADR の「画像解析」の項)。解析エンドポイントの実装は issue #7 のスコープで、本 Worker は現時点でアップロード・取得のみを提供する。

## API

すべてのエンドポイントで `Authorization: Bearer <Firebase ID token>` が必須。未認証・検証失敗は 401。

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

- デプロイ後に表示される `*.workers.dev` URL を Flutter の `--dart-define=IMAGE_API_BASE_URL=...` に渡す
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
