# monthly (月次一覧)

## 概要

当月の明細一覧と月次集計 (支出・収入・残り・カテゴリ内訳) を表示するホーム画面。
デザインは design_handoff_kashakeibo/README.md (ホームの月切替ヘッダー・収支サマリー、
レポートのカテゴリ横棒、明細タブの日付グループ行) に合わせる。
集計はサマリードキュメントを持たず、購読中の明細からクライアント集計する
(`.claude/rules/firestore-aggregation-rules.md`)。

## 画面

- `MonthlyPage`: アプリのホーム画面。サインイン完了後 (`SignInResolver`) に表示される
  - 月切替ヘッダー: 左右の円形ゴーストボタンと中央の月ラベル (+ 英語表記の副題)
  - 収支サマリーカード (radius 28): 支出を主表示 (¥ 記号は小さく neutral-600)、右に収入・残り (残りはセージ)
  - カテゴリ内訳: 支出のカテゴリ別合計を金額の大きい順の横棒で表示 (支出が無い月は非表示)
  - 明細リスト: 日付見出しでグループ化した取引日時の降順。計算対象外の明細は opacity 0.45 + 「計算対象外」注記。金額に赤は使わない (トークンに赤が無い)
  - DEBUG ビルドのみ月ラベルの長押しでデバッグメニュー (`features/debug`) を開く

## フロー

1. 起動すると当月の明細を snapshot listener で購読する (リアルタイム反映・オフラインキャッシュ対応)
2. 前月・次月ボタンで表示月を切り替えると、その月のクエリを購読し直す
3. 明細の追加・変更は listener 経由で自動的に一覧と集計へ反映される

## データ形式

- 明細: `/users/{userID}/transactions/{id}` の `Transaction` (lib/entity/transaction.dart)
- 月次クエリ: `yearMonth == "yyyy-MM"` + `transactionDate` 降順
  (複合インデックス: firebase/firestore.indexes.json)
- 計算対象外 (`excludedFromAggregation: true`) の明細は一覧に表示するが集計に含めない
