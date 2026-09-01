---
feature: onboarding
verification: mobile-mcp,maestro
last_verified_commit: null
last_verified_at: null
---

# onboarding QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/76
- 設計: documents/onboarding-design.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 価値宣言、課題、個別化、社会的証明、プラン生成、結果を順に提示する | 初回オンボーディングの導線 |
| S2 | US 向けは長尺、JP 向けは短尺のファネルを表示する | ロケール別の画面数 |
| S3 | 回答を結果へ反映してから既存ペイウォールへ遷移する | 個別化された結果とペイウォール |
| S4 | オンボーディング完了とトライアル開始を計測できる | ファネルと購入のAnalyticsイベント |
| S5 | 完了後の再起動ではオンボーディングを再表示しない | 完了状態の永続化 |

## 1. 初回導線

- [ ] **初回オンボーディングの導線**: 初回起動時に価値宣言から質問、社会的証明、プラン生成、結果まで順に進み、質問へ回答する前は次へ進めない
  - 自動化: auto（maestro/flows/onboarding.yaml）
- [ ] **ロケール別の画面数**: 日本語では7画面、英語では価値説明・頻度・意思確認を加えた10画面を表示する
  - 自動化: auto（test/features/onboarding/onboarding_page_test.dart）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回オンボーディングの導線**: 初回起動時に価値宣言から質問、社会的証明、プラン生成、結果まで順に進み、質問へ回答する前は次へ進めない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **ロケール別の画面数**: 日本語では7画面、英語では価値説明・頻度・意思確認を加えた10画面を表示する

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 個別化と課金導線

- [ ] **個別化された結果とペイウォール**: 選択した悩み・記録対象・目標を結果へ反映し、最終ボタンから既存ペイウォールへ遷移する
  - 自動化: auto（maestro/flows/onboarding.yaml）
- [ ] **完了状態の永続化**: ペイウォールを閉じると月次画面が表示され、アプリを終了して再起動してもオンボーディングを再表示しない
  - 自動化: auto（maestro/flows/onboarding.yaml）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **個別化された結果とペイウォール**: 選択した悩み・記録対象・目標を結果へ反映し、最終ボタンから既存ペイウォールへ遷移する

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **完了状態の永続化**: ペイウォールを閉じると月次画面が表示され、アプリを終了して再起動してもオンボーディングを再表示しない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 3. Analytics

- [ ] **ファネルと購入のAnalyticsイベント**: 開始・各画面・回答・完了を記録し、実際のentitlementがtrialならtrial_start、paidならpurchase_completeを記録する
  - 自動化: auto（test/features/onboarding/onboarding_page_test.dart、test/features/paywall/paywall_page_test.dart）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **ファネルと購入のAnalyticsイベント**: 開始・各画面・回答・完了を記録し、実際のentitlementがtrialならtrial_start、paidならpurchase_completeを記録する

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---
