# App Store スクリーンショット生成

Flutter の widget test でストア掲載用の最終画像を描画する。シミュレータや Firebase 接続は不要。
Flutter の PNG エンコーダーが付与する alpha チャンネルは、macOS 標準の CoreGraphics/ImageIO を使う `strip_png_alpha.swift` で除去する。

## 生成物

- iPhone スクリーンショット: 1290×2796 px、PNG、日本語・英語それぞれ5枚
- iPad スクリーンショット: 2048×2732 px、PNG、日本語・英語それぞれ5枚
- iPhone Duo 外側ディスプレイ: 1398×2034 px、PNG、日本語・英語それぞれ5枚
- iPhone Duo 内側ディスプレイ: 2853×2007 px (横)、PNG、日本語・英語それぞれ5枚
- Product Page Header: 3840×1646 px、PNG、日本語・英語

スクリーンショットの中間生成物は `scripts/generate_screenshots/artifacts/{lang}/`、fastlane からアップロードする最終画像は `fastlane/screenshots/{lang}/` に置く。Product Page Header は `fastlane/creative_assets/product_page_header/` に置く。

iPhone Duo の画像だけは `scripts/generate_screenshots/artifacts_iphone_duo/{lang}/iphone_duo_outer/` と `.../iphone_duo_inner/` に置き、`fastlane/screenshots/` へは配置しない。fastlane deliver は画像の px 寸法で表示クラスを判定するため、寸法表に無い Duo の画像を同じディレクトリに置くとアップロード全体が検証で止まる (master の `deliver/lib/deliver/app_screenshot.rb` の `DEVICE_RESOLUTIONS` を 2026-10-14 に確認し、1398×2034・2853×2007 とその縦横逆のどれも無く、`DUO` を含むキーも無い。寸法が合わない時の挙動は appstore-screenshot-builder skill の `references/iphone-duo.md` の 2026-10-12 の調査で、`deliver/lib/deliver/app_screenshot_validator.rb` が「Screenshot size is not supported」で弾くと記録されている)。

## 全言語・全ページを生成

```sh
./scripts/generate_screenshots/generate_appstore_screenshots.sh
./scripts/generate_screenshots/generate_iphone_duo_screenshots.sh
./scripts/generate_screenshots/generate_header_creatives.sh
```

## 1言語・1ページで確認

```sh
./scripts/generate_screenshots/generate_appstore_screenshots.sh -l ja -n 1
./scripts/generate_screenshots/generate_iphone_duo_screenshots.sh -l ja -n 1
./scripts/generate_screenshots/generate_header_creatives.sh -l ja
```

`fastlane/screenshots/` への配置後は、既存 lane からメタデータと一緒にアップロードできる。

```sh
fastlane ios metadata_upload
```

## iPhone Duo の画像を App Store Connect へ上げる

iPhone Duo は fastlane deliver で上げられないため、`artifacts_iphone_duo/{lang}/` の 10 枚 (外側 5 枚 + 内側 5 枚) を別経路で上げる。外側と内側は App Store Connect 上で 1 つの iPhone Duo の枠 (最大 10 枚) に入り、並び順はアップロードした順になる (appstore-screenshot-builder skill の `references/iphone-duo.md` に 2026-10-12 時点の調査を記録。App Store 上での見え方は実機が無く未確認)。本リポジトリで採用する並び順は、外側の 01 → 05、次に内側の 01 → 05 とする。ディレクトリを表示側で分けているのは、`asc` がディレクトリ内をファイル名順に上げるため、外側のディレクトリ → 内側のディレクトリの順に 2 回実行すればこの並びになるようにするため。

- CLI: `asc` (rorkai/App-Store-Connect-CLI) 5.12.0 以降が表示タイプ `APP_IPHONE_DUO` を受け付ける (同 reference の記録。内側の 2 寸法をサーバが受理するかは同 reference でも未確認)。言語ごとに外側 → 内側の順で実行する

  ```sh
  asc screenshots upload --version-localization <LOCALIZATION_ID> --path scripts/generate_screenshots/artifacts_iphone_duo/<lang>/iphone_duo_outer --device-type APP_IPHONE_DUO --skip-existing
  asc screenshots upload --version-localization <LOCALIZATION_ID> --path scripts/generate_screenshots/artifacts_iphone_duo/<lang>/iphone_duo_inner --device-type APP_IPHONE_DUO --skip-existing
  ```

- Web UI: App Store Connect のバージョンの「iPhone Duo」の枠へ、上記の並び順でドラッグする (未検証。画面の構成は Apple の Screenshot specifications https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications を参照)

## スクリプトの責務

- `appstore_screenshot_env.sh`: 出力先の共通定義
- `generate_appstore_screenshots.sh`: Flutter 描画テストの起動と fastlane 配置の統括 (iPhone・iPad)
- `generate_iphone_duo_screenshots.sh`: iPhone Duo の描画テストの起動と、sips による寸法・alpha・枚数の検査 (fastlane へは配置しない)
- `organize_screenshots.sh`: artifacts から fastlane 形式への配置
- `generate_header_creatives.sh`: Product Page Header の描画と配置
- `strip_png_alpha.swift`: PNG の寸法と見た目を保ったまま alpha チャンネルを除去
