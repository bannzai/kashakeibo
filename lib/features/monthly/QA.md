---
feature: monthly
verification: mobile-mcp
last_verified_commit: bfadca170ab924a332f4c369a645776cf13e4d43
last_verified_at: 2026-08-23
---

# monthly QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/5 (月次一覧の受け入れ条件) / https://github.com/bannzai/kashakeibo/issues/10 (重複検知と手動マージの受け入れ条件)
- 関連: lib/features/monthly/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| S1 | 明細は users/{userID}/transactions/{id} に保存され、yearMonth・type・計算対象除外フラグのクエリ用フィールドと複合インデックスを持つ | 明細リスト表示 (yearMonth + transactionDate の複合インデックスは、欠落すると failed-precondition エラーとして画面に現れる)。yearMonth + type + excludedFromAggregation の第 2 インデックスは現時点でアプリのクエリが使っておらず (lib/provider/transaction.dart は yearMonth + transactionDate のみ)、動作 QA では未検証。firebase/firestore.indexes.json の定義確認のみ |
| S2 | 集計はサマリードキュメントを持たず、当月明細のクライアント集計で表示する | 収支サマリー / カテゴリ内訳 (表示額が明細合計と一致することを確認。「サマリードキュメントを持たない」こと自体は lib/provider/transaction.dart が transactions コレクションの購読しか持たないコード確認のみで、動作 QA では未検証) |
| S3a | snapshot listener でリアルタイム反映される | 明細追加の即時反映 (同一アプリ内からの追加で確認) / 別クライアントからの書き込みの自動反映 (未検証) |
| S3b | オフラインキャッシュでも動作する (ネットワーク遮断中の起動・月切替・既存明細表示) | オフラインキャッシュでの表示 (未検証。リモート・ローカルいずれの Simulator も、その Simulator だけをネットワークから切り離す手段が無い) |
| S4 | 金額+日付+店名のヒューリスティックで重複候補を検出し、確認 UI で提示する | 重複候補バナー表示 / 重複確認シート表示 (同日・同一店名の組で確認) / 日付ずれ・店名の表記揺れの重複候補 (同額・2 日ずれ・店名が包含関係の組は候補になり、同額・同一店名でも 6 日離れた組は候補にならないことを 2026-08-23 に確認) |
| S5 | ユーザーはマージ (1件に統合) か「別物として残す」を選べる | 重複マージ / 残す明細の選択がマージ結果に反映される / 別々の支出として残す |
| S6 | マージは複数端末の同時操作でも二重計上・消失が起きない | — (未検証。複数端末の同時操作は手動 QA で再現困難で、lib/provider/transaction.dart の MergeDuplicateTransactions / KeepBothTransactions の競合を検証するユニットテストも 2026-08-23 時点で存在しない。テスト漏れとして可視化) |

## 1. 表示・集計

- [x] **明細リスト表示**: 明細が日付見出しでグループ化され、取引日時の降順で表示される。各行に店名・カテゴリ・出所、支出は `-¥`、収入は `+¥` (セージ色) の金額が出る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **とった記録セクション行と残量チップ**: 明細リストの上に「とった記録」セクション行が表示され、右端のチップが無料プランでは「スキャン残り n 回」、プレミアムでは「スキャンし放題」になる (無料プランで残量未取得なら非表示)。チップをタップするとペイウォールが開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **収支サマリー**: サマリーカードに当月の支出 (主表示)・収入・残り (収入 - 支出、セージ色) がクライアント集計で表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **カテゴリ内訳**: 支出のカテゴリ別合計が金額の大きい順の横棒で表示される。明細が無い月ではセクションごと非表示になる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **収入のみの月のカテゴリ内訳非表示**: 収入明細だけがあり支出が無い月では、カテゴリ内訳セクションが表示されない (明細ゼロの月と同じ扱い)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **空状態**: 明細が 1 件も無い月では空メッセージが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **計算対象外の明細**: excludedFromAggregation の明細 (明細詳細の「計算対象から除外」を ON にしたもの、またはデバッグメニューの「鳥貴族 (重複疑い)」) は opacity を落とし「計算対象外」注記付きで一覧に表示されるが、サマリー・カテゴリ内訳の集計には含まれない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細追加の即時反映**: 手動入力またはデバッグメニューで明細を追加すると、画面操作なしで一覧・サマリー・カテゴリ内訳に即時反映される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **別クライアントからの書き込みの自動反映**: 月次一覧を開いたまま別クライアント (別端末・Firebase コンソール・Admin SDK) から当月の明細を書き込むと、画面操作なしに一覧・集計へ反映される (snapshot listener)
  - 自動化: todo (同一アプリ内からの追加では listener 経由か明示的な再取得かを区別できない。kashakeibo-dev へ別クライアントから書き込む手順が未整備。listener の使用は lib/provider/transaction.dart の monthlyTransactions のコード確認のみ)
