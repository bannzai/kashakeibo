# App Store スクリーンショット生成

Flutter の widget test でストア掲載用の最終画像を描画する。シミュレータや Firebase 接続は不要。
Flutter の PNG エンコーダーが付与する alpha チャンネルは、macOS 標準の CoreGraphics/ImageIO を使う `strip_png_alpha.swift` で除去する。

## 生成物

- スクリーンショット: 1290×2796 px、PNG、日本語・英語それぞれ5枚
- Product Page Header: 3840×1646 px、PNG、日本語・英語

スクリーンショットの中間生成物は `scripts/generate_screenshots/artifacts/{lang}/`、fastlane からアップロードする最終画像は `fastlane/screenshots/{lang}/` に置く。Product Page Header は `fastlane/creative_assets/product_page_header/` に置く。

## 全言語・全ページを生成

```sh
./scripts/generate_screenshots/generate_appstore_screenshots.sh
./scripts/generate_screenshots/generate_header_creatives.sh
```

## 1言語・1ページで確認

```sh
./scripts/generate_screenshots/generate_appstore_screenshots.sh -l ja -n 1
./scripts/generate_screenshots/generate_header_creatives.sh -l ja
```

`fastlane/screenshots/` への配置後は、既存 lane からメタデータと一緒にアップロードできる。

```sh
bundle exec fastlane ios metadata_upload
```

## スクリプトの責務

- `appstore_screenshot_env.sh`: 対象言語・ページ・出力先・共通関数
- `generate_appstore_screenshots.sh`: Flutter 描画テストの起動と fastlane 配置の統括
- `organize_screenshots.sh`: artifacts から fastlane 形式への配置
- `generate_header_creatives.sh`: Product Page Header の描画と配置
- `strip_png_alpha.swift`: PNG の寸法と見た目を保ったまま alpha チャンネルを除去
