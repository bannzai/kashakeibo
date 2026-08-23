# audit_log (操作履歴)

## 概要

明細の追加・訂正・削除と、元画像 (R2) の削除の履歴を後から確認できるようにする
(issue #73 の訂正削除履歴)。履歴は「いつ・どの操作が・何に対して行われたか」を残すためのもので、
削除された明細の店名・金額も履歴に残るため、明細が消えた後も何を消したのかを確認できる。

履歴の正は BigQuery にあり、アプリは履歴を書き込まない。明細の変更は「Stream Firestore to BigQuery
extension」が `users/{userID}/transactions` の変更から自動生成する changelog に、画像 (R2) の削除は
Worker が画像削除の成功時に記録する `image_deletion_logs` に残る (明細を変えない画像削除は changelog に
現れないため、Worker 側で記録して監査の抜けを作らない)。Worker がその 2 つを読んで新しい順に統合した
結果を、アプリは API から取得して表示するだけ (読み取り専用で、履歴から明細を復元する導線は持たない)。

## 画面

- `AuditLogPage`: 設定画面の「操作履歴」から表示する
  - 行の左に操作種別のラベル (追加 / 訂正 / 削除 / 画像を削除 / その他の操作)
  - 中央に対象明細の店名と、操作が起きたサーバー時刻 (端末のローカル時刻で表示)。訂正では
    変更したフィールドの表示名 (計算対象 / 元画像 / 重複の判定) も添える
  - 右に操作時点の金額
  - 履歴が 1 件も無い時は「操作の履歴はまだありません」を表示する
  - 引き下げる (pull-to-refresh) と Worker から取り直す

## フロー

1. 明細を操作する (追加・計算対象の切替・元画像の削除・明細の削除・重複候補のマージ・別々の支出として残す)
2. 明細の変更が BigQuery の changelog に自動で記録される (アプリ側の書き込みは明細だけ)
3. 設定画面の「操作履歴」を開くと、Worker の `GET /audit-logs` から新しい順に取得して表示する
4. 画面を開いたまま行った操作は自動では反映されないため、pull-to-refresh で取り直す

## データ形式

- 履歴 1 件: `GET /audit-logs` のレスポンスの `auditLogs[]` 要素
  (lib/features/audit_log/audit_log_client.dart の `AuditLog`。API スキーマが SSOT)
- 操作種別 (`operation`): `transactionCreated` / `transactionUpdated` / `transactionDeleted` /
  `transactionImageDeleted`。未知の値は `unknown` として読む
- Worker が記録した画像削除は `transactionImageDeleted` で返るが、明細のドキュメントに紐付かないため
  店名・金額を持たない (時刻と操作種別だけの行として表示される)
- 訂正で変わったフィールド (`changedFieldNames`) は Transaction の Firestore フィールド名
  (`TransactionFirestoreKeys`)
- 「いつ」は `occurredAt` (ISO 8601 の日時文字列)。一覧はこの降順で返る

## 有効期限・制約

- 一覧が一度に取得できるのは最大 200 件。それより古い履歴を辿る導線は持たない
- 無料プランでは直近 3 ヶ月の履歴だけが返る (`features/paywall` の履歴制限と同じ範囲)。
  制限はサーバー側で適用され、クライアントは一覧の先頭に注記を出してペイウォールへ誘導する
- Firestore の snapshot listener で購読していた頃のリアルタイム反映は API 化で失われている。
  画面を開いたまま行った操作は pull-to-refresh で取り直す
- 取得回数の上限超過 (429) やサーバーエラー (5xx) は、Worker が返したメッセージを加工せず画面に表示する
- アカウント削除時は Worker の `DELETE /audit-logs` へパージを依頼する (lib/provider/account.dart)。
  BigQuery の実削除は Worker 側で遅延実行されるため、依頼の受付 (202) をもって成功として扱う
