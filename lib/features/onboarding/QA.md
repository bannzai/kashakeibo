---
feature: onboarding
verification: mobile-mcp,maestro
last_verified_commit: e9122a0b1d37eaea0fb11266fa9c4bce355f02f8
last_verified_at: 2026-09-01
---

# onboarding QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/76
- 設計: documents/onboarding-design.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 価値宣言、課題、個別化、社会的証明、プラン生成、結果を順に提示する | 初回オンボーディングの導線 |
| S2 | 英語では長尺、日本語・韓国語・中国語では短尺のファネルを表示する | ロケール別の画面数 |
| S3 | 回答を結果へ反映してから既存ペイウォールへ遷移する | 個別化された結果とペイウォール |
| S4 | オンボーディング完了とトライアル開始を計測できる | ファネルと購入のAnalyticsイベント |
| S5 | 完了後の再起動ではオンボーディングを再表示しない | 完了状態の永続化 |

## 1. 初回導線

- [x] **初回オンボーディングの導線**: 初回起動時に価値宣言から質問、社会的証明、プラン生成、結果まで順に進み、質問へ回答する前は次へ進めない
  - 自動化: auto（maestro/flows/onboarding.yaml）
- [x] **ロケール別の画面数**: 日本語・韓国語・中国語では7画面、英語では価値説明・頻度・意思確認を加えた10画面を表示する
  - 自動化: auto（test/features/onboarding/onboarding_page_test.dart）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **初回オンボーディングの導線**: 初回起動時に価値宣言から質問、社会的証明、プラン生成、結果まで順に進み、質問へ回答する前は次へ進めない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

専用のiPhone 16 Pro Simulatorで日本語7画面の初期表示から完了まで確認した。Maestroでは未回答の「次へ」をタップしても悩み画面から進まないことを含め、価値宣言、質問、社会的証明、プラン生成、結果の全コマンドがCOMPLETEDになった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/565dabe3-469b-4ecb-a896-31a4573baee2.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/218013be-184c-4d0b-958b-8f6ff68ccbcc.png" width="320">

</details>

### **ロケール別の画面数**: 日本語・韓国語・中国語では7画面、英語では価値説明・頻度・意思確認を加えた10画面を表示する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

日本語は画面上の進捗表示が1/7から7/7まで増えることをSimulatorとMaestroで確認した。レビュー修正後の `e9122a0b1d37eaea0fb11266fa9c4bce355f02f8` ではwidget testを再実行し、英語の1/10と価値説明を含む2/10への遷移、日本語・韓国語・中国語の1/7表示を確認した。韓国語・中国語のSimulator上の見た目は、Xcodeビルドサービスが15分以上応答待ちになったため未検証。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/565dabe3-469b-4ecb-a896-31a4573baee2.png" width="320">

</details>

</details>

---

## 2. 個別化と課金導線

- [x] **個別化された結果とペイウォール**: 選択した悩み・記録対象・目標を結果へ反映し、最終ボタンから既存ペイウォールへ遷移する
  - 自動化: auto（maestro/flows/onboarding.yaml）
- [x] **完了状態の永続化**: ペイウォールを閉じると月次画面が表示され、アプリを終了して再起動してもオンボーディングを再表示しない
  - 自動化: auto（maestro/flows/onboarding.yaml）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **個別化された結果とペイウォール**: 選択した悩み・記録対象・目標を結果へ反映し、最終ボタンから既存ペイウォールへ遷移する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

悩み「毎回の入力が面倒」、記録対象「レシートもWeb明細も両方」、目標「時間を減らす」を選び、結果に対応する見出しと2つのプランが表示されることを確認した。最終ボタンから既存ペイウォールへ遷移した。開発用RevenueCatのOffering未設定状態のため料金カードは未取得表示だが、オンボーディングからの画面遷移は成立している。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/cf31c93f-b342-4d56-bb7c-17b8f980d2d1.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/f3b2bb1f-4d22-4a6b-bcc5-189b2c3b6ed6.png" width="320">

</details>

### **完了状態の永続化**: ペイウォールを閉じると月次画面が表示され、アプリを終了して再起動してもオンボーディングを再表示しない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

ペイウォールを閉じて月次画面へ進んだ後、Maestroでアプリを終了して再起動した。月次画面が再表示され、オンボーディングの価値宣言が存在しないことを確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/35c18bbc-b352-43ca-af7c-facbd5770da8.png" width="320">

</details>

</details>

---

## 3. Analytics

- [x] **ファネルと購入のAnalyticsイベント**: 開始・各画面・回答・完了を記録し、実際のentitlementがtrialならtrial_start、paidならpurchase_completeを記録する
  - 自動化: auto（test/features/onboarding/onboarding_page_test.dart、test/features/paywall/paywall_page_test.dart）

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **ファネルと購入のAnalyticsイベント**: 開始・各画面・回答・完了を記録し、実際のentitlementがtrialならtrial_start、paidならpurchase_completeを記録する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-09-01**

レビュー修正後の `e9122a0b1d37eaea0fb11266fa9c4bce355f02f8` で`flutter test`を再実行し、onboarding_start、7回のonboarding_step_view、回答内容、完了状態保存後のonboarding_complete、Analytics送信失敗時もペイウォールを開くことを確認した。paywall widget testではRevenueCatのPeriodTypeを直接扱い、trial時にtrial_startだけ、既知の有料期間でpurchase_completeを記録し、unknownではどちらも記録しないことを確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260901/f3b2bb1f-4d22-4a6b-bcc5-189b2c3b6ed6.png" width="320">

</details>

</details>

---
