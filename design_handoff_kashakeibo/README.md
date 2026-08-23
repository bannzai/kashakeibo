# Handoff: カシャケイボ (Kashakeibo) — AI家計簿アプリ 全画面UI

## Overview
スクショ・写真を撮ると AI (Gemini vision) が金額・日付・店名を読み取り明細を自動作成する家計簿アプリ (iOS / Android、Flutter + Material 3)。口座連携をしない (「連携しないから壊れない・認証情報を預けないから怖くない」) ことが売りで、**明細は必ず元画像と紐づく**ことが信頼の核。このハンドオフはホーム〜設定まで全9画面 + 取込フローのデザインを含む。

## About the Design Files
このバンドルの HTML ファイルは **HTML で作られたデザインリファレンス** であり、そのまま出荷するコードではない。タスクは、これらのデザインを **対象コードベース (Flutter / Material 3、リポジトリ: bannzai/kashakeibo — 現状ほぼ空) に再現実装する**こと。Flutter の標準的なパターン (ColorScheme / TextTheme / NavigationBar / BottomSheet 等) を使い、見た目と挙動を忠実に移植する。

- `Kashakeibo Prototype.dc.html` — **正**となるタップ遷移プロトタイプ (全画面 + フロー)。ブラウザで開いて操作できる
- `Design Options.dc.html` — 検討経緯 (3方向比較 → 1a採用 → 数字書体2a採用)。参考のみ
- `Kashakeibo Handoff.dc.html` — 人間向け引き継ぎ書 (印刷可)。本 README と同内容の要約
- `_ds/…/styles.css` — デザイントークンの原本 (CSS変数)

## Fidelity
**High-fidelity (hifi)**。色・タイポ・角丸・余白・状態は最終仕様。プロトタイプの見た目をピクセル基準で再現すること。ただし画像類 (レシート写真等) はストライプのプレースホルダーであり、実装では実画像サムネイルに置き換える。

## Design Tokens

### Colors
- background: `#f5ead8` (クリーム) / surface (カード): `#f9f4ed` / surface変異: `#eee7db`
- onSurface (本文): `#201e1d`
- primary (テラコッタ): `#c67139` / onPrimary: `#f5ead8` / hover: `#b2622d` / pressed: `#8c491a`
- primary tint: 100 `#fff2eb`, 200 `#ffe1d0`, 300 `#ffc6a5`, 400 `#f6a06b`, 500 `#d67f48`, 700 `#8c491a` (tint上の文字)
- secondary (セージ): `#7a8a5e` — ramp: 100 `#f0fae1`, 200 `#e1eecc`, 300 `#ccdbb2`, 400 `#aebf92`, 500 `#8fa073`, 700 `#56633f`, 800 `#3d472b`
- neutral ramp: 100 `#f9f4ed`, 200 `#eee7db`, 300 `#dcd3c4`, 400 `#c0b6a5`, 500 `#a19786`, 600 `#82796a`, 700 `#645c50`, 800 `#474238`, 900 `#2e2b25`
- divider/outline: `#201e1d` @16%
- 赤は存在しない。破壊的操作 (削除) は `#643312` (accent-800) 系で表現

