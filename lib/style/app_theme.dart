import 'package:flutter/material.dart';
import 'package:kashakeibo/style/tokens.dart';

/// ライト / ダークで切り替わる意味付きの色トークン。
///
/// フィールド名は design_handoff_kashakeibo/README.md の Design Tokens (Colors) の
/// 名前をそのまま使い、画面のコードは `context.appColors.<名前>` で参照する。
/// ライトは [AppColors] の原本値。ダークはデザイン未設計 (README「トーンランプの
/// 反転を前提に別途確認」) のため、地色と文字色を入れ替え、neutral / accent / sage の
/// トーンランプを反転させて (100 ⇄ 900) 同じ段が地色からの距離を保つように定義する。
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  /// 画面の地色。
  final Color background;

  /// カード・シートの地色 (neutral-100)。
  final Color surface;

  /// カード内の一段沈んだ地色・バーのトラック (neutral-200)。
  final Color surfaceVariant;

  /// 本文・見出しの文字色。
  final Color onSurface;

  /// 補助文言の文字色 (neutral-600)。
  final Color textMuted;

  /// 区切り線・枠線 (onSurface の 16%)。
  final Color divider;

  /// primary (テラコッタ)。
  final Color primary;

  /// primary 上の文字色。
  final Color onPrimary;

  /// secondary (セージ)。
  final Color secondary;

  /// 破壊的操作 (削除) の文字色。赤は存在しないため accent-800 系で表現する。
  final Color destructive;

  final Color neutral100;
  final Color neutral200;
  final Color neutral300;
  final Color neutral400;
  final Color neutral500;
  final Color neutral600;
  final Color neutral700;
  final Color neutral800;
  final Color neutral900;

  final Color accent100;
  final Color accent200;
  final Color accent300;
  final Color accent400;
  final Color accent500;
  final Color accent600;
  final Color accent700;
  final Color accent800;

  final Color sage100;
  final Color sage200;
  final Color sage300;
  final Color sage400;
  final Color sage500;
  final Color sage700;
  final Color sage800;

  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.textMuted,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.destructive,
    required this.neutral100,
    required this.neutral200,
    required this.neutral300,
    required this.neutral400,
    required this.neutral500,
    required this.neutral600,
    required this.neutral700,
    required this.neutral800,
    required this.neutral900,
    required this.accent100,
    required this.accent200,
    required this.accent300,
    required this.accent400,
    required this.accent500,
    required this.accent600,
    required this.accent700,
    required this.accent800,
    required this.sage100,
    required this.sage200,
    required this.sage300,
    required this.sage400,
    required this.sage500,
    required this.sage700,
    required this.sage800,
  });

  /// ライトテーマ (README の Material 3 mapping と原本トークンそのまま)。
  static const AppColorScheme light = AppColorScheme(
    background: AppColors.background,
    surface: AppColors.neutral100,
    surfaceVariant: AppColors.neutral200,
    onSurface: AppColors.onSurface,
    textMuted: AppColors.neutral600,
    divider: AppColors.divider,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    destructive: AppColors.accent800,
    neutral100: AppColors.neutral100,
    neutral200: AppColors.neutral200,
    neutral300: AppColors.neutral300,
    neutral400: AppColors.neutral400,
    neutral500: AppColors.neutral500,
    neutral600: AppColors.neutral600,
    neutral700: AppColors.neutral700,
    neutral800: AppColors.neutral800,
    neutral900: AppColors.neutral900,
    accent100: AppColors.accent100,
    accent200: AppColors.accent200,
    accent300: AppColors.accent300,
    accent400: AppColors.accent400,
    accent500: AppColors.accent500,
    accent600: AppColors.accent600,
    accent700: AppColors.accent700,
    accent800: AppColors.accent800,
    sage100: AppColors.sage100,
    sage200: AppColors.sage200,
    sage300: AppColors.sage300,
    sage400: AppColors.sage400,
    sage500: AppColors.sage500,
    sage700: AppColors.sage700,
    sage800: AppColors.sage800,
  );

  /// ダークテーマ。地色 ⇄ 文字色を入れ替え、各トーンランプを反転させる。
  ///
  /// primary / onPrimary / secondary はブランド色として両テーマで固定する。
  /// 反転すると accent800 は淡いピーチ (accent-200 原本値) になり注意色として
  /// 読めなくなるため、destructive だけは反転値ではなく accent-400 原本値を使う。
  static const AppColorScheme dark = AppColorScheme(
    background: AppColors.onSurface,
    surface: AppColors.neutral900,
    surfaceVariant: AppColors.neutral800,
    onSurface: AppColors.background,
    textMuted: AppColors.neutral400,
    divider: Color(0x29F5EAD8),
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    destructive: AppColors.accent400,
    neutral100: AppColors.neutral900,
    neutral200: AppColors.neutral800,
    neutral300: AppColors.neutral700,
    neutral400: AppColors.neutral600,
    neutral500: AppColors.neutral500,
    neutral600: AppColors.neutral400,
    neutral700: AppColors.neutral300,
    neutral800: AppColors.neutral200,
    neutral900: AppColors.neutral100,
    accent100: AppColors.accent900,
    accent200: AppColors.accent800,
    accent300: AppColors.accent700,
    accent400: AppColors.accent600,
    accent500: AppColors.accent500,
    accent600: AppColors.accent400,
    accent700: AppColors.accent300,
    accent800: AppColors.accent200,
    sage100: AppColors.sage900,
    sage200: AppColors.sage800,
    sage300: AppColors.sage700,
    sage400: AppColors.sage600,
    sage500: AppColors.sage500,
    sage700: AppColors.sage300,
    sage800: AppColors.sage200,
  );

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? onSurface,
    Color? textMuted,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? destructive,
    Color? neutral100,
    Color? neutral200,
    Color? neutral300,
    Color? neutral400,
    Color? neutral500,
    Color? neutral600,
    Color? neutral700,
    Color? neutral800,
    Color? neutral900,
    Color? accent100,
    Color? accent200,
    Color? accent300,
    Color? accent400,
    Color? accent500,
    Color? accent600,
    Color? accent700,
    Color? accent800,
    Color? sage100,
    Color? sage200,
    Color? sage300,
    Color? sage400,
    Color? sage500,
    Color? sage700,
    Color? sage800,
  }) {
    return AppColorScheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurface: onSurface ?? this.onSurface,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      destructive: destructive ?? this.destructive,
      neutral100: neutral100 ?? this.neutral100,
      neutral200: neutral200 ?? this.neutral200,
      neutral300: neutral300 ?? this.neutral300,
      neutral400: neutral400 ?? this.neutral400,
      neutral500: neutral500 ?? this.neutral500,
      neutral600: neutral600 ?? this.neutral600,
      neutral700: neutral700 ?? this.neutral700,
      neutral800: neutral800 ?? this.neutral800,
      neutral900: neutral900 ?? this.neutral900,
      accent100: accent100 ?? this.accent100,
      accent200: accent200 ?? this.accent200,
      accent300: accent300 ?? this.accent300,
      accent400: accent400 ?? this.accent400,
      accent500: accent500 ?? this.accent500,
      accent600: accent600 ?? this.accent600,
      accent700: accent700 ?? this.accent700,
      accent800: accent800 ?? this.accent800,
      sage100: sage100 ?? this.sage100,
      sage200: sage200 ?? this.sage200,
      sage300: sage300 ?? this.sage300,
      sage400: sage400 ?? this.sage400,
      sage500: sage500 ?? this.sage500,
      sage700: sage700 ?? this.sage700,
      sage800: sage800 ?? this.sage800,
    );
  }

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other == null) {
      return this;
    }
    return AppColorScheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      neutral100: Color.lerp(neutral100, other.neutral100, t)!,
      neutral200: Color.lerp(neutral200, other.neutral200, t)!,
      neutral300: Color.lerp(neutral300, other.neutral300, t)!,
      neutral400: Color.lerp(neutral400, other.neutral400, t)!,
      neutral500: Color.lerp(neutral500, other.neutral500, t)!,
      neutral600: Color.lerp(neutral600, other.neutral600, t)!,
      neutral700: Color.lerp(neutral700, other.neutral700, t)!,
      neutral800: Color.lerp(neutral800, other.neutral800, t)!,
      neutral900: Color.lerp(neutral900, other.neutral900, t)!,
      accent100: Color.lerp(accent100, other.accent100, t)!,
      accent200: Color.lerp(accent200, other.accent200, t)!,
      accent300: Color.lerp(accent300, other.accent300, t)!,
      accent400: Color.lerp(accent400, other.accent400, t)!,
      accent500: Color.lerp(accent500, other.accent500, t)!,
      accent600: Color.lerp(accent600, other.accent600, t)!,
      accent700: Color.lerp(accent700, other.accent700, t)!,
      accent800: Color.lerp(accent800, other.accent800, t)!,
      sage100: Color.lerp(sage100, other.sage100, t)!,
      sage200: Color.lerp(sage200, other.sage200, t)!,
      sage300: Color.lerp(sage300, other.sage300, t)!,
      sage400: Color.lerp(sage400, other.sage400, t)!,
      sage500: Color.lerp(sage500, other.sage500, t)!,
      sage700: Color.lerp(sage700, other.sage700, t)!,
      sage800: Color.lerp(sage800, other.sage800, t)!,
    );
  }
}

