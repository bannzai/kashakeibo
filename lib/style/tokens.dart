import 'package:flutter/material.dart';

/// デザイントークンの色定義。
/// 原本は design_handoff_kashakeibo/_ds/organic-*/styles.css (CSS 変数) で、
/// 本ファイルはその Dart 転写。値を変える時は原本側と揃えること。
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

  static const Color sage100 = Color(0xFFF0FAE1);
  static const Color sage200 = Color(0xFFE1EECC);
  static const Color sage300 = Color(0xFFCCDBB2);
  static const Color sage400 = Color(0xFFAEBF92);
  static const Color sage500 = Color(0xFF8FA073);
  static const Color sage700 = Color(0xFF56633F);
  static const Color sage800 = Color(0xFF3D472B);
}

/// shadow-sm (`0 1px 2px #2e2b25 @14%`) の Dart 転写。
const List<BoxShadow> appShadowSm = [
  BoxShadow(color: Color(0x242E2B25), offset: Offset(0, 1), blurRadius: 2),
];