- [ ] **オフラインキャッシュでの表示**: 明細を表示した後にネットワークを遮断してアプリを再起動・月切替しても、Firestore のオフラインキャッシュから既存明細とサマリーが表示される
  - 自動化: todo (2026-08-23 のローカル Simulator での実行でも未検証。`xcrun simctl` にネットワーク遮断のコマンドは無く、Network Link Conditioner は開発マシン全体に効く macOS の環境設定のため QA 実行中に切り替えられない。Simulator 単体を遮断する手段が見つかるまで未カバー)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **明細リスト表示**: 明細が日付見出しでグループ化され、取引日時の降順で表示される。各行に店名・カテゴリ・出所、支出は `-¥`、収入は `+¥` (セージ色) の金額が出る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

デバッグメニューの「サンプル明細を追加」で投入した 5 件 + 手動入力の 1 件。日付見出しが 8月23日(日) → 8月22日(土) → 8月21日(金) → 8月20日(木) → 8月19日(水) の降順に並び、各見出しの下にその日の明細がまとまる。各行は店名 (給与 / スーパーマーケット 等) + 「カテゴリ · 出所」(給与 · 手動 / 食費 · 手動 等) の 2 段で、支出は黒の `-¥3,480`、収入はセージ色の `+¥280,000` で表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/39e55acd-7f88-435f-b740-6c90a12c933c.png" width="320" />

</details>

### **収支サマリー**: サマリーカードに当月の支出 (主表示)・収入・残り (収入 - 支出、セージ色) がクライアント集計で表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

サマリーカードは 支出 ¥133,220 (左の主表示・最大サイズ)・収入 ¥280,000・残り ¥146,780 (セージ色)。当月明細の値と一致することを計算で確認した: 支出 = 128,400 + 3,480 + 880 + 460 = ¥133,220 (計算対象外の鳥貴族 ¥4,230 を含まない)、収入 = ¥280,000、残り = 280,000 - 133,220 = ¥146,780。サマリードキュメントを持たないクライアント集計の値が一致している。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />

あわせて issue #72 (支出の主表示の ¥ 記号が小さく数字と密着している) の修正を確認した。¥ を 15px w700 (金額 21px の約 0.7 倍) にし、金額側の詰め (letterSpacing -0.42) を打ち消す字間を入れたことで、¥0 でも桁区切りのある ¥128,400 / ¥133,220 でも記号として読め、数字との間に余白がある。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/222021d6-db6b-4948-8ae0-a82a47adeb3b.png" width="320" />

issue #72 の報告時 (上) と修正後 (下) の支出金額の比較 (3 倍拡大)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/b600f9a8-860a-410d-9694-1c440772b77d.png" width="320" />

</details>

### **カテゴリ内訳**: 支出のカテゴリ別合計が金額の大きい順の横棒で表示される。明細が無い月ではセクションごと非表示になる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

支出のカテゴリ別合計が金額の大きい順の横棒で表示された: 食費 ¥131,880 (= 128,400 + 3,480) → 日用品 ¥880 → 交通 ¥460。計算対象外の鳥貴族 ¥4,230 は外食に計上されていない。明細が無い 2026 年 7 月ではセクションごと非表示になる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/2074ab5c-0b3a-44cd-9b8d-38e7246dfd36.png" width="320" />

</details>

### **収入のみの月のカテゴリ内訳非表示**: 収入明細だけがあり支出が無い月では、カテゴリ内訳セクションが表示されない (明細ゼロの月と同じ扱い)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

2026 年 7 月に手動入力で収入のみ (給与 ¥50,000) を 1 件登録した。支出 ¥0 / 収入 ¥50,000 / 残り ¥50,000 が表示され、明細リストには収入 1 件が並ぶ一方、カテゴリ内訳セクションは表示されない (支出が無い月は明細ゼロの月と同じ扱い)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/895746e3-a6f4-4ecb-bd57-28bd2cc8986e.png" width="320" />