/// 画面のコードから色トークンを取り出す入口。
extension AppColorSchemeContext on BuildContext {
  /// 現在のテーマの [AppColorScheme]。
  ///
  /// [buildAppTheme] を通さない MaterialApp (Widget テストなど) では extension が
  /// 無いため、テーマの明暗に合わせたトークンへフォールバックする。
  AppColorScheme get appColors =>
      Theme.of(this).extension<AppColorScheme>() ??
      switch (Theme.of(this).brightness) {
        Brightness.light => AppColorScheme.light,
        Brightness.dark => AppColorScheme.dark,
      };
}

/// デザイン指定の書体 (pubspec.yaml の fonts に登録)。
///
/// ThemeData.fontFamily は textTheme にしか効かず、AppBar・SnackBar・Chip の
/// テーマは自身の TextStyle をそのまま DefaultTextStyle にするため、
/// それらには書体を明示する。
const _fontFamily = 'Figtree';

/// TextTheme への文字スタイルトークンの割当。
///
/// Material 部品 (AppBar タイトル・ボタン・ListTile 等) が既定で参照するスロットに
/// デザインの寸法を載せ、画面のコードは `Theme.of(context).textTheme` か
/// [AppTextStyles] を直接使う。
const TextTheme _appTextTheme = TextTheme(
  headlineMedium: AppTextStyles.amountLarge,
  headlineSmall: AppTextStyles.amountSummary,
  titleLarge: AppTextStyles.screenTitle,
  titleMedium: AppTextStyles.sectionTitle,
  bodyMedium: AppTextStyles.body,
  bodySmall: AppTextStyles.caption,
  labelLarge: AppTextStyles.button,
  labelSmall: AppTextStyles.label,
);

