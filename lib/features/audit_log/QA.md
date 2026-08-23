---
feature: audit_log
verification: mobile-mcp
last_verified_commit: 未実行
last_verified_at: 未実行
---

# audit_log QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/73 (訂正削除履歴・検索要件の受け入れ条件)
- 関連: lib/features/audit_log/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| A1 | 明細の作成・訂正・削除と画像の削除について、いつ・どの操作が・何に対して行われたかを後から確認できる | 履歴画面の表示 (API 経由) / 操作後の pull-to-refresh での反映 |
| A2 | 履歴は本人のものだけが返る (Worker が JWT の uid で絞る) | 他ユーザーの履歴を取得できないこと |
| A3 | アカウント削除時は履歴のパージを Worker へ依頼する | アカウント削除でのパージ登録 |

## 1. 履歴の表示

- [ ] **履歴画面の表示 (API 経由)**: 設定画面の「操作履歴」をタップすると Worker から取得した履歴が
  操作の新しい順に並び、追加・訂正・削除の各行に店名・金額・日時が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **履歴が無い状態の表示**: 明細を一度も操作していないユーザーでは「操作の履歴はまだありません」が表示される
  - 自動化: manual (新規 uid の作成が必要なため agent のシミュレータ操作で確認する)
- [ ] **pull-to-refresh での再取得**: 履歴画面を開いたまま明細を操作しても一覧は自動更新されず、
  引き下げると取り直されて最新の履歴が先頭に並ぶ
  - 自動化: manual (リアルタイム反映を持たない仕様の確認のため、シミュレータ操作で確認する)
- [ ] **取得失敗時の表示**: Worker がエラー (429 の回数上限・5xx) を返した時、そのメッセージが加工されずに表示される
  - 自動化: manual (エラー応答の作り込みが必要。デコードとメッセージの非加工は
    test/features/audit_log/audit_log_client_test.dart で検証している)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **履歴画面の表示 (API 経由)**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **履歴が無い状態の表示**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **pull-to-refresh での再取得**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **取得失敗時の表示**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 無料プランの履歴制限

- [ ] **無料プランの注記表示**: 無料プランでは履歴一覧の上に「無料プランでは直近3ヶ月の操作履歴だけを表示します」の
  注記が表示され、タップでペイウォールが開ける
  - 自動化: manual (直近 3 ヶ月より古い履歴を返さないことは Worker 側で適用・検証する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無料プランの注記表示**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. データの寿命

- [ ] **アカウント削除でのパージ登録**: 設定画面からアカウントを削除すると Worker の `DELETE /audit-logs` が
  呼ばれ、パージの受付 (202) 後に明細・ユーザードキュメント・Auth が削除される。パージ依頼が失敗した場合は
  明細の削除へ進まない
  - 自動化: auto (test/provider/account_test.dart の「アカウント削除は再認証後に全明細・ユーザードキュメント・Authを削除し、
    操作履歴のパージを依頼する」と「操作履歴のパージ依頼が失敗した場合はFirestoreとAuthを削除しない」。
    BigQuery 側の実削除は Worker の QA で確認する)
- [ ] **他ユーザーの履歴を取得できないこと**: 取得も削除も JWT の uid 配下に限られる
  - 自動化: todo (アプリ UI からは他ユーザーの履歴を要求できないため、Worker 側のテストとして整備する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **アカウント削除でのパージ登録**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **他ユーザーの履歴を取得できないこと**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