</details>

### **空状態**: 明細が 1 件も無い月では空メッセージが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

明細が 1 件も無い 2026 年 7 月へ月送りすると「今月の明細はまだありません」が表示され、サマリーは支出 ¥0 / 収入 ¥0 / 残り ¥0 になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/2074ab5c-0b3a-44cd-9b8d-38e7246dfd36.png" width="320" />

</details>

### **計算対象外の明細**: excludedFromAggregation の明細 (明細詳細の「計算対象から除外」を ON にしたもの、またはデバッグメニューの「鳥貴族 (重複疑い)」) は opacity を落とし「計算対象外」注記付きで一覧に表示されるが、サマリー・カテゴリ内訳の集計には含まれない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

サンプルの「鳥貴族 三軒茶屋店 (重複疑い)」は opacity を落とした表示で、サブ行が「外食 · 手動 · 計算対象外」になる。集計には含まれず、支出 ¥133,220 に ¥4,230 は乗らず、カテゴリ内訳にも外食が現れない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/39e55acd-7f88-435f-b740-6c90a12c933c.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />

</details>

### **明細追加の即時反映**: 手動入力またはデバッグメニューで明細を追加すると、画面操作なしで一覧・サマリー・カテゴリ内訳に即時反映される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

月次一覧を開いたままデバッグメニューの「サンプル明細を追加」を実行すると、画面操作なしにサマリー (支出 ¥128,400 → ¥133,220、収入 ¥0 → ¥280,000)・カテゴリ内訳 (食費のみ → 食費・日用品・交通)・明細リスト (1 件 → 6 件) が更新された。手動入力での登録も同様に、シートを閉じた直後の一覧へ反映された (2026 年 7 月の収入 ¥50,000、8 月の ¥7,777 / ¥6,666)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/895746e3-a6f4-4ecb-bd57-28bd2cc8986e.png" width="320" />

</details>

### **別クライアントからの書き込みの自動反映**: 月次一覧を開いたまま別クライアント (別端末・Firebase コンソール・Admin SDK) から当月の明細を書き込むと、画面操作なしに一覧・集計へ反映される (snapshot listener)

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **オフラインキャッシュでの表示**: 明細を表示した後にネットワークを遮断してアプリを再起動・月切替しても、Firestore のオフラインキャッシュから既存明細とサマリーが表示される

<details><summary>動作確認スクショ</summary>

（未実行）

</details>

### **とった記録セクション行と残量チップ**: 明細リストの上に「とった記録」セクション行が表示され、右端のチップが無料プランでは「スキャン残り n 回」、プレミアムでは「スキャンし放題」になる (無料プランで残量未取得なら非表示)。チップをタップするとペイウォールが開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド (kashakeibo-dev)。RevenueCat の public API key は注入していないため、プレミアム判定は常に無料プランになる。

左: 月次一覧。サマリーカードの下に「とった記録」セクション行が出て、右端に無料プランの残量チップ「スキャン残り50回」が表示された (Worker の `GET /analyses/quota` が App Check 検証込みで通っている)。右: チップをタップすると全画面のペイウォールが開き、「今月の無料スキャン 0/50」がチップの残量と整合していた。料金カードが「料金プランを取得できませんでした」になっているのは RevenueCat の key 未注入ビルドの既定の挙動 (lib/features/paywall/README.md) で、本項目の「タップでペイウォールが開く」の判定には影響しない。

プレミアム側の「スキャンし放題」表示は、Test Store キーを注入して mock 購入する必要があるため本レーンでは確認していない (paywall QA.md の「購入後の残量チップ」で確認済み)。

残量チップが出るには App Check の debug token 登録が必要 (未登録だと `GET /analyses/quota` が 401 で `monthlyScanQuotaProvider` が値を持たず、`isPremium || scanQuota != null` の条件を満たさずチップごと消える)。手順は root QA.md の実行ナレッジを参照。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/cbbe160a-7a5c-4c45-ab11-edc6cffcabca.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b7825b24-06d0-4866-99c5-97168b422b31.png" width="320">

</details>

</details>

---

## 2. 月切替

