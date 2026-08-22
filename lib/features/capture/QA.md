---
feature: capture
verification: mobile-mcp
last_verified_commit: a98c098aa2c1140213505b0157402db95836624a
last_verified_at: 2026-08-20
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

## 1. 入力経路 (記録するシート)

- [x] **3 経路の表示**: 「記録する」FAB でボトムシートが開き、カメラで撮影 / 写真・スクショから選ぶ (sage 系アイコン) / 手動で入力 の 3 行が表示される
  - 自動化: manual (Maestro 未導入のため agent のシミュレータ操作で確認する)
- [x] **フォトライブラリの起動**: 「写真・スクショから選ぶ」でフォトピッカー (PHPicker) が開き、画像を選ぶとアップロード → 解析が始まる
  - 自動化: manual
- [ ] **残量 0 のペイウォール (フォトライブラリ)**: 無料プランで今月の残量が 0 の時に「写真・スクショから選ぶ」を選ぶとペイウォールが開き、閉じるとピッカーは開かない
  - 自動化: manual
  - ⏭️ スキップ: 2026-08-20 の実行では未実施 (ペイウォールガードは main の issue #12 とのマージで追加。widget テストでは未カバーのため次回 run-qa で残量 0 を作り込んで確認する)

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

</details>

## 未検証の範囲

- 実機のカメラ撮影・実機フォトライブラリ (シミュレータでは開発者メニューのサンプル画像とシミュレータ標準写真で代替)
- 残量 0 時のペイウォールガード (issue #12 とのマージで追加。単体の widget テストは main 側でカバー済み、実機動作は次回 run-qa)
- 「記録する」シート下部のプレミアム表示の文言変更 (2026-08-22 の「スキャン無制限」→「スキャンし放題」。lib/l10n の scanQuotaUnlimited) はシート上の表示・レイアウトを未検証 (プレミアム状態の作り込みが必要。paywall QA.md「購入後の残量チップ」の再検証と合わせて次回 run-qa で確認する。widget テストでは add_record_sheet_test が文言追従済み)
