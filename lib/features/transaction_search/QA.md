---
feature: transaction_search
verification: mobile-mcp
last_verified_commit: d6f42f2c10de1aa3a9d4db26591e898366a42d17
last_verified_at: 2026-08-23
---

# transaction_search QA

## 関連リンク

- 仕様: https://github.com/bannzai/kashakeibo/issues/73 (訂正削除履歴・検索要件の受け入れ条件)
- 関連: lib/features/transaction_search/README.md

## 仕様チェックリスト

| ID | 期待挙動 | 対応項目 |
|----|---------|---------|
| T1 | 取引年月日を範囲指定して明細を検索できる | 取引年月日での検索 |
| T2 | 取引金額を範囲指定して明細を検索できる | 取引金額での検索 |
| T3 | 取引先 (店名) で明細を検索できる | 取引先での検索 |
| T4 | 検索に必要な Firestore 複合インデックスが定義されている | 複合インデックスの定義 |

## 1. 検索フォーム

- [x] **検索画面への遷移**: 月次一覧の右上の検索アイコンをタップすると検索画面が開き、条件未入力の状態で「検索条件を1つ以上入力してください」が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **条件のクリア**: 条件を入力して検索した後に「条件をクリア」をタップすると、入力欄と結果が初期状態に戻る
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **日付の前後関係の検証**: 終了日を開始日より前に設定して検索すると、検索は実行されず「終了日は開始日以降にしてください」が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **金額の大小関係の検証**: 最大金額を最小金額より小さくして検索すると、検索は実行されず「最大金額は最小金額以上にしてください」が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **検索画面への遷移**: 月次一覧の右上の検索アイコンをタップすると検索画面が開き、条件未入力の状態で「検索条件を1つ以上入力してください」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23** (ローカル Simulator / debug ビルド = kashakeibo-dev)

月次一覧右上の検索アイコンから遷移。未入力状態でプロンプトが表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/610d4f06-927a-4d5f-b76b-81d7fa80b845.png" width="320" />

</details>

### **条件のクリア**: 条件を入力して検索した後に「条件をクリア」をタップすると、入力欄と結果が初期状態に戻る

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

取引先「スーパー」で 1 件ヒットさせた後に「条件をクリア」をタップ。入力欄が空になり「検索条件を1つ以上入力してください」の初期状態に戻った。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/ce2e1b0c-5819-4a5f-ab71-b8ed9e188209.png" width="320" />

</details>

### **日付の前後関係の検証**: 終了日を開始日より前に設定して検索すると、検索は実行されず「終了日は開始日以降にしてください」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

開始日 2026/8/22・終了日 2026/8/21 で「検索する」をタップ。エラーメッセージが表示され、結果欄は未検索状態のままだった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/e93ed61d-045e-4f53-9334-ec89726d838e.png" width="320" />

</details>

### **金額の大小関係の検証**: 最大金額を最小金額より小さくして検索すると、検索は実行されず「最大金額は最小金額以上にしてください」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

最小 ¥5000・最大 ¥500 で「検索する」をタップ。エラーメッセージが表示され、結果欄は未検索状態のままだった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/bf1962bd-1223-4e5d-b2e3-009ec50328da.png" width="320" />

</details>

</details>

---

## 2. 検索の実行

- [x] **取引年月日での検索**: 開始日・終了日を指定して検索すると、その期間の明細だけが取引日の新しい順で表示され、期間外の明細は出ない
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する。絞り込みのロジックは test/provider/transaction_search_test.dart でも検証している)
- [x] **取引金額での検索**: 最小・最大金額を指定して検索すると、その範囲 (両端を含む) の金額の明細だけが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する。絞り込みのロジックは test/provider/transaction_search_test.dart でも検証している)
- [x] **取引先での検索**: 店名の一部を入力して検索すると、店名にその文字列を含む明細だけが表示される (大文字小文字を無視する)
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する。絞り込みのロジックは test/provider/transaction_search_test.dart でも検証している)
- [x] **複数条件の同時指定**: 期間・金額・店名を同時に指定すると、すべての条件を満たす明細だけが表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **0 件の表示**: 一致する明細が無い条件で検索すると「条件に一致する明細はありません」が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **明細詳細への遷移**: 検索結果の行をタップすると、その明細の明細詳細が開く
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **取引年月日での検索**: 開始日・終了日を指定して検索すると、その期間の明細だけが取引日の新しい順で表示され、期間外の明細は出ない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

