---
feature: capture
verification: mobile-mcp
last_verified_commit: d77ea92d27f40570f879b97fc8a3e746ef7bec34
last_verified_at: 2026-09-02
---

# capture QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/7 (レシート撮影 → 解析 → 確認 → 登録) / https://github.com/bannzai/kashakeibo/issues/8 (スクショ取込: フォトライブラリ選択 + 共有 Extension)
- 関連: lib/features/capture/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | フォトライブラリから画像を選択して解析・登録できる | 写真選択と解析 / 明細なし画像の失敗表示 |
| S2 | 複数明細を含むスクショは複数明細に分解される | 複数明細の候補リスト表示 |
| S3 | 1 画像から複数明細が抽出された場合、個別に採用・破棄を選べる | 候補の破棄 / 候補の修正 / 一括登録と出所記録 |
| S4 | レシート撮影 → 解析 → 確認 → 登録が通る (issue #7) | サンプルレシートの撮影フロー (2026-08-19 実施の項目。撮影経路は issue #7 側で検証済み)。maestro/flows/capture_receipt_register.yaml で E2E 自動化済み (issue #19) |
| S5 | 無料枠の残量が表示され、無料枠を超えたスキャンはサーバー (Worker の 402) が拒否し、ペイウォール経由の購入で続行できる (PR #56 の課金再設計) | 残量表示 (記録するシート) / 残量 0 のペイウォール / 無料枠超過 (402) からの購入・再解析 |
| S6 | 確認画面から AI にチャット形式で追加指示を出して同じ画像を読み直せ、指示の履歴が画面に残り、登録した明細にも保存される (issue #40) | 追加指示による読み直し / 追加指示の履歴の保存 |
| S7 | 背景が写り込んだ写真・複数レシートが写った写真・複数の紙片に分かれた写真が正しく明細に分かれる/まとまる (issue #82) | 背景・複数レシート・分割紙片の抽出 |

## 1. 入力経路 (記録するシート)

- [x] **3 経路の表示**: 「記録する」FAB でボトムシートが開き、カメラで撮影 / 写真・スクショから選ぶ (sage 系アイコン) / 手動で入力 の 3 行が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **フォトライブラリの起動**: 「写真・スクショから選ぶ」でフォトピッカー (PHPicker) が開き、画像を選ぶとアップロード → 解析が始まる
  - 自動化: manual
- [x] **残量表示 (記録するシート)**: シート下部に無料プランでは「スキャン残り n 回」、プレミアムでは「スキャンし放題」が表示される。解析を実行する (失敗を含む) と残量の表示が更新される (Worker が Gemini 呼び出し前にカウンタを進めるため、失敗した解析でも残量は減る)
  - 自動化: manual
- [x] **残量 0 のペイウォール (フォトライブラリ)**: 無料プランで今月の残量が 0 の時に「写真・スクショから選ぶ」を選ぶとペイウォールが開き、閉じるとピッカーは開かない
  - 自動化: manual (残量 0 は debug 開発者メニューの「スキャン残量を使い切る」で作る。issue #67 で整備)
- [ ] **残量 0 のペイウォール (カメラ)**: 無料プランで今月の残量が 0 の時に「カメラで撮影」を選ぶとペイウォールが開き、閉じるとカメラは開かない
  - 自動化: manual
  - ⏭️ スキップ: 2026-08-22 の実行でも未実施。残量 0 の状態を作れないため。理由は 2 段階:
    - 恒久策: 開発者メニューに「残量を使い切った状態にする」項目を用意する (Worker 側にも DEBUG 用のカウンタ設定経路が必要)
- [ ] **無料枠超過 (402) からの購入・再解析**: 解析が無料枠超過 (Worker の 402) で拒否されると失敗画面の上にペイウォールが開き、購入・復元でプレミアムになると同じアップロード済み画像で解析だけが再実行される。ペイウォールを閉じた場合は失敗画面に戻り、手動入力・取り直しを選べる (lib/features/capture/README.md)
  - 自動化: manual (残量 0 の作り込みと Test Store での購入が必要)
  - ⏭️ スキップ: 上の「残量 0 のペイウォール」と同じ理由で、402 を発生させる状態を作れないため未実施

#### 動作確認

### **残量 0 のペイウォール (フォトライブラリ)**
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-23 (issue #67)**

Simulator kashakeibo-issue-67-iOS26.5 の debug ビルド (kashakeibo-dev + dev Worker) で確認した。
新規の匿名 uid では残量チップが「スキャン残り50回」で、月ラベル長押し → 開発者メニュー「スキャン残量を使い切る」を実行すると「スキャン残り0回」に変わった。その状態で「記録する」→「写真・スクショから選ぶ」をタップするとフォトピッカーは開かずペイウォール (無料枠バー「今月の無料スキャン 50/50」) が開き、✕ で閉じた後もピッカーは開かず月次一覧に戻った。

- 実行前の残量チップ (スキャン残り50回): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/40d5a0f7-9f1b-4257-89b7-eb70be46b6a9.png" width="240" />
- 開発者メニュー (「スキャン残量を使い切る」): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/a4394962-5c24-4143-a342-18df11d925d0.png" width="240" />
- 実行後の残量チップ (スキャン残り0回): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/0bcea9ab-bffa-462c-abcf-595cacc94202.png" width="240" />
- 「写真・スクショから選ぶ」で開いたペイウォール: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/2e98e747-ee69-4a6b-aa50-2ff5014812b1.png" width="240" />

</details>
<details>
<summary>動作確認エビデンス</summary>

### **3 経路の表示**: 「記録する」FAB でボトムシートが開き、カメラで撮影 / 写真・スクショから選ぶ (sage 系アイコン) / 手動で入力 の 3 行が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (kashakeibo-無名-iOS26.5 / UDID 3DAA814A-102E-4D40-A0DD-676959F17E48、日本語ロケール)、debug ビルド (kashakeibo-dev + dev Worker、RevenueCat Test Store キー注入) で確認した。「記録する」FAB でボトムシートが開き、「カメラで撮影 / レシートを撮ると AI が明細を読み取ります」「写真・スクショから選ぶ / カード明細や購入履歴のスクショを AI が明細に分けます」(sage 系の緑アイコン)「手動で入力 / 画像がない現金支出などを入力します」の 3 行が並んだ。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/c6c72d24-157f-4bdb-bb9c-c0e657ef263e.png" width="320" alt="記録するシート。カメラで撮影・写真スクショから選ぶ・手動で入力の3行とスキャン残り50回">

</details>

### **フォトライブラリの起動**: 「写真・スクショから選ぶ」でフォトピッカー (PHPicker) が開き、画像を選ぶとアップロード → 解析が始まる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

「写真・スクショから選ぶ」でフォトピッカー (PHPicker。「写真へのプライベートアクセス」の案内付き) が開き (左)、風景写真 (滝) を選ぶと画面が「AI が読み取っています / カテゴリを推定しています」に切り替わってアップロード → 解析が始まった (右)。テスト用の画像は `xcrun simctl addmedia <UDID> <画像パス>` で投入した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/69a23533-afe5-4028-955b-0cc9159e597c.png" width="320" alt="PHPickerのフォトピッカー">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/4ad028ec-affd-4a28-ad77-2a487591a383.png" width="320" alt="AIが読み取っていますの解析中画面">

</details>

### **残量表示 (記録するシート)**: シート下部に無料プランでは「スキャン残り n 回」、プレミアムでは「スキャンし放題」が表示される。解析を実行する (失敗を含む) と残量の表示が更新される (Worker が Gemini 呼び出し前にカウンタを進めるため、失敗した解析でも残量は減る)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

無料プランの新規 uid でシート下部に「スキャン残り50回」が表示された (左。月次一覧の残量チップも同じ 50)。この状態で風景写真の解析を 1 回実行して失敗 (明細なしで「読み取れませんでした」) させた後、同じシートを開き直すと「スキャン残り49回」に更新された (右)。失敗した解析でも残量が 1 減る仕様どおりの挙動。

プレミアム時の「スキャンし放題」表示は paywall QA.md の「購入後の残量チップ」の項に記録した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/c6c72d24-157f-4bdb-bb9c-c0e657ef263e.png" width="320" alt="シート下部にスキャン残り50回">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/7905fc1b-e4e9-4811-9722-586aba36d7ec.png" width="320" alt="解析失敗後にシート下部がスキャン残り49回へ更新">

</details>

### **残量 0 のペイウォール (カメラ)**: 無料プランで今月の残量が 0 の時に「カメラで撮影」または「写真・スクショから選ぶ」を選ぶとペイウォールが開き、閉じるとカメラ・ピッカーは開かない

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **無料枠超過 (402) からの購入・再解析**: 解析が無料枠超過 (Worker の 402) で拒否されると失敗画面の上にペイウォールが開き、購入・復元でプレミアムになると同じアップロード済み画像で解析だけが再実行される。ペイウォールを閉じた場合は失敗画面に戻り、手動入力・取り直しを選べる (lib/features/capture/README.md)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

## 2. 解析と確認 (スクショ取込)

- [x] **複数明細の候補リスト表示**: カード明細風の画像 (取引 3 件。開発者メニュー「サンプル明細スクショで取込フローを試す」) を解析すると、3 件の候補カード (店名・金額・日付・カテゴリ・収支) と「3 件を登録する」ボタンが表示される
  - 自動化: manual
- [x] **候補の破棄**: 候補のチェックを外すとカードが半透明になり、ボタンの件数が「2 件を登録する」に減る
  - 自動化: manual
- [x] **候補の修正**: 「修正する」で単一フォームと同じ入力項目のシートが開き、「変更を反映」でカードの表示 (カテゴリ等) が更新される
  - 自動化: manual
- [x] **一括登録と出所記録**: 採用 2 件を登録すると月次一覧に 2 件だけ反映され、出所は「スクショ」、修正した候補のみ「手調整」・未修正は「自動取込」になる。集計にも反映される
  - 自動化: manual
- [x] **明細なし画像の失敗表示**: 明細が写っていない画像 (風景写真) を選ぶと「読み取れませんでした」画面になり、「取り直す」でフォトライブラリが開き直す
  - 自動化: manual
- [x] **追加指示による読み直し**: 確認画面 (単一フォーム・候補リストのどちらでも) の「AI に指示して読み直す」でシートが開き、指示 (例: 「一番下の明細が読めていない」) を送信すると「AI 解析中」を経て確認画面が作り直され、元画像サムネイルの下に「AI への追加指示」としてユーザーの指示の吹き出しと AI の「読み直して n 件になりました」の吹き出しが並ぶ。未入力では送信できず、シートを閉じると読み直さない (lib/features/capture/README.md)
  - 自動化: manual (widget テスト test/features/capture/capture_page_test.dart の「追加指示:」で分岐は網羅済み。未入力での送信不可・シートを閉じた時の非再解析・上限 10 回の無効化は widget テストのみで、Simulator では未実施)
- [x] **追加指示の履歴の保存**: 追加指示を出してから登録した明細を明細詳細で開くと、出所チップの下に「AI への指示」として指示文が表示される。指示を出さずに登録した明細には表示されない
  - 自動化: manual (非表示側は widget テスト test/features/transaction_detail/transaction_detail_page_test.dart で検証)
- [ ] **背景・複数レシート・分割紙片の抽出 (issue #82)**: 背景 (机・小物) が写り込んだ写真でも紙面だけから抽出される。別々の支払いのレシート 2 枚が写った写真は 2 件の候補になり (同じ店・同じ日付でも、それぞれに合計がある完結したレシートは 2 件)、長いレシートが 2 つの紙片に分かれた写真は支払全体の合計で 1 件にまとまる
  - 自動化: サーバー側の抽出品質は合成フィクスチャ (workers/image の `receipt_two_receipts.jpg` / `receipt_same_store_two_receipts.jpg` / `receipt_split_long.jpg`、7 枚 7/7 全項目一致) と実物ベンチマーク 15 枚で機械検証済み (workers/image/benchmark/README.md の 2026-09-03 の再実測)。アプリ画面での取込確認 (実写真相当の画像をフォトライブラリへ投入 → 候補リスト表示) は未実施のため未検証

#### 動作確認 (2026-09-02、issue #40 の項目のみ。他の項目はこの実行では再テストしていない)

### **追加指示による読み直し**: 確認画面の「AI に指示して読み直す」でシートが開き、指示を送信すると読み直され、履歴が吹き出しで並ぶ

<details><summary>動作確認エビデンス</summary>

**確認日: 2026-09-02 (PR #79、commit d77ea92)**

simtunnel のリモート Simulator (session kashakeibo-issue-40、iPhone 17、英語ロケール) の debug ビルド (kashakeibo-dev + dev Worker。本 PR の Worker を dev にデプロイ済み) で確認した。App Check は `ios-wda.sh launch --env-file ~/.config/kashakeibo/appcheck-debug-token-simtunnel.secret` で登録済み debug token を渡した。開発者メニュー「サンプルレシートで撮影フローを試す」で確認画面 (¥872) を開き、「Ask the AI to re-read」→ シートに「Use the subtotal before tax as the amount」を入力 → 「Send and re-read」で「AI 解析中」を経て確認画面が作り直され、金額が小計の ¥808 に変わった。元画像の下に「Instructions to the AI」としてユーザーの吹き出しと AI の「Re-read as 1 entry」が並んだ。残量チップは 50 → 48 (初回 + 読み直しで 2 回消費)。候補リスト (開発者メニュー「サンプル明細スクショで取込フローを試す」、3 件) でも同じボタンから指示を送れ、履歴の吹き出し (「Re-read as 3 entries」) が候補カードの上に並んだ。

- 確認画面 (指示前): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260902/5f4023df-5f2f-4836-b37a-8c1f398fd7bc.jpg" width="240" />
- 指示の入力シート: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260902/7ec810b9-86e8-498f-8982-e445844bc64c.jpg" width="240" />
- 読み直し後 (履歴の吹き出し + 金額 ¥808): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260902/408b68c3-c2f8-4840-b475-5de8f666db6d.jpg" width="240" />
- 候補リストでの指示後: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260902/bbfb170e-ba76-42fe-a939-5ae4c8e679a5.jpg" width="240" />

</details>

### **追加指示の履歴の保存**: 登録した明細の詳細に「AI への指示」として指示文が表示される

<details><summary>動作確認エビデンス</summary>

**確認日: 2026-09-02 (PR #79、commit d77ea92)**

上の読み直し後に「Register」で登録し、8 月の月次一覧から明細を開くと、出所チップ (Receipt / Auto-imported。フォームは手修正していないため自動取込のまま) の下に「Instructions to the AI」として「Use the subtotal before tax as the amount」が表示された。指示を出していない明細 (サンプル明細) には表示されないことは widget テストで検証済み。

- 明細詳細: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260902/e51748c8-5064-4d0d-a80b-0c325fbd9ffd.jpg" width="240" />

</details>

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

**確認日: 2026-08-19〜2026-08-20 (PR #49)**

ローカル Simulator (kashakeibo-issue-8-iOS26.5) + Firebase Emulator + ローカル Worker (`wrangler dev --port 8788`) + 実 Gemini API で確認した。スクリーンショットと確認手順の全記録は PR #49 body を参照: https://github.com/bannzai/kashakeibo/pull/49

- 記録するシートの 3 経路表示: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/40172b3a-929b-43c2-906e-b637e57dc3a7.png" width="240">
- 複数明細の候補リスト (3 件抽出): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/21034253-bb27-4226-95c5-a0bc252a8c8c.png" width="240">
- 候補の破棄 (2 件を登録する): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/37de9c6f-e40b-4928-a4f7-409418d2ff06.png" width="240">
- 修正の反映 (外食 → 食費) と登録後の一覧 (スクショ出所・手調整/自動取込): <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/cfd9882a-021c-4ed5-8259-91e3ada3daa9.png" width="240">
- 明細なし画像の失敗表示: <img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/e5a8953c-d995-4fcd-87f3-e3872fe678ba.png" width="240">

### **複数明細の候補リスト表示**: カード明細風の画像 (取引 3 件。開発者メニュー「サンプル明細スクショで取込フローを試す」) を解析すると、3 件の候補カード (店名・金額・日付・カテゴリ・収支) と「3 件を登録する」ボタンが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (kashakeibo-無名-iOS26.5)、debug ビルド (kashakeibo-dev + dev Worker + 実 Gemini API)。月ラベルの長押しで開く開発者メニューの「サンプル明細スクショで取込フローを試す」を実行すると「読み取り確認」画面になり、「3件の明細を読み取りました。登録する明細を選んでください」と 3 件の候補カード (Amazon.co.jp ¥3,980 / 2026年8月14日・その他・支出、モバイルSuica チャージ ¥3,000 / 2026年8月15日・交通・支出、鳥貴族 三軒茶屋店 ¥4,230 / 2026年8月16日・外食・支出)、「3件を登録する」ボタンが表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/9ff55f00-cf59-48ef-b16e-f6b6df247be6.png" width="320" alt="読み取り確認画面。3件の候補カードと3件を登録するボタン">

</details>

### **候補の破棄**: 候補のチェックを外すとカードが半透明になり、ボタンの件数が「2 件を登録する」に減る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

Amazon.co.jp のチェックを外すと、そのカードだけが半透明 (文字・チェックボックスが淡色) になり、ボタンの表示が「3件を登録する」から「2件を登録する」に減った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/7759d106-1b3a-49c4-a5e7-857eb8c9bd2d.png" width="320" alt="Amazonの候補が半透明になり2件を登録するに変わった状態">

</details>

### **候補の修正**: 「修正する」で単一フォームと同じ入力項目のシートが開き、「変更を反映」でカードの表示 (カテゴリ等) が更新される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

鳥貴族 三軒茶屋店の鉛筆アイコン (修正する) をタップすると「修正する」シートが開き、店名・メモ / 金額 / 収支種別 / カテゴリ / 日付 と手動入力フォームと同じ入力項目が並んだ (左)。カテゴリを「外食」から「食費」に変えて「変更を反映」をタップすると、候補カードの表示が「2026年8月16日 · 外食 · 支出」から「2026年8月16日 · 食費 · 支出」に更新された (右)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/10ee3f87-68a0-4e32-92f5-2f05cbb9813c.png" width="320" alt="修正するシート。店名・金額・収支種別・カテゴリ・日付の入力項目">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/c271ea03-9cd9-4f44-8b35-c6afe7cba732.png" width="320" alt="候補カードのカテゴリが食費へ更新された状態">

</details>

### **一括登録と出所記録**: 採用 2 件を登録すると月次一覧に 2 件だけ反映され、出所は「スクショ」、修正した候補のみ「手調整」・未修正は「自動取込」になる。集計にも反映される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

「2件を登録する」で登録すると月次一覧に戻り、破棄した Amazon.co.jp を除く 2 件だけが反映された。修正した鳥貴族 三軒茶屋店は「食費 · スクショ · 手調整」、未修正のモバイルSuica チャージは「交通 · スクショ · 自動取込」。集計も支出 ¥7,230 / 残り ¥-7,230、カテゴリ内訳に食費 ¥4,230・交通 ¥3,000 として反映された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/fb765fe0-5b76-417c-9b59-ee0cfd27b781.png" width="320" alt="月次一覧に2件が反映され出所がスクショ・手調整/自動取込で表示">

</details>

### **明細なし画像の失敗表示**: 明細が写っていない画像 (風景写真) を選ぶと「読み取れませんでした」画面になり、「取り直す」でフォトライブラリが開き直す

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

フォトライブラリから風景写真 (滝) を選ぶと「読み取れませんでした」画面になり、「Bad state: 画像から明細を読み取れませんでした」というエラー文がそのまま表示され、「もう一度読み取る」「手動で入力する」「取り直す」が並んだ (左)。「取り直す」をタップするとフォトピッカーが開き直った (右)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/7c31bce1-bb5c-4254-8393-05465d0989ba.png" width="320" alt="読み取れませんでした画面">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b1d9fe65-44c2-4dee-9f7e-5035d5f65d64.png" width="320" alt="取り直すでフォトピッカーが開き直した状態">

</details>

</details>

## 未検証の範囲

- issue #82 の抽出ルール (背景の映り込み・複数レシート・分割紙片) のアプリ画面での取込確認 (サーバー側の抽出品質は workers/image のフィクスチャ・ベンチマークで機械検証済み。アプリを通した確認は次回 run-qa で実施する)
- 実機のカメラ撮影・実機フォトライブラリ (シミュレータでは開発者メニューのサンプル画像とシミュレータ標準写真で代替)
- 縦長画像の長辺制限 (capture_image_picker が maxWidth に加えて maxHeight も渡す修正) は widget テストでの確認のみ
- 残量 0 時のペイウォールガードのうち、解析 402 からの購入・再解析 (paywall QA.md の「解析 402 導線」。RevenueCat の Test Store キーを注入したビルドが要るため次回 run-qa)
- 「記録する」シート下部のプレミアム表示の文言変更 (2026-08-22 の「スキャン無制限」→「スキャンし放題」。lib/l10n の scanQuotaUnlimited) はシート上の表示・レイアウトを未検証 (プレミアム状態の作り込みが必要。paywall QA.md「購入後の残量チップ」の再検証と合わせて次回 run-qa で確認する。widget テストでは add_record_sheet_test が文言追従済み)
