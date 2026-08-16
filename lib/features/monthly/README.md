# monthly (月次一覧)

## 概要

当月の明細一覧と月次集計 (収入・支出・収支・カテゴリ内訳) を表示するホーム画面。
集計はサマリードキュメントを持たず、購読中の明細からクライアント集計する
(`.claude/rules/firestore-aggregation-rules.md`)。

## 画面

- `MonthlyPage`: アプリのホーム画面。サインイン完了後 (`SignInResolver`) に表示される
  - AppBar 中央: 表示月ラベルと前月・次月ボタン
  - 月次サマリーカード: 収入・支出・収支 (収入 - 支出)
  - カテゴリ内訳: 支出のカテゴリ別合計を金額の大きい順に Chip で表示 (支出が無い月は非表示)
  - 明細リスト: 取引日時の降順。計算対象外の明細は「計算対象外」ラベル付き・グレー表示
  - DEBUG ビルドのみ AppBar 右にデバッグメニュー (`features/debug`) の入口

## フロー

1. 起動すると当月の明細を snapshot listener で購読する (リアルタイム反映・オフラインキャッシュ対応)
2. 前月・次月ボタンで表示月を切り替えると、その月のクエリを購読し直す
3. 明細の追加・変更は listener 経由で自動的に一覧と集計へ反映される

## データ形式

- 明細: `/users/{userID}/transactions/{id}` の `Transaction` (lib/entity/transaction.dart)
- 月次クエリ: `yearMonth == "yyyy-MM"` + `transactionDate` 降順
  (複合インデックス: firebase/firestore.indexes.json)
- 計算対象外 (`excludedFromAggregation: true`) の明細は一覧に表示するが集計に含めない
