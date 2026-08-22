---
feature: paywall
verification: mobile-mcp
last_verified_commit: f492e1566dfd2fae08cfc3a15b79e1cc469e1e1e
last_verified_at: 2026-08-22
---

# paywall QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/12 (RevenueCat 課金・スキャン無料枠とハードペイウォールの受け入れ条件)
- 関連: https://github.com/bannzai/kashakeibo/pull/48 (実装 PR)、lib/features/paywall/README.md、lib/features/capture/README.md、workers/image/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 残量チップ (月次一覧)・設定のプラン行・無料範囲より古い月への月送り・記録するシートの残量 0・解析の 402 からペイウォールが開く | 残量チップからペイウォールを開く / 設定のプラン行から開く / 古い月への月送りでペイウォールを開く / 記録するシートの残量 0 導線 / 解析 402 導線 |
| S2 | 料金カードにストアが解決した月額・年額の価格と年額の割引率バッジを表示する (未設定ビルドは「料金プランを取得できませんでした」) | 料金プランの表示 / 未設定ビルドの表示 |
| S3 | 「プレミアムを始める」で選択中のパッケージを購入し、成功で完了メッセージを出して閉じる。キャンセルは何も表示せず、失敗はエラー文をそのまま表示する | mock 購入の成功 / 購入キャンセル / 購入失敗 |
| S4 | プレミアム判定は entitlement `premium` で行い、購入後は残量チップが「スキャンし放題」、設定のプラン行が「プレミアム」、ペイウォールは「プレミアム利用中」になる | 購入後の残量チップ / 購入後の設定のプラン行 / プレミアム利用中の表示 |
| S5 | app user ID は Firebase uid で、Worker が同じ uid で RevenueCat の entitlement を検証できる | サーバー側の entitlement 確認 |
| S6 | 「購入の復元」で entitlement を復元し、復元できる購入が無ければその旨を表示する | 購入の復元 (復元対象なし) / 購入の復元 (復元対象あり) |

## 1. ペイウォールの表示と導線

- [x] **残量チップからペイウォールを開く**: 月次一覧の「とった記録」行に無料プランの残量チップ「スキャン残り N 回」が表示され、タップでペイウォールが全画面で開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **料金プランの表示**: ペイウォールに月額 / 年額の料金カードがストアの価格で表示され、年額が初期選択で割引率バッジと月換算価格が付く。「料金プランを取得できませんでした」にならない
  - 自動化: manual (RevenueCat Test Store の価格解決を伴うため agent のシミュレータ操作で確認する)
