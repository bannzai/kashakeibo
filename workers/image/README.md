# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスと、Gemini による明細抽出を一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、さらに Firebase App Check token を `src/app_check.ts` で検証して (公開鍵 JWKS は同じ KV に別キーでキャッシュ)、両方の検証を通ったリクエストだけが R2 の読み書きと解析を行える。

- ID token は「誰のリクエストか」(uid) を、App Check token は「正規のアプリからのリクエストか」を判定する。匿名認証の ID token は公開クライアント設定から誰でも取得できるため、ID token だけでは正規アプリ由来かを判定できない
- firebase-auth-cloudflare-workers (2.0.6) は App Check token の検証 API を持たないため、Firebase Admin SDK の AppCheckTokenVerifier と同じ手順 (alg / iss / aud / sub / exp / iat / RS256 署名) を `src/app_check.ts` に Web Crypto で実装している
- App Check は「量」の制限にはならないため、日次のアップロード・解析回数上限はそのまま併用する

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」「画像解析」を参照。

AI 画像解析 (Gemini) は、スキャン無料枠 (uid ごとの月次回数・entitlement 判定) をサーバー側で強制するため本 Worker の解析エンドポイント (`POST /analyses`) が担う。Gemini の API キーは Worker の secret にだけ置き、クライアントへ配布しない。無料枠 (月50スキャン。documents/PROJECT.md の課金設計) を超えた解析は、RevenueCat のプレミアム entitlement をサーバー側で確認したユーザーだけに許可する (`src/entitlement.ts`。クライアント申告のプレミアム状態は信用しない)。

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
- スキャン無料枠: uid ごとに今月 (UTC の暦月) の解析回数を数え、`src/handler.ts` の `monthlyFreeScanLimit` (50) までは無条件に解析する。使い切った後は RevenueCat API v2 の `active_entitlements` を uid (= クライアントが `Purchases.logIn` に渡す app user ID) で引き、`REVENUECAT_PREMIUM_ENTITLEMENT_ID` の entitlement が有効なら `monthlyPremiumScanLimit` (1000。プレミアムでも LLM 原価の上限を固定する月次キャップ。到達時は 429) の範囲で解析する。有効でなければ `402 {"error": "...", "monthlyScanCount": 50, "monthlyFreeScanLimit": 50}` を返し、クライアントはペイウォールを表示する。RevenueCat API の失敗 (5xx・接続不能) は 402 と区別して 503 で返す (再試行可)。判定は日次上限 (429) の後、Gemini 呼び出しの前に行い、無料枠内の解析では RevenueCat を呼ばない。RevenueCat の設定 (`REVENUECAT_SECRET_API_KEY` / `REVENUECAT_PROJECT_ID` / `REVENUECAT_PREMIUM_ENTITLEMENT_ID`) が無い環境では全ユーザーを無料プランとして扱う (無料枠だけを強制する fail-closed)。回数の判定と加算は月次シングルトンの Durable Object (`src/usage_counter.ts`。日次カウンターと同じクラスの別インスタンス) で直列化する

### GET /analyses/quota

今月のスキャン (解析) 回数と無料枠の上限を返す: `200 {"monthlyScanCount": 3, "monthlyFreeScanLimit": 50}`。クライアントは残量チップの表示 (`monthlyFreeScanLimit - monthlyScanCount`) と、残量 0 でのペイウォール表示判定に使う。プレミアムかどうかはクライアントが RevenueCat SDK (`CustomerInfo`) から直接得るため含めない。

## スキャン原価 (実測)

