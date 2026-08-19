---
feature: settings
verification: mobile-mcp
last_verified_commit: e389e1c15b680ccf604644635cd7dda411f2623a
last_verified_at: 2026-08-19
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

- [x] **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / PrivacyPolicy / SpecifiedCommercialTransactionAct-ja) が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く
  - 自動化: manual (シミュレータの言語切替を伴うため agent のシミュレータ操作で確認する)
- [x] **戻る操作**: 戻るボタンで月次一覧へ戻る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **設定画面の表示**: 月次一覧の設定アイコンから設定画面へ遷移し、利用規約・プライバシーポリシー・特定商取引法に基づく表示の 3 行が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、行の文言は英語 ("Terms of Service" / "Privacy Policy" / "Commercial Transaction Disclosure") になる。日本語ロケールの「利用規約 / プライバシーポリシー / 特定商取引法に基づく表示」に対応する 3 行が同じ順で表示されることを確認した。

月次一覧の右上の設定アイコンから遷移した設定画面。タイトル "Settings" と、1 枚のカードにまとまった 3 行 (それぞれ右端に > のシェブロン) が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/9d7ba270-694c-4949-9f69-c9802334b795.jpg" width="320">

</details>

### **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / PrivacyPolicy / SpecifiedCommercialTransactionAct-ja) が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、行の文言は英語表示。またこの Simulator は英語ロケールなので Privacy Policy 行が開くのは PrivacyPolicy-en で、日本語ロケールでの PrivacyPolicy (ja) が開くことは本 Simulator では確認できない。

前回 (2026-08-19 の初回実行) は GitHub Pages 未有効化で 404 だったが、有効化後の再確認で解消。

3 行とも既定ブラウザ (Safari) が起動し、法務ドキュメントの本文が表示された。Safari のアドレス欄をタップして編集状態にし、`bash tmp/qa/wda.sh elements` の `"name": "URL"` の value で読み取ったフル URL もそれぞれ期待どおりだった:

```
Terms of Service                  → https://bannzai.github.io/kashakeibo/Terms
Privacy Policy                    → https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
Commercial Transaction Disclosure → https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
```

左から Terms of Service (見出し「カシャケイボ利用規約」と本文・第1条(定義))、Privacy Policy (見出し "Privacy Policy" と英語本文・"User Information We Collect and How We Collect It")、Commercial Transaction Disclosure (見出し「特定商取引法に基づく表示」と問い合わせ先・販売価格・支払方法) をタップした結果。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/31a52e36-3cc5-444a-978e-0124191d8366.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/31d846aa-0ff6-4dff-9fd5-651cbfee782d.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/3e39e4a7-d0fe-4caf-9c7d-33b1e2e8bf39.jpg" width="320">

Safari からアプリへ戻るには `bash tmp/qa/wda.sh launch com.bannzai.kashakeibo` を実行する (設定画面を開いたまま復帰する)。

</details>

### **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator は英語ロケールのため、この項目の前提 (端末の言語が英語) はそのまま満たされている。日本語ロケールに切り替えての PrivacyPolicy (ja) 側の確認は本 Simulator ではできない。

前回 (2026-08-19 の初回実行) は GitHub Pages 未有効化で 404 だったが、有効化後の再確認で解消。

Privacy Policy 行をタップすると Safari が `https://bannzai.github.io/kashakeibo/PrivacyPolicy-en` を開き (アドレス欄を編集状態にして `elements` の `"name": "URL"` の value で確認)、英語版プライバシーポリシー本文が表示された。見出し "Privacy Policy" と、`bannzai (the "Provider") establishes this Privacy Policy...` で始まる英語の本文・"User Information We Collect and How We Collect It" の節が読める。アプリ側のロケール分岐 (英語なら PrivacyPolicy-en) も期待どおり。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/31d846aa-0ff6-4dff-9fd5-651cbfee782d.jpg" width="320">

</details>

### **戻る操作**: 戻るボタンで月次一覧へ戻る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した。

設定画面の AppBar 左上の戻るボタンをタップすると月次一覧へ戻り、サマリー (Spending ¥12,640 / Income ¥860,000 / Balance ¥847,360)・重複候補バナー・カテゴリ内訳・明細一覧が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/0587deb0-7050-45b1-9971-edce22a6d273.jpg" width="320">

</details>

</details>

---

## 2. 配信

- [x] **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す
  - 自動化: manual (curl での機械確認が可能。Maestro ではなくコマンド実行で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

この項目は curl での確認のため、画面のスクリーンショットではなく curl の出力を画像化して貼る (mark_verified.sh がチェック済み項目に画像を要求するため)。

前回 (2026-08-19 の初回実行) は GitHub Pages 未有効化で 404 だったが、有効化後の再確認で解消。

ホストマシンから 6 URL に `curl -s -o /dev/null -w '%{http_code} %{url_effective}\n'` を実行した結果、すべて 200 を返した:

```
200 https://bannzai.github.io/kashakeibo/
200 https://bannzai.github.io/kashakeibo/Terms
200 https://bannzai.github.io/kashakeibo/PrivacyPolicy
200 https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
200 https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
200 https://bannzai.github.io/kashakeibo/AccountDeletion
```

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/78fa607a-9ccd-43fc-8fca-b3742196eb0a.png" width="320">

</details>

</details>