### Typography
- 書体は **Figtree 一本** (和文は Noto Sans JP 等の丸みのないゴシック)。装飾書体 (Caprasimo) は検討の末**不採用**
- 金額: **w800 + tabular figures** (`font-feature-settings:'tnum'`)、¥記号は本体より小さく `neutral-600`。例: サマリー 21px/¥は15px (数字との字間 2px)、明細詳細 34px、行金額 14px w700
  - ¥ は本体の 0.7 倍程度を下限にし、数字側の詰め (負の letter-spacing) を継承させない。当初の「21px に対し ¥ 10px 上付き相当」は実機で記号として読めず数字と密着したため改めた ([issue #72](https://github.com/bannzai/kashakeibo/issues/72))
- 見出し: w800 (画面タイトル19px、セクション15-16px)。本文 13-13.5px w600、補助 10-11px `neutral-600`
- 最小サイズ: 補助9.5px相当を下限。タップ領域は44px以上

### Shape / Elevation / Icons
- radius: カード 16px、大カード・シート 28px、ボタン/チップ/入力 999px (ピル)。鋭角・ヘアラインのみの境界は禁止
- shadow: sm `0 1px 2px #2e2b25@14%`, md `0 3px 10px @16%`, lg `0 12px 32px @22%`
- アイコン: **Lucide**、stroke-width **2.75**

### Material 3 mapping
primary=#c67139, onPrimary=#f5ead8, secondary=#7a8a5e, surface=#f9f4ed, background=#f5ead8, onSurface=#201e1d, outline=#201e1d@16%。ダークモードは要件 (未設計) — トーンランプの反転を前提に別途確認。

## Screens / Views

### 1. ホーム「とった記録」(初期画面)
- 月切替ヘッダー: 左右に34px円形ゴーストボタン (chevron)、中央「2026年8月」19px w800 + 下に「AUGUST 2026」10.5px letter-spacing .06em
- 収支サマリー (1行カード, surface #f9f4ed, radius 28, padding 14×18, shadow-sm): 支出 (ラベル10px + ¥金額21px w800 tnum) を主、右に収入・残り (12px w700、残りはsage-700)、右端28px円形ボタン (chevron) → レポートへ
- 重複候補バナー (条件表示): sage-100地 + sage-300枠、radius 16。「重複の可能性が1件あります / Possible duplicate — tap to review」→ 重複確認画面へ
- セクション行:「とった記録 Captures」15px w800 + 右にスキャン残量チップ (accent-100地 / accent-700文字、ピル)「スキャン残り3回 · 3 left」→ タップでペイウォール
- **キャプチャグリッド (主役)**: 3列、gap 12×8。各セル = 元画像サムネイル (aspect 3:4, radius 16, 枠divider) + 左上に日付バッジ (8/16、ピル、bg地色) + 下に金額12px w700・店名9.5px ellipsis。出所により表現差: レシート=カメラアイコン、スクショ=画像アイコン(sage系)、手動=¥のみのタイル。タップ → 明細詳細。除外済みは opacity 0.45
- 新規登録時はグリッド先頭にスライドイン

### 2. タブバー (全タブ画面共通)
ホーム / 明細 / [カメラFAB] / レポート / 設定。ラベル9.5px w700、アクティブ=accent-700、非アクティブ=neutral-600。中央FAB: 58px円、primary地、地色4px縁、上に34pxはみ出す、shadow-md。押下でscale縮小+色deepen。残スキャン0 かつ 無料プランなら FAB はペイウォールを開く。

### 3. 取込フロー
1. **ボトムシート「記録する Add a record」**(radius 28上のみ、kk-pop 250ms ease-out): 3行 — カメラで撮影 (accent-100地、42px円primaryアイコン) / 写真・スクショから選ぶ (sage系) / 手動で入力 (¥)。下部に残量表示
2. **カメラ**: neutral-900全面。上部✕とタイトル、中央に250×420の破線ガイド枠「レシートを枠内に」、下部に写真選択ボタンとシャッター (74px白円 + 5px縁、押下scale 0.92)
3. **シャッター演出**: 白フラッシュ120–240ms + シャッター音 + 軽ハプティクス (日本のiOSは消音不可仕様に準拠)
4. **AI解析中**: クリーム全面。96px accent-200円 (pulse 1.4s) 内にスパークル。ステップ文言を約950ms間隔で切替:「画像を読み込んでいます → 金額・日付を読み取っています → カテゴリを推定しています」+ 3ドット進捗 + シマースケルトン3行。2秒未満で終わる場合は中間ステップをスキップ。失敗時は手動入力へ誘導
5. **読み取り確認**: 元画像サムネ (92×120) + sage-100の説明カード「読み取りに使った元画像は、明細からいつでも見返せます」。編集可能フィールド: 店名 / 金額 (16px w800) / 日付 / カテゴリ (チップ単一選択: 食費・外食・日用品・交通・サブスク・その他。選択=neutral-900地×地色文字) / **自動タグ** (sage-100チップ、例「三軒茶屋 · 位置情報」「コンビニ」+ 注記「写真の位置情報・店名・サービス名から自動で付きます」)。主ボタン「登録する · Register」(primaryピル) + ゴースト「取り直す」
6. **登録完了**: sage-700トースト (下部100px、ピル)「カシャッと記録!Logged ✓」等の褒め文言をローテーション、2.4sで消える。ホームへ戻りグリッド先頭に追加、残量-1
- 共有Extension経由も 5. の確認画面に合流する

### 4. 明細詳細
金額 (34px w800 tnum) → 店名 (15px w700) → 日付・カテゴリ (11px) → **元画像** (高さ170px, radius 28, 右下「拡大 · Zoom」ピル) + 注記「元画像はいつでも確認できます」。情報カード: 出所 (「自動取込 AI」/「手動入力 Manual」チップ) / タグ (「三軒茶屋 · コンビニ」) / 計算対象から除外 (スイッチ 44×26、ON=sage-500)。フッター: 保存 (primary) + 削除 (アウトライン、accent-800文字)。手動入力明細は画像プレースホルダーに「no image · 手動入力のため元画像なし」。

### 5. 重複候補の確認
説明文 → レシート側カード (鳥貴族 三軒茶屋店 / 8/10 / ¥4,230) → 中央に「≒ 金額と日付が一致 · Same amount & date」(sage-700) → カード明細側カード (楽天カード明細 (トリキ))。主ボタン「1件にまとめる · Merge」/ 副「別々の支出として残す · Keep both」。マージ時は元画像を両方保持。検知ロジック: 金額+日付 (±数日) 一致。

### 6. 手動入力
金額最優先 (¥ + 36px w800 の数値入力、numeric)。店名/メモ、カテゴリチップ、日付 (デフォルト今日)。「登録する」。スキャン残量は消費しない。金額未入力なら「金額を入力してください」トースト。

### 7. 明細タブ
日付グループ (「8月16日 (日) · Today」10.5px w600) のリスト。行 = 店名13.5px w600 + サブ行「カテゴリ EN · 出所 · タグ…」10.5px + 右端金額 w700 tnum。ヘッダー右に「絞り込み」ボタン (funnelアイコン、フィルタ適用中は accent-100地/accent-700文字)。**フィルタはボトムシート**: 取込元 (すべて/レシート/スクショ/手動) + タグ (すべて + データ由来: 楽天カード, PayPay, Amazon, モバイルSuica, 三軒茶屋, 桜新町, コンビニ, スーパー, ドラッグストア) の単一選択チップ2セクション + 「クリア」/「完了 Done · n件」。適用中はリスト上部に「絞り込み中: … クリア」。

### 8. レポート
「2026年8月の支出」+ 合計 (34px w800)。カテゴリ横棒 (額降順、grid 64px/1fr/66px、バー16pxピル、色: 食費=accent-500, 外食=accent-400, 日用品=sage-500, 交通=sage-400, サブスク=neutral-400、幅は最大カテゴリ比%)。下に「CSVで書き出す Export CSV — 確定申告・経費精算に。元画像もまとめて保存できます」行 (この文言は実装時にそのまま採用しない。[ADR 0002](../documents/adr/0002-denshi-choubo-hozon-hou-out-of-scope.md) の制約に従い、集計データの書き出しの範囲の表現に改める)。**節約アドバイスや評価コメントは置かない** (明示的な要件)。

### 9. ペイウォール
✕ → 72pxスパークル円 → 見出し「スキャン、し放題に。/ Go unlimited with Premium」(22px w800) → 無料枠バー「今月の無料スキャン n/10」(accent-500) → 特典3点 (✓sageチップ: スキャン無制限 / 全期間の履歴 / 今後の新機能) → 料金2カード: 月額¥480 / **年額¥3,800 (推奨: accent枠 + accent-100地 + 上部バッジ「2ヶ月分お得 · Save 34%」、¥317/月換算)** → CTA「プレミアムを始める」→ 「いつでも解約できます · 購入の復元」。トリガー: 残量チップ / 設定のプラン行 / 残量0でのFAB。

### 10. 設定
最上部に**バックアップカード** (sage-100地+sage-300枠, radius 28):「バックアップ + 未設定バッジ」「アカウントをリンクすると、機種変更してもデータが引き継げます」+ 「 Appleでリンク」(neutral-900地) / 「G Googleでリンク」(アウトライン) — 匿名認証→アカウントリンクの導線。以下: プラン行 (→ペイウォール)、通知、言語、利用規約、プライバシーポリシー、最下部に「アカウントを削除」(accent-800テキスト)。

## Interactions & Behavior
- 遷移/シート: 200–250ms ease-out (シートは下からスライド kk-pop 相当)。ホバー/押下: primaryは600/700段、ゴーストはaccent 10%/18% tint、行は neutral-200
- 解析中インターバル ~950ms/ステップ、フラッシュ 240ms、トースト 2.4s 自動消滅
- 除外トグルは合計・レポートへ即時反映 (行は opacity 0.45)
- 状態: 現在タブ / オーバーレイ (取込step, 詳細id, 重複, ペイウォール, 手動, フィルタ) / 明細配列 / 除外set / フィルタ (出所, タグ) / 残スキャン数 / プレミアムflag / dup解決flag

## State Management (実装指針)
明細エンティティ: `{id, date, storeName, category, source(receipt|screenshot|manual), amountJpy, tags[], imageRef?, excluded}`。自動タグは取込時に生成 (サービス名はスクショUI推定、位置情報は写真EXIF、店種は店名から)。無料枠: 月10スキャン、手動入力は非消費。重複検知は登録時に金額+日付一致で候補作成。

## i18n
プロトタイプは日英併記だが、実装は locale 切替 (ja / en)。英語で文字列が約1.5倍に伸びても破綻しないこと: 行は Flex + gap、金額は右端固定、ラベル折返し許容。語彙は「元画像 / source image」(receipt に限定しない。レシート文脈のみ receipt)。

## Assets
- フォント: Figtree (Google Fonts) + 和文ゴシック
- アイコン: Lucide (stroke 2.75): camera, image, home, list, bar-chart-2, sliders-horizontal, chevron-left/right, copy, filter(funnel), sparkle(菱形)
- 画像はすべてプレースホルダー。実装では実キャプチャのサムネイルを使用

## Files
- `Kashakeibo Prototype.dc.html` — 全画面タップ遷移プロトタイプ (正)
- `Design Options.dc.html` — 3方向比較と改訂の経緯
- `Kashakeibo Handoff.dc.html` + `doc-page.js` — 印刷用引き継ぎ書
- `_ds/organic-dc1d89a9-d628-41b7-996e-f57cf805588b/styles.css` — トークン原本 (CSS変数)
