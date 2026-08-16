# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスを一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、検証を通ったリクエストだけが R2 を読み書きできる。

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」を参照。

## API

すべてのエンドポイントで `Authorization: Bearer <Firebase ID token>` が必須。未認証・検証失敗は 401。

### POST /images

multipart/form-data の `file` フィールドで画像をアップロードする。

- オブジェクトキーは JWT の uid から `users/{uid}/{UUID}.{拡張子}` を Worker 側で生成する。クライアント申告のパス・ファイル名は使わない
- 対応 Content-Type と上限サイズは `src/handler.ts` の `imageContentTypeExtensions` / `maxImageBytes` を参照
- レスポンス: `201 {"imageObjectKey": "users/{uid}/{UUID}.{拡張子}"}`。Firestore の明細にはこのキーを保存する (配信ドメインはデプロイ時に決まるため URL ではなくキーを保存する)

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
