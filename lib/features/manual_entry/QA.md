---
feature: manual_entry
verification: mobile-mcp
last_verified_commit: 7da2a80ac3ab9bea18d06b5316b381e02ea6a46a
last_verified_at: 2026-08-19
---

# manual_entry QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/6 (手動明細入力の受け入れ条件)
- 関連: lib/features/manual_entry/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 金額・日付・店名・カテゴリ・収支種別を入力して明細を登録できる | 支出の登録 / 収入の登録 / 日付の変更 / 非既定カテゴリの登録 (未実施) / 前月・翌月の日付で登録 (未実施) |
| S2 | 出所記録が「手動」で保存される | 支出の登録 (一覧の行に出所「手動」が表示されることで確認) |
| S3 | 登録した明細が月次一覧と集計に即時反映される | 支出の登録 / 収入の登録 |

## 1. 入力と登録

- [x] **支出の登録**: 金額・店名を入力し「登録する」をタップすると、シートが閉じて登録完了のスナックバーが出る。月次一覧に出所「手動」の支出明細が即時反映され、サマリーの支出額が増える
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **収入の登録**: 収支種別を「収入」に切り替えて登録すると、カテゴリが給与・その他に切り替わり、一覧に `+¥` (セージ色) の収入明細が反映されサマリーの収入額が増える
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **カテゴリの切替**: 収支種別の切替で選択可能カテゴリが切り替わる (支出: 食費・外食・日用品・交通・サブスク・その他 / 収入: 給与・その他)。切替時の初期選択は支出=食費、収入=給与
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **日付の変更**: 日付ボタンからデートピッカーで過去日を選ぶと、選んだ日付で登録され一覧の該当日グループに表示される。日付の初期値は今日
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **店名の省略**: 店名を空のまま登録すると、既定タイトル「現金支出」(l10n の manualEntryDefaultTitle) で登録される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **非既定カテゴリの登録**: 初期選択以外のカテゴリ (例: 支出の「外食」、収入の「その他」) を選んで登録すると、一覧の行にそのカテゴリが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - ⏭️ スキップ: 2026-08-19 の実行では未実施 (登録したのは初期選択の食費・給与のみ)。次回 run-qa で ChoiceChip を切り替えて登録し、行のカテゴリ表示で確認する
- [ ] **前月・翌月の日付で登録**: デートピッカーで前月または翌月の日付を選んで登録すると、明細は登録月ではなく選んだ日付の月にだけ表示される (yearMonth が transactionDate から導出される)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - ⏭️ スキップ: 2026-08-19 の実行では未実施 (同月内の過去日への変更のみ)。次回 run-qa で前月の日付で登録し、月切替で表示月を確認する

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **支出の登録**: 金額・店名を入力し「登録する」をタップすると、シートが閉じて登録完了のスナックバーが出る。月次一覧に出所「手動」の支出明細が即時反映され、サマリーの支出額が増える

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (「登録する」= "Add transaction"、登録完了のスナックバー = "Transaction added"、出所「手動」= "Manual")。

¥1200 / 店名 "Lawson QA" を入力して "Add transaction" をタップした結果。シートが閉じ、"Transaction added" のスナックバーが表示され、Spending が ¥0 → ¥1,200 に増え、"Tue, Aug 18" グループに `Lawson QA / Food · Manual / -¥1,200` の行が即時反映された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/d724b514-26a4-4d40-8fbd-be2885e38326.jpg" width="320">

</details>

### **収入の登録**: 収支種別を「収入」に切り替えて登録すると、カテゴリが給与・その他に切り替わり、一覧に `+¥` (セージ色) の収入明細が反映されサマリーの収入額が増える

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (「収入」= "Income"、給与 = "Salary")。

¥300000 / 店名 "Salary August" を入力し Income に切り替えて登録した結果。カテゴリが Salary / Other に切り替わった状態で登録され、一覧に `Salary August / Salary · Manual / +¥300,000` の行がセージ色で表示され、サマリーの Income が ¥0 → ¥300,000、Balance が ¥-1,200 → ¥298,800 になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ae0bffd8-d2b3-4da6-89e5-b2080f74ad70.jpg" width="320">

</details>

### **カテゴリの切替**: 収支種別の切替で選択可能カテゴリが切り替わる (支出: 食費・外食・日用品・交通・サブスク・その他 / 収入: 給与・その他)。切替時の初期選択は支出=食費、収入=給与

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (支出カテゴリ = Food / Eating out / Daily goods / Transport / Subscriptions / Other、収入カテゴリ = Salary / Other)。

左: シートを開いた直後の支出 (Spending 選択)。カテゴリは 6 件で Food がチェック付きで初期選択。右: Income に切り替えた後。カテゴリが Salary / Other の 2 件に切り替わり、Salary がチェック付きで初期選択になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/a87defd6-1a0f-4bbe-a3e4-f8961390c2eb.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/89de375c-f5da-4981-a294-8fbec3c28c7f.jpg" width="320">

</details>