- [x] **設定のプラン行から開く**: 設定画面の「プラン」行をタップするとペイウォールが開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **古い月への月送りでペイウォールを開く**: 無料プランで当月を含む直近 3 ヶ月までは月送りでき、それより古い月へ送ろうとするとペイウォールが開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **記録するシートの残量 0 導線**: 無料枠を使い切った状態で「記録する」シートの「カメラで撮影」をタップするとペイウォールが開く
  - 自動化: todo (無料枠 50 回 (issue #50 で月10→月50) を使い切る状態の作り込み手段が未整備。スキャン回数の保存先は Cloudflare Durable Object (`workers/image/src/usage_counter.ts` の `UsageCounter`。月次インスタンス名 = 年月、キー `scan:uid:{uid}`) で、firebase / gcloud CLI からも wrangler からも外部で書き換えられない。API 経由でカウンタだけを進める案も `iam.serviceAccounts.signJwt` 権限が無く custom token を署名できないため実行できない (詳細はルート QA.md の実行ナレッジ)。debug 開発者メニュー + Worker 側の DEBUG 用カウンタ設定経路での状態作り込みを検討する)
- [ ] **解析 402 導線**: 無料枠超過で Worker の `POST /analyses` が 402 を返すと撮影フローからペイウォールが開き、購入後に同じ画像で解析をやり直す
  - 自動化: todo (上と同じく無料枠超過状態の作り込み手段が未整備)
- [ ] **未設定ビルドの表示**: RevenueCat の public API key を注入しないビルドでは SDK を初期化せず、ペイウォールに「料金プランを取得できませんでした」が表示される
  - 自動化: manual (`--dart-define` 無しの別ビルドが必要なため agent のシミュレータ操作で確認する)
  - ⏭️ スキップ: 今回は Test Store キー注入済みビルドのみで実行した。キー無しビルドの表示は PR #48 の実装時に確認済み (PR body のスクリーンショット)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **残量チップからペイウォールを開く**: 月次一覧の「とった記録」行に無料プランの残量チップ「スキャン残り N 回」が表示され、タップでペイウォールが全画面で開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

ローカル Simulator (iPhone 16 Pro / iOS 26.2、日本語ロケール)、debug ビルド (kashakeibo-dev + dev Worker) に `--dart-define=REVENUECAT_TEST_STORE_API_KEY` を注入して実行。Simulator を消去した直後の新規匿名 uid で起動し、月次一覧の「とった記録」行の右端に「スキャン残り10回」のチップが表示された (Worker の `GET /analyses/quota` が App Check 検証込みで通っている)。チップをタップするとペイウォールが全画面で開いた (ペイウォールの画面は次項のスクリーンショット)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/89cf228e-6086-4d25-9ccc-a9aea3c9e4f8.png" width="320">

</details>

### **料金プランの表示**: ペイウォールに月額 / 年額の料金カードがストアの価格で表示され、年額が初期選択で割引率バッジと月換算価格が付く。「料金プランを取得できませんでした」にならない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

残量チップから開いたペイウォール。見出し「スキャン、し放題に。」、無料枠バー「今月の無料スキャン 0/10」、特典 3 点、料金カード (月額 $3.00 / 年額 $24.00・「33%お得」バッジ・「$2.00/月換算」)、CTA「プレミアムを始める」、「いつでも解約できます · 購入の復元」、自動更新の説明、利用規約・プライバシーポリシーのリンクが表示された。年額カードが初期選択 (オレンジ枠)。

価格は RevenueCat Test Store の product に登録された価格 (月額 $3.00 / 年額 $24.00、USD) がそのまま表示されている。App Store の実価格 (¥480 / ¥3,800) と割引率 (34%) は Test Store では検証できない (Test Store は StoreKit を使わない mock のため)。表示経路 (`StoreProduct.priceString` をそのまま出す・割引率は月額 × 12 に対する比率で計算) が動いていることの確認として扱う。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/7b7fb4a9-9223-4bb7-a086-3c4e3d8376c2.png" width="320">

**確認日: 2026-08-22**

無料枠の月10→月50 変更 (issue #50) と文言変更 (issue #51) の後に再確認した。ローカル Simulator (kashakeibo-無名-iOS26.5、日本語ロケール)、debug ビルド (kashakeibo-dev + dev Worker) に **RevenueCat の Test Store 鍵 (dev)** を `--dart-define=REVENUECAT_TEST_STORE_API_KEY` で注入して実行 (値は .envrc の `REVENUECAT_TESTSTORE_API_KEY_DEV` を direnv 経由で渡し、コマンドラインに露出させない)。App Store の public API key (`appl_`) は StoreKit を使うため simctl 起動の Simulator では商品を解決できず、購入系の項目は Test Store 鍵でしか確認できない。月次一覧の残量チップから開いたペイウォールに、月額 $3.00 / 年額 $24.00 (「33%お得」バッジ・「$2.00/月換算」・年額が初期選択のオレンジ枠) が Test Store の価格で表示され、「料金プランを取得できませんでした」にはならなかった。無料枠バーは「今月の無料スキャン 6/50」で月50の新しい上限を反映している。見出し「スキャンし放題に」・特典「スキャンし放題 / 全期間の履歴 / 今後の新機能」・フェアユース注記も表示された。

無料トライアルの表示は無い。現在の Offering に導入期間 (intro price / free trial) を持つ商品が無いため (トライアルの要否は documents/PROJECT.md のとおり issue #51 で検討中)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/89620a62-31c1-4f36-bcdf-44f12f18861b.png" width="320" alt="ペイウォール。月額$3.00と年額$24.00の料金カード、無料スキャン6/50のバー">

</details>

### **設定のプラン行から開く**: 設定画面の「プラン」行をタップするとペイウォールが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (kashakeibo-issue-50-51-iOS26.5)、debug ビルド (kashakeibo-dev。RevenueCat Test Store キー未注入のため料金カードは「料金プランを取得できませんでした」表示)。無料プランで設定画面の「プラン / 無料」行をタップするとペイウォールが開いた。文言変更 (issue #50/#51) の表示確認も兼ねる: 見出し「スキャンし放題に」(295f856 の見出し修正後に再ビルドして撮影) / 特典「スキャンし放題」/ フェアユースの注記「スキャンし放題は、サービス品質維持のため通常の利用では達しない月間上限の範囲で提供されます。」を日本語で確認。英語は Scan freely with Premium / Scan freely / Scanning is subject to a monthly fair-use limit that typical use won't reach. を確認 (英語の文言は見出し修正の影響を受けないため修正前ビルドのスクリーンショット)。レイアウト崩れなし。料金カードの表示・購入系の項目は今回未検証。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/441c7593-bcf7-4062-9084-009563518623.png" width="320" alt="日本語のペイウォール。見出し「スキャンし放題に」と特典、下部にフェアユース注記を表示">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/a1aac18d-0707-49ea-968a-6c100e1f6682.png" width="320" alt="English paywall showing Scan freely and the monthly fair-use note">

**確認日: 2026-08-20**

購入後の状態で設定画面の「プラン / プレミアム」行をタップすると、ペイウォールが「プレミアム利用中」の表示で開いた (スクリーンショットは「プレミアム利用中の表示」の項と同じ画面)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/b560a18c-8a27-4aba-afd8-1c08900f05eb.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/729623c7-fbd3-47b5-8620-0cf48e7d4f9c.png" width="320">

</details>

### **古い月への月送りでペイウォールを開く**: 無料プランで当月を含む直近 3 ヶ月までは月送りでき、それより古い月へ送ろうとするとペイウォールが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

Simulator の当日は 2026-08-20。無料プランの新規 uid で 2026年8月 → 7月 → 6月までは「前の月」で月送りでき (左: 2026年6月の月次一覧)、6月からさらに「前の月」をタップすると 5月には移らずペイウォールが開いた (右)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/56e58604-6f32-4f07-8c36-f6bb398cece4.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/ed6f5319-ce5d-4c88-b29b-5ebc01218646.png" width="320">

</details>

### **記録するシートの残量 0 導線**: 無料枠を使い切った状態で「記録する」シートの「カメラで撮影」をタップするとペイウォールが開く

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **解析 402 導線**: 無料枠超過で Worker の `POST /analyses` が 402 を返すと撮影フローからペイウォールが開き、購入後に同じ画像で解析をやり直す

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **未設定ビルドの表示**: RevenueCat の public API key を注入しないビルドでは SDK を初期化せず、ペイウォールに「料金プランを取得できませんでした」が表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 購入・復元

- [x] **mock 購入の成功**: 「プレミアムを始める」で RevenueCat Test Store の購入モーダルが開き、「Test valid purchase」で購入が成立するとペイウォールが閉じて完了メッセージ「プレミアムを開始しました。スキャンし放題です!」が表示される
  - 自動化: manual (Test Store の mock 購入モーダルは Maestro で flaky の実績があるため agent のシミュレータ操作で確認する)
- [x] **購入後の残量チップ**: 購入直後に月次一覧の残量チップと記録するシート下部の残量表示が「スキャンし放題」になる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **購入後の設定のプラン行**: 設定画面の「プラン」行の値が「プレミアム」になる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **プレミアム利用中の表示**: プレミアムのユーザーがペイウォールを開くと「プレミアム利用中」と特典 3 点だけが表示され、料金カード・CTA・購入の復元は表示されない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **サーバー側の entitlement 確認**: 購入したユーザーの Firebase uid に対して RevenueCat REST API v2 の `active_entitlements` が entitlement `premium` を返す (Worker の `entitlement.ts` が同じ uid で判定できる状態)
  - 自動化: manual (curl での機械確認が可能。Maestro ではなくコマンド実行で確認する)
- [x] **購入失敗**: Test Store の購入モーダルで「Test failed purchase」を選ぶと、ペイウォールは開いたままで、ストアが返したエラー文が加工されずスナックバーに表示される
  - 自動化: manual (Test Store の mock 購入モーダルの操作を伴うため agent のシミュレータ操作で確認する)
- [x] **購入キャンセル**: Test Store の購入モーダルで「Cancel」を選ぶと、ペイウォールは開いたままで何もメッセージが表示されない
  - 自動化: manual (Test Store の mock 購入モーダルの操作を伴うため agent のシミュレータ操作で確認する)
- [x] **購入の復元 (復元対象なし)**: 購入履歴の無いユーザーが「購入の復元」をタップすると「復元できる購入がありません」が表示され、プレミアムにならない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **購入の復元 (復元対象あり)**: 購入済みのストアアカウントで別端末・再インストール後に「購入の復元」をタップすると entitlement が復元され、完了メッセージを出して閉じる
  - 自動化: todo (Test Store で「購入済みだが entitlement 未反映」の状態を作る手段が未整備。同じ Firebase uid は再起動時の `Purchases.logIn` で entitlement が即時反映されるため復元を経由しない。StoreKit Configuration + SKTestSession (`/ios-storekit-testing`) での代替を検討する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **mock 購入の成功**: 「プレミアムを始める」で RevenueCat Test Store の購入モーダルが開き、「Test valid purchase」で購入が成立するとペイウォールが閉じて完了メッセージ「プレミアムを開始しました。スキャンし放題です!」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

年額 (初期選択) のまま「プレミアムを始める」をタップすると Test Store の購入モーダル (Product ID: kashakeibo_premium_annual_3800yen / Title: Premium / Price: $24.00 / SubscriptionPeriod: 1 year、Test valid purchase / Test failed purchase / Cancel) が開いた (左)。「Test valid purchase」をタップするとペイウォールが閉じ、月次一覧に戻って画面下部にスナックバー「プレミアムを開始しました。スキャンし放題です!」が表示された (右)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/94611b98-07d8-4590-9e97-7dba36fadf3e.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/90423793-57a4-4773-b06a-abcf386a755c.png" width="320">

**確認日: 2026-08-22**

文言変更 (issue #51) の後に、RevenueCat の Test Store 鍵 (dev) を注入したビルドで再確認した。年額 (初期選択) のまま「プレミアムを始める」をタップすると Test Store の購入モーダル (Product ID: kashakeibo_premium_annual_3800yen / Title: Premium / Price: $24.00 / SubscriptionPeriod: 1 year) が開き (左)、「Test valid purchase」でペイウォールが閉じて月次一覧に戻り、スナックバー「プレミアムを開始しました。スキャンし放題です!」が表示された (右)。スナックバーは数秒で消えるため、タップと撮影を 1 コマンドにまとめて撮影した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/19493766-b830-4b2c-81d5-0dc0ccea101a.png" width="320" alt="Test Storeの購入モーダル">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b689badd-b33a-488f-aaec-077b98dbd593.png" width="320" alt="購入完了のスナックバーと、スキャンし放題に変わった残量チップ">

</details>

### **購入後の残量チップ**: 購入直後に月次一覧の残量チップと記録するシート下部の残量表示が「スキャンし放題」になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

文言変更後の表示を、RevenueCat の Test Store 鍵 (dev) を注入したビルドの mock 購入で確認した。購入直後の月次一覧で「とった記録」行のチップが「スキャン残り44回」から「スキャンし放題」に変わった (左)。記録するシート下部の残量表示も「スキャンし放題」になった (右)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b689badd-b33a-488f-aaec-077b98dbd593.png" width="320" alt="月次一覧の残量チップがスキャンし放題">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/924a9fa4-7fe8-4d51-8251-1250c8b369e0.png" width="320" alt="記録するシート下部がスキャンし放題">

**確認日: 2026-08-20**

購入直後の月次一覧で「とった記録」行のチップが「スキャン残り10回」から「スキャン無制限」に変わった (アクセシビリティツリーでも `とった記録\nスキャン無制限`)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/90423793-57a4-4773-b06a-abcf386a755c.png" width="320">

</details>

### **購入後の設定のプラン行**: 設定画面の「プラン」行の値が「プレミアム」になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

購入後に右上の設定アイコンから開いた設定画面で、「プラン」行の右端が「プレミアム」と表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/b560a18c-8a27-4aba-afd8-1c08900f05eb.png" width="320">

</details>

### **プレミアム利用中の表示**: プレミアムのユーザーがペイウォールを開くと「プレミアム利用中」と特典 3 点だけが表示され、料金カード・CTA・購入の復元は表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

購入後に設定の「プラン」行から開いたペイウォール。✕・スパークル円・「プレミアム利用中」・「スキャン無制限と全期間の履歴が使えます。」・特典 3 点だけが表示され、無料枠バー・料金カード・CTA・購入の復元・法務リンクは表示されなかった (アクセシビリティツリーにも存在しない)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/729623c7-fbd3-47b5-8620-0cf48e7d4f9c.png" width="320">

</details>

### **サーバー側の entitlement 確認**: 購入したユーザーの Firebase uid に対して RevenueCat REST API v2 の `active_entitlements` が entitlement `premium` を返す (Worker の `entitlement.ts` が同じ uid で判定できる状態)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

この項目は curl での確認のため、コマンド出力を画像化して貼る。購入したユーザーの uid は RevenueCat の customers 一覧 (`GET /v2/projects/proje2d79a89/customers`) で特定した (Firebase uid 形式の 28 文字で、`Purchases.logIn(uid)` により RevenueCat の匿名 ID ではなく Firebase uid が app user ID になっている)。

```text
$ curl -s -H "Authorization: Bearer $REVENUECAT_SECRET_API_KEY_DEV" \
    "https://api.revenuecat.com/v2/projects/proje2d79a89/customers/<uid>/active_entitlements" | jq
{
  "items": [
    { "entitlement_id": "entl34c3809c32", "expires_at": 1787221975313, "object": "customer.active_entitlement" }
  ],
  ...
}
```

`entl34c3809c32` は Kashakeibo-dev の entitlement `premium`。Worker (`workers/image/src/entitlement.ts`) はこの API を同じ uid で呼んで 402 をバイパスするため、無料枠を使い切ってもプレミアムとして解析が通る状態になっている (無料枠 10 回を実際に使い切る確認は Gemini 原価がかかるため未実施)。購入後の反映はほぼ即時 (購入の数秒後の呼び出しで返った)。Test Store の年額購入の `expires_at` は購入の約 1 時間後で、Test Store のサブスクリプション期間は実期間より短縮されている。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/0cc46846-f29b-45d2-934d-b9cc8ff71758.png" width="320">

</details>

### **購入失敗**: Test Store の購入モーダルで「Test failed purchase」を選ぶと、ペイウォールは開いたままで、ストアが返したエラー文が加工されずスナックバーに表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

Simulator 消去後の新規 uid (無料プラン) で「プレミアムを始める」→「Test failed purchase」をタップすると、ペイウォールは開いたままで、スナックバーに `PlatformException(42, Purchase failure simulated successfully in Test Store., {readable_error_code: TEST_STORE_SIMULATED_PURCHASE_ERROR, ...}, null)` がそのまま表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/9c9451a7-452f-4031-be7e-b10a195638dd.png" width="320">

</details>

### **購入キャンセル**: Test Store の購入モーダルで「Cancel」を選ぶと、ペイウォールは開いたままで何もメッセージが表示されない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

「プレミアムを始める」で開いた Test Store の購入モーダル (左) で「Cancel」をタップすると、モーダルが閉じてペイウォールが開いたまま残り、スナックバー等のメッセージは表示されなかった (右)。RevenueCat の customers 一覧でもこの uid に購入は記録されていない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/9d019f7e-41c4-4245-81df-127e6d3c8bd7.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/67d486e2-08ff-4be4-b0d8-f65ab12e392e.png" width="320">

</details>

### **購入の復元 (復元対象なし)**: 購入履歴の無いユーザーが「購入の復元」をタップすると「復元できる購入がありません」が表示され、プレミアムにならない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-20**

新規 uid で「購入の復元」をタップすると、画面下部にスナックバー「復元できる購入がありません」が表示され、ペイウォールは無料プランの表示 (料金カード・CTA) のまま残った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260820/0e404afe-e562-4534-8c1e-577fef0feeae.png" width="320">

</details>

### **購入の復元 (復元対象あり)**: 購入済みのストアアカウントで別端末・再インストール後に「購入の復元」をタップすると entitlement が復元され、完了メッセージを出して閉じる

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>
