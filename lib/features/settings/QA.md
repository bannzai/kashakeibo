---
feature: settings
verification: mobile-mcp
last_verified_commit: 8a9634107c725e2670c43709dd1ea4493699072f
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
- [ ] **法務ドキュメントを開く**: 各行をタップすると端末の既定ブラウザで bannzai.github.io/kashakeibo/ 配下の該当ページ (Terms / PrivacyPolicy / SpecifiedCommercialTransactionAct-ja) が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - ❌ 失敗: 3 行とも Safari は起動し正しい URL を開くが、どのページも GitHub Pages の「404 File not found」になり法務ドキュメントを閲覧できない。再現手順: 設定画面で Terms of Service / Privacy Policy / Commercial Transaction Disclosure のいずれかをタップ → Safari に GitHub Pages の 404 ページが出る。原因は bannzai/kashakeibo で GitHub Pages が有効化されていないこと (`gh api repos/bannzai/kashakeibo/pages` が 404 Not Found を返す。docs/ 配下のファイル自体は origin/main に存在する)。issue: 未起票
- [ ] **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く
  - 自動化: manual (シミュレータの言語切替を伴うため agent のシミュレータ操作で確認する)
  - ❌ 失敗: 英語ロケールの Simulator で Privacy Policy 行が開く URL は正しく `https://bannzai.github.io/kashakeibo/PrivacyPolicy-en` になるが、そのページが 404 のため英語版プライバシーポリシーを閲覧できない。アプリ側のロケール分岐は期待どおりで、失敗の原因は GitHub Pages 未有効化 (「法務ドキュメントを開く」と同じ)。再現手順: 英語ロケールの Simulator で設定画面 → Privacy Policy をタップ → Safari の URL が PrivacyPolicy-en なのに 404 ページが出る。issue: 未起票
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

3 行とも既定ブラウザ (Safari) が起動し、`bash tmp/qa/wda.sh elements` で読み取った Safari のアドレス欄はそれぞれ期待どおりの URL だった:

```
Terms of Service                  → https://bannzai.github.io/kashakeibo/Terms
Privacy Policy                    → https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
Commercial Transaction Disclosure → https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
```

しかしどの URL も GitHub Pages の「404 File not found」ページになり、法務ドキュメントが表示されない。左から Terms / Privacy Policy / Commercial Transaction Disclosure をタップした結果。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/6ce15405-97c0-4bb3-8628-813b67983348.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/909425a9-d22a-47d2-b412-02fdea1972d3.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/93bd1871-7213-4ed0-858d-a8d7bb63f8f2.jpg" width="320">

Safari からアプリへ戻るには `bash tmp/qa/wda.sh launch com.bannzai.kashakeibo` を実行する (設定画面を開いたまま復帰する)。

</details>

### **英語環境のプライバシーポリシー**: 端末の言語を英語にした状態でプライバシーポリシーをタップすると PrivacyPolicy-en が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator は英語ロケールのため、この項目の前提 (端末の言語が英語) はそのまま満たされている。日本語ロケールに切り替えての PrivacyPolicy (ja) 側の確認は本 Simulator ではできない。

Privacy Policy 行をタップすると Safari が `https://bannzai.github.io/kashakeibo/PrivacyPolicy-en` を開き、アプリ側のロケール分岐 (英語なら PrivacyPolicy-en) は期待どおり動いている。ただしそのページ自体が GitHub Pages の 404 になるため、英語版プライバシーポリシーは閲覧できない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/909425a9-d22a-47d2-b412-02fdea1972d3.jpg" width="320">

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

- [ ] **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す
  - 自動化: manual (curl での機械確認が可能。Maestro ではなくコマンド実行で確認する)
  - ❌ 失敗: 6 URL すべてが HTTP 404 を返す。再現手順: `curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' <各 URL>` を実行する (出力はエビデンス欄)。GitHub Pages 自体が有効化されておらず (`gh api repos/bannzai/kashakeibo/pages` が「Not Found」)、docs/ 配下の 6 ファイルは origin/main にあるものの配信されていない。issue: 未起票

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **法務ページの配信確認**: https://bannzai.github.io/kashakeibo/ の index・Terms・PrivacyPolicy・PrivacyPolicy-en・SpecifiedCommercialTransactionAct-ja・AccountDeletion が HTTP 200 を返す

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

この項目は curl での確認のためスクリーンショットは無い。ホストマシンから 6 URL に `curl -s -o /dev/null -w '%{http_code} %{url_effective}\n'` を実行した結果:

```
404 https://bannzai.github.io/kashakeibo/
404 https://bannzai.github.io/kashakeibo/Terms
404 https://bannzai.github.io/kashakeibo/PrivacyPolicy
404 https://bannzai.github.io/kashakeibo/PrivacyPolicy-en
404 https://bannzai.github.io/kashakeibo/SpecifiedCommercialTransactionAct-ja
404 https://bannzai.github.io/kashakeibo/AccountDeletion
```

原因の切り分け: GitHub Pages サイトがそもそも作られていない。

```
$ gh api repos/bannzai/kashakeibo/pages
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/pages/pages#get-a-apiname-pages-site","status":"404"}

$ git ls-tree --name-only origin/main docs/
docs/AccountDeletion.md
docs/PrivacyPolicy-en.md
docs/PrivacyPolicy.md
docs/SpecifiedCommercialTransactionAct-ja.md
docs/Terms.md
docs/index.md
```

配信するファイルは origin/main の docs/ に揃っているので、リポジトリ設定で GitHub Pages を有効化 (source を main ブランチの /docs に設定) すれば解消する見込み。

</details>

</details>