### **日付の変更**: 日付ボタンからデートピッカーで過去日を選ぶと、選んだ日付で登録され一覧の該当日グループに表示される。日付の初期値は今日

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (デートピッカーは Material の "Select date"、確定は "OK")。runner の Simulator の当日は 2026-08-18 (UTC) で、ホストマシンの日付 (JST 2026-08-19) とは 1 日ずれる。日付の初期値の判定はホストではなく Simulator の当日を基準にする。

左: 日付ボタン (初期値 "Aug 18, 2026") からデートピッカーを開き Aug 10 を選択した状態。18 に "Today" の枠線が付いており、初期値が Simulator の当日と一致していることも同時に確認できる。右: ¥4500 / "Past Date Cafe" を Aug 10 で登録した結果。一覧に "Mon, Aug 10" の日付グループが新設され、`Past Date Cafe / Food · Manual / -¥4,500` が入った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/1bf59282-4cb9-403a-95ba-072371e493e4.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/f72577df-5285-4445-b939-0b4ec3372456.jpg" width="320">

</details>

### **店名の省略**: 店名を空のまま登録すると、既定タイトル「現金支出」(l10n の manualEntryDefaultTitle) で登録される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (manualEntryDefaultTitle の en 値 = "Cash expense")。

金額 ¥780 のみ入力し店名 ("Store or note") を空のまま登録した結果。一覧に `Cash expense / Food · Manual / -¥780` の行が入り、既定タイトルが適用された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/97059259-3eb8-40d4-a7cb-f3365f3e4d18.jpg" width="320">

</details>

### **非既定カテゴリの登録**: 初期選択以外のカテゴリ (例: 支出の「外食」、収入の「その他」) を選んで登録すると、一覧の行にそのカテゴリが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **前月・翌月の日付で登録**: デートピッカーで前月または翌月の日付を選んで登録すると、明細は登録月ではなく選んだ日付の月にだけ表示される (yearMonth が transactionDate から導出される)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. バリデーション・キャンセル

- [x] **金額のバリデーション**: 金額が空・0 のまま登録しようとするとエラーメッセージが表示され、登録されない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **金額欄の非数字入力**: 金額欄に文字・小数点・符号を入力 (貼り付け) しても除去され、数字だけが残る (FilteringTextInputFormatter.digitsOnly)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - ⏭️ スキップ: 2026-08-19 の実行では未実施。WDA の `keys` で `12a.5-` のような文字列を送り、残る値が `125` になることを確認する
- [x] **キャンセル**: 閉じるボタンまたはシート外タップで閉じると、明細が登録されずスナックバーも出ない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - シート外タップは、キーボードが出ている間は scrim が画面上端の 62pt 分しか無く、ステータスバー領域と重なってタップが届かない。先に店名欄で改行を送ってキーボードを閉じると scrim が 222pt に広がり、その領域 (例: 中央 y=150pt) のタップでシートが閉じる
- [ ] **登録失敗時のエラー表示**: 登録に失敗した場合、エラーメッセージが加工されずシート内に表示され、シートは開いたまま再試行できる
  - 自動化: todo (Firestore 書き込みはオフラインキャッシュでも成功するため、失敗状態を作る手段が未整備)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **金額のバリデーション**: 金額が空・0 のまま登録しようとするとエラーメッセージが表示され、登録されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (manualEntryAmountRequired の en 値 = "Enter an amount of at least 1 yen")。

左: 金額を空のまま "Add transaction" をタップ。金額欄が赤枠になり "Enter an amount of at least 1 yen" が表示され、シートは開いたまま。右: 金額に 0 を入れて再度タップしても同じエラーで登録されない。どちらもシート背後のサマリー Spending は ¥6,480 のまま増えておらず、スナックバーも出ていない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/653496a2-92ec-4c8d-8344-86ed7256d631.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/89d476fc-2eed-45a8-9dcc-428cd632ed31.jpg" width="320">

</details>

### **金額欄の非数字入力**: 金額欄に文字・小数点・符号を入力 (貼り付け) しても除去され、数字だけが残る (FilteringTextInputFormatter.digitsOnly)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **キャンセル**: 閉じるボタンまたはシート外タップで閉じると、明細が登録されずスナックバーも出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した (閉じるボタンの accessibility label = "Close")。

左: 金額 0 を入れた状態で右上の閉じる (×) ボタンをタップして閉じた直後。右: 金額 9999 を入れた状態でシート外 (scrim) をタップして閉じた直後。どちらもスナックバーは出ず、Spending ¥6,480 / Income ¥300,000 / Balance ¥293,520 と明細 4 件がキャンセル前から変化していない (入力した 0・9999 の明細は追加されていない)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/bbb08a3d-7eb0-4aad-803c-968e6f5f1afe.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/4993a3bf-456f-48e7-8217-e568eaca33d5.jpg" width="320">

</details>

### **登録失敗時のエラー表示**: 登録に失敗した場合、エラーメッセージが加工されずシート内に表示され、シートは開いたまま再試行できる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
