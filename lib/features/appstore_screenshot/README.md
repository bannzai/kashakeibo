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

日本語と英語、6.9インチ iPhone・13インチ iPad・iPhone Duo (外側ディスプレイ・内側ディスプレイ) をそれぞれ独立した画像として生成する。

iPhone Duo の内側ディスプレイは Apple の仕様が縦 (2007×2853) と横 (2853×2007) の両方を受け付けるうち、横で生成する。開いた端末を持つ向きに合わせるためで、横長の画面では縦組みが成立しないので、左に訴求文・右に端末モックを置く横向きのレイアウトを使う。外側ディスプレイは 6.9インチ iPhone の縦組みを、短い縦寸法に合わせて端末モックを縮めた比率違いとして作る。App Store アプリが内側で縦・横の画像をどう見せるかは実機が無く未確認で、実機で見た結果が食い違ったら向きを見直す。
撮影環境で OS の日本語フォントへ依存しないよう、Google Fonts の Noto Sans JP を掲載文言に限定してサブセット化した `assets/fonts/NotoSansJP-AppStoreSubset.ttf` を使用する。キャッチコピーやモック画面内の日本語を変更する場合は、追加文字を含めてサブセットを再生成する。ライセンスは `assets/fonts/NotoSansJP-OFL.txt`。

サブセットの再生成は、Noto Sans JP Regular の元フォントを用意し、`appstore_screenshot.dart` 内の全非 ASCII 文字を対象に fontTools で行う (収録漏れは `flutter test` のフォント検査が検出する):

```sh
mkdir -p tmp
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
4. iPhone Duo は `scripts/generate_screenshots/generate_iphone_duo_screenshots.sh` が別に起動し、外側 466×678 logical px・内側 951×669 logical px を3倍で画像化して `scripts/generate_screenshots/artifacts_iphone_duo/{lang}/{iphone_duo_outer,iphone_duo_inner}/` へ書き出す。fastlane deliver が受理しない寸法のため `fastlane/screenshots/` へは配置しない (経路は `scripts/generate_screenshots/README.md`)。
5. Product Page Header は 1920×823 logical px の Widget を2倍で画像化し、Apple 公式テンプレートの 3840×1646 px に合わせる。

## データ形式

- iPhone スクリーンショット: PNG、1290×2796 px、`ja` / `en-US`、各5枚
- iPad スクリーンショット: PNG、2048×2732 px、`ja` / `en-US`、各5枚
- iPhone Duo 外側スクリーンショット: PNG、1398×2034 px、`ja` / `en-US`、各5枚
- iPhone Duo 内側スクリーンショット: PNG、2853×2007 px (横)、`ja` / `en-US`、各5枚
- Product Page Header: PNG、3840×1646 px、`ja` / `en-US`
- キャッチコピー: `appStoreScreenshotCopy` のスクリーンショット専用静的辞書

## 有効期限・制約

- App Store スクリーンショット用の固定データであり、本番の取引データには接続しない。
- Product Page Header のキーコンテンツは、Apple 公式テンプレートから実測した Art Safe Area 内に配置する。
- Apple がテンプレートを更新した場合は、`appstore-header-creative` スキルで canvas と Art Safe Area を再確認する。
