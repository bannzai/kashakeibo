---
feature: monthly
verification: mobile-mcp
last_verified_commit: 8a9634107c725e2670c43709dd1ea4493699072f
last_verified_at: 2026-08-19
---

# monthly QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/5 (月次一覧の受け入れ条件) / https://github.com/bannzai/kashakeibo/issues/10 (重複検知と手動マージの受け入れ条件)
- 関連: lib/features/monthly/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 明細は users/{userID}/transactions/{id} に保存され、yearMonth・type・計算対象除外フラグのクエリ用フィールドと複合インデックスを持つ | 明細リスト表示 (インデックス欠落は permission/failed-precondition エラーとして画面に現れる) |
| S2 | 集計はサマリードキュメントを持たず、当月明細のクライアント集計で表示する | 収支サマリー / カテゴリ内訳 |
| S3a | snapshot listener でリアルタイム反映される | 明細追加の即時反映 |
| S3b | オフラインキャッシュでも動作する (ネットワーク遮断中の起動・月切替・既存明細表示) | オフラインキャッシュでの表示 (未検証。simtunnel のリモート Simulator ではネットワーク遮断ができない) |
| S4 | 金額+日付+店名のヒューリスティックで重複候補を検出し、確認 UI で提示する | 重複候補バナー表示 / 重複確認シート表示 |
| S5 | ユーザーはマージ (1件に統合) か「別物として残す」を選べる | 重複マージ / 別々の支出として残す |
| S6 | マージは複数端末の同時操作でも二重計上・消失が起きない | — (未検証。複数端末の同時操作は手動 QA で再現困難で、lib/provider/transaction.dart の MergeDuplicateTransactions / KeepBothTransactions の競合を検証するユニットテストも 2026-08-19 時点で存在しない。テスト漏れとして可視化) |

## 1. 表示・集計

- [x] **明細リスト表示**: 明細が日付見出しでグループ化され、取引日時の降順で表示される。各行に店名・カテゴリ・出所、支出は `-¥`、収入は `+¥` (セージ色) の金額が出る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **収支サマリー**: サマリーカードに当月の支出 (主表示)・収入・残り (収入 - 支出、セージ色) がクライアント集計で表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **カテゴリ内訳**: 支出のカテゴリ別合計が金額の大きい順の横棒で表示される。支出が無い月ではセクションごと非表示になる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **空状態**: 明細が 1 件も無い月では空メッセージが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **計算対象外の明細**: excludedFromAggregation の明細 (デバッグメニューの「鳥貴族 (重複疑い)」) は opacity を落とし「計算対象外」注記付きで一覧に表示されるが、サマリー・カテゴリ内訳の集計には含まれない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細追加の即時反映**: 手動入力またはデバッグメニューで明細を追加すると、画面操作なしで一覧・サマリー・カテゴリ内訳に即時反映される (snapshot listener)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **オフラインキャッシュでの表示**: 明細を表示した後にネットワークを遮断してアプリを再起動・月切替しても、Firestore のオフラインキャッシュから既存明細とサマリーが表示される
  - 自動化: todo (simtunnel のリモート Simulator ではネットワーク遮断ができない。ローカル Simulator なら Network Link Conditioner または `xcrun simctl` でのネットワーク遮断で確認できる見込み)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **明細リスト表示**: 明細が日付見出しでグループ化され、取引日時の降順で表示される。各行に店名・カテゴリ・出所、支出は `-¥`、収入は `+¥` (セージ色) の金額が出る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、日付見出し・カテゴリ・出所が英語表示 ("Tue, Aug 18" / "Food · Manual") になる。店名はデータの値なので日本語のまま表示される。

デバッグメニューの「サンプル明細を追加」でサンプル 5 件を投入した状態。日付見出しが Tue, Aug 18 → Mon, Aug 17 → Sun, Aug 16 → Sat, Aug 15 → Fri, Aug 14 → Mon, Aug 10 の降順に並び、各見出しの下にその日の明細がまとまっている。各行は店名 (給与 / スーパーマーケット 等) + 「カテゴリ · 出所」(Salary · Manual / Food · Manual 等) の 2 段で、支出は `-¥3,480` のように黒の `-¥`、収入 (給与 +¥280,000 / Salary August +¥300,000) はセージ色の `+¥` で表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ad8df1d9-ee7b-4d97-85e4-463a4b806977.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/d7b6ea94-509a-4bd6-9642-603e6624ac58.jpg" width="320">

</details>

### **収支サマリー**: サマリーカードに当月の支出 (主表示)・収入・残り (収入 - 支出、セージ色) がクライアント集計で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、"Spending" / "Income" / "Balance" の英語表示で確認した。

