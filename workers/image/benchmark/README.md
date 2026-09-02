# 実レシートベンチマーク

明細抽出 (POST /analyses) の品質が安定しているかを継続的に確かめるための、実物のレシート画像による回帰ベンチマーク (issue #50/#51 の原価・モデル切替の検証から派生)。モデル・プロンプト・generationConfig を変更した時は、合成テスト画像 (`scripts/generate-analysis-fixtures.py`) に加えて本ベンチマークを実行し、基準値からの劣化がないことを確認する。

## 実行

```sh
cd workers/image
FIXTURES_DIR=benchmark node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.5-flash-lite-baseline
```

出力の `measurement-results.json` は実行ごとの生成物のためコミットしない (.gitignore 済み)。

## 基準値 (2026-09-01 実測)

| 構成 | 全項目一致 | 平均原価/スキャン |
| --- | --- | --- |
| gemini-3.1-flash-lite (旧採用) | 14/15 | 約 ¥0.070 |
| gemini-3.5-flash-lite (採用) | **15/15** | 約 ¥0.090 |
| gemini-3.7-flash | **15/15** | 約 ¥0.292 |
| gemini-3.1-flash-lite + mediaResolution low | 8/8 (8枚時点) | 約 ¥0.040 |

判定は店名・摘要 (titleAliases 許容)・金額・取引日・収支・カテゴリ (categoryAliases 許容)・件数の全一致 (`scripts/measure-analysis-cost.mjs`)。「合計 vs お釣り・お預り」(maxvalu: 合計¥246 に対しお釣り¥254、mcdonalds: お預り¥1,000、okinawa_family: お預り¥10,000)、支払方法行「交通系 ¥357」(cascade)、伝票形式 (ohsho)、交通系領収証 (monorail / jreast)、金券ショップで飲食店の商品券を買うケース (igami: 品目に「吉野家」が出るが店は切手社 → other)、手持ち斜め撮影・高額 (okinawa_bbq: ¥16,126)、2007年の古い印字 (viedefrance)、店名と日付が読めないピンぼけ・20品目超の長尺レシート (blurred_long_supermarket)、Amazon.co.jp 注文支出ダッシュボードの実画面スクリーンショット (サンプル注文データ、amazon_jp_order_dashboard) を含む。

2026-09-03 のプロンプト更新 (issue #82: 背景の映り込みの無視・1 画像内の複数レシート・分割紙片の扱い・EC 購入履歴の title を商品名にする規則を追記) 後の再実測では、採用構成 (gemini-3.5-flash-lite) は全項目一致 13〜15/15・約 ¥0.098〜0.102/スキャン (プロンプト追記ぶん入力トークンが約 200 増。複数回実行)。不一致はいずれも難例の店名表記の揺れ (ohsho のロゴ誤読・maxvalu のかすれ印字) のみで、金額・取引日・収支・カテゴリ・件数は全実行で全画像一致。issue #82 のケース自体は合成フィクスチャ (`scripts/generate-analysis-fixtures.py` の `receipt_two_receipts.jpg` / `receipt_same_store_two_receipts.jpg` / `receipt_with_card_slip.jpg` / `receipt_split_long.jpg`) で検証する (8 枚 × 3 回実行で 24/24 全項目一致)。

3.1はピンぼけ画像の読めない店名を「スーパーマーケット」と推測して14/15、3.5と3.7は空文字で返して15/15だった。3.5と3.7の合格数に差がなく、3.7は3.5の約3.2倍の原価で2027-01-01に単価がさらに倍増するため、プレミアム向け上位モデルは採用しない (issue #58)。3.1は最短2027-05-07の廃止予定に備えて、精度が維持された3.5へ切り替える (issue #61)。

## 正解データ (ground-truth.json)

- 形式は合成テスト画像と同じ (`AnalyzedTransaction` と同形)。追加フィールド:
  - `titleAliases`: レシート上に併記される別表記 (ローマ字ロゴとカタカナ店名など)。いずれかに一致すれば店名正解
  - `categoryAliases`: 正解が一意に決まらない境界ケースの許容カテゴリ (例: ベーカリー cascade は food / eatingOut の両方を正解とする)
- 店名が人間にも読み取れない難例は `title` を空文字にする。抽出結果も空文字なら一致とし、根拠のない店名推測は不一致にする
- 正解の値はすべて画像の目視で作成した (出典ページの説明文ではなく印字を正とする)

## 画像の出典とライセンス

再配布可能な実レシート画像と、実装された注文履歴ダッシュボードのサンプルデータ画面。クライアントの撮影条件 (長辺 1600px / JPEG 品質 85、`lib/features/capture/capture_image_picker.dart`) に合わせて JPEG 化・縮小済み。原本・作者・ライセンスは次のとおり:

| ファイル | 内容 | 出典 | 作者 | ライセンス |
| --- | --- | --- | --- | --- |
| lawson_convenience.jpg | ローソン (コンビニ) ¥103 | https://commons.wikimedia.org/wiki/File:Lawson_Naha_Makishi_Park_Front_Store_receipt_JPY103_20191112.jpg | Solomon203 | CC BY-SA 4.0 |
| maxvalu_supermarket.jpg | マックスバリュ (スーパー) ¥246 | https://commons.wikimedia.org/wiki/File:MaxValu_Matsuyama_Store_receipt_JPY254_20191109.jpg | Solomon203 | Public domain |
| camelmart_convenience.jpg | キャメルマート (コンビニ) ¥697 | https://commons.wikimedia.org/wiki/File:Receipt_of_CamelMart_220917.jpg | Yauchi | CC BY-SA 4.0 |
| mcdonalds_fastfood.jpg | マクドナルド (ファストフード) ¥400 | https://commons.wikimedia.org/wiki/File:McDonalds-Kanayama-Receipt.jpg | HQA02330 | CC BY-SA 4.0 |
| sugakiya_ramen.jpg | スガキヤ (ラーメン) ¥330 | https://commons.wikimedia.org/wiki/File:Receipt-Sugakiya-Osu-Akamon-Nagoya.jpg | HQA02330 | CC BY-SA 4.0 |
| ohsho_restaurant.jpg | 餃子の王将 (伝票形式) ¥2,033 | https://commons.wikimedia.org/wiki/File:JP_%E6%97%A5%E6%9C%AC_Japan_%E4%BA%AC%E9%83%BD%E5%B8%82Kyoto_%E4%B8%AD%E5%8D%8E%E6%96%99%E7%90%86%E5%BA%97_%E9%A4%83%E5%AD%90%E3%81%AE%E7%8E%8B%E5%B0%86_Gyoza_no_Ohsho_Japanese_Chinese_restaurant_chain_Receipt_in_June_2026_N13P_01.jpg | TKdows 2026 | CC0 |
| monorail_transport.jpg | ゆいレール領収証 (交通) ¥230 | https://commons.wikimedia.org/wiki/File:Okinawa_Monorail_receipt_issuing_from_Omoromachi_Station_65313_20191111.jpg | Solomon203 | CC BY-SA 4.0 |
| cascade_bakery.jpg | Cascade (ベーカリー) ¥357 | https://commons.wikimedia.org/wiki/File:A-Receipt-Cascade-bakery.jpg | HQA02330 | CC BY-SA 4.0 |
| igami_stamps.jpg | 伊神切手社 (金券ショップ) ¥520 | https://commons.wikimedia.org/wiki/File:Igami-Kitte-sha-Osu-Receipt.jpg | HQA02330 | CC BY-SA 4.0 |
| okinawa_family_restaurant.jpg | ケンミン食堂 (食堂) ¥4,130 | https://commons.wikimedia.org/wiki/File:JP_%E6%97%A5%E6%9C%AC_Japan_%E6%B2%96%E7%B9%A9_OKINAWA_Family_Cuisine_Restaurant_January_2025_R12S_01.jpg | Naha Mama Pavilionz | CC0 |
| okinawa_bbq_restaurant.jpg | 焼肉 琉球の牛 (焼肉) ¥16,126 | https://commons.wikimedia.org/wiki/File:JP_%E6%97%A5%E6%9C%AC_Japan_%E6%B2%96%E7%B9%A9_OKINAWA_%E7%87%92%E8%82%89%E7%90%89%E7%90%83%E4%B9%8B%E7%89%9B_Beef_BBQ_Restaurant_January_2025_R12S_01.jpg | Naha Mama Pavilionz | CC0 |
| viedefrance_bakery.jpg | ヴィドフランス (ベーカリー・2007年) ¥147 | https://commons.wikimedia.org/wiki/File:Kofu_-_Vie_de_France_L%27adition_(1471241442).jpg | Charlotte Marillet | CC BY-SA 2.0 |
| jreast_ticket_machine.jpg | JR東日本 券売機領収証 (交通) ¥160 | https://commons.wikimedia.org/wiki/File:Receipt_issued_by_JR_East_from_a_ticket_machine_in_Shinkiba_Station.jpg | 不明 (Public domain) | Public domain |
| blurred_long_supermarket.jpg | 店名・日付が読めないピンぼけ・20品目超のスーパー長尺レシート ¥9,402 | https://commons.wikimedia.org/wiki/File:%E3%83%AC%E3%82%B7%E3%83%BC%E3%83%88_2011_(5605505961).jpg | Kiwamu Okabe | CC BY-SA 2.0 |
| amazon_jp_order_dashboard.jpg | Amazon.co.jp 注文支出ダッシュボードの実画面スクリーンショット (サンプル注文データ) ¥4,911 | https://github.com/HanaCROOK/amazon-jp-orders-dashboard/blob/0b4986810c490e1c3baeddc0df11fa438a49bd3f/docs/assets/dashboard-demo.png | Amazon JP Orders Dashboard contributors | MIT |

- CC BY-SA の画像はそれぞれ上記ライセンスのまま再配布する (本リポジトリのコードのライセンスとは独立)。改変内容は上記の JPEG 化・縮小のみ
- Amazon JP Orders Dashboard のスクリーンショットは同リポジトリの MIT License で再配布する。ライセンス全文は `licenses/amazon-jp-orders-dashboard-MIT.txt`
- 個人情報は含まない (店舗情報のみ。camelmart は出典時点で住所・電話番号の一部が黒塗り済み)
- 追加する時は、再配布可能なライセンス (CC BY / CC BY-SA / CC0 / Public domain / MIT 等) であることと出典・作者をこの表に記録し、画像を目視して正解データを作る