/// デザイントークンを Material 3 の ThemeData に載せる。
///
/// [brightness] ごとに [AppColorScheme.light] / [AppColorScheme.dark] を使い、
/// ColorScheme のロールと主要部品のテーマをトークンから組み立てる。
ThemeData buildAppTheme({required Brightness brightness}) {
  final appColors = switch (brightness) {
    Brightness.light => AppColorScheme.light,
    Brightness.dark => AppColorScheme.dark,
  };
  // README の Material 3 mapping (primary / onPrimary / secondary / surface /
  // background / onSurface / outline) を起点に、部品が参照する派生ロールも
  // トークンで埋める。ここで埋めないロールは fromSeed が primary から生成した
  // 暖色系の値を使う。
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: appColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: appColors.primary,
        onPrimary: appColors.onPrimary,
        // 残スキャン数チップ (accent-100 地 / accent-700 文字)。
        primaryContainer: appColors.accent100,
        onPrimaryContainer: appColors.accent700,
        secondary: appColors.secondary,
        onSecondary: appColors.onPrimary,
        // 選択中チップ (neutral-900 地 × 地色文字)。
        secondaryContainer: appColors.neutral900,
        onSecondaryContainer: appColors.background,
        tertiary: appColors.sage700,
        onTertiary: appColors.sage100,
        // セージ系の説明カード・バナー (sage-100 地 / sage-800 文字)。
        tertiaryContainer: appColors.sage100,
        onTertiaryContainer: appColors.sage800,
        surface: appColors.surface,
        onSurface: appColors.onSurface,
        onSurfaceVariant: appColors.textMuted,
        surfaceContainerLowest: appColors.background,
        surfaceContainerLow: appColors.surface,
        surfaceContainer: appColors.surface,
        surfaceContainerHigh: appColors.surfaceVariant,
        surfaceContainerHighest: appColors.surfaceVariant,
        inverseSurface: appColors.neutral900,
        onInverseSurface: appColors.background,
        outline: appColors.divider,
        outlineVariant: appColors.divider,
        error: appColors.destructive,
        onError: appColors.background,
        shadow: AppColors.neutral900,
      );
  final pillShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: _fontFamily,
    textTheme: _appTextTheme,
    scaffoldBackgroundColor: appColors.background,
    canvasColor: appColors.background,
    dividerColor: appColors.divider,
    extensions: [appColors],
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: appColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTextStyles.screenTitle.copyWith(
        fontFamily: _fontFamily,
        color: appColors.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: appColors.divider,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: appColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: appColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: appColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: appColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: pillShape,
      // 登録完了トースト (sage-700 のピル) の配色。文字は地色で両テーマの
      // コントラストを確保する。
      backgroundColor: appColors.sage700,
      contentTextStyle: AppTextStyles.body.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w700,
        color: appColors.background,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: appColors.primary,
      foregroundColor: appColors.onPrimary,
      shape: const StadiumBorder(),
      // shadow-md 相当 (README のタブバー中央 FAB)。
      elevation: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: appColors.primary,
        foregroundColor: appColors.onPrimary,
        // タップ領域 44px 以上 (README の Typography 最小サイズ)。
        minimumSize: const Size(44, 48),
        shape: pillShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: appColors.onSurface,
        side: BorderSide(color: appColors.divider),
        minimumSize: const Size(44, 48),
        shape: pillShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: appColors.primary,
        shape: pillShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: appColors.neutral700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: appColors.surface,
        foregroundColor: appColors.onSurface,
        selectedBackgroundColor: appColors.neutral900,
        selectedForegroundColor: appColors.background,
        side: BorderSide(color: appColors.divider),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: appColors.surface,
      selectedColor: appColors.neutral900,
      side: BorderSide(color: appColors.divider),
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: AppTextStyles.body.copyWith(
        fontFamily: _fontFamily,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? appColors.background
              : appColors.onSurface,
        ),
      ),
      // プロトタイプのカテゴリチップ (padding 7px 14px、ピル)。
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appColors.surface,
      labelStyle: TextStyle(color: appColors.textMuted),
      floatingLabelStyle: TextStyle(color: appColors.textMuted),
      // ピル形状の入力欄で文字が角丸に被らない左右余白と、44px 以上のタップ領域。
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: appColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: appColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: appColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: appColors.destructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: BorderSide(color: appColors.destructive, width: 2),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: appColors.onSurface,
      iconColor: appColors.neutral500,
    ),
    switchTheme: SwitchThemeData(
      // 除外トグル ON = sage-500 (README の明細詳細)。
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? appColors.sage500
            : appColors.neutral300,
      ),
      thumbColor: WidgetStateProperty.all(appColors.surface),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: appColors.primary,
      linearTrackColor: appColors.surfaceVariant,
    ),
  );
}
