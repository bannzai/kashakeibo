# App Store ヘッダー入稿素材

`header.jpg` は全言語共通の文字なし画像。訴求は「撮るだけで、ばらばらの支出がすっきり整理される」。白紙のレシート、抽象的なカメラ、整列した低い棒グラフで表現する。

## 設計の根拠

- `fastlane/metadata/ja/` の name・subtitle・description にある、スクショ・写真からの明細登録と月次集計を視覚化した。
- `lib/style/tokens.dart` の背景色・primary・secondary を生成プロンプトの配色に使い、`lib/style/app_theme.dart` の温かなトーンに合わせた。
- 文字・数字・実在サービスのロゴを使わず、多言語で共通利用する。価格・割引・受賞表示も含めない。

## 仕様と制作

- 入稿画像: JPEG、3840×1646、RGB、透過なし。
- Apple の公式 PSD を2026-09-09に取得・解析し、canvas と Art Safe Area（left=1097、top=493、right=2743、bottom=1154）を確認した。
- Gemini `gemini-3-pro-image-preview` に `prompt.txt` を渡し、21:9・4K指定で生成。生成結果は6336×2688。中央クロップと縮小後、`sips` の品質95でJPEGに変換した。
- AI生成素材のみを使用。実在サービスの画像・ロゴは使用していない。生成は確率的なため、同一プロンプトでも同一画像にはならない。

公式仕様・テンプレート配布元:
https://developer.apple.com/app-store/asset-best-practices/

## 検証

以下はリポジトリルートで実行する。中間画像は生成作業時のローカルファイル。

```sh
bash ~/.agents/skills/appstore-header-creative/scripts/fetch_template_spec.sh --type header --cache-dir ./tmp/appstore-header-creative
bash ~/.agents/skills/appstore-header-creative/scripts/normalize_asset.sh ./tmp/header-generated-v2.png ./tmp/header-normalized-v2.jpg --type header
sips -s format jpeg -s formatOptions 95 ./tmp/header-normalized-v2.jpg --out appstore/product-page-header/header.jpg
bash ~/.agents/skills/appstore-header-creative/scripts/check_header_asset.sh appstore/product-page-header/header.jpg --type header
bash ~/.agents/skills/pr-attach-screenshots/scripts/check-upload-target.sh appstore/product-page-header/header.jpg
```

2026-09-09実行: いずれも終了コード0。入稿検証の出力:

```text
[OK] フォーマット: jpeg
[OK] サイズ: 3840x1646
[INFO] Art Safe Area (実画像換算): left=1097 top=493 right=2743 bottom=1154 — キーコンテンツ・コピーはこの範囲内に収める
```

入稿検証は OK 2件、WARN 0件、NG 0件。公開前の機械検査も `mime=image/jpeg` で合格。最終JPEGを表示して、主要モチーフがセーフエリア内に余裕を持って収まること、文字・数字・実在ロゴ・秘匿情報がないこと、配色とトーンを確認した。

生成時にはSDKから `Models.generate_content` のAFC使用に関する推奨警告、正規化時には `sysctlbyname for kern.hv_vmm_present failed with status -1` が出た。両コマンドは正常終了し、最終JPEGの検証にも合格した。

アプリ実装の変更はないため、Flutterの解析・テスト・ビルドとアプリ内QAは対象外。App Store Connectの入稿先確認・アップロード・受理確認は依頼どおり未実施。

## セッション再開

```sh
cd /Users/bannzai/worktrees/bannzai/kashakeibo/appstore-header-creative
codex resume 01a08542-4804-75b2-8323-0bee13bf5a73
```
