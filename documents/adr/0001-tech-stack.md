# 0001. 技術スタック: Flutter × Firebase (サーバーコードゼロ) × RevenueCat

- ステータス: 採用
- 日付: 2026-08-16
- 決定の経緯: https://github.com/bannzai/IdeaMemo/issues/188 の「技術スタック決定」コメント (本 ADR はその転記 + 未決定だった Analytics・法務ドキュメント公開手段の追記)。画像ストレージは原案 (issue 本文) どおり Cloudflare R2 を採用し、issue コメントの「Cloud Storage for Firebase、R2 は後から移行可能」から差し替えた (2026-08-16、実証済みの Firebase × R2 構成が既存プロジェクトにあるため)

## 方針

明細データが唯一の真実・サーバーコードを最小 (画像アップロードの Cloudflare Worker 1本のみ)・預かるものを最小にする。MVP (Shipaton 2026、締切 2026-09-30) の開発速度を最優先する。

## 決定一覧

| レイヤ | 決定 | 理由 |
| --- | --- | --- |
| フロントエンド | Flutter | Android 展開の要望に応えられる形にしておく (DB を Firestore にする動機と一貫)。shoppinglist で Flutter × Firebase × RevenueCat (purchases_flutter) × fastlane の構成が実証済みで、flutter-maestro / translate-app-arb など開発・検証・多言語化の手元資産をそのまま使える |
| 画像解析 | Gemini vision モデル (Cloudflare Worker 経由で呼び出す) | 当初案の Firebase AI Logic クライアント直呼びでは、スキャン無料枠 (月10回) の回数判定をクライアント側にしか置けず、クライアント改変や SDK 直叩きで迂回できて LLM 原価の上限を強制できない (PR #2 レビュー指摘で変更)。画像アップロードと同じ Cloudflare Worker (Firebase Auth の ID token 検証済み) に解析エンドポイントを相乗りさせ、uid ごとの利用回数と entitlement をサーバー側で判定してから Gemini API を呼ぶ。API キーは Worker の secret に置きクライアントへ配布しない。解析はステートレスな呼び出しで、画像・結果とも解析側には永続化しない |
| オンデバイス AI | Foundation Models は MVP では採用しない | ①画像入力を受けられず Vision OCR → テキストの2段構えになりレイアウト情報が落ちる ②Apple Intelligence 必須 = iPhone 15 Pro 以降の端末ゲートが家計簿ユーザー層と合わない ③解析精度が製品の核であり ~3B のオンデバイスモデルで妥協できない。v2 で「対応端末はオンデバイス解析でスキャン無料枠無制限」というコスト削減・差別化機能として導入する |
| DB | Firestore | 端末を変えても・OS をまたいでもデータが残ることが価値の核 (カテゴリ最大の不満「データが消えた」への回答)。Flutter との組み合わせで iOS/Android 両対応が自然に成立する |
| 集計 | サマリードキュメントは持たない。明細から都度計算 | 派生データの二重管理を避ける。詳細は `.claude/rules/firestore-aggregation-rules.md` を参照 |
| Cloud Functions | MVP ではゼロ | 集計の都度計算方針によりトリガーが不要になる。サーバーコードは画像アップロード・取得の Cloudflare Worker のみで、デプロイ対象はアプリ + Worker の2つに収まる |
| 画像ストレージ | Cloudflare R2 (Cloudflare Worker 経由) | 明細と元画像の紐付けが仕様の核なので、端末をまたいで残す。ストレージ・エグレスが安く、原案どおり。アクセス経路は Cloudflare Worker に一本化し、Firebase Auth の ID token を `firebase-auth-cloudflare-workers` (JWK は Workers KV にキャッシュ) で検証してから R2 を読み書きする。実証済みの構成が既存プロジェクトにある。レシート・明細スクショは機微情報のため R2 の公開バケット配信は使わず、アップロード・取得ともオブジェクトキーを JWT の uid 配下 (`users/{uid}/...`) に Worker 側で強制する (クライアント申告のパスを信用しない) |
| 認証 | 匿名認証スタート → Sign in with Apple / Google へのアカウントリンク | 登録なしで使い始められることとデータ寿命の両立。匿名のまま端末を失うとデータも失われるため、「機種変更に備えてバックアップ」の導線を早期に出す |
| 課金 | RevenueCat (purchases_flutter) | Shipaton 応募要件。スキャン無料枠 → プレミアムのハードペイウォール |
| Analytics | Firebase Analytics | Firebase スタックに追加コストゼロで乗る標準構成 (issue では未決定だったため本 ADR で決定) |
| 法務ドキュメント公開 | GitHub Pages (docs/ 配信) | リポジトリが public でホスティング追加不要。利用規約・プライバシーポリシー・特商法表記・アカウント削除手順ページを配信する (issue では未決定だったため本 ADR で決定) |
