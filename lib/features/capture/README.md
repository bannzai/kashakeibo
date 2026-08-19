# capture (撮影・スクショ取込 → AI 解析 → 確認・修正 → 登録)

## 概要

カメラで撮ったレシートやフォトライブラリのスクショ (カード明細・EC の購入履歴) を R2 にアップロードし、
Cloudflare Worker 経由の Gemini 解析で金額・日付・店名・カテゴリを抽出して、確認・修正画面を経て
明細として登録するコア機能 (issue #7・#8)。1 枚の画像から複数の明細が読み取れた場合は候補リストで
採用・破棄を選ぶ。共有 Extension から受け取った画像も同じ確認画面へ合流する (`features/share_import`)。
解析の呼び出し先はクライアント SDK ではなく Worker の `POST /analyses`
(スキャン無料枠をサーバー側で強制するため。documents/adr/0001-tech-stack.md の「画像解析」)。
API 仕様は `workers/image/README.md` を SSOT とする。

## 画面

- `AddRecordSheet`: 月次一覧の「記録する」FAB から開くボトムシート。3 行を表示する
  - カメラで撮影 (accent-100 の円) / 写真・スクショから選ぶ (sage 系の円。本 feature) / 手動で入力 (`features/manual_entry`)
- `CapturePage`: 画像を選んだ後に全画面で開く取込フロー画面。解析の進行と読み取れた明細の件数で表示を切り替える
  - AI 解析中: 脈打つ accent-200 の円 + ステップ文言 (画像を読み込んでいます → 金額・日付を読み取っています → カテゴリを推定しています) を約 950ms 間隔で切替
  - 読み取れませんでした: エラー文をそのまま表示し、「もう一度読み取る」「手動で入力する」「取り直す」を選べる
  - 読み取り確認 (明細 1 件・手動入力フォールバック): 元画像サムネイル (92×120) + 説明カード、店名 / 金額 / 収支種別 / カテゴリ / 日付の全項目を修正でき、「登録する」「取り直す」
  - 読み取り確認 (明細 2 件以上): 元画像サムネイル + 読み取り件数の説明カード + 候補カードのリスト。カード 1 枚 = 採用チェックボックス (既定は全件採用) + 店名 · 金額 + 取引日 · カテゴリ · 収支 + 「修正する」。破棄したカードは opacity 0.45。主ボタンは「n 件を登録する」(採用 0 件で無効)
  - 候補の修正シート: 候補 1 件を単一フォームと同じ入力項目で編集し、「変更を反映」で候補カードへ戻す
- 登録完了トースト: sage-700 のピル「カシャッと記録!」を 2.4 秒表示 (`showCaptureRegisteredToast`)

## フロー

1. 取込フローの入口は 3 種類 (`CaptureEntryPoint`)。「記録する」→「カメラで撮影」は端末カメラ、「写真・スクショから選ぶ」はフォトライブラリを起動し (image_picker、長辺 1600px・JPEG 品質 85 に縮小)、共有 Extension 経由 (`features/share_import`) は受け取った画像でそのまま始まる
2. 画像が決まると `CapturePage` を開き、UUID の `uploadImageID` を採番して `uploadCapturedImageProvider` で R2 にアップロードする
3. 返ったオブジェクトキーで `analyzeUploadedImageProvider` (Worker の `POST /analyses`) を呼ぶ。明細が 1 件なら確認フォームの初期値にし、2 件以上なら候補リストを表示する。0 件なら失敗として扱う
4. 「登録する」で `AddTransaction` が出所 (カメラは `receipt`、フォトライブラリ・共有 Extension は `screenshot`)・元画像キー付きの明細を保存する。初期値から 1 項目でも変更していれば `analysisAdjustedByUser: true` (出所表示は「手調整」、変更なしは「自動取込」)
5. 候補リストでは採用した候補を上から順に登録する。途中で失敗した場合は登録済みの候補をリストから外してエラー文をそのまま表示し、残りの候補だけを再登録できる (二重登録しない)
6. アップロードまたは解析に失敗した場合は失敗画面へ。「もう一度読み取る」は同じ `uploadImageID` で再試行 (孤児画像を作らない)、「手動で入力する」は空フォーム (アップロード済みなら画像は紐づけたまま、`analysisAdjustedByUser: true`)
7. 「取り直す」「閉じる」(システムの戻る操作を含む) はアップロード済み画像を Worker 経由で削除 (失敗しても閉じる) してから戻り、「取り直す」は入口に応じてカメラまたはフォトライブラリを開き直す (共有 Extension 経由はフォトライブラリ)。アップロード中に閉じた場合はアップロード完了側で画像を削除する。登録の実行中は閉じられない
8. 登録完了後は月次一覧へ戻り、snapshot listener で一覧と集計に反映される。明細行のタップで `features/transaction_detail` から元画像を確認できる

## データ形式

- 保存先: `/users/{userID}/transactions/{id}` の `Transaction` (`source` は `receipt` / `screenshot`、`sourceImageObjectKey`、`analysisAdjustedByUser`)
- 1 枚の画像から登録した複数の明細は、同じ `sourceImageObjectKey` を共有する (元画像は 1 つ)
- 解析結果: `ImageAnalysisResult` (`lib/features/capture/image_analysis_client.dart`)。Worker が Flutter 側 Entity と同じ enum 名で `type` / `category` を返す契約
- 取引日は Worker が `YYYY-MM-DD` で返し、読み取れない場合は null (フォームの既定値は今日)

## 有効期限・制約

- 解析は Worker の日次上限 (uid 別・接続元 IP 別・全体) の対象。月次の無料枠 (月 10 スキャン) と entitlement の判定は課金 (issue #12) のスコープ
- 撮影フローの中断時に画像削除まで失敗した場合、どこからも参照されない画像が R2 に残る (アカウント削除時の全消去で回収される)
- DEBUG ビルドでは開発者メニュー (`features/debug`) の「サンプルレシートで撮影フローを試す」で、端末カメラの無いシミュレータでも描画したレシート画像でフローを通せる
