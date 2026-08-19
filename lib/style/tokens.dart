import 'package:flutter/material.dart';

/// デザイントークンの色定義 (ライトテーマの原本値)。
/// 原本は design_handoff_kashakeibo/_ds/organic-*/styles.css (CSS 変数) で、
/// 本ファイルはその Dart 転写。値を変える時は原本側と揃えること。
///
/// 画面のコードからは本クラスを直接参照せず、ライト / ダークで切り替わる
/// [AppColorScheme] (lib/style/app_theme.dart) を `context.appColors` 経由で使う。
/// 本クラスを直接参照してよいのは、テーマ定義 (app_theme.dart) と、
/// 常にライト配色で描画する App Store スクリーンショット素材だけ。
abstract class AppColors {
  /// 画面の地色 (クリーム)。
  static const Color background = Color(0xFFF5EAD8);

  /// 本文・見出しの文字色。
  static const Color onSurface = Color(0xFF201E1D);

  /// 区切り線・枠線 (onSurface の 16%)。
  static const Color divider = Color(0x29201E1D);

  /// primary (テラコッタ)。
  static const Color primary = Color(0xFFC67139);

  /// primary 上の文字色。
  static const Color onPrimary = Color(0xFFF5EAD8);

  /// secondary (セージ)。
  static const Color secondary = Color(0xFF7A8A5E);

  static const Color neutral100 = Color(0xFFF9F4ED);
  static const Color neutral200 = Color(0xFFEEE7DB);
  static const Color neutral300 = Color(0xFFDCD3C4);
  static const Color neutral400 = Color(0xFFC0B6A5);
  static const Color neutral500 = Color(0xFFA19786);
  static const Color neutral600 = Color(0xFF82796A);
  static const Color neutral700 = Color(0xFF645C50);
  static const Color neutral800 = Color(0xFF474238);
  static const Color neutral900 = Color(0xFF2E2B25);

  static const Color accent100 = Color(0xFFFFF2EB);
  static const Color accent200 = Color(0xFFFFE1D0);
  static const Color accent300 = Color(0xFFFFC6A5);
  static const Color accent400 = Color(0xFFF6A06B);
  static const Color accent500 = Color(0xFFD67F48);
  static const Color accent600 = Color(0xFFB2622D);
  static const Color accent700 = Color(0xFF8C491A);
  static const Color accent800 = Color(0xFF643312);
  static const Color accent900 = Color(0xFF402310);

  static const Color sage100 = Color(0xFFF0FAE1);
  static const Color sage200 = Color(0xFFE1EECC);
  static const Color sage300 = Color(0xFFCCDBB2);
  static const Color sage400 = Color(0xFFAEBF92);
  static const Color sage500 = Color(0xFF8FA073);
  static const Color sage600 = Color(0xFF728157);
  static const Color sage700 = Color(0xFF56633F);
  static const Color sage800 = Color(0xFF3D472B);
  static const Color sage900 = Color(0xFF272E1B);
}

/// shadow-sm (`0 1px 2px #2e2b25 @14%`) の Dart 転写。
const List<BoxShadow> appShadowSm = [
  BoxShadow(color: Color(0x242E2B25), offset: Offset(0, 1), blurRadius: 2),
];

/// shadow-md (`0 3px 10px #2e2b25 @16%`) の Dart 転写。
const List<BoxShadow> appShadowMd = [
  BoxShadow(color: Color(0x292E2B25), offset: Offset(0, 3), blurRadius: 10),
];

/// shadow-lg (`0 12px 32px #2e2b25 @22%`) の Dart 転写。
const List<BoxShadow> appShadowLg = [
  BoxShadow(color: Color(0x382E2B25), offset: Offset(0, 12), blurRadius: 32),
];

/// 角丸トークン (design_handoff_kashakeibo/README.md の Shape)。
abstract class AppRadius {
  /// カード・バナー・明細行。
  static const double card = 16;

  /// 大カード (収支サマリー・バックアップカード)・ボトムシート・ダイアログ。
  static const double sheet = 28;

  /// ボタン・チップ・入力欄 (ピル)。
  static const double pill = 999;
}

/// 余白トークン。
///
/// 原本 CSS の `--space-*` (4.4px 基準) はプロトタイプ (正) では使われておらず、
/// プロトタイプは 4px 刻みの整数 px で組まれているため、その実測値を採用する。
/// カード内 padding のような部品固有の寸法 (14×18 等) は README の部品仕様に従い、
/// 本スケールへ丸めない。
abstract class AppSpacing {
  /// ラベルと値の間などの最小間隔。
  static const double xs = 4;

  /// チップ・ボタンの間隔。
  static const double sm = 8;

  /// カード・バナーの積み重ね間隔。
  static const double md = 12;

  /// カード内の要素グループ間・見出しと本文の間。
  static const double lg = 16;

  /// 画面左右の余白と、画面上部のヘッダー余白。
  static const double xl = 20;

  /// 空状態などの大きな余白。
  static const double xxl = 32;
}

/// 文字スタイルトークン (design_handoff_kashakeibo/README.md の Typography)。
///
/// 書体はテーマの fontFamily (Figtree) を継承するためここでは指定しない。
/// 色もテーマ (onSurface) を継承し、補助文言の色 (textMuted) は使う側で
/// [AppColorScheme] から与える。
abstract class AppTextStyles {
  /// 画面タイトル (19px w800)。
  static const TextStyle screenTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
  );

  /// セクション見出し (15px w800)。
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  /// 本文・行タイトル (13.5px w600)。
  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
  );

  /// 補助文言・日付見出し (10.5px)。
  static const TextStyle caption = TextStyle(fontSize: 10.5);

  /// タブラベル・バッジ (9.5px w700。補助 9.5px が下限)。
  static const TextStyle label = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
  );

  /// ボタン文言 (14px w700)。
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// 金額 (明細詳細 34px w800 tnum)。
  static const TextStyle amountLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 金額 (収支サマリー 21px w800 tnum)。
  static const TextStyle amountSummary = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.42,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 金額 (明細行 14px w700 tnum)。
  static const TextStyle amountRow = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 金額 (サマリーの副金額・内訳 12px w700 tnum)。
  static const TextStyle amountSub = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