1 スキャンあたりの LLM 原価の実測 (issue #50。2026-08-22、合成テスト画像 4 枚: 紙レシート2・明細スクショ2、円換算 150円/USD)。
単価の出典は https://ai.google.dev/gemini-api/docs/pricing (thinking トークンは output 単価で課金)。

| 構成 | 平均原価/スキャン | 抽出精度 (店名・金額・日付・カテゴリ・件数) |
| --- | --- | --- |
| gemini-3.7-flash (旧採用・既定設定) | 約 ¥0.38 | 全問一致 |
| gemini-3.7-flash + thinkingLevel low | 約 ¥0.27 | 全問一致 |
| **gemini-3.1-flash-lite (採用・既定設定)** | **約 ¥0.09** | **全問一致 (劣化画像セットでも全問一致)** |
| gemini-3.1-flash-lite + mediaResolution low (単独) | 約 ¥0.06 | 全問一致 (不採用: 下記) |

- 採用: モデルを `gemini-3.1-flash-lite` へ切替 (原価 約1/4)。thinking は既定で発生しない。カテゴリ判定の揺れ (EC の家電・ガジェットが dailyGoods になる) はプロンプトのカテゴリ定義の明確化 (`src/analysis.ts`) で解消を確認済み
- 不採用: `mediaResolution` の引き下げ (単独実測で入力 1,396→598 トークン・原価 約34% 減 (¥0.089→¥0.059) と削減は大きいが、画像のトークン割当が約1/4 になるため、実レシートの細かい印字の読み取り低下リスクを合成画像だけでは否定できず見送り。実レシートでの精度検証とセットで再検討する。既定は画像1枚 約1,120トークンの固定割当)。thinkingLevel low の付与 (3.1-flash-lite は既定 thinking なしのため、付与すると逆に thinking が発生して原価増)。クライアント縮小の強化 (画像のトークン数は mediaResolution 固定割当のため長辺 1600→1024 でも入力トークン不変)。同一画像の再解析キャッシュ (再試行頻度が未知で効果を見積もれないため見送り)
- 月額原価の目安: 無料ユーザー上限 = 月50スキャン × ¥0.09 ≒ ¥4.5/ユーザー。プレミアム上限 = 月1000スキャン × ¥0.09 ≒ ¥90/ユーザー (< 月額 ¥480)
- 再実測の手順 (workers/image で。API キーは `.dev.vars` の `GEMINI_API_KEY`)。フィクスチャ生成に Pillow を使うため、初回のみ `scripts/requirements.txt` で導入する (実測時のバージョンで結果が再現するようピン留めしている):

```sh
python3 -m pip install -r scripts/requirements.txt   # 初回のみ
python3 scripts/generate-analysis-fixtures.py
node --experimental-strip-types scripts/measure-analysis-cost.mjs            # 全構成
node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.1-flash-lite-baseline   # 構成指定
FIXTURES_DIR=tmp/analysis-fixtures-degraded node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.1-flash-lite-baseline   # 劣化セット
```

- 本番のトークン数は `src/analysis.ts` が解析ごとに `{"event":"gemini_usage",...}` の構造化ログで記録する (Workers のログで集計できる)
- **実レシートベンチマーク**: Wikimedia Commons の再配布可能な実レシート 13 枚 (`benchmark/`) で、モデル・プロンプト変更時の品質回帰を検証する。基準値 (採用構成で全項目一致 13/13・約 ¥0.070/スキャン)・出典・実行手順は `benchmark/README.md` を参照。実レシートでも mediaResolution low は全項目一致 (約 ¥0.040) だったため、上記の不採用判断はサンプル数を増やした上で再検討の余地がある

## 開発

```sh
cd workers/image
npm install
npm test        # vitest (@cloudflare/vitest-pool-workers)。R2/KV は miniflare、token 検証はスタブ、Gemini API は fetchMock
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

## ローカル開発 (wrangler dev)

ローカルで Flutter アプリから叩く時は、`.dev.vars` (git 管理外) に `GEMINI_API_KEY=...` を置いて `npx wrangler dev --env dev --port 8787` で起動し、アプリを `--dart-define=IMAGE_API_BASE_URL=http://127.0.0.1:8787` で実行する (iOS シミュレータからホストの 127.0.0.1 に到達できる)。App Check token の検証は wrangler dev でも実際の JWKS で行われるため、上記の debug token の登録が必要。

Flutter アプリは debug ビルドでは dev `https://kashakeibo-image-worker-dev.star-kojiki.workers.dev`、release / profile ビルドでは prod `https://kashakeibo-image-worker-prod.star-kojiki.workers.dev` を既定で使う。`IMAGE_API_BASE_URL` は上記のローカル開発などで接続先を上書きするために使う。


## デプロイ

Cloudflare 側のリソースは作成済み (2026-08-17):

- R2 バケット: `kashakeibo-images-dev` / `kashakeibo-images-prod`
- KV namespace: `PUBLIC_JWK_CACHE_KV_DEV` / `PUBLIC_JWK_CACHE_KV_PROD` (ID は wrangler.jsonc に記載済み)
- Durable Object (`UsageCounter`。v1 では `DailyUploadCounter` の名前で作成され、v2 の migration で改名) は初回デプロイ時に wrangler.jsonc の migrations から自動作成される

デプロイは environment 必須 (トップレベルに binding を置いていないため、env 指定なしの誤デプロイは失敗する)。解析エンドポイントには Gemini API キーの secret が必要で、環境ごとに一度だけ登録する。スキャン無料枠超過時のプレミアム判定には RevenueCat の secret API key (v2、`customer_information:customers:read` 権限。`~/.claude/skills/revenuecat-product-setup/references/api_key_handling.md` の「secret API key の扱い」) と、wrangler.jsonc の `REVENUECAT_PROJECT_ID` / `REVENUECAT_PREMIUM_ENTITLEMENT_ID` (RevenueCat プロジェクトを作成した後に `rc_list.sh entitlements` で得る `entl...` の ID) が必要:

```sh
cd workers/image
npx wrangler secret put GEMINI_API_KEY --env dev    # 値は Google AI Studio の API キー
npx wrangler secret put GEMINI_API_KEY --env prod
npx wrangler secret put REVENUECAT_SECRET_API_KEY --env dev    # 値は RevenueCat の v2 secret API key (sk_...)
npx wrangler secret put REVENUECAT_SECRET_API_KEY --env prod
npx wrangler deploy --env dev    # → kashakeibo-image-worker-dev
npx wrangler deploy --env prod   # → kashakeibo-image-worker-prod
```

- dev / prod とも 2026-08-19 に初回デプロイ済み。デプロイ後に表示される `*.workers.dev` URL が変わった場合は、Flutter の `lib/features/image_upload/image_upload_client.dart` にある既定値を更新する
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
