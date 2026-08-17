# App Store スクリーンショット

## 概要

App Store 掲載用のスクリーンショットと Product Page Header を、Flutter Widget から再現可能に生成する。背景、キャッチコピー、コード描画のデバイスフレーム、アプリ画面風 UI を1つの Widget で構成し、Firebase やネットワークへ接続せず固定データだけで描画する。

## 画面

- 1枚目: スクリーンショットやレシートを AI が明細へ変換する中心価値
- 2枚目: レシート撮影
- 3枚目: レシートとカード明細の重複検知
- 4枚目: 明細と元画像の紐付け
- 5枚目: 口座連携なしで確認できる月次集計
- Product Page Header: 「撮った瞬間、家計簿になる」という1つのアイデア

日本語と英語、6.9インチ iPhone と13インチ iPad をそれぞれ独立した画像として生成する。
撮影環境で OS の日本語フォントへ依存しないよう、Google Fonts の Noto Sans JP を掲載文言に限定してサブセット化した `assets/fonts/NotoSansJP-AppStoreSubset.ttf` を使用する。キャッチコピーやモック画面内の日本語を変更する場合は、追加文字を含めてサブセットを再生成する。ライセンスは `assets/fonts/NotoSansJP-OFL.txt`。

サブセットの再生成は、Noto Sans JP Regular の元フォントを用意し、`appstore_screenshot.dart` 内の全非 ASCII 文字を対象に fontTools で行う (収録漏れは `flutter test` のフォント検査が検出する):

```sh
python3 - <<'EOF'
import re
src = open('lib/features/appstore_screenshot/appstore_screenshot.dart', encoding='utf-8').read()
chars = sorted({ch for m in re.finditer(r"'((?:\\.|[^'\\])*)'", src) for ch in m.group(1) if ord(ch) > 0x7f})
open('tmp/subset_unicodes.txt', 'w').write(','.join(f'U+{ord(c):04X}' for c in chars))
EOF
python3 -m fontTools.subset <NotoSansJP-Regular.ttf のパス> \
  --unicodes-file=tmp/subset_unicodes.txt \
  --output-file=assets/fonts/NotoSansJP-AppStoreSubset.ttf \
  --layout-features='*' --glyph-names --notdef-outline
```

## フロー

1. `scripts/generate_screenshots/generate_appstore_screenshots.sh` が生成テストを起動する。
2. iPhone は430×932 logical px を3倍、iPad は1024×1366 logical px を2倍で画像化し、Apple が受理する PNG を artifacts へ書き出す。
3. 生成スクリプトが PNG を `fastlane/screenshots/{lang}/` へ配置する。
4. Product Page Header は 1920×823 logical px の Widget を2倍で画像化し、Apple 公式テンプレートの 3840×1646 px に合わせる。

## データ形式

- iPhone スクリーンショット: PNG、1290×2796 px、`ja` / `en-US`、各5枚
- iPad スクリーンショット: PNG、2048×2732 px、`ja` / `en-US`、各5枚
- Product Page Header: PNG、3840×1646 px、`ja` / `en-US`
- キャッチコピー: `appStoreScreenshotCopy` のスクリーンショット専用静的辞書

## 有効期限・制約

- App Store スクリーンショット用の固定データであり、本番の取引データには接続しない。
- Product Page Header のキーコンテンツは、Apple 公式テンプレートから実測した Art Safe Area 内に配置する。
- Apple がテンプレートを更新した場合は、`appstore-header-creative` スキルで canvas と Art Safe Area を再確認する。
