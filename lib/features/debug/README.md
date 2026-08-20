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
