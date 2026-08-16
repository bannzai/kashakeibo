# 0001. 技術スタック: Flutter × Firebase (サーバーコードゼロ) × RevenueCat

- ステータス: 採用
- 日付: 2026-08-16
- 決定の経緯: https://github.com/bannzai/IdeaMemo/issues/188 の「技術スタック決定」コメント (本 ADR はその転記 + 未決定だった Analytics・法務ドキュメント公開手段の追記)

## 方針

明細データが唯一の真実・サーバーコードゼロ・預かるものを最小にする。MVP (Shipaton 2026、締切 2026-09-30) の開発速度を最優先する。

## 決定一覧

| レイヤ | 決定 | 理由 |
| --- | --- | --- |
| フロントエンド | Flutter | Android 展開の要望に応えられる形にしておく (DB を Firestore にする動機と一貫)。shoppinglist で Flutter × Firebase × RevenueCat (purchases_flutter) × fastlane の構成が実証済みで、flutter-maestro / translate-app-arb など開発・検証・多言語化の手元資産をそのまま使える |
| 画像解析 | Firebase AI Logic (旧 Vertex AI in Firebase) 経由の Gemini vision モデル | クライアント SDK から直接呼べて、API キー秘匿と不正利用対策は App Check が担う。自前バックエンド不要。解析はステートレスな呼び出しで、画像・結果とも解析側には永続化しない |
| オンデバイス AI | Foundation Models は MVP では採用しない | ①画像入力を受けられず Vision OCR → テキストの2段構えになりレイアウト情報が落ちる ②Apple Intelligence 必須 = iPhone 15 Pro 以降の端末ゲートが家計簿ユーザー層と合わない ③解析精度が製品の核であり ~3B のオンデバイスモデルで妥協できない。v2 で「対応端末はオンデバイス解析でスキャン無料枠無制限」というコスト削減・差別化機能として導入する |
| DB | Firestore | 端末を変えても・OS をまたいでもデータが残ることが価値の核 (カテゴリ最大の不満「データが消えた」への回答)。Flutter との組み合わせで iOS/Android 両対応が自然に成立する |
| 集計 | サマリードキュメントは持たない。明細から都度計算 | 派生データの二重管理を避ける。詳細は `.claude/rules/firestore-aggregation-rules.md` を参照 |
| Cloud Functions | MVP ではゼロ | 集計の都度計算方針によりトリガーが不要になり、デプロイ対象がアプリだけになる |
| 画像ストレージ | Cloud Storage for Firebase | 明細と元画像の紐付けが仕様の核なので、端末をまたいで残す。Auth 連動のセキュリティルールで uid 単位の保護が最短。原案の R2 はコスト最適化として後から移行可能 (MVP 規模では差額が誤差) |
| 認証 | 匿名認証スタート → Sign in with Apple / Google へのアカウントリンク | 登録なしで使い始められることとデータ寿命の両立。匿名のまま端末を失うとデータも失われるため、「機種変更に備えてバックアップ」の導線を早期に出す |
| 課金 | RevenueCat (purchases_flutter) | Shipaton 応募要件。スキャン無料枠 → プレミアムのハードペイウォール |
| Analytics | Firebase Analytics | Firebase スタックに追加コストゼロで乗る標準構成 (issue では未決定だったため本 ADR で決定) |
| 法務ドキュメント公開 | GitHub Pages (docs/ 配信) | リポジトリが public でホスティング追加不要。利用規約・プライバシーポリシー・特商法表記・アカウント削除手順ページを配信する (issue では未決定だったため本 ADR で決定) |
