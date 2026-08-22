# 実レシートベンチマーク

明細抽出 (POST /analyses) の品質が安定しているかを継続的に確かめるための、実物のレシート画像による回帰ベンチマーク (issue #50/#51 の原価・モデル切替の検証から派生)。モデル・プロンプト・generationConfig を変更した時は、合成テスト画像 (`scripts/generate-analysis-fixtures.py`) に加えて本ベンチマークを実行し、基準値からの劣化がないことを確認する。

## 実行

```sh
cd workers/image
FIXTURES_DIR=benchmark node --experimental-strip-types scripts/measure-analysis-cost.mjs 3.1-flash-lite-baseline
```

出力の `measurement-results.json` は実行ごとの生成物のためコミットしない (.gitignore 済み)。

## 基準値 (2026-08-22 実測)

| 構成 | 全項目一致 | 平均原価/スキャン |
| --- | --- | --- |
| gemini-3.1-flash-lite (採用) | **8/8** | 約 ¥0.070 |
| gemini-3.1-flash-lite + mediaResolution low | 8/8 | 約 ¥0.040 |
| gemini-3.7-flash (旧採用) | 8/8 (7枚時点) | 約 ¥0.271 |

判定は店名 (titleAliases 許容)・金額・取引日・収支・カテゴリ (categoryAliases 許容)・件数の全一致 (`scripts/measure-analysis-cost.mjs`)。「合計 vs お釣り・お預り」(maxvalu: 合計¥246 に対しお釣り¥254、mcdonalds: お預り¥1,000)、支払方法行「交通系 ¥357」(cascade)、伝票形式 (ohsho)、交通系領収証 (monorail) などの取り違えやすいケースを含む。

## 正解データ (ground-truth.json)

- 形式は合成テスト画像と同じ (`AnalyzedTransaction` と同形)。追加フィールド:
  - `titleAliases`: レシート上に併記される別表記 (ローマ字ロゴとカタカナ店名など)。いずれかに一致すれば店名正解
  - `categoryAliases`: 正解が一意に決まらない境界ケースの許容カテゴリ (例: ベーカリー cascade は food / eatingOut の両方を正解とする)
- 正解の値はすべて画像の目視で作成した (出典ページの説明文ではなく印字を正とする)

## 画像の出典とライセンス

すべて Wikimedia Commons から取得した再配布可能な実レシート画像。クライアントの撮影条件 (長辺 1600px / JPEG 品質 85、`lib/features/capture/capture_image_picker.dart`) に合わせて縮小済み。原本・作者・ライセンスは次のとおり:

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

- CC BY-SA の画像はそれぞれ上記ライセンスのまま再配布する (本リポジトリのコードのライセンスとは独立)。改変内容は上記の縮小のみ
- 個人情報は含まない (店舗情報のみ。camelmart は出典時点で住所・電話番号の一部が黒塗り済み)
- 追加する時は、再配布可能なライセンス (CC BY / CC BY-SA / CC0 / Public domain 等) であることと出典・作者をこの表に記録し、画像を目視して正解データを作る
