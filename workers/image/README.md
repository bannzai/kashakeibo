# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスと、Gemini による明細抽出を一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、検証を通ったリクエストだけが R2 の読み書きと解析を行える。

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」「画像解析」を参照。

AI 画像解析 (Gemini) は、スキャン無料枠 (uid ごとの回数・entitlement 判定) をサーバー側で強制するため本 Worker の解析エンドポイント (`POST /analyses`) が担う。Gemini の API キーは Worker の secret にだけ置き、クライアントへ配布しない。月次の無料枠と entitlement の判定は課金 (issue #12) のスコープで、現時点では日次上限だけを強制する。

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

### DELETE /images/{imageObjectKey}

画像 1 件を削除する (明細から画像だけを外す・明細ごと削除する時に使う)。オブジェクトキーが JWT の uid 配下でない場合は 403。冪等で、対象が無くても 200 を返す。

### DELETE /images

アカウント削除時に、JWT の uid 配下の全オブジェクトを削除する (docs/AccountDeletion.md の「画像は削除操作と同時に削除される」に対応)。クライアントは Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。冪等で、対象が無くても 200 を返す。

### POST /analyses

アップロード済み画像を Gemini vision で解析し、家計簿の明細を抽出する。リクエストは `application/json` の `{"imageObjectKey": "users/{uid}/..."}` (画像はクライアントから再送させず R2 から読む)。

- オブジェクトキーが JWT の uid 配下でない場合は 403、存在しないキーは 404。`src/handler.ts` の `maxAnalysisImageBytes` を超える画像は 413
- 日次解析回数上限 (uid 別・接続元 IP 別・全体の3層。超過は 429) はアップロードとは別のカウンター (`analysis:` プレフィックス) で数える。値は `src/handler.ts` の `maxDailyAnalysisCount*` を参照。上限判定は Gemini 呼び出しの直前に行い、超過時に LLM 原価を発生させない
- Gemini は `generateContent` を構造化出力 (`responseSchema`) で 1 回呼ぶステートレスな呼び出しで、画像・結果とも Gemini 側に保存しない。モデルは wrangler.jsonc の `GEMINI_MODEL`。プロンプト・出力スキーマ・出力の検証は `src/analysis.ts`
- レスポンス: `200 {"transactions": [{"title": "店名", "amount": 872, "transactionDate": "2026-08-16" | null, "type": "income" | "expense", "category": "food" | "eatingOut" | "dailyGoods" | "transportation" | "subscription" | "salary" | "other"}]}`。`type` / `category` は Flutter 側 Entity (`lib/entity/transaction.dart`) と同じ enum 名。紙のレシートは 1 枚 1 件 (合計金額)、明細スクショは取引ごとに 1 件、明細が写っていなければ空配列
- Gemini API のエラーは 502 でエラー本文をそのまま返す (クライアントは手動入力へフォールバックする)

## 開発

```sh
cd workers/image
npm install
npm test        # vitest (@cloudflare/vitest-pool-workers)。R2/KV は miniflare、token 検証はスタブ、Gemini API は fetchMock
npm run typecheck
```

ローカルで Flutter アプリから叩く時は、`.dev.vars` (git 管理外) に `GEMINI_API_KEY=...` を置いて `npx wrangler dev --env dev --port 8787` で起動し、アプリを `--dart-define=IMAGE_API_BASE_URL=http://127.0.0.1:8787` で実行する (iOS シミュレータからホストの 127.0.0.1 に到達できる)。

## デプロイ

Cloudflare 側のリソースは作成済み (2026-08-17):

- R2 バケット: `kashakeibo-images-dev` / `kashakeibo-images-prod`
- KV namespace: `PUBLIC_JWK_CACHE_KV_DEV` / `PUBLIC_JWK_CACHE_KV_PROD` (ID は wrangler.jsonc に記載済み)
- Durable Object (`DailyUploadCounter`) は初回デプロイ時に wrangler.jsonc の migrations から自動作成される

デプロイは environment 必須 (トップレベルに binding を置いていないため、env 指定なしの誤デプロイは失敗する)。解析エンドポイントには Gemini API キーの secret が必要で、環境ごとに一度だけ登録する:

```sh
cd workers/image
npx wrangler secret put GEMINI_API_KEY --env dev    # 値は Google AI Studio の API キー
npx wrangler secret put GEMINI_API_KEY --env prod
npx wrangler deploy --env dev    # → kashakeibo-image-worker-dev
npx wrangler deploy --env prod   # → kashakeibo-image-worker-prod
```

- デプロイ後に表示される `*.workers.dev` URL を Flutter の `--dart-define=IMAGE_API_BASE_URL=...` に渡す
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