- [x] **前月・次月の切替**: 左右の円形ボタンで表示月が切り替わり、月ラベル (日本語 + 英語副題) とその月の明細・集計が更新される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細が無い月への移動**: 明細が無い月へ移動すると空メッセージが表示され、当月へ戻ると明細が再表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [ ] **無料プランの履歴制限ペイウォール**: 無料プランで当月を含む直近 3 ヶ月より古い月へ前月ボタンで移動しようとするとペイウォールが開き、月は切り替わらない。ペイウォールを閉じると元の月のまま。プレミアムなら制限なく移動できる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
  - プレミアム側の「制限なく移動できる」は未確認。RevenueCat の Test Store キーを注入したビルドでの購入が必要なため (paywall QA.md「古い月への月送りでペイウォールを開く」と合わせて次回 run-qa で扱う)。無料プラン側の挙動のみ確認済み

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **前月・次月の切替**: 左右の円形ボタンで表示月が切り替わり、月ラベル (日本語 + 英語副題) とその月の明細・集計が更新される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

前月ボタンで「2026年8月 / AUGUST 2026」から「2026年7月 / JULY 2026」へ切り替わり、サマリーも当月の値から ¥0 に更新された。次月ボタンで 2026 年 8 月へ戻ると、サマリー (支出 ¥133,220 / 収入 ¥280,000 / 残り ¥146,780)・カテゴリ内訳・明細リストが再表示された。日本語ロケールのため主表示が日本語 (2026年8月)、副題が英語 (AUGUST 2026) の 2 段構成になる。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/2074ab5c-0b3a-44cd-9b8d-38e7246dfd36.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />

</details>

### **明細が無い月への移動**: 明細が無い月へ移動すると空メッセージが表示され、当月へ戻ると明細が再表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

明細が無い 2026 年 7 月へ移動すると「今月の明細はまだありません」が表示され、次月ボタンで 2026 年 8 月へ戻ると明細 6 件とサマリーが再表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/2074ab5c-0b3a-44cd-9b8d-38e7246dfd36.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f9aebf33-e895-40e2-98bb-5ead98ee4b46.png" width="320" />

</details>

### **無料プランの履歴制限ペイウォール**: 無料プランで当月を含む直近 3 ヶ月より古い月へ前月ボタンで移動しようとするとペイウォールが開き、月は切り替わらない。ペイウォールを閉じると元の月のまま。プレミアムなら制限なく移動できる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。RevenueCat の key 未注入で無料プラン扱い。Simulator の当日は 2026-08-22 なので、無料で見られるのは 2026 年 8 月・7 月・6 月の 3 ヶ月。

左: 当月 2026 年 8 月から前月ボタンを 2 回押した 2026 年 6 月。ここまでは制限なく移動できた。中: 6 月からもう一度前月ボタンを押した結果。5 月へは切り替わらずペイウォールが全画面で開いた (特典に「全期間の履歴」が並ぶ)。右: ペイウォールを閉じるボタンで閉じた直後。月ラベルは 2026 年 6 月のままで、5 月へ進んでいない。

プレミアム側の「制限なく移動できる」は Test Store キーを注入した購入が必要なため本レーンでは確認していない (paywall QA.md「古い月への月送りでペイウォールを開く」と合わせて扱う)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/b3e79b05-fb0c-4810-a4fa-7d1dd32e781e.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/937c08ba-d6e9-4799-b80b-c19c07f89c0c.png" width="320">
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/1135d095-a30b-4102-97b3-4ee85a5e2a63.png" width="320">

</details>

</details>

---

## 3. 重複検知と手動マージ

状態の作り込み: 同一金額・店名が一致または包含・取引日 3 日以内の支出 2 件を作る (手動入力を同条件で 2 回、またはデバッグメニューの「サンプル明細を追加」を 2 回実行。詳細は root QA.md「再現が難しい操作の手順」)。収入・計算対象外の明細は重複候補にならない (lib/entity/transaction.dart の isDuplicateCandidate)。

マージ結果の識別が必要な項目では、店名・日付が同一の組ではどちらが残ったか画面から分からないため、店名または日付をずらした組 (例: ¥3,480 の「スーパーマーケット」8/20 と「スーパーマーケット 渋谷店」8/18) を手動入力で作る。

