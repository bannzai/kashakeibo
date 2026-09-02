# App Privacy / データセーフティの回答内容

App Store Connect の App Privacy と Google Play のデータセーフティに回答する内容を、実装から読み取った収集実態としてまとめる。回答が実態とずれないよう、データの経路 (収集元・保存先・送信先) を変える変更をした時はこの文書と `fastlane/app_privacy_details.json` を同じ PR で更新する。

- App Store の回答の正は `fastlane/app_privacy_details.json`。appstore-app-privacy skill の `privacy_apply.sh` で App Store Connect へ適用・publish・一致検証する (公開 ASC API 非対応のため fastlane spaceship の Web セッションを使う)。2026-08-22 に publish 済み ( https://github.com/bannzai/kashakeibo/pull/63 )
- Google Play のデータセーフティは Play Console の Web UI でしか回答できない。本文書の「Google Play データセーフティ」の表をそのまま転記する。Play Console へのアプリ登録は https://github.com/bannzai/kashakeibo/issues/38 で行う

## 収集しているデータと経路

| データ | 収集元 (実装) | 保存先・送信先 | 用途 | ユーザーに紐づくか | トラッキング |
|---|---|---|---|---|---|
| ユーザー ID (Firebase Auth の uid) | 初回起動の匿名認証 (`lib/features/auth/sign_in_resolver.dart`) | Firebase Auth、Firestore `users/{uid}`、R2 のオブジェクトキー `users/{uid}/...`、RevenueCat の app user ID (`Purchases.logIn`)、BigQuery の changelog (`path_params.userId`)、Worker の日次・月次カウンター (Durable Object) | アプリの機能 (本人のデータの特定・無料枠の判定) | 紐づく | しない |
| 名前・メールアドレス | 設定画面の Apple / Google アカウント連携 (`lib/provider/account.dart`)。連携しない限り収集しない | Firebase Auth のプロバイダ情報。アプリ内では表示・利用しない | アカウント管理 (機種変更時のデータ引き継ぎ) | 紐づく | しない |
| 写真 (レシート写真・明細のスクリーンショット) | カメラ・フォトライブラリ (`image_picker`)、iOS の共有 Extension | Cloudflare R2 (Worker 経由、`users/{uid}/` 配下に保存)。解析時に Worker が R2 から読み Gemini API へ送信する (`workers/image/src/analysis.ts`。ステートレスな呼び出しで Gemini 側に画像・結果を保存しない) | アプリの機能 (AI による明細の抽出、明細と元画像の紐付け) | 紐づく | しない |
| その他の財務情報 (明細: 金額・日付・店名・カテゴリ・収入 / 支出の区分) | 画像解析の結果と手入力 (`lib/features/capture`、`lib/features/manual_entry`) | Firestore `users/{uid}/transactions`。訂正削除履歴として BigQuery の changelog にも変更前後の値が残る (`documents/adr/0004-audit-log-bigquery-extension.md`) | アプリの機能 (家計簿の記録・集計・操作履歴) | 紐づく | しない |
| 購入履歴 | RevenueCat SDK (`purchases_flutter`)。全ユーザーを uid で `logIn` するため購入前でも顧客レコードができる | RevenueCat。Worker が RevenueCat API v2 で entitlement を照会する (`workers/image/src/entitlement.ts`) | アプリの機能 (プレミアム判定)、分析 (RevenueCat 公式が両方の申告を最低要件としている) | 紐づく | しない |
| アプリの操作 (画面遷移・タップ等のイベント) | Firebase Analytics (`lib/utils/analytics/analytics.dart`。`.claude/rules/analytics.md` に従い各操作で記録) | Google Analytics for Firebase。パラメータに transactionID 等の自社 ID を含むため、自社データと結合すれば本人に再連結できる | 分析 | 紐づく | しない |
| おおよその位置情報 | Firebase Analytics が端末の IP アドレス (マスク済み) から導出する (SDK の既定動作) | Google Analytics for Firebase | 分析 | 紐づく | しない |
| デバイス ID または他の ID | Firebase Analytics の app-instance ID。Android では Analytics SDK が広告 ID (`AD_ID` 権限) も既定で収集する。Firebase App Check の端末証明トークン (App Attest / Play Integrity、`lib/utils/firebase_app_check/`) | Google Analytics for Firebase、Firebase App Check | 分析 (Analytics)、不正行為の防止 (App Check は Worker が正規のアプリからのリクエストか判定するために必須) | 紐づく | しない |

回答の項目に入れていないもの (保存しない・一時的に参照するだけの情報):

- IP アドレス: Worker がアップロード・解析の日次回数制限に `CF-Connecting-IP` をカウンターのキーとして使う (`workers/image/src/handler.ts`。カウンターは 2 日後に削除)。Firebase Auth も不正防止のために参照する。ユーザーのデータとして保存しないため、上表では Analytics の「おおよその位置情報」に反映するだけで独立した項目にしていない
- 端末内の他の写真: ユーザーが選んだ 1 枚だけを受け取る。フォトライブラリ全体は読まない

## 収集していないデータ・トラッキングなし

- 正確な位置情報・連絡先・カレンダー・健康情報・メッセージ・閲覧履歴は収集しない
- クラッシュログ・診断情報は収集しない (Crashlytics を導入していない)
- 広告 SDK・IDFA を使わない。`ios/Runner/Info.plist` に `NSUserTrackingUsageDescription` と `SKAdNetworkItems` は無い。App Store の回答に `DATA_USED_TO_TRACK_YOU` を含めず、Google Play でも「広告またはマーケティング」目的は選ばない
- 第三者への「共有」はない。Google (Firebase / Gemini API)、Cloudflare (R2 / Worker)、RevenueCat はいずれも提供者の委託先 (処理者) として扱う。Gemini API は有料枠の利用規約 (入力を Google の製品改善に使わない) を前提にしているため、Worker の `GEMINI_API_KEY` が課金有効なプロジェクトの API キーであることをデータセーフティの回答時に確認する

## 保持期間・削除

削除の手順と削除されるデータは https://bannzai.github.io/kashakeibo/AccountDeletion (`docs/AccountDeletion.md`) が正。設定画面の「アカウントを削除」で、Firebase Auth・Firestore の明細・R2 の画像はその場で削除され、BigQuery の操作履歴は Worker の遅延パージで数時間以内に削除される。RevenueCat の購入履歴は Apple / Google の決済プラットフォームと RevenueCat の定めに従い、提供者が任意に削除できない。

## App Store (App Privacy)

`fastlane/app_privacy_details.json` の 9 エントリと上表の対応。すべて `DATA_LINKED_TO_YOU` で、トラッキングは無し。

| category | purposes | 上表の行 |
|---|---|---|
| NAME | APP_FUNCTIONALITY | 名前・メールアドレス |
| EMAIL_ADDRESS | APP_FUNCTIONALITY | 名前・メールアドレス |
| USER_ID | APP_FUNCTIONALITY | ユーザー ID |
| PHOTOS_OR_VIDEOS | APP_FUNCTIONALITY | 写真 |
| PURCHASE_HISTORY | ANALYTICS, APP_FUNCTIONALITY | 購入履歴 |
| OTHER_FINANCIAL_INFO | APP_FUNCTIONALITY | その他の財務情報 |
| COARSE_LOCATION | ANALYTICS | おおよその位置情報 |
| PRODUCT_INTERACTION | ANALYTICS | アプリの操作 |
| DEVICE_ID | ANALYTICS | デバイス ID または他の ID |

回答を変えた時は `bash ~/.claude/skills/appstore-app-privacy/scripts/privacy_apply.sh --app-identifier com.bannzai.kashakeibo --username <Apple ID> --team-id <ITC team ID> --json-path fastlane/app_privacy_details.json` で再適用する (spaceship セッションが失効していたら agent は `fastlane spaceauth` を実行せず、通常のターミナルでの実行を依頼する)。

## Google Play データセーフティ

Play Console → ポリシー → アプリのコンテンツ → データセーフティ の回答。画面の流れ順に書く。

### 1. 概要の質問

| 質問 | 回答 |
|---|---|
| アプリはユーザーデータを収集または共有しますか？ | **はい** |
| 収集したデータはすべて転送中に暗号化されますか？ | **はい** (Firebase・Worker・RevenueCat・Gemini API はすべて HTTPS / TLS) |
| データの削除をリクエストする方法を提供していますか？ | **はい** (設定画面の「アカウントを削除」。手順ページ: https://bannzai.github.io/kashakeibo/AccountDeletion ) |

### 2. データタイプ (チェックを入れるもの)

- 個人情報 → **名前** (Apple / Google アカウント連携)
- 個人情報 → **メールアドレス** (Apple / Google アカウント連携)
- 個人情報 → **ユーザー ID** (Firebase Auth の uid)
- 財務情報 → **購入履歴** (RevenueCat)
- 財務情報 → **その他の財務情報** (明細: 金額・日付・店名・カテゴリ。レシート・クレジットカード明細から抽出した記録)
- 位置情報 → **おおよその位置情報** (Firebase Analytics が IP から導出)
- 写真と動画 → **写真** (レシート写真・明細のスクリーンショット)
- アプリのアクティビティ → **アプリの操作** (Firebase Analytics)
- デバイス ID または他の ID → **デバイス ID または他の ID** (Analytics の app-instance ID・広告 ID、App Check のトークン)

上記以外 (正確な位置情報・住所・電話番号・連絡先・カレンダー・SMS・音声・健康・閲覧履歴・クラッシュログ・診断など) はすべてチェックなし。

### 3. 各データタイプごとの質問

全タイプ共通:

| 質問 | 回答 |
|---|---|
| 収集ですか、共有ですか？ | **収集のみ** (共有はチェックしない。Google・Cloudflare・RevenueCat は処理者) |
| 一時的に処理されますか？ | **いいえ** (写真は R2 に保存する。Gemini への送信は一時的だが保存先があるため「いいえ」) |
| 必須 / 任意、収集の目的 | 下表 |

| データ | 必須 / 任意 | 目的 |
|---|---|---|
| 名前 | **任意** (アカウント連携した人だけ) | アカウント管理 |
| メールアドレス | **任意** (アカウント連携した人だけ) | アカウント管理 |
| ユーザー ID | 必須 (起動時に匿名認証で発行) | アプリの機能、アカウント管理 |
| 購入履歴 | 必須 (全ユーザーを RevenueCat に登録) | アプリの機能、分析 |
| その他の財務情報 | 必須 (家計簿の記録そのもの) | アプリの機能 |
| おおよその位置情報 | 必須 (Analytics の既定動作) | 分析 |
| 写真 | **任意** (手入力だけでも使える) | アプリの機能 |
| アプリの操作 | 必須 | 分析 |
| デバイス ID または他の ID | 必須 | 分析、不正行為の防止・セキュリティ・コンプライアンス |

### 4. 全体の注意点

- 「共有」はすべて**なし**。「広告またはマーケティング」目的はすべて**なし**
- プライバシーポリシー URL: https://bannzai.github.io/kashakeibo/PrivacyPolicy
- 広告 ID の申告 (ポリシー → アプリのコンテンツ → 広告 ID): Firebase Analytics の Android SDK (`play-services-measurement-api`) が `com.google.android.gms.permission.AD_ID` をマニフェストに含めるため「**はい**」、用途は「**分析**」。広告 ID を使わない回答にするなら `AndroidManifest.xml` に `google_analytics_adid_collection_enabled=false` を入れて収集を止めてから回答を変える

### 5. データセーフティ以外の残りフォーム

| フォーム | 回答 |
|---|---|
| アプリのアクセス権 | **すべての機能を制限なく利用できる** (匿名認証で起動し、ログインなしで家計簿を使える。プレミアムは購入で解放される機能で、ログインによる制限ではない) |
| 広告 | 広告を含まない |
| コンテンツレーティング (IARC) | 暴力・性的表現・冒涜的表現・薬物・ギャンブルすべて「なし」。ユーザー同士の交流「なし」 (共有・チャット機能は無い) |
| ターゲット層 | 子供向けではない (家計簿・クレジットカード明細を扱うため 13 歳以上を対象にする) |
