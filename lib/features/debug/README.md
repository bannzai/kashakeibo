# debug (開発者メニュー)

## 概要

DEBUG ビルド限定の開発者メニュー。到達困難な状態の作り込みと外部サービスの疎通確認を
アプリ内メニューから行う (~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md のパターン)。
release ビルドには入口ごと含まれない (`kDebugMode` ガード)。

## 画面

- `DebugSheet`: MonthlyPage の AppBar 右のバグアイコンから開くボトムシート
  - サンプル明細を追加: 今月の明細 5 件 (計算対象外 1 件を含む) を Firestore へ書き込む
  - Gemini 疎通確認: Firebase AI Logic (`FirebaseAI.googleAI()`) 経由で `generateContent` を呼び、レスポンスまたはエラーをそのまま表示する

## フロー

1. debug ビルドで MonthlyPage 右上のバグアイコンをタップ
2. メニュー項目をタップ → 実行結果がダイアログまたは一覧への反映で確認できる

## 制約

- DEBUG 限定のため文言は日本語固定で l10n の対象外
- サンプル明細の追加は冪等ではない (実行のたびに 5 件追加される)