サンプル投入後のサマリーカードは Spending ¥11,300 (左の主表示・最大サイズ)・Income ¥580,000・Balance ¥568,700 (セージ色)。当月明細の値と一致することを計算で確認した: 支出 = 780 + 1,200 + 4,500 + 3,480 + 880 + 460 = ¥11,300 (計算対象外の鳥貴族 ¥4,230 を含まない)、収入 = 300,000 + 280,000 = ¥580,000、残り = 580,000 - 11,300 = ¥568,700。サマリードキュメントを持たないクライアント集計の値が一致している。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ad8df1d9-ee7b-4d97-85e4-463a4b806977.jpg" width="320">

</details>

### **カテゴリ内訳**: 支出のカテゴリ別合計が金額の大きい順の横棒で表示される。支出が無い月ではセクションごと非表示になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、カテゴリ名も英語表示 ("Food" / "Daily goods" / "Transport") になる。

左: サンプル投入後の 2026 年 8 月。Categories セクションに Food ¥9,960 → Daily goods ¥880 → Transport ¥460 の 3 カテゴリが金額の降順で並び、横棒の長さも金額に比例して短くなっている (Food が満幅、Transport が最短)。Food ¥9,960 = 780 + 1,200 + 4,500 + 3,480 で、計算対象外の鳥貴族 (Eating out ¥4,230) はカテゴリ内訳にも現れない。右: 支出が無い 2026 年 7 月では Categories セクションごと表示されず、サマリーカードの直下が空メッセージになる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ad8df1d9-ee7b-4d97-85e4-463a4b806977.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/b42d45c6-2c1e-4727-9d2a-bfd7749e064c.jpg" width="320">

</details>

### **空状態**: 明細が 1 件も無い月では空メッセージが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示 ("No transactions this month") で確認した。

明細のある 2026 年 8 月から前月ボタンで 2026 年 7 月へ移動した。明細が 1 件も無いため一覧の代わりに空メッセージ "No transactions this month" が表示され、サマリーは Spending ¥0 / Income ¥0 / Balance ¥0 になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/b42d45c6-2c1e-4727-9d2a-bfd7749e064c.jpg" width="320">

</details>

### **計算対象外の明細**: excludedFromAggregation の明細 (デバッグメニューの「鳥貴族 (重複疑い)」) は opacity を落とし「計算対象外」注記付きで一覧に表示されるが、サマリー・カテゴリ内訳の集計には含まれない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、「計算対象外」の注記は英語の "Excluded" として表示される。

Fri, Aug 14 の「鳥貴族 三軒茶屋店 (重複疑い) / Eating out · Manual · Excluded / -¥4,230」の行は、他の行と比べて店名・金額・カード背景がいずれも薄く (opacity を落として) 描画され、出所の後ろに "Excluded" が付いている。この ¥4,230 が集計に入っていないことを金額で確認した: サマリーの Spending は ¥11,300 で、これは他の支出 6 件の合計 (780 + 1,200 + 4,500 + 3,480 + 880 + 460) と一致し、4,230 を足した ¥15,530 にはなっていない。カテゴリ内訳にも鳥貴族のカテゴリである "Eating out" の横棒は現れない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/d7b6ea94-509a-4bd6-9642-603e6624ac58.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ad8df1d9-ee7b-4d97-85e4-463a4b806977.jpg" width="320">

</details>

### **明細追加の即時反映**: 手動入力またはデバッグメニューで明細を追加すると、画面操作なしで一覧・サマリー・カテゴリ内訳に即時反映される (snapshot listener)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した。

デバッグメニュー (月ラベルの長押しで開く。DEBUG ビルドのみ・文言は日本語固定) の「サンプル明細を追加」を実行した。左: 実行直前 (明細 4 件 / Spending ¥6,480 / Income ¥300,000 / Categories は Food のみ)。中: 開いたデバッグメニュー。右: メニューが自動で閉じた直後の月次一覧。月の切替・再読み込みなどの画面操作をしていないのに、一覧にサンプル 5 件が加わり、サマリーが Spending ¥11,300 / Income ¥580,000 / Balance ¥568,700 へ、カテゴリ内訳が Food 単独から Food / Daily goods / Transport の 3 本へ更新された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/aeb660e8-e847-4850-9743-0f25c383fa41.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/1ddaa179-c624-4fce-9799-d77a1a6fbdba.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ad8df1d9-ee7b-4d97-85e4-463a4b806977.jpg" width="320">

</details>

### **オフラインキャッシュでの表示**: 明細を表示した後にネットワークを遮断してアプリを再起動・月切替しても、Firestore のオフラインキャッシュから既存明細とサマリーが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

