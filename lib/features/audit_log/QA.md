---
feature: audit_log
verification: mobile-mcp
last_verified_commit: 21738a3f1de08c355ba9be1949a082dcc4bb85a0
last_verified_at: 2026-08-23
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

- [x] **履歴画面の表示 (API 経由)**: 設定画面の「操作履歴」をタップすると Worker から取得した履歴が
  操作の新しい順に並び、追加・訂正・削除の各行に店名・金額・日時が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **履歴が無い状態の表示**: 明細を一度も操作していないユーザーでは「操作の履歴はまだありません」が表示される
  - 自動化: manual (新規 uid の作成が必要なため agent のシミュレータ操作で確認する)
- [x] **pull-to-refresh での再取得**: 履歴画面を開いたまま明細を操作しても一覧は自動更新されず、
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

**確認日: 2026-08-23** (ローカル Simulator / kashakeibo-dev。extension・Worker とも dev にデプロイ済みの実環境)

アプリから「計算対象から除外 (訂正)」「サンプルレシート撮影フローで登録 (追加)」「画像だけを削除 (画像を削除)」を実行し、extension → BigQuery changelog → Worker GET /audit-logs 経由で 3 件が新しい順に表示された。各行に店名・金額・サーバー時刻と、訂正の変更内容 (計算対象 / 元画像) の注記が付く。extension 導入前の操作 (それ以前のサンプル明細 5 件の追加等) は changelog に存在しないため表示されない (導入時点から記録が始まる仕様どおり)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/d0b52a91-f2c7-4ba8-9dd3-8e740f8f0001.png" width="320" alt="訂正・追加・画像を削除の 3 件が新しい順に並んだ操作履歴画面" />

</details>

### **履歴が無い状態の表示**

<details><summary>動作確認スクショ</summary>

**未検証 (2026-08-23)**: 今回の E2E は履歴のある既存 uid で行ったため未実施 (新規 uid の作り込みが必要)。空配列時の表示はウィジェット実装のみで分岐し、以前の方式で同一文言の表示を確認済み。

</details>

### **pull-to-refresh での再取得**

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

履歴画面 (訂正 1 件表示) を閉じて明細の追加・画像削除を行い、再度開くと最新 3 件が取得された。一覧を引き下げるとインジケータ表示ののちエラーなく再取得され、同じ最新一覧が維持された。「画面を開いたまま操作し、引き下げるまで自動更新されない」の厳密な手順は未実施 (取得が FutureProvider の 1 回取得であることは実装とテストで担保)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/629dad7c-114b-4bf8-8567-61d22bf10cbc.png" width="320" alt="一覧を引き下げて再取得した後も最新 3 件が維持された操作履歴画面" />

</details>

### **取得失敗時の表示**

<details><summary>動作確認スクショ</summary>

**未検証 (2026-08-23)**: Worker からの 429 / 5xx の作り込みは未実施 (デコードと非加工はユニットテストで検証済み)。参考: App Check debug token 未登録時のクライアント側エラー ([firebase_app_check/unknown] 403) が加工されず全文表示されることは実機で確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/b795e2c9-4629-4714-871a-c8be66bc71b6.png" width="320" alt="App Check の 403 エラーが加工されず全文表示された操作履歴画面" />

</details>

</details>

---

## 2. 無料プランの履歴制限

- [x] **無料プランの注記表示**: 無料プランでは履歴一覧の上に「無料プランでは直近3ヶ月の操作履歴だけを表示します」の
  注記が表示され、タップでペイウォールが開ける
  - 自動化: manual (直近 3 ヶ月より古い履歴を返さないことは Worker 側で適用・検証する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **無料プランの注記表示**

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (RevenueCat 未設定の debug ビルド = プレミアムなし)

履歴一覧の上に注記が表示された (「履歴画面の表示」のスクショ参照)。直近 3 ヶ月より古い履歴を返さない絞り込みは Worker のユニットテスト (@oldestTimestamp パラメータ) で検証している。

</details>

</details>

---

## 3. データの寿命

- [x] **アカウント削除でのパージ登録**: 設定画面からアカウントを削除すると Worker の `DELETE /audit-logs` が
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

**確認日: 2026-08-23**

`flutter test` (158 件 pass) に含まれる test/provider/account_test.dart で、パージ依頼が呼ばれること・失敗時に後続の削除へ進まないことを検証した。BigQuery 側の実削除 (毎時 cron の DML) はシミュレータでは未検証 (パージ待機 1 時間以上を要するため。ロジックは workers/image/test/audit_log.test.ts で検証済み)。

</details>

### **他ユーザーの履歴を取得できないこと**

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