- [x] **重複候補バナー表示**: 重複候補があると月次一覧に件数付きバナーが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **重複確認シート表示**: バナーをタップすると確認シートが開き、2 件の明細 (店名・日付・金額) が比較表示され、残す明細をタップで選択できる
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **重複マージ**: 「1件にまとめる」を実行すると 2 件が 1 件になり、削除された分だけ集計が減りバナー件数が更新される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **残す明細の選択がマージ結果に反映される**: 表示上区別できる重複候補 (日付または店名が異なる組) で下側の明細を選んで「1件にまとめる」を実行すると、選んだ下側が残り上側が削除される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **別々の支出として残す**: 「別々の支出として残す」を実行すると 2 件とも残り、同じ組み合わせが重複候補として再提示されない (アプリ再起動後も再提示されない)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **日付ずれ・店名の表記揺れの重複候補**: 同額で取引日が 1〜3 日ずれ、店名が包含関係 (例: 「スーパーマーケット」と「スーパーマーケット 渋谷店」) の支出 2 件も重複候補になる。取引日が 4 日以上離れた組は候補にならない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **重複候補バナー表示**: 重複候補があると月次一覧に件数付きバナーが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

「サンプル明細を追加」を 2 回実行して支出 3 種 (スーパーマーケット ¥3,480 / ドラッグストア ¥880 / 電車 ¥460) をそれぞれ 2 件ずつにした状態で、サマリー直下に「重複の可能性が3件あります / タップして確認」のバナーが表示された。同じく 2 件になった収入 (給与 ¥280,000) と計算対象外の鳥貴族は候補に数えられていない。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/34ed91db-37cc-444f-81ff-81969b0071c6.png" width="320" />

</details>

### **重複確認シート表示**: バナーをタップすると確認シートが開き、2 件の明細 (店名・日付・金額) が比較表示され、残す明細をタップで選択できる

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

バナーをタップすると「重複候補の確認」シートが開き、2 件の明細が店名・日付 (2026/8/22)・金額 (¥3,480) 付きで上下に比較表示された。上側が既定で選択され「この明細を残す」と表示され、間に「金額が同じ・日付と店名が近い」の判定理由が入る。下部に「1件にまとめる」「別々の支出として残す」の 2 ボタンが並ぶ。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/e34f08dd-ceda-4542-b6c3-0a55894de76d.png" width="320" />

</details>

### **重複マージ**: 「1件にまとめる」を実行すると 2 件が 1 件になり、削除された分だけ集計が減りバナー件数が更新される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

スーパーマーケット ¥3,480 の組で「1件にまとめる」を実行すると、支出が ¥138,040 → ¥134,560 (削除した ¥3,480 ぶん) に減り、食費も ¥135,360 → ¥131,880 に減った。バナーは「3件」→「2件」に更新され、明細リストの 8月22日(土) に残るスーパーマーケットは 1 件になった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/34ed91db-37cc-444f-81ff-81969b0071c6.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/11bb9243-0195-4a92-b3cb-ac059e469887.png" width="320" />

</details>

### **残す明細の選択がマージ結果に反映される**: 表示上区別できる重複候補 (日付または店名が異なる組) で下側の明細を選んで「1件にまとめる」を実行すると、選んだ下側が残り上側が削除される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

表示上区別できる組を作るため、手動入力で ¥7,777 の支出を 2 件登録した (「カフェ」2026/8/10 と「カフェ 渋谷店」2026/8/12)。確認シートでは既定で上側の「カフェ 渋谷店 (2026/8/12)」が選択されている。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/8cdce512-1495-456f-bf45-44ca033bc3c6.png" width="320" />

下側の「カフェ (2026/8/10)」をタップすると選択が下側へ移り、「この明細を残す」の表示も下側へ移動した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/8018bca7-210b-40a5-8845-68b623ed1564.png" width="320" />

その状態で「1件にまとめる」を実行すると、選んだ下側の「カフェ (8月10日)」が残り、上側の「カフェ 渋谷店 (8月12日)」は削除された (8月12日の日付見出しごと消えている)。支出は ¥163,446 → ¥155,669 (¥7,777 ぶん)、外食は ¥15,554 → ¥7,777 に減った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/e7590a1e-873c-4e0f-88cb-8ead6e58d048.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/77159e61-ba4c-4411-890f-9512f00c2c4a.png" width="320" />

</details>

### **別々の支出として残す**: 「別々の支出として残す」を実行すると 2 件とも残り、同じ組み合わせが重複候補として再提示されない (アプリ再起動後も再提示されない)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

