---
feature: settings
verification: mobile-mcp
last_verified_commit: null
last_verified_at: null
---

# settings QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/18 (GitHub Pages 有効化と法務ドキュメント導線の受け入れ条件)
- 関連: lib/features/settings/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | https://bannzai.github.io/kashakeibo/ で index・Terms・PrivacyPolicy・SpecifiedCommercialTransactionAct-ja・AccountDeletion が 200 を返す | 法務ページの配信確認 |
| S2 | 設定画面に利用規約・プライバシーポリシー・特商法表記へのリンクがある | 設定画面の表示 / 法務ドキュメントを開く |
| S3 | en-US ストアメタデータの privacy_url 用に英語版法務ページを用意する | 英語環境のプライバシーポリシー |

## 1. 設定画面

- [ ] **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / PrivacyPolicy / SpecifiedCommercialTransactionAct-ja) が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く
  - 自動化: manual (シミュレータの言語切替を伴うため agent のシミュレータ操作で確認する)
- [ ] **戻る操作**: 戻るボタンで月次一覧へ戻る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / PrivacyPolicy / SpecifiedCommercialTransactionAct-ja) が開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **戻る操作**: 戻るボタンで月次一覧へ戻る

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 配信

- [ ] **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す
  - 自動化: manual (curl での機械確認が可能。Maestro ではなくコマンド実行で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