</details>

---

## 2. 月切替

- [x] **前月・次月の切替**: 左右の円形ボタンで表示月が切り替わり、月ラベル (日本語 + 英語副題) とその月の明細・集計が更新される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細が無い月への移動**: 明細が無い月へ移動すると空メッセージが表示され、当月へ戻ると明細が再表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **前月・次月の切替**: 左右の円形ボタンで表示月が切り替わり、月ラベル (日本語 + 英語副題) とその月の明細・集計が更新される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、月ラベルの主表示も英語になる ("August 2026" + 副題 "AUGUST 2026")。項目文の「日本語 + 英語副題」は日本語ロケールでの表示で、英語ロケールでは主表示・副題とも英語になるのが l10n どおりの挙動。主表示と副題の 2 段構成・月切替でどちらも更新されることを確認した。

左: 前月ボタン (画面左の円形ボタン) をタップして "August 2026 / AUGUST 2026" から "July 2026 / JULY 2026" へ切り替わり、サマリーも ¥0 に更新された。右: 次月ボタンで "August 2026" に戻り、サマリー (Spending ¥6,480 / Income ¥300,000 / Balance ¥293,520)・カテゴリ内訳・明細 4 件が再表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/b42d45c6-2c1e-4727-9d2a-bfd7749e064c.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/aeb660e8-e847-4850-9743-0f25c383fa41.jpg" width="320">

</details>

### **明細が無い月への移動**: 明細が無い月へ移動すると空メッセージが表示され、当月へ戻ると明細が再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、英語表示で確認した。

左: 明細が無い 2026 年 7 月へ移動すると "No transactions this month" が表示された。右: 次月ボタンで 2026 年 8 月へ戻ると明細 4 件 (Salary August / Cash expense / Lawson QA / Past Date Cafe) とサマリーが再表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/b42d45c6-2c1e-4727-9d2a-bfd7749e064c.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/aeb660e8-e847-4850-9743-0f25c383fa41.jpg" width="320">

</details>

</details>

---

## 3. 重複検知と手動マージ

状態の作り込み: 同一金額・同一店名・取引日 3 日以内の支出 2 件を作る (手動入力を同条件で 2 回、またはデバッグメニューの「サンプル明細を追加」を 2 回実行。詳細は root QA.md「再現が難しい操作の手順」)。収入・計算対象外の明細は重複候補にならない (lib/entity/transaction.dart の isDuplicateCandidate)。

- [x] **重複候補バナー表示**: 重複候補があると月次一覧に件数付きバナーが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **重複確認シート表示**: バナーをタップすると確認シートが開き、2 件の明細 (店名・日付・金額) が比較表示され、残す明細をタップで選択できる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **重複マージ**: 残す明細を選んで「1件にまとめる」を実行すると、選んだ方が残りもう片方が削除され、一覧・集計・バナー件数が更新される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **別々の支出として残す**: 「別々の支出として残す」を実行すると 2 件とも残り、同じ組み合わせが重複候補として再提示されない (アプリ再起動後も再提示されない)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **重複候補バナー表示**: 重複候補があると月次一覧に件数付きバナーが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、バナーの文言は英語 ("3 possible duplicates" / "Tap to review") になる。

デバッグメニューの「サンプル明細を追加」を 2 回実行して、支出 3 件 (スーパーマーケット ¥3,480 / ドラッグストア ¥880 / 電車 ¥460) がそれぞれ同額・同店名・同日で 2 件ずつある状態を作った。サマリーカードの直下に「3 possible duplicates / Tap to review」のバナーが出て、件数 3 が重複候補の組数と一致した。2 件ずつになった収入の給与 (+¥280,000) と計算対象外の鳥貴族 (¥4,230) は候補に数えられていない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/ebdf29a2-62f6-457c-b360-8d54b447414f.jpg" width="320">

</details>

### **重複確認シート表示**: バナーをタップすると確認シートが開き、2 件の明細 (店名・日付・金額) が比較表示され、残す明細をタップで選択できる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、シートの文言は英語 ("Review possible duplicate" / "Keep this transaction" / "Merge into one" / "Keep as separate expenses") になる。

左: バナーをタップするとボトムシート "Review possible duplicate" が開き、候補 2 件 (どちらも「スーパーマーケット / 8/17/2026 / ¥3,480」) が上下に並んで比較表示された。間に検出理由 "Same amount with nearby dates and similar store names" が出る。初期状態では上の 1 件が選択され (緑の枠 + 塗りつぶしのラジオ + "Keep this transaction")、下は未選択の空ラジオ。右: 下の明細をタップすると選択が下へ移り、枠・ラジオ・"Keep this transaction" の表示も下の明細に移動した。タップで残す明細を選び替えられる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/69023fd9-f296-43d1-89ac-bd4869358cfc.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/7129a3c5-93cd-477c-8850-0b52edc1c549.jpg" width="320">

