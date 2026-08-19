# capture (レシート撮影 → AI 解析 → 確認・修正 → 登録)

## 概要

カメラでレシートを撮影し、画像を R2 にアップロードしてから Cloudflare Worker 経由の Gemini 解析で
金額・日付・店名・カテゴリを抽出し、確認・修正画面を経て明細として登録するコア機能 (issue #7)。
解析の呼び出し先はクライアント SDK ではなく Worker の `POST /analyses`
(スキャン無料枠をサーバー側で強制するため。documents/adr/0001-tech-stack.md の「画像解析」)。
API 仕様は `workers/image/README.md` を SSOT とする。

## 画面

- `AddRecordSheet`: 月次一覧の「記録する」FAB から開くボトムシート
  - カメラで撮影 (本 feature) / 手動で入力 (`features/manual_entry`) を選ぶ
  - 写真・スクショから選ぶ経路は issue #8 のスコープでまだ無い
- `CapturePage`: 撮影後に全画面で開く撮影フロー画面。3 つの状態を持つ
  - AI 解析中: 脈打つ accent-200 の円 + ステップ文言 (画像を読み込んでいます → 金額・日付を読み取っています → カテゴリを推定しています) を約 950ms 間隔で切替
  - 読み取れませんでした: エラー文をそのまま表示し、「もう一度読み取る」「手動で入力する」「取り直す」を選べる
  - 読み取り確認: 元画像サムネイル (92×120) + 説明カード、店名 / 金額 / 収支種別 / カテゴリ / 日付の全項目を修正でき、「登録する」「取り直す」
- 登録完了トースト: sage-700 のピル「カシャッと記録!」を 2.4 秒表示 (`showCaptureRegisteredToast`)

## フロー

1. 「記録する」→「カメラで撮影」で端末カメラ (image_picker、長辺 1600px・JPEG 品質 85 に縮小) を起動する
2. 撮影すると `CapturePage` を開き、UUID の `uploadImageID` を採番して `uploadCapturedImageProvider` で R2 にアップロードする
3. 返ったオブジェクトキーで `analyzeUploadedImageProvider` (Worker の `POST /analyses`) を呼び、先頭の明細を確認フォームの初期値にする。明細が 0 件なら失敗として扱う
4. 「登録する」で `AddTransaction` が出所 `receipt`・元画像キー付きの明細を保存する。初期値から 1 項目でも変更していれば `analysisAdjustedByUser: true` (出所表示は「手調整」、変更なしは「自動取込」)
5. アップロードまたは解析に失敗した場合は失敗画面へ。「もう一度読み取る」は同じ `uploadImageID` で再試行 (孤児画像を作らない)、「手動で入力する」は空フォーム (アップロード済みなら画像は紐づけたまま、`analysisAdjustedByUser: true`)
6. 「取り直す」「閉じる」はアップロード済み画像を Worker 経由で削除 (失敗しても閉じる) してから戻り、「取り直す」はカメラを開き直す
7. 登録完了後は月次一覧へ戻り、snapshot listener で一覧と集計に反映される。明細行のタップで `features/transaction_detail` から元画像を確認できる

## データ形式

- 保存先: `/users/{userID}/transactions/{id}` の `Transaction` (`source: receipt`、`sourceImageObjectKey`、`analysisAdjustedByUser`)
- 解析結果: `ImageAnalysisResult` (`lib/features/capture/image_analysis_client.dart`)。Worker が Flutter 側 Entity と同じ enum 名で `type` / `category` を返す契約
- 取引日は Worker が `YYYY-MM-DD` で返し、読み取れない場合は null (フォームの既定値は今日)

## 有効期限・制約

- 解析は Worker の日次上限 (uid 別・接続元 IP 別・全体) の対象。月次の無料枠 (月 10 スキャン) と entitlement の判定は課金 (issue #12) のスコープ
- 撮影フローの中断時に画像削除まで失敗した場合、どこからも参照されない画像が R2 に残る (アカウント削除時の全消去で回収される)
- DEBUG ビルドでは開発者メニュー (`features/debug`) の「サンプルレシートで撮影フローを試す」で、端末カメラの無いシミュレータでも描画したレシート画像でフローを通せる