サンプル明細 5 件 (8/19〜8/23) を投入した状態で、開始日 8/21・終了日 8/22 を指定して検索。期間内の 2 件 (スーパーマーケット 8/22 → ドラッグストア 8/21) だけが新しい順で表示され、期間外 (給与 8/23・電車 8/20・鳥貴族 8/19) は表示されなかった。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/682de900-975e-4d26-8913-3b3d97b736d0.png" width="320" />

</details>

### **取引金額での検索**: 最小・最大金額を指定して検索すると、その範囲 (両端を含む) の金額の明細だけが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

最小 ¥500・最大 ¥5000 で検索し、範囲内の 3 件 (スーパーマーケット ¥3,480・ドラッグストア ¥880・鳥貴族 ¥4,230) が表示され、範囲外 (給与 ¥280,000) は表示されなかった。kashakeibo-dev にデプロイした複合インデックスでクエリが成功している (インデックスビルド完了前は failed-precondition のエラーがそのまま表示されることも確認した)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/c62dfa84-a2a7-4732-9c39-7995a7800376.png" width="320" />

</details>

### **取引先での検索**: 店名の一部を入力して検索すると、店名にその文字列を含む明細だけが表示される (大文字小文字を無視する)

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

取引先「スーパー」で検索し、部分一致する「スーパーマーケット」1 件だけが表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/a8dc1e8f-ec6b-4ff4-a21f-97515ea6f210.png" width="320" />

</details>

### **複数条件の同時指定**: 期間・金額・店名を同時に指定すると、すべての条件を満たす明細だけが表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

金額 ¥500〜¥5000 + 取引先「ドラッグ」の同時指定で、両方を満たす「ドラッグストア ¥880」1 件だけが表示された (金額のみでは 3 件)。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/6287ccdc-ffe9-4ba4-aaab-1d64df8bcfbe.png" width="320" />

</details>

### **0 件の表示**: 一致する明細が無い条件で検索すると「条件に一致する明細はありません」が表示される

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

取引先「存在しない店」で検索し、「条件に一致する明細はありません」が表示された。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/bf2f1905-99ed-4af6-8bda-406ca1c9c5dd.png" width="320" />

</details>

### **明細詳細への遷移**: 検索結果の行をタップすると、その明細の明細詳細が開く

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

検索結果の「ドラッグストア」行をタップし、その明細の詳細画面 (¥880・2026年8月21日(金)・日用品) が開いた。

<img src="https://pub-7f3469dd3e2e445b9b8ec2d1381b5ea8.r2.dev/bannzai/kashakeibo/20260823/74025674-9bb2-4c08-ab7d-c95923c1f907.png" width="320" />

</details>

</details>

---

## 3. Firestore の設定

- [x] **複合インデックスの定義**: firebase/firestore.indexes.json に transactions の `amount ASC` + `transactionDate DESC` が定義され、デプロイ済みの環境で金額範囲を指定した検索が failed-precondition にならない
  - 自動化: manual (ファイル内容の確認と、インデックスをデプロイした環境での金額検索で確認する)

#### 動作確認
<details>
<summary>動作確認エビデンス</summary>

### **複合インデックスの定義**: firebase/firestore.indexes.json に transactions の `amount ASC` + `transactionDate DESC` が定義され、デプロイ済みの環境で金額範囲を指定した検索が failed-precondition にならない

<details><summary>動作確認スクショ</summary>

**確認日: 2026-08-23**

`firebase deploy --only firestore:indexes --project dev` で kashakeibo-dev にデプロイし、`gcloud firestore indexes composite list` で `(amount ASC, transactionDate DESC)` が `READY` であることを確認した。READY 後の金額範囲検索は failed-precondition にならず結果が返った (「取引金額での検索」のスクショ参照)。kashakeibo-prod へのデプロイは本 PR のマージ後のリリース作業で行う (未デプロイ)。

</details>

</details>
