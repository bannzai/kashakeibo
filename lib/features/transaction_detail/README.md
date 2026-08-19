# transaction_detail (明細詳細)

## 概要

明細 1 件の詳細を表示し、「元の画像にいつでも戻れる」ことと、AI の読み取りをユーザーが確認・修正
できる保険を提供する画面 (issue #9)。元画像の表示・拡大、画像だけの削除、明細ごとの削除、
計算対象からの除外、出所 (レシート/スクショ/手動 と 自動取込/手調整) の表示を行う。
デザインは design_handoff_kashakeibo/README.md の 4「明細詳細」に合わせる。

## 画面

- `TransactionDetailPage`: 月次一覧の明細行をタップすると開く
  - 見出し: 金額 (34px w800 tnum、収入は sage-700) → 店名 → 日付 · カテゴリ (計算対象外なら注記)
  - 元画像: 高さ 170・radius 28 のカード。右下の「拡大」でピンチ操作できる全画面表示。
    下に注記「元画像はいつでも確認できます」と「画像だけを削除」
  - 画像が無い明細はプレースホルダー (手動入力なら「手動入力のため元画像なし」、それ以外は「元画像なし」)
  - 情報カード: 出所チップ (`transactionSourceLabel` + `transactionProvenanceLabel`)、
    「計算対象から除外」スイッチ (ON = sage-500)
  - フッター: 「明細を削除」(アウトライン・accent-800)
- 削除系は確認ダイアログを挟む。操作の失敗はエラー文をそのまま SnackBar に表示する

## フロー

1. 月次一覧で明細行をタップ → `transactionProvider(transactionID:)` で明細 1 件を snapshot listener で購読して表示
2. 元画像は `storedImageProvider(imageObjectKey:)` (Worker 経由の取得結果をキャッシュ) で読み込み、`Image.memory` で表示
3. 「計算対象から除外」を切り替えると `UpdateTransactionExclusion` が即時に保存し、listener 経由で本画面と月次一覧の合計・カテゴリ内訳へ反映される
4. 「画像だけを削除」→ 確認 → `RemoveTransactionSourceImage` が R2 の画像を削除してから `sourceImageObjectKey` を null にする (明細は残る)
5. 「明細を削除」→ 確認 → `DeleteTransaction` が R2 の画像 (あれば) を削除してから Firestore ドキュメントを削除し、月次一覧へ戻る
6. 別端末などで明細が削除された場合は「この明細は削除されました」を表示する

## データ形式

- 明細: `/users/{userID}/transactions/{id}` の `Transaction`
- 元画像: `Transaction.sourceImageObjectKey` (R2 のオブジェクトキー。`lib/features/image_upload/README.md`)
- 出所記録: `Transaction.source` (経路) と `Transaction.analysisAdjustedByUser` (AI 解析結果の修正有無)

## 有効期限・制約

- 元画像の取得には Firebase ID token が必要で、Worker 経由でのみ取得できる (`Image.network` は使えない)
- 画像の削除・明細の削除は元に戻せない (確認ダイアログで明示する)
- 金額・店名などの編集は本画面では行わない (登録前の修正は `features/capture` の読み取り確認画面)
