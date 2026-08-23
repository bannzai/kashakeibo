# debug (開発者メニュー)

## 概要

DEBUG ビルド限定の開発者メニュー。到達困難な状態の作り込みをアプリ内メニューから行う
(~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md のパターン)。
release ビルドには入口ごと含まれない (`kDebugMode` ガード)。

## 画面

- `DebugSheet`: MonthlyPage の月ラベルを**長押し**すると開くボトムシート
  (デザインに存在しない入口を画面に足さないための隠し操作)
  - サンプル明細を追加: 今月の明細 5 件 (計算対象外 1 件を含む) を Firestore へ書き込む
  - サンプルレシートで撮影フローを試す: レシート風の画像 (店名・明細行・合計・日付) をその場で描画し、
    `features/capture` の `CapturePage` (アップロード → Gemini 解析 → 確認 → 登録) を開く。
    端末カメラの無いシミュレータでも撮影フローを通すための入口 (画像 API の接続先は
    debug ビルドの既定で dev Worker。ローカルの Worker 等へ向ける時だけ
    `--dart-define=IMAGE_API_BASE_URL=...` で上書きする)
  - サンプル明細スクショで取込フローを試す: カード明細のスクショ風の画像 (取引 3 件) をその場で描画し、
    出所 `screenshot` で `CapturePage` を開く。複数明細の候補リスト (採用・破棄・修正 → 一括登録) を
    フォトライブラリに画像を用意せずに通すための入口
  - スキャン残量を使い切る: 今月のスキャン回数を無料枠の上限に設定し、残量 0
    (「カメラで撮影」「写真・スクショから選ぶ」でペイウォールが開く状態) を作る。
    使用回数は Cloudflare の Durable Object の中にしか無く firebase / gcloud / wrangler のどれからも
    書き換えられないため、dev 環境の Worker にだけ用意した DEBUG 経路 (`POST /debug/scan-count`。
    workers/image/README.md) 経由で設定する。prod の Worker では経路自体が 404 のため、
    release ビルドから同じ操作をしても効かない。冪等 (何度実行しても残量 0 のまま)
  - ペイウォールをサンプル価格で開く: RevenueCat の public API key が未注入のビルドでも、
    実商品と同じ識別子・価格 (月額 ¥480 / 年額 ¥3,800) のサンプル Offering で `features/paywall` の
    `PaywallPage` を開く。購入は mock で成功し、復元は「復元できる購入がありません」になる
    (残量バー・プレミアム判定は実 Provider のまま)。実ストア・RevenueCat の購入フロー検証の代替ではない
    (それは `/ios-storekit-testing` と RevenueCat Test Store で行う)

## フロー

1. debug ビルドで MonthlyPage 中央の月ラベル (「2026年8月」) を長押し
2. メニュー項目をタップ → 実行結果が一覧への反映で確認できる

## 制約

- DEBUG 限定のため文言は日本語固定で l10n の対象外
- サンプル明細の追加は冪等ではない (実行のたびに 5 件追加される)
- 「スキャン残量を使い切る」は dev の Worker (debug ビルドの既定の接続先) が相手の時だけ成功する。
  接続先が prod の場合は 404 のエラーダイアログになる
