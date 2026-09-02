# kashakeibo-image-worker

レシート・スクショ画像の保存先 (Cloudflare R2) へのアクセスと、Gemini による明細抽出を一本化する Cloudflare Worker。
Firebase Auth の ID token を [firebase-auth-cloudflare-workers](https://github.com/Code-Hex/firebase-auth-cloudflare-workers) で検証し (公開 JWK は Workers KV にキャッシュ)、さらに Firebase App Check token を `src/app_check.ts` で検証して (公開鍵 JWKS は同じ KV に別キーでキャッシュ)、両方の検証を通ったリクエストだけが R2 の読み書きと解析を行える。

- ID token は「誰のリクエストか」(uid) を、App Check token は「正規のアプリからのリクエストか」を判定する。匿名認証の ID token は公開クライアント設定から誰でも取得できるため、ID token だけでは正規アプリ由来かを判定できない
- firebase-auth-cloudflare-workers (2.0.6) は App Check token の検証 API を持たないため、Firebase Admin SDK の AppCheckTokenVerifier と同じ手順 (alg / iss / aud / sub / exp / iat / RS256 署名) を `src/app_check.ts` に Web Crypto で実装している
- App Check は「量」の制限にはならないため、日次のアップロード・解析回数上限はそのまま併用する

設計の決定は `documents/adr/0001-tech-stack.md` の「画像ストレージ」「画像解析」を参照。

明細の訂正・削除履歴 (監査ログ) の読み取りも本 Worker が担う (`GET /audit-logs`)。履歴は 2 つの BigQuery テーブルから成り、どちらもクライアントには書き込み経路が無く、読み取りもサービスアカウント権限を持つ Worker 経由に限られる。アカウント削除時の履歴パージ (`DELETE /audit-logs` の予約と毎時の cron 実行) も同じ経路で扱う (`src/audit_log.ts` / `src/bigquery.ts`)。

| テーブル | 書き込む主体 | 内容 |
| --- | --- | --- |
| `firestore_export.transactions_raw_changelog` | Firebase Extension「Stream Firestore to BigQuery」 | 明細 (`users/{uid}/transactions`) の作成・更新・削除 |
| `firestore_export.image_deletion_logs` | 本 Worker (`DELETE /images` 系の成功時) | R2 の画像削除 (`uid` STRING / `image_object_key` STRING NULLABLE / `deleted_at` TIMESTAMP) |

画像だけを消す削除は Firestore の明細を変えないため changelog に痕跡が残らず、`DELETE /images/{objectKey}` を直接呼べば監査を迂回できてしまう。これを塞ぐために、Worker 自身が `image_deletion_logs` へ 1 行記録する。テーブルは最初の記録時に Worker が作る (`tables.insert`。作成済みの 409 は成功扱い) ため、事前のスキーマ作成は不要。

AI 画像解析 (Gemini) は、スキャン無料枠 (uid ごとの月次回数・entitlement 判定) をサーバー側で強制するため本 Worker の解析エンドポイント (`POST /analyses`) が担う。Gemini の API キーは Worker の secret にだけ置き、クライアントへ配布しない。無料枠 (月50スキャン。documents/PROJECT.md の課金設計) を超えた解析は、RevenueCat のプレミアム entitlement をサーバー側で確認したユーザーだけに許可する (`src/entitlement.ts`。クライアント申告のプレミアム状態は信用しない)。

## API

すべてのエンドポイントで `Authorization: Bearer <Firebase ID token>` と `X-Firebase-AppCheck: <Firebase App Check token>` の両方が必須。どちらかの欠落・検証失敗は 401 (両方通って初めて後続の処理に進む)。

### POST /images

multipart/form-data の `file` フィールドで画像をアップロードする。`X-Upload-Id` ヘッダーに、クライアントが論理アップロードごとに生成する UUID が必須 (欠落・UUID 形式外は 400)。

- オブジェクトキーは `users/{JWTのuid}/{X-Upload-Id}.{拡張子}` を Worker 側で組み立てる。uid プレフィックスは JWT から強制し、クライアント申告のパス・ファイル名は使わない
- 同じ `X-Upload-Id` での再試行は同じキーへの上書きになる (冪等)。レスポンスが届かなかった再試行でも孤児オブジェクトが残らない
- 対応 Content-Type・上限サイズ・日次アップロード回数上限 (uid 別・接続元 IP 別・全体の3層。超過は 429) は `src/handler.ts` の `imageContentTypeExtensions` / `maxImageBytes` / `maxDailyUploadCount*` を参照。空ファイルは 400。回数の判定と加算は日次シングルトンの Durable Object (`src/upload_counter.ts`) で直列化し、並行リクエストによる上限すり抜けを防ぐ。保存済みキーへの再試行はカウントを消費しない
- 画像のヘッダーを解析して実寸 (px) と色の階調を判定し、アップロード時刻 (Worker の時刻。クライアント申告は使わない) と一緒に R2 の customMetadata に記録する。判定基準と根拠は `src/image_dimensions.ts` の `scannerResolutionMinimumPixelCount` を参照。基準を満たさない画像・実寸を解析できない画像 (判定は `"unknown"`) も保存を拒否しない (家計簿としての利用を阻害しないため)
- レスポンス: `201 {"imageObjectKey": "users/{uid}/{X-Upload-Id}.{拡張子}", "imageWidth": 3024 | null, "imageHeight": 4032 | null, "scannerResolutionSatisfied": "true" | "false" | "unknown", "scannerColorSatisfied": "true" | "false" | "unknown", "uploadedAt": "2026-08-23T00:00:00.000Z" | null}`。Firestore の明細にはこのキーを保存する (配信ドメインはデプロイ時に決まるため URL ではなくキーを保存する)

### GET /images/{imageObjectKey}

アップロード済み画像を取得する。オブジェクトキーが JWT の uid 配下 (`users/{uid}/`) でない場合は 403。存在しないキーは 404。

- アップロード時に記録した画質判定とアップロード時刻を `X-Image-Width` / `X-Image-Height` / `X-Scanner-Resolution-Satisfied` / `X-Scanner-Color-Satisfied` / `X-Uploaded-At` ヘッダーで返す (記録前にアップロードされた既存オブジェクトではヘッダーを付けない)

### DELETE /images/{imageObjectKey}

画像 1 件を削除する (明細から画像だけを外す・明細ごと削除する時に使う)。オブジェクトキーが JWT の uid 配下でない場合は 403。冪等で、対象が無くても 200 を返す。

- 削除の成功時に `image_deletion_logs` へ uid・オブジェクトキー・サーバー時刻の 1 行を記録する (`GET /audit-logs` に `transactionImageDeleted` として現れる)。記録はベストエフォートで、BigQuery 側が失敗しても警告をログに残すだけで 200 を返す (画像削除の応答を BigQuery 障害に巻き込まないため)

### DELETE /images

アカウント削除時に、JWT の uid 配下の全オブジェクトを削除する (docs/AccountDeletion.md の「画像は削除操作と同時に削除される」に対応)。クライアントは Firebase Auth ユーザーを削除する前 (ID token が有効なうち) に呼ぶ。冪等で、対象が無くても 200 を返す。

- 削除の成功時に `image_deletion_logs` へ `image_object_key` が NULL の 1 行 (「全画像の削除」) を記録する。記録の扱いは個別削除と同じくベストエフォート

### POST /analyses

アップロード済み画像を Gemini vision で解析し、家計簿の明細を抽出する。リクエストは `application/json` の `{"imageObjectKey": "users/{uid}/..."}` (画像はクライアントから再送させず R2 から読む)。

- オブジェクトキーが JWT の uid 配下でない場合は 403、存在しないキーは 404。`src/handler.ts` の `maxAnalysisImageBytes` を超える画像は 413
- 日次解析回数上限 (uid 別・接続元 IP 別・全体の3層。超過は 429) はアップロードとは別のカウンター (`analysis:` プレフィックス) で数える。値は `src/handler.ts` の `maxDailyAnalysisCount*` を参照。上限判定は Gemini 呼び出しの直前に行い、超過時に LLM 原価を発生させない
- Gemini は `generateContent` を構造化出力 (`responseSchema`) で 1 回呼ぶステートレスな呼び出しで、画像・結果とも Gemini 側に保存しない。モデルは wrangler.jsonc の `GEMINI_MODEL`。プロンプト・出力スキーマ・出力の検証は `src/analysis.ts`
- レスポンス: `200 {"transactions": [{"title": "店名", "amount": 872, "transactionDate": "2026-08-16" | null, "type": "income" | "expense", "category": "food" | "eatingOut" | "dailyGoods" | "transportation" | "subscription" | "salary" | "other"}]}`。`type` / `category` は Flutter 側 Entity (`lib/entity/transaction.dart`) と同じ enum 名。紙のレシートは 1 枚 1 件 (合計金額)、明細スクショは取引ごとに 1 件、明細が写っていなければ空配列
- 実際の撮影を想定した抽出ルール (issue #82。プロンプトは `src/analysis.ts`): 背景 (机・手・財布等) の映り込みは無視する。1 枚の画像に別々の支払いのレシートが複数写っていればレシートごとに 1 件、1 回の支払いが複数の紙片に分かれて写っていれば (長いレシート・分割発行の領収書) まとめて 1 件にする。品質は合成フィクスチャ (`scripts/generate-analysis-fixtures.py` の `receipt_two_receipts.jpg` / `receipt_split_long.jpg`) と実物ベンチマーク (`benchmark/`) で検証する
- Gemini API のエラーは 502 でエラー本文をそのまま返す (クライアントは手動入力へフォールバックする)
- 追加指示による再解析 (issue #40): リクエストに `"instructionTurns": [{"previousTransactions": [<直前の応答の transactions>], "instruction": "一番下の明細が読めていない"}, ...]` を付けると、画像に加えて「直前の結果 (model) → 指示 (user)」の往復を generateContent の複数ターンとして積み、指示を反映した明細の全件を返す。解析はステートレスのため対話は Gemini 側に残らず、クライアントが往復の履歴 (古い順) を毎回送る。往復数と指示の文字数 (書記素単位。クライアントの入力欄と同じ数え方) の上限は `src/analysis.ts` の `maxAnalysisInstructionTurnCount` (10) / `maxAnalysisInstructionLength` (500)、`previousTransactions` の件数・店名の長さの上限は同ファイルの `maxAnalysisPreviousTransactionCount` (50) / `maxAnalysisTransactionTitleLength` (200)。空の指示・上限超過・配列でない値は 400、リクエスト本体が `src/handler.ts` の `maxAnalysisRequestBodyBytes` (256 KB) を超える場合は parse 前に 413 (いずれも回数は消費しない)。`previousTransactions` は Worker 自身の出力の再送として扱い、不正な明細を取り除いてからプロンプトに載せる。再解析も Gemini 呼び出しを伴うため、日次上限・月次の無料枠・プレミアム上限を通常の解析と同じく消費する
- スキャン無料枠: uid ごとに今月 (UTC の暦月) の解析回数を数え、`src/handler.ts` の `monthlyFreeScanLimit` (50) までは無条件に解析する。使い切った後は RevenueCat API v2 の `active_entitlements` を uid (= クライアントが `Purchases.logIn` に渡す app user ID) で引き、`REVENUECAT_PREMIUM_ENTITLEMENT_ID` の entitlement が有効なら `monthlyPremiumScanLimit` (1000。プレミアムでも LLM 原価の上限を固定する月次キャップ。到達時は 429) の範囲で解析する。有効でなければ `402 {"error": "...", "monthlyScanCount": 50, "monthlyFreeScanLimit": 50}` を返し、クライアントはペイウォールを表示する。RevenueCat API の失敗 (5xx・接続不能) は 402 と区別して 503 で返す (再試行可)。判定は日次上限 (429) の後、Gemini 呼び出しの前に行い、無料枠内の解析では RevenueCat を呼ばない。RevenueCat の設定 (`REVENUECAT_SECRET_API_KEY` / `REVENUECAT_PROJECT_ID` / `REVENUECAT_PREMIUM_ENTITLEMENT_ID`) が無い環境では全ユーザーを無料プランとして扱う (無料枠だけを強制する fail-closed)。回数の判定と加算は月次シングルトンの Durable Object (`src/usage_counter.ts`。日次カウンターと同じクラスの別インスタンス) で直列化する

### GET /analyses/quota

今月のスキャン (解析) 回数と無料枠の上限を返す: `200 {"monthlyScanCount": 3, "monthlyFreeScanLimit": 50}`。クライアントは残量チップの表示 (`monthlyFreeScanLimit - monthlyScanCount`) と、残量 0 でのペイウォール表示判定に使う。プレミアムかどうかはクライアントが RevenueCat SDK (`CustomerInfo`) から直接得るため含めない。

### GET /audit-logs

明細 (`users/{uid}/transactions`) の訂正・削除履歴と、R2 の画像削除の履歴を新しい順に返す。読むテーブルは冒頭の表の 2 つ (どちらも `{FIREBASE_PROJECT_ID}.firestore_export`、ロケーション asia-northeast1) で、クライアントには履歴の書き込み経路が無い (履歴自体の改ざんを構造的に防ぐ)。

- 2 つのテーブルを同じ uid・同じ期間の下限で読み (2 クエリ)、`occurredAt` の新しい順に統合して最大 `maxAuditLogCount` 件を返す。`image_deletion_logs` は最初の画像削除の記録時に作られるため、まだ存在しない (404) 環境では画像削除の履歴なしとして扱い、明細の履歴だけを返す
- 対象は検証済み ID token の uid の変更だけ (changelog は `path_params` の `userId`、`image_deletion_logs` は `uid` 列で絞り込む。クライアント申告のユーザー ID は受け取らない)。extension の導入時に既存ドキュメントを取り込んだ行 (`operation = 'IMPORT'`) はユーザーの操作ではないため返さない
- 無料プランは今月を含む直近 `freePlanAuditLogHistoryMonthCount` (3) ヶ月の先頭 (UTC の月初) より古い履歴を返さない。プレミアム entitlement (`src/entitlement.ts`) を持つユーザーは期間で絞り込まない。月数はアプリ側 `lib/features/paywall/free_plan_history_limit.dart` の `freePlanHistoryMonthCount` と同じ値で、月境界がアプリの端末ローカルと Worker の UTC で最大数時間ずれる近似 (`src/audit_log.ts`)。RevenueCat の判定に失敗した場合は履歴を切り詰めず 503 を返す (再試行可)
- 件数は `src/audit_log.ts` の `maxAuditLogCount` (200) 件まで。日次取得回数上限 (uid 別 100・接続元 IP 別・全体の3層。超過は 429) は `src/handler.ts` の `maxDailyAuditLogCount*` を参照。BigQuery のオンデマンド課金は 1 クエリあたり最低 10MB ぶんが課金されるため、上限判定は BigQuery 呼び出しの直前に行う
- レスポンス: `200 {"auditLogs": [{"occurredAt": "2026-08-23T01:23:45.678Z", "operation": "transactionCreated" | "transactionUpdated" | "transactionDeleted" | "transactionImageDeleted", "transactionID": "abc123", "transactionTitle": "スーパーマーケット" | null, "transactionAmount": 3480 | null, "changedFieldNames": ["excludedFromAggregation"]}]}`
- `operation` は changelog の `operation` 列から導く。CREATE → `transactionCreated`、DELETE → `transactionDeleted` (表示する明細の内容は削除直前の `old_data` から読む)、UPDATE → `transactionUpdated`。UPDATE のうち `sourceImageObjectKey` が非 null から null になった更新だけは `transactionImageDeleted` にする
- `image_deletion_logs` 由来の行は `operation` が `transactionImageDeleted`、明細に紐付かないため `transactionID` が空文字・`transactionTitle` / `transactionAmount` が null・`changedFieldNames` が空配列になる
- `changedFieldNames` は UPDATE の `data` と `old_data` のトップレベルフィールドを値で比較した差分。更新のたびに必ず変わる `serverCreatedDateTime` / `serverUpdatedDateTime` は除く
- `data` / `old_data` の JSON を読めなかった行も落とさず、`operation` はそのままに `transactionTitle` / `transactionAmount` を null、`changedFieldNames` を空配列にして返す (履歴の件数が実際の操作回数と食い違わないようにする)
- BigQuery の失敗 (HTTP エラー・ジョブのタイムアウト) は 502。エラー本文にはテーブル名等の内部情報が含まれるためクライアントへは返さず、ログにだけ残して status を伝える

### DELETE /audit-logs

アカウント削除時に、JWT の uid の履歴のパージを予約する。レスポンスは `202 {"purgeRequestedAt": "2026-08-23T01:23:45.678Z"}`。冪等 (何度呼んでも予約は 1 件に収束する)。

- 即時に DML を実行しない。明細の一括削除で生まれる DELETE イベントが changelog に届くのは非同期 (数秒〜数分) で、さらに extension のストリーミング挿入でバッファに乗っている行は DML で削除できない (最大 90 分程度) ため、即時実行では必ず取りこぼす
- 予約は KV (`PUBLIC_JWK_CACHE_KV`) の `audit-log-purge:{uid}` に登録時刻として置き、実際の DML (changelog と `image_deletion_logs` の 2 テーブル) は毎時の scheduled (`wrangler.jsonc` の `triggers.crons`、`src/index.ts`) が実行する。登録から `auditLogPurgeMinimumWaitMilliseconds` (1時間) 未満の予約はスキップして次回に回し、DML に失敗した予約 (2 テーブルのうち片方だけ成功した場合を含む) は KV に残して次回以降に再試行する
- **DML の前に Firebase Auth のアカウントが消えていることをサーバー側で確認する** (Identity Toolkit の `accounts:lookup` を BigQuery と同じサービスアカウントの token で呼ぶ)。この確認が無いと、有効な token を持つ利用中のユーザーが `DELETE /audit-logs` を直接呼ぶだけで自分の監査証跡を消せてしまう。アカウントが残っている間はパージせず予約を維持し、`auditLogPurgeAbandonedRequestExpiryMilliseconds` (7日) を過ぎても残っている予約は、アカウント削除が完了しなかったものとして警告を出して取り下げる (履歴は消さない)。lookup の一時的な失敗は予約を残して次回に再試行する

### POST /debug/scan-count (dev 環境限定)

今月のスキャン回数を指定値に設定する。リクエストは `{"monthlyScanCount": 50}`、レスポンスは `GET /analyses/quota` と同じ `200 {"monthlyScanCount": 50, "monthlyFreeScanLimit": 50}`。

- 目的: スキャン回数は Durable Object の中にしか無く firebase / gcloud / wrangler のどれからも書き換えられないため、残量 0 の QA (残量 0 のペイウォールガード、無料枠超過 402 → 購入 → 再解析) の状態を作れない。アプリの DEBUG 開発者メニュー (`lib/features/debug/debug_sheet.dart` の「スキャン残量を使い切る」) から作れるようにするための経路 (`~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md`)
- **有効化は dev 環境だけ**: wrangler.jsonc の `env.dev.vars.DEBUG_ENDPOINTS_ENABLED` が `"true"` の時だけ経路が存在する。prod の vars にはこの項目を置かないため、prod では未知のパスと同じ `404 {"error": "not found"}` になる (`test/handler.test.ts` の「prod 相当 (DEBUG_ENDPOINTS_ENABLED 無し) では 404 になり、回数も変わらない」で保証)
- 認証は他のエンドポイントと同じく ID token + App Check token が必須。変更できるのは JWT の uid 本人のカウンターだけで、他ユーザーの回数は変更できない
- `monthlyScanCount` は 0 以上 `monthlyPremiumScanLimit` 以下の整数。それ以外は 400。冪等 (同じ値で何度呼んでも結果は同じ)

## スキャン原価 (実測)

1 スキャンあたりの LLM 原価の実測 (issue #50/#61。2026-09-01、合成テスト画像 4 枚: 紙レシート2・明細スクショ2、円換算 150円/USD)。
単価の出典は https://ai.google.dev/gemini-api/docs/pricing (thinking トークンは output 単価で課金)。

| 構成 | 平均原価/スキャン | 抽出精度 (店名・金額・日付・カテゴリ・件数) |
| --- | --- | --- |
| gemini-3.1-flash-lite (旧採用・既定設定) | 約 ¥0.089 | 全問一致 |
| **gemini-3.5-flash-lite (採用・既定設定)** | **約 ¥0.115** | **全問一致** |
| gemini-3.7-flash (既定設定) | 約 ¥0.354 | 全問一致 |
| gemini-3.1-flash-lite + mediaResolution low (単独) | 約 ¥0.06 | 全問一致 (不採用: 下記) |

- 採用: `gemini-3.1-flash-lite` は最短 2027-05-07 に廃止予定のため、推奨後継の `gemini-3.5-flash-lite` へ切替 (issue #61。廃止予定: https://ai.google.dev/gemini-api/docs/deprecations)。実物ベンチマークでは3.1の14/15に対して3.5は15/15、合成画像はどちらも全問一致。合成画像の平均原価は約30%増だが、プレミアム月1,000回でも約¥115で月額¥480を下回る
- プレミアム向け `gemini-3.7-flash` は不採用 (issue #58)。難例・実物スクリーンショットを含む15枚で3.5と同じ15/15のため精度差がなく、平均原価は3.5の約3.2倍。さらに3.7は2027-01-01に単価が倍増するため、entitlement によるモデル切替・高精度モデル専用上限・ペイウォール特典は追加しない
- 不採用: `mediaResolution` の引き下げ (単独実測で入力 1,396→598 トークン・原価 約34% 減 (¥0.089→¥0.059) と削減は大きいが、画像のトークン割当が約1/4 になるため、実レシートの細かい印字の読み取り低下リスクを合成画像だけでは否定できず見送り。実レシートでの精度検証とセットで再検討する。既定は画像1枚 約1,120トークンの固定割当)。thinkingLevel low の付与 (3.1-flash-lite は既定 thinking なしのため、付与すると逆に thinking が発生して原価増)。クライアント縮小の強化 (画像のトークン数は mediaResolution 固定割当のため長辺 1600→1024 でも入力トークン不変)。同一画像の再解析キャッシュ (再試行頻度が未知で効果を見積もれないため見送り)
- 月額原価の目安: 無料ユーザー上限 = 月50スキャン × ¥0.115 ≒ ¥6/ユーザー。プレミアム上限 = 月1000スキャン × ¥0.115 ≒ ¥115/ユーザー (< 月額 ¥480)
- 再実測の手順 (workers/image で。API キーは `.dev.vars` の `GEMINI_API_KEY`)。フィクスチャ生成に Pillow を使うため、初回のみ `scripts/requirements.txt` で導入する (実測時のバージョンで結果が再現するようピン留めしている):

```sh
python3 -m pip install -r scripts/requirements.txt   # 初回のみ
python3 scripts/generate-analysis-fixtures.py
node --experimental-strip-types scripts/measure-analysis-cost.mjs            # 全構成
node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.5-flash-lite-baseline   # 構成指定
FIXTURES_DIR=tmp/analysis-fixtures-degraded node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.5-flash-lite-baseline   # 劣化セット
```

- 本番のトークン数は `src/analysis.ts` が解析ごとに `{"event":"gemini_usage",...}` の構造化ログで記録する (Workers のログで集計できる)
- **実物ベンチマーク**: 再配布可能ライセンスの実レシート・注文履歴スクリーンショット 15 枚 (`benchmark/`) で、モデル・プロンプト変更時の品質回帰を検証する。基準値 (採用構成で全項目一致 15/15・約 ¥0.090/スキャン)・出典・実行手順は `benchmark/README.md` を参照

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
npx wrangler secret put BIGQUERY_SERVICE_ACCOUNT_KEY --env dev    # 値はサービスアカウントの JSON キーの中身 (1行に貼り付ける)
npx wrangler secret put BIGQUERY_SERVICE_ACCOUNT_KEY --env prod
npx wrangler deploy --env dev    # → kashakeibo-image-worker-dev
npx wrangler deploy --env prod   # → kashakeibo-image-worker-prod
```

- 監査ログ (`GET /audit-logs`・画像削除の記録・毎時のパージ) は BigQuery の REST API を直接呼ぶため、環境ごとにサービスアカウントの JSON キーを `BIGQUERY_SERVICE_ACCOUNT_KEY` として登録する。必要な権限は、クエリを実行する権限 (プロジェクトの `roles/bigquery.jobUser`)、changelog / `image_deletion_logs` テーブルの読み取り・DML・テーブル作成の権限 (`firestore_export` データセットの `roles/bigquery.dataEditor`)、パージ前のアカウント確認に使う `accounts:lookup` の権限 (プロジェクトの `roles/firebaseauth.viewer`)。access token は BigQuery と identitytoolkit の 2 スコープをまとめて要求する (`src/bigquery.ts`)。キーはリポジトリに置かず wrangler secret にだけ置く
- 毎時の cron トリガー (`triggers.crons`) は deploy 時に登録される。アカウント削除時の履歴パージがこのトリガーで実行されるため、cron を外すとパージが実行されなくなる

- dev / prod とも 2026-08-19 に初回デプロイ済み。デプロイ後に表示される `*.workers.dev` URL が変わった場合は、Flutter の `lib/features/image_upload/image_upload_client.dart` にある既定値を更新する
- 画像は機微情報のため、R2 バケットの公開アクセス (r2.dev ドメイン・カスタムドメイン直結) は有効化しない
