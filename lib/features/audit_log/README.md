# audit_log (操作履歴)

## 概要

明細の追加・訂正・削除と、元画像 (R2) の削除の履歴を記録し、後から確認できるようにする
(issue #73 の訂正削除履歴)。履歴は「いつ・どの操作が・何に対して行われたか」を残すためのもので、
削除された明細の店名・金額も履歴側に写し取るため、明細が消えた後も何を消したのかを確認できる。

履歴は読み取り専用で、履歴から明細を復元する導線は持たない。

## 画面

- `AuditLogPage`: 設定画面の「操作履歴」から表示する
  - 行の左に操作種別のラベル (追加 / 訂正 / 削除 / 画像を削除 / その他の操作)
  - 中央に対象明細の店名と、記録されたサーバー時刻 (端末のローカル時刻で表示)。訂正では
    変更したフィールドの表示名 (計算対象 / 元画像 / 重複の判定) も添える
  - 右に操作時点の金額
  - 履歴が 1 件も無い時は「操作の履歴はまだありません」を表示する

## フロー

1. 明細を操作する (追加・計算対象の切替・元画像の削除・明細の削除・重複候補のマージ・別々の支出として残す)
2. 操作と同じ書き込み (WriteBatch または Firestore トランザクション) で履歴が 1 件記録される。
   明細と履歴が食い違わないよう、常にアトミックに書き込む
3. 元画像 (R2) の削除だけは Firestore とアトミックにできないため、Worker への削除が成功してから
   履歴を記録する (削除されていない画像の履歴を残さない)
4. 設定画面の「操作履歴」から、新しい順に履歴を確認する

## データ形式

- 履歴: `/users/{userID}/auditLogs/{id}` の `AuditLog` (lib/entity/audit_log.dart)
- 操作種別 (`operation`): `transactionCreated` / `transactionUpdated` / `transactionDeleted` /
  `transactionImageDeleted`。未知の値は `unknown` として読む
- 訂正で変わったフィールド (`changedFieldNames`) は Transaction の Firestore フィールド名
  (`TransactionFirestoreKeys`) で保存する
- 「いつ」は `serverCreatedDateTime` (サーバータイムスタンプ)。一覧はこの降順で購読する
  (lib/provider/audit_log.dart)

## 有効期限・制約

- 一覧が一度に購読する件数は `auditLogDisplayLimit` (200 件) まで。それより古い履歴を辿る導線は持たない
- 無料プランでは `features/paywall` の履歴制限 (当月を含む直近 3 ヶ月) を操作履歴にも適用し、
  下限より古い履歴は読み取らない (lib/provider/audit_log.dart の `auditLogsQuery`)。
  制限中は一覧の先頭に注記を出し、タップでペイウォールを開く
- 書き込み直後はサーバータイムスタンプが未確定のため、`serverCreatedDateTime` が null の履歴が
  一時的に流れる。その行は日時の代わりに「同期中」を表示する
- 履歴は `users/{userID}` 配下に閉じており、アカウント削除時に明細と一緒に全削除する
  (lib/provider/account.dart)
- 明細の操作は成功したが履歴の書き込みだけが失敗する状態は作らない (同じバッチ / トランザクション)。
  逆に、同じ操作を再実行した時の履歴は操作ごとに異なる: 値が変わらない訂正は履歴を残さず、
  明細の削除と画像の削除は実行のたびに 1 件残す (lib/provider/transaction.dart の各 call クラス)
