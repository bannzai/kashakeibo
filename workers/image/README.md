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
- 対応 Content-Type・上限サイズ・日次アップロード回数上限 (uid 別・接続元 IP 別・全体の3層。超過は 429) は `src/handler.ts` の `imageContentTypeExtensions` / `maxImageBytes` / `maxDailyUploadCount*` を参照。空ファイルは 400
- レスポンス: `201 {"imageObjectKey": "users/{uid}/{X-Upload-Id}.{拡張子}"}`。Firestore の明細にはこのキーを保存する (配信ドメインはデプロイ時に決まるため URL ではなくキーを保存する)

### GET /images/{imageObjectKey}

アップロード済み画像を取得する。オブジェクトキーが JWT の uid 配下 (`users/{uid}/`) でない場合は 403。存在しないキーは 404。

## 開発

```sh
cd workers/image
npm install
npm test        # vitest (@cloudflare/vitest-pool-workers)。R2/KV は miniflare、token 検証はスタブ
npm run typecheck
```

## デプロイ (未実施・要ユーザー承認)

Cloudflare アカウント配下へのリソース作成を伴うため、初回は以下を手動 (または承認の上で agent が) 実行する。

```sh
cd workers/image

# 1. R2 バケット作成 (bucket_name は wrangler.jsonc と一致させる)
npx wrangler r2 bucket create kashakeibo-images

# 2. JWK キャッシュ用 KV namespace 作成 → 出力された id を wrangler.jsonc の REPLACE_WITH_KV_NAMESPACE_ID に反映
npx wrangler kv namespace create PUBLIC_JWK_CACHE_KV

# 3. wrangler.jsonc の REPLACE_WITH_FIREBASE_PROJECT_ID を Firebase プロジェクト ID に置き換え (issue #3 で作成)

# 4. デプロイ
npx wrangler deploy
```

- dev / prod の Firebase プロジェクトを分ける場合は wrangler の [environments](https://developers.cloudflare.com/workers/wrangler/environments/) (`env.dev` / `env.prod`) で `FIREBASE_PROJECT_ID`・バケット・KV を分ける
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