</details>

### **重複マージ**: 残す明細を選んで「1件にまとめる」を実行すると、選んだ方が残りもう片方が削除され、一覧・集計・バナー件数が更新される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、「1件にまとめる」は英語の "Merge into one" として表示される。

スーパーマーケット ¥3,480 の組で下の明細を選んだ状態から "Merge into one" をタップした。左: 実行直後の月次一覧。バナー件数が 3 → 2 possible duplicates に減り、Spending が ¥16,120 → ¥12,640 (ちょうど ¥3,480 減)、Balance が ¥843,880 → ¥847,360、カテゴリ内訳の Food が ¥13,440 → ¥9,960 (同じく ¥3,480 減) に更新された。集計が 1 件分だけ減っていることが、もう片方が削除されて二重計上が解消されたことの裏付けになる。右: 一覧をスクロールした状態。Mon, Aug 17 のスーパーマーケット ¥3,480 は 1 件だけになり、まだマージしていないドラッグストア ¥880 と電車 ¥460 は 2 件ずつ残っている。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/98d4cbc3-e2e2-4e87-9460-92dbe82aaf94.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/5cb8cd02-a643-4848-8935-24e7fa74b14a.jpg" width="320">

</details>

### **別々の支出として残す**: 「別々の支出として残す」を実行すると 2 件とも残り、同じ組み合わせが重複候補として再提示されない (アプリ再起動後も再提示されない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、「別々の支出として残す」は英語の "Keep as separate expenses" として表示される。

スーパーマーケットのマージ後に残った 2 candidates のうち、ドラッグストア ¥880 (8/16/2026) の組で "Keep as separate expenses" をタップした。左: 確認シートに出たドラッグストアの組。中: 実行直後の月次一覧。バナー件数は 2 → "1 possible duplicate" に減ったのに Spending は ¥12,640 のまま変わらず、カテゴリ内訳の Daily goods も ¥1,760 (= 880 × 2) のままで、2 件とも削除されずに残っている (マージなら 1 件分減るはずの金額が減っていない)。残った 1 件は未処理の電車 ¥460 の組。右: `terminate` → `launch` でアプリを再起動した後も "1 possible duplicate" のままで、Spending ¥12,640 / Daily goods ¥1,760 も変わらない。別物と判断したドラッグストアの組が再提示されないことを確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/3c10055a-91ec-4729-80bd-3b8e69326bd2.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/c92bdb2a-2ec5-4627-99a1-be597ad9174b.jpg" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/225e5c48-317d-4b39-8eed-dd6cbbdf7c64.jpg" width="320">

再起動を挟んだ証拠として、`bash tmp/qa/wda.sh terminate com.bannzai.kashakeibo` の直後にホーム画面が出ている (アプリのプロセスが残っていない) ことも確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/cf83dc48-c076-45ec-a0ed-6a2b1c9f2bf7.jpg" width="320">

</details>

</details>

---

## 4. 導線

- [x] **設定画面への遷移**: ヘッダー右上の設定アイコンをタップすると設定画面へ遷移する
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **手動入力シートの起動**: 「手動で入力」FAB をタップすると ManualEntrySheet が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **設定画面への遷移**: ヘッダー右上の設定アイコンをタップすると設定画面へ遷移する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、遷移先の画面タイトルは "Settings" になる。

月次一覧の右上にあるスライダー型の設定アイコン (アクセシビリティラベル "Open settings") をタップすると、設定画面へ遷移して "Settings" タイトルと法務ドキュメント 3 行が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/9d7ba270-694c-4949-9f69-c9802334b795.jpg" width="320">

</details>

### **手動入力シートの起動**: 「手動で入力」FAB をタップすると ManualEntrySheet が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-19**

runner の Simulator が英語ロケールのため、FAB のラベルは "Enter manually"、シートのタイトルは "Manual entry" になる。

右下の "Enter manually" FAB をタップすると ManualEntrySheet がボトムシートで開いた。金額欄 (Amount) が autofocus されて数字キーボードが立ち上がり、店名欄 (Store or note)・収支種別 (Spending / Income)・カテゴリ (Food / Eating out / Daily goods / Transport / Subscriptions / Other) が表示された。右上の閉じるボタンで月次一覧へ戻れることも確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260819/f0eecf1a-49a1-45d1-b1ba-a94274a7969e.jpg" width="320">

</details>

</details>
