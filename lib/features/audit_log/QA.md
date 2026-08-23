---
feature: audit_log
verification: mobile-mcp
last_verified_commit: d6f42f2c10de1aa3a9d4db26591e898366a42d17
last_verified_at: 2026-08-23
---

# audit_log QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/73 (訂正削除履歴・検索要件の受け入れ条件)
- 関連: lib/features/audit_log/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| A1 | 明細の作成・訂正・削除と画像の削除について、いつ・どの操作が・何に対して行われたかを後から確認できる | 履歴画面の表示 / 明細の追加の記録 / 計算対象の切替の記録 / 元画像の削除の記録 / 明細の削除の記録 |
| A2 | 履歴は `users/{userID}` 配下に閉じる | 他ユーザーの履歴へのアクセス拒否 |
| A3 | アカウント削除時は履歴も含めて全削除する | アカウント削除での履歴の削除 |

## 1. 履歴の表示

- [x] **履歴画面の表示**: 設定画面の「操作履歴」をタップすると履歴画面が開き、操作が新しい順に並ぶ
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **履歴が無い状態の表示**: 明細を一度も操作していないユーザーでは「操作の履歴はまだありません」が表示される
  - 自動化: manual (新規 uid の作成が必要なため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **履歴画面の表示**: 設定画面の「操作履歴」をタップすると履歴画面が開き、操作が新しい順に並ぶ

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (ローカル Simulator / debug ビルド = kashakeibo-dev)

設定画面の「操作履歴」から遷移。削除 (10:27) → 訂正 (10:27) → 追加 5 件 (10:22) の新しい順で表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/277dfe6b-9da1-4648-b0a6-b2ce31ea2547.png" width="320" />

</details>

### **履歴が無い状態の表示**: 明細を一度も操作していないユーザーでは「操作の履歴はまだありません」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

明細を一度も操作していない匿名 uid (初回起動直後) で履歴画面を開き、「操作の履歴はまだありません」が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/5306549a-e3f0-44a9-98de-cc31d9256385.png" width="320" />

</details>

</details>

---

## 2. 操作の記録

- [x] **明細の追加の記録**: 手動入力または撮影・取込で明細を登録すると、「追加」の履歴が店名・金額・日時付きで残る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **計算対象の切替の記録**: 明細詳細で計算対象から除外すると、「訂正」の履歴が「計算対象」の注記付きで残る。同じ値へ切り替え直さない再実行では履歴が増えない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **元画像の削除の記録**: 明細詳細で「画像だけを削除」すると、「画像を削除」と「訂正」(元画像) の履歴が残る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細の削除の記録**: 明細を削除すると「削除」の履歴が残り、明細が一覧から消えた後も履歴に店名と金額が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **重複候補の解決の記録**: 重複候補を「1件にまとめる」と残す側の「訂正」と削除側の「削除」が、「別々の支出として残す」と両方の「訂正」(重複の判定) が残る
  - 自動化: manual (重複候補の作り込みが必要なため agent のシミュレータ操作で確認する。作り込み手順はルート QA.md の「再現が難しい操作の手順」)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **明細の追加の記録**: 手動入力または撮影・取込で明細を登録すると、「追加」の履歴が店名・金額・日時付きで残る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

開発者メニューの「サンプル明細を追加」(AddTransaction 経由) で 5 件登録し、それぞれに「追加」の履歴が店名・金額・サーバー時刻 (2026/8/23 10:22) 付きで残った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/48473495-17d8-451b-9708-50791dbdf241.png" width="320" />

</details>

### **計算対象の切替の記録**: 明細詳細で計算対象から除外すると、「訂正」の履歴が「計算対象」の注記付きで残る。同じ値へ切り替え直さない再実行では履歴が増えない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

明細「電車」を計算対象から除外し、「訂正」の履歴が「計算対象」の注記付きで残った (下記スクショの上から 2 件目)。同じ値の再実行で履歴が増えないことは test/provider/transaction_test.dart の同値書き込みのテストで検証している (シミュレータ上での再実行は未実施)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/277dfe6b-9da1-4648-b0a6-b2ce31ea2547.png" width="320" />

</details>

### **元画像の削除の記録**: 明細詳細で「画像だけを削除」すると、「画像を削除」と「訂正」(元画像) の履歴が残る

<details><summary>動作確認スクショ</summary>

**未検証 (2026-08-23)**: サンプル明細は手動入力扱いで元画像を持たず、画像付き明細の作り込み (撮影フロー + App Check debug token 登録) を要するためシミュレータでは未実施。記録ロジック自体は test/provider/transaction_test.dart の RemoveTransactionSourceImage のテスト (画像削除の履歴 + sourceImageObjectKey の訂正履歴) で検証済み。

</details>

### **明細の削除の記録**: 明細を削除すると「削除」の履歴が残り、明細が一覧から消えた後も履歴に店名と金額が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

明細「電車」を削除し、「削除」の履歴が残った。明細一覧から消えた後も履歴に店名「電車」と金額 ¥460 が表示されている。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/277dfe6b-9da1-4648-b0a6-b2ce31ea2547.png" width="320" />

</details>

### **重複候補の解決の記録**: 重複候補を「1件にまとめる」と残す側の「訂正」と削除側の「削除」が、「別々の支出として残す」と両方の「訂正」(重複の判定) が残る

<details><summary>動作確認スクショ</summary>

**未検証 (2026-08-23)**: 重複候補の作り込みを伴うシミュレータ操作は未実施。記録ロジック自体は test/provider/transaction_test.dart の MergeDuplicateTransactions / KeepBothTransactions のテストで検証済み。

</details>

</details>

---

## 3. データの寿命

- [x] **アカウント削除での履歴の削除**: 設定画面からアカウントを削除すると、`/users/{uid}/auditLogs` のドキュメントが 1 件も残らない
  - 自動化: auto (test/provider/account_test.dart の「アカウント削除は再認証後に全明細・操作履歴・ユーザードキュメント・Authを削除する」。Firestore 実機での確認は Firebase コンソールで行う)
- [ ] **他ユーザーの履歴へのアクセス拒否**: 別の匿名 uid から `/users/{他人の uid}/auditLogs` を読み書きしようとすると permission-denied になる (firebase/firestore.rules の再帰ワイルドカード)
  - 自動化: todo (アプリ UI からは他ユーザーのパスにアクセスできないため、Firebase Emulator 上のルールテストとして整備する。ルート QA.md の明細側の同項目と同じ扱い)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **アカウント削除での履歴の削除**: 設定画面からアカウントを削除すると、`/users/{uid}/auditLogs` のドキュメントが 1 件も残らない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

`flutter test` (152 件 pass) に含まれる test/provider/account_test.dart のアカウント削除テストで、auditLogs コレクションが空になることを検証した。シミュレータからの実削除は未実施 (uid が失われ再作成が必要になるため)。

</details>

### **他ユーザーの履歴へのアクセス拒否**: 別の匿名 uid から `/users/{他人の uid}/auditLogs` を読み書きしようとすると permission-denied になる (firebase/firestore.rules の再帰ワイルドカード)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