ドラッグストア ¥880 の組で「別々の支出として残す」を実行すると、バナーが「2件」→「1件」に減る一方で支出は ¥134,560 のまま変わらず、日用品も ¥1,760 (¥880 × 2) のままで 2 件とも残っていることを確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/78afad88-5d7c-4aa5-94f7-9bbecee37405.png" width="320" />

アプリを終了してホーム画面に戻ったことを確認したうえで再起動しても、バナーは「1件」のままでこの組は再提示されなかった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/f802a552-6a93-4257-ba06-8ae892ea4372.png" width="320" />

</details>

### **日付ずれ・店名の表記揺れの重複候補**: 同額で取引日が 1〜3 日ずれ、店名が包含関係 (例: 「スーパーマーケット」と「スーパーマーケット 渋谷店」) の支出 2 件も重複候補になる。取引日が 4 日以上離れた組は候補にならない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

**候補になる側**: 手動入力で ¥7,777 の支出を「カフェ」2026/8/10 と「カフェ 渋谷店」2026/8/12 の 2 件登録した (同額・取引日 2 日ずれ・店名が包含関係)。バナーの件数が「1件」→「2件」に増え、シートに「金額が同じ・日付と店名が近い」の判定理由付きでこの組が提示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/b0e42e94-4446-4544-aaaa-1e8494ae0335.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/8cdce512-1495-456f-bf45-44ca033bc3c6.png" width="320" />

**候補にならない側**: 同じく手動入力で ¥6,666 の支出を「ベーカリー」2026/8/5 と「ベーカリー」2026/8/11 の 2 件登録した (同額・同一店名だが取引日が 6 日離れている)。支出は ¥150,114 → ¥163,446、食費は ¥131,880 → ¥145,212 と 2 件とも登録されている一方、バナーは「2件」のままで件数が増えず、この組は候補にならないことを確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/b0e42e94-4446-4544-aaaa-1e8494ae0335.png" width="320" />

</details>

</details>

---

## 4. 導線

- [x] **設定画面への遷移**: ヘッダー右上の設定アイコンをタップすると設定画面へ遷移する
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **手動入力シートの起動**: 「記録する」FAB でボトムシートが開き、「手動で入力」をタップすると手動明細入力シート (ManualEntrySheet) が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する。2026-08-22 の見直しで FAB が「手動で入力」から「記録する」シート経由に変わったため項目を差し替えた)
- [x] **明細詳細への遷移**: 明細行をタップすると明細詳細画面 (TransactionDetailPage) が開く (詳細画面の中身は lib/features/transaction_detail/QA.md で確認する)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **設定画面への遷移**: ヘッダー右上の設定アイコンをタップすると設定画面へ遷移する

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

月切替ヘッダー右上の設定アイコンをタップすると設定画面へ遷移し、バックアップ (Apple / Google でリンク)・プラン・法務ドキュメント 3 種・アカウント削除が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/732d904e-60af-4abf-8390-349e6511671d.png" width="320" />

</details>

### **手動入力シートの起動**: 「手動で入力」FAB をタップすると ManualEntrySheet が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

ローカル Simulator (kashakeibo-issue-72-iOS26.5、日本語ロケール・JST) の debug ビルドで確認した。

「記録する」FAB をタップすると 3 経路の「記録する」シートが開き、「手動で入力」を選ぶと ManualEntrySheet (金額・店名/メモ・収支種別・カテゴリ・日付・登録する) が開いた。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/d5424f6d-d915-4336-8cae-a4d227cd0d21.png" width="320" />
<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/ffeb0b83-68ea-4245-80f5-2706ef53e74d.png" width="320" />

</details>


### **明細詳細への遷移**: 明細行をタップすると明細詳細画面 (TransactionDetailPage) が開く (詳細画面の中身は lib/features/transaction_detail/QA.md で確認する)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-22**

ローカル Simulator (iPhone 16 Pro / iOS 26.5、日本語ロケール) の debug ビルド。

月次一覧の `ローソン QA / 日用品 · 手動 / -¥1,200` の行をタップすると、タイトル「明細」の明細詳細画面へ遷移し、タップした明細と同じ金額 ¥1,200・店名・日付・カテゴリが表示された。左上の戻るボタンで月次一覧へ戻れることも確認した。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260822/35c669ce-c6ff-49a0-a2a5-ba09f0cbf756.png" width="320">

</details>

</details>
