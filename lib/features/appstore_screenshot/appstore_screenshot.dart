import 'package:flutter/material.dart';
import 'package:kashakeibo/style/tokens.dart';

/// App Store スクリーンショットの対象ロケール。
enum AppStoreScreenshotLocale {
  ja(fastlaneDirectoryName: 'ja'),
  enUs(fastlaneDirectoryName: 'en-US');

  /// fastlane の既存ロケールディレクトリ名へ対応付ける。
  const AppStoreScreenshotLocale({required this.fastlaneDirectoryName});

  /// fastlane/screenshots 配下の言語ディレクトリ名。
  final String fastlaneDirectoryName;

  /// CLI から渡された fastlane 言語名を対象ロケールへ変換する。
  static AppStoreScreenshotLocale fromFastlaneDirectoryName({
    required String fastlaneDirectoryName,
  }) {
    return values.singleWhere(
      (locale) => locale.fastlaneDirectoryName == fastlaneDirectoryName,
      orElse: () => throw ArgumentError.value(
        fastlaneDirectoryName,
        'fastlaneDirectoryName',
        '対応言語は ja, en-US です',
      ),
    );
  }
}

/// App Store スクリーンショットの対象端末クラス。
enum AppStoreScreenshotDevice {
  iphone69(
    fileNameLabel: 'iphone_69',
    logicalSize: Size(430, 932),
    pixelRatio: 3,
    expectedPixelWidth: 1290,
    expectedPixelHeight: 2796,
  ),
  ipad13(
    fileNameLabel: 'ipad_13',
    logicalSize: Size(1024, 1366),
    pixelRatio: 2,
    expectedPixelWidth: 2048,
    expectedPixelHeight: 2732,
  );

  /// Apple が受理する端末別の出力寸法から描画条件を作る。
  const AppStoreScreenshotDevice({
    required this.fileNameLabel,
    required this.logicalSize,
    required this.pixelRatio,
    required this.expectedPixelWidth,
    required this.expectedPixelHeight,
  });

  /// fastlane 配置時に端末クラスを識別するファイル名ラベル。
  final String fileNameLabel;

  /// Widget test で描画する論理サイズ。
  final Size logicalSize;

  /// Apple の要求ピクセル寸法へ変換する倍率。
  final double pixelRatio;

  /// Apple が受理する画像幅。
  final int expectedPixelWidth;

  /// Apple が受理する画像高さ。
  final int expectedPixelHeight;
}

/// 1言語分のストア用キャッチコピー。
@immutable
class AppStoreScreenshotCopy {
  /// ストア画面の3段階の訴求文を保持する。
  const AppStoreScreenshotCopy({
    required this.eyebrow,
    required this.headline,
    required this.supportingText,
  });

  /// 見出し上部の短いラベル。
  final String eyebrow;

  /// スクリーンショットの主見出し。
  final String headline;

  /// 主見出しを補足する短文。
  final String supportingText;
}

/// ストア掲載順のページ番号。
const appStoreScreenshotPageNumbers = [1, 2, 3, 4, 5];

/// ページ番号と端末クラスから fastlane 配置用ファイル名を返す。
String appStoreScreenshotFileName({
  required int pageNumber,
  required AppStoreScreenshotDevice device,
}) {
  final fileStem = switch (pageNumber) {
    1 => 'snap_to_budget',
    2 => 'receipt_scan',
    3 => 'duplicate_detection',
    4 => 'source_image',
    5 => 'monthly_report',
    _ => throw ArgumentError.value(pageNumber, 'pageNumber'),
  };
  return '${pageNumber.toString().padLeft(2, '0')}_${device.fileNameLabel}_$fileStem.png';
}

/// ページ番号と言語に対応するキャッチコピーを返す。
AppStoreScreenshotCopy appStoreScreenshotCopy({
  required int pageNumber,
  required AppStoreScreenshotLocale locale,
}) {
  final copies = switch (locale) {
    AppStoreScreenshotLocale.ja => const {
      1: AppStoreScreenshotCopy(
        eyebrow: 'スクショも、レシートも',
        headline: '撮ったら、\n家計簿になる。',
        supportingText: 'AIが金額・日付・店名を読み取り、明細にします',
      ),
      2: AppStoreScreenshotCopy(
        eyebrow: 'かんたんAIスキャン',
        headline: 'レシートは\nカメラで一瞬。',
        supportingText: '撮影するだけ。面倒な入力はAIにおまかせ',
      ),
      3: AppStoreScreenshotCopy(
        eyebrow: '二重計上を防ぐ',
        headline: '同じ支出を\nかしこく発見。',
        supportingText: 'レシートとカード明細の重複候補をまとめられます',
      ),
      4: AppStoreScreenshotCopy(
        eyebrow: 'AIでも、ちゃんと確かめられる',
        headline: '元画像へ\nいつでも戻れる。',
        supportingText: '読み取り結果を画像と見比べて、すぐに修正できます',
      ),
      5: AppStoreScreenshotCopy(
        eyebrow: '口座連携なし',
        headline: '連携切れを気にせず\n支出が見える。',
        supportingText: '認証情報を預けず、月の家計をひと目で把握',
      ),
    },
    AppStoreScreenshotLocale.enUs => const {
      1: AppStoreScreenshotCopy(
        eyebrow: 'SCREENSHOTS OR RECEIPTS',
        headline: 'Snap it.\nBudgeted.',
        supportingText: 'AI extracts the amount, date, and merchant for you',
      ),
      2: AppStoreScreenshotCopy(
        eyebrow: 'EFFORTLESS AI SCANNING',
        headline: 'Receipts become\nrecords in a snap.',
        supportingText: 'Take a photo and let AI handle the typing',
      ),
      3: AppStoreScreenshotCopy(
        eyebrow: 'PREVENT DOUBLE COUNTING',
        headline: 'Catch duplicate\nspending.',
        supportingText: 'Merge matching receipts and card statement entries',
      ),
      4: AppStoreScreenshotCopy(
        eyebrow: 'AI YOU CAN VERIFY',
        headline: 'Your source image\nis always there.',
        supportingText: 'Compare, confirm, and correct any scanned detail',
      ),
      5: AppStoreScreenshotCopy(
        eyebrow: 'NO BANK LINKING',
        headline: 'See your spending.\nSkip broken syncs.',
        supportingText:
            'Keep credentials private and your monthly budget clear',
      ),
    },
  };

  final copy = copies[pageNumber];
  if (copy == null) {
    throw ArgumentError.value(pageNumber, 'pageNumber', '対応ページは 1〜5 です');
  }
  return copy;
}

/// iPhone・iPad の規定寸法で撮影する App Store スクリーンショット画面。
///
/// 端末別の論理サイズと倍率は [AppStoreScreenshotDevice] を単一ソースにする。
/// 本番の永続化層や Firebase に接続せず、固定データだけで再現可能にする。
class AppStoreScreenshotPage extends StatelessWidget {
  /// 指定端末・掲載順・ロケールのストア画面を作る。
  const AppStoreScreenshotPage({
    required this.pageNumber,
    required this.locale,
    required this.device,
    super.key,
  });

  /// ストア掲載順のページ番号。
  final int pageNumber;

  /// 表示するキャッチコピーのロケール。
  final AppStoreScreenshotLocale locale;

  /// 表示レイアウトを合わせる端末クラス。
  final AppStoreScreenshotDevice device;

  @override
  Widget build(BuildContext context) {
    final copy = appStoreScreenshotCopy(pageNumber: pageNumber, locale: locale);
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Figtree',
        fontFamilyFallback: ['NotoSansJPAppStore'],
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: _backgroundGradient(pageNumber)),
          child: Stack(
            children: [
              const Positioned(
                top: -74,
                right: -94,
                child: _BackgroundOrb(diameter: 260, color: Color(0x33FFF2EB)),
              ),
              const Positioned(
                top: 266,
                left: -120,
                child: _BackgroundOrb(diameter: 230, color: Color(0x267A8A5E)),
              ),
              device == AppStoreScreenshotDevice.iphone69
                  ? _buildIPhoneContent(copy: copy)
                  : _buildIPadContent(copy: copy),
            ],
          ),
        ),
      ),
    );
  }

  /// 6.9インチ iPhone の縦長画面へ訴求と端末モックを配置する。
  Widget _buildIPhoneContent({required AppStoreScreenshotCopy copy}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 58, 30, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandMark(locale: locale),
          const SizedBox(height: 28),
          Text(
            copy.eyebrow,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.headline,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 39,
              height: 1.04,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.25,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 354,
            child: Text(
              copy.supportingText,
              style: const TextStyle(
                color: AppColors.neutral700,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: _DeviceFrame(
                child: _mockAppScreen(pageNumber: pageNumber, locale: locale),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 13インチ iPad の4:3画面へ訴求と端末モックを横並びで配置する。
  Widget _buildIPadContent({required AppStoreScreenshotCopy copy}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(64, 68, 64, 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrandMark(locale: locale, large: true),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 430,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.eyebrow,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        copy.headline,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 60,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        copy.supportingText,
                        style: const TextStyle(
                          color: AppColors.neutral700,
                          fontSize: 22,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 400,
                  height: 704,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _DeviceFrame(
                      child: _mockAppScreen(
                        pageNumber: pageNumber,
                        locale: locale,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Product Page Header の日英ローカライズ済みクリエイティブ。
///
/// 1920×823 logical px を devicePixelRatio 2 で撮影し、Apple 公式テンプレートの
/// 3840×1646 px canvas に合わせる。キーコンテンツは Art Safe Area 相当の中央
/// 823×330 logical px に対し、横方向へ3 pxの余白を取った820×330 px内へ収める。
class ProductPageHeaderCreative extends StatelessWidget {
  /// 指定ロケールの Product Page Header を作る。
  const ProductPageHeaderCreative({required this.locale, super.key});

  /// 表示するキャッチコピーのロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: 'Figtree',
        fontFamilyFallback: ['NotoSansJPAppStore'],
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5EAD8), Color(0xFFFFE1D0)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                left: -140,
                top: -230,
                child: _BackgroundOrb(diameter: 650, color: Color(0x44C67139)),
              ),
              const Positioned(
                right: -190,
                bottom: -340,
                child: _BackgroundOrb(diameter: 790, color: Color(0x337A8A5E)),
              ),
              Center(
                child: SizedBox(
                  width: 820,
                  height: 330,
                  child: Row(
                    children: [
                      const SizedBox(width: 300, child: _HeaderVisualMotif()),
                      const SizedBox(width: 46),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BrandMark(locale: locale, large: true),
                            const SizedBox(height: 24),
                            Text(
                              isJapanese
                                  ? '撮った瞬間、\n家計簿になる。'
                                  : 'Snap it.\nBudgeted.',
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 58,
                                height: 0.98,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2.2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              isJapanese
                                  ? 'スクショもレシートも、AIでかんたん記録'
                                  : 'AI budgeting for screenshots and receipts',
                              style: const TextStyle(
                                color: AppColors.neutral700,
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 掲載順ごとのテーマ色から背景グラデーションを返す。
LinearGradient _backgroundGradient(int pageNumber) {
  return switch (pageNumber) {
    1 => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF5EAD8), Color(0xFFFFE1D0)],
    ),
    2 => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF5EAD8), Color(0xFFF0FAE1)],
    ),
    3 => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF0FAE1), Color(0xFFF5EAD8)],
    ),
    4 => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFF2EB), Color(0xFFF5EAD8)],
    ),
    5 => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF5EAD8), Color(0xFFE1EECC)],
    ),
    _ => throw ArgumentError.value(pageNumber, 'pageNumber'),
  };
}

/// 掲載順に対応する固定データのアプリ画面モックを返す。
Widget _mockAppScreen({
  required int pageNumber,
  required AppStoreScreenshotLocale locale,
}) {
  return switch (pageNumber) {
    1 => _ScreenshotImportMock(locale: locale),
    2 => _ReceiptScanMock(locale: locale),
    3 => _DuplicateDetectionMock(locale: locale),
    4 => _SourceImageMock(locale: locale),
    5 => _MonthlyReportMock(locale: locale),
    _ => throw ArgumentError.value(pageNumber, 'pageNumber'),
  };
}

/// 背景へ奥行きを加える半透明の円形装飾。
class _BackgroundOrb extends StatelessWidget {
  /// 指定直径と色の装飾を作る。
  const _BackgroundOrb({required this.diameter, required this.color});

  /// 円の直径。
  final double diameter;

  /// 円の塗り色。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// アイコンとローカライズ済み名称で構成するブランド表記。
class _BrandMark extends StatelessWidget {
  /// 通常はスクリーンショット向けの小サイズとし、ヘッダーだけ拡大指定する。
  const _BrandMark({required this.locale, this.large = false});

  /// ブランド名を切り替えるロケール。
  final AppStoreScreenshotLocale locale;

  /// Product Page Header 用の拡大表示かどうか。
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 42 : 30,
          height: large ? 42 : 30,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.document_scanner_rounded,
            color: AppColors.onPrimary,
            size: large ? 25 : 18,
          ),
        ),
        SizedBox(width: large ? 13 : 9),
        Text(
          locale == AppStoreScreenshotLocale.ja ? 'カシャケイボ' : 'Kashakeibo',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: large ? 24 : 17,
            fontWeight: FontWeight.w800,
            letterSpacing: large ? -0.4 : -0.2,
          ),
        ),
      ],
    );
  }
}

/// アプリ画面モックを収める iPhone 風の端末フレーム。
class _DeviceFrame extends StatelessWidget {
  /// 指定した画面モックをフレーム内へ収める。
  const _DeviceFrame({required this.child});

  /// フレーム内へ表示するアプリ画面モック。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      height: 580,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF201E1D),
        borderRadius: BorderRadius.circular(50),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402E2B25),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(41),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 10,
              left: 112,
              right: 112,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF201E1D),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 各アプリ画面モックで共有するタイトルと余白の骨格。
class _MockScreenScaffold extends StatelessWidget {
  /// 通常画面は明色とし、撮影画面だけ明示的に暗色へ切り替える。
  const _MockScreenScaffold({
    required this.title,
    required this.child,
    this.dark = false,
  });

  /// モック画面上部のタイトル。
  final String title;

  /// タイトル下へ表示する画面内容。
  final Widget child;

  /// カメラ画面向けの暗色表示かどうか。
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = dark ? Colors.white : AppColors.onSurface;
    return ColoredBox(
      color: dark ? const Color(0xFF201E1D) : AppColors.background,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web明細のスクリーンショット取り込みを表す画面モック。
class _ScreenshotImportMock extends StatelessWidget {
  /// 指定ロケールの固定データを表示する。
  const _ScreenshotImportMock({required this.locale});

  /// モック内文言のロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return _MockScreenScaffold(
      title: isJapanese ? '写真・スクショから選ぶ' : 'Choose a screenshot',
      child: Column(
        children: [
          _MockCard(
            color: const Color(0xFFF9F4ED),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _RoundIcon(
                      icon: Icons.credit_card_rounded,
                      color: AppColors.sage700,
                      backgroundColor: AppColors.sage100,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isJapanese ? 'カードご利用明細' : 'Card statement',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _StatementRow(label: 'AMAZON.CO.JP', amount: '¥3,280'),
                const SizedBox(height: 10),
                const _StatementRow(label: 'PAYPAY', amount: '¥1,240'),
                const SizedBox(height: 10),
                const _StatementRow(label: 'SUICA MOBILE', amount: '¥2,000'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Icon(
            Icons.keyboard_double_arrow_down_rounded,
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(height: 16),
          _MockCard(
            color: AppColors.accent100,
            borderColor: AppColors.accent300,
            child: Row(
              children: [
                const _RoundIcon(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.accent700,
                  backgroundColor: AppColors.accent200,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isJapanese ? '3件を読み取りました' : '3 entries found',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isJapanese
                            ? '金額・日付・店名を確認'
                            : 'Review amount, date, and merchant',
                        style: const TextStyle(
                          color: AppColors.neutral600,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// レシートをカメラで読み取る画面モック。
class _ReceiptScanMock extends StatelessWidget {
  /// 指定ロケールの固定データを表示する。
  const _ReceiptScanMock({required this.locale});

  /// モック内文言のロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return _MockScreenScaffold(
      title: isJapanese ? 'レシートを撮影' : 'Scan a receipt',
      dark: true,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 220,
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'KASHA MART',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _ReceiptLine(label: 'GROCERIES', value: '¥2,480'),
                  const SizedBox(height: 10),
                  const _ReceiptLine(label: 'COFFEE', value: '¥480'),
                  const SizedBox(height: 10),
                  const _ReceiptLine(label: 'TAX', value: '¥237'),
                  const Spacer(),
                  const Divider(color: AppColors.neutral400),
                  const _ReceiptLine(
                    label: 'TOTAL',
                    value: '¥3,197',
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 24,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.neutral800,
                          AppColors.neutral800,
                          AppColors.neutral100,
                          AppColors.neutral800,
                          AppColors.neutral100,
                          AppColors.neutral800,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isJapanese ? 'レシートを枠内に' : 'Fit receipt inside the frame',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neutral400, width: 5),
            ),
          ),
        ],
      ),
    );
  }
}

/// レシートとカード明細の重複候補を表す画面モック。
class _DuplicateDetectionMock extends StatelessWidget {
  /// 指定ロケールの固定データを表示する。
  const _DuplicateDetectionMock({required this.locale});

  /// モック内文言のロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return _MockScreenScaffold(
      title: isJapanese ? '重複候補の確認' : 'Review duplicate',
      child: Column(
        children: [
          _TransactionSourceCard(
            icon: Icons.receipt_long_rounded,
            sourceLabel: isJapanese ? 'レシート' : 'Receipt',
            merchant: isJapanese ? '鳥貴族 三軒茶屋店' : 'Torikizoku Sangenjaya',
            amount: '¥4,230',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.sage100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isJapanese ? '金額と日付が一致' : 'Same amount and date',
              style: const TextStyle(
                color: AppColors.sage700,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _TransactionSourceCard(
            icon: Icons.credit_card_rounded,
            sourceLabel: isJapanese ? 'カード明細' : 'Card statement',
            merchant: isJapanese ? '楽天カード明細（トリキ）' : 'Card statement (TORIKI)',
            amount: '¥4,230',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isJapanese ? '1件にまとめる' : 'Merge into one',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 読み取り結果と元画像の紐付きを表す画面モック。
class _SourceImageMock extends StatelessWidget {
  /// 指定ロケールの固定データを表示する。
  const _SourceImageMock({required this.locale});

  /// モック内文言のロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return _MockScreenScaffold(
      title: isJapanese ? '明細' : 'Transaction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¥3,280',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Amazon.co.jp',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Container(
            height: 205,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isJapanese ? '注文履歴' : 'Your Orders',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _StatementRow(
                      label: 'KITCHEN GOODS',
                      amount: '¥3,280',
                    ),
                    const SizedBox(height: 12),
                    const _StatementRow(
                      label: 'ORDER # 701-123',
                      amount: '8/16',
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isJapanese ? '拡大' : 'Zoom',
                      style: const TextStyle(
                        color: AppColors.neutral100,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.sage700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isJapanese
                      ? '読み取りに使った元画像をいつでも確認できます'
                      : 'Your original source image stays linked',
                  style: const TextStyle(
                    color: AppColors.sage700,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 口座連携なしの月次集計を表す画面モック。
class _MonthlyReportMock extends StatelessWidget {
  /// 指定ロケールの固定データを表示する。
  const _MonthlyReportMock({required this.locale});

  /// モック内文言のロケール。
  final AppStoreScreenshotLocale locale;

  @override
  Widget build(BuildContext context) {
    final isJapanese = locale == AppStoreScreenshotLocale.ja;
    return _MockScreenScaffold(
      title: isJapanese ? '2026年8月' : 'August 2026',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MockCard(
            color: AppColors.neutral100,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isJapanese ? '支出' : 'Spending',
                        style: const TextStyle(
                          color: AppColors.neutral600,
                          fontSize: 10,
                        ),
                      ),
                      const Text(
                        '¥84,320',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isJapanese ? '残り' : 'Remaining',
                      style: const TextStyle(
                        color: AppColors.neutral600,
                        fontSize: 10,
                      ),
                    ),
                    const Text(
                      '¥35,680',
                      style: TextStyle(
                        color: AppColors.sage700,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isJapanese ? 'カテゴリ別' : 'By category',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _CategoryBar(
            label: isJapanese ? '食費' : 'Groceries',
            amount: '¥31,200',
            fraction: 1,
            color: AppColors.accent500,
          ),
          const SizedBox(height: 12),
          _CategoryBar(
            label: isJapanese ? '外食' : 'Dining',
            amount: '¥21,840',
            fraction: 0.7,
            color: AppColors.accent400,
          ),
          const SizedBox(height: 12),
          _CategoryBar(
            label: isJapanese ? '日用品' : 'Household',
            amount: '¥14,500',
            fraction: 0.46,
            color: AppColors.sage500,
          ),
          const SizedBox(height: 12),
          _CategoryBar(
            label: isJapanese ? '交通' : 'Transit',
            amount: '¥9,280',
            fraction: 0.3,
            color: AppColors.sage400,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.sage100,
              border: Border.all(color: AppColors.sage300),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.sage700,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isJapanese
                        ? '口座の認証情報は預かりません'
                        : 'Your bank credentials stay private',
                    style: const TextStyle(
                      color: AppColors.sage700,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Product Page Header で撮影から明細化までを示す視覚モチーフ。
class _HeaderVisualMotif extends StatelessWidget {
  /// 固定デザインの視覚モチーフを作る。
  const _HeaderVisualMotif();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -0.08,
          child: Container(
            width: 190,
            height: 270,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332E2B25),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: [
                Text(
                  'KASHA MART',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 30),
                _ReceiptLine(label: 'GROCERIES', value: '¥2,480'),
                SizedBox(height: 14),
                _ReceiptLine(label: 'COFFEE', value: '¥480'),
                Spacer(),
                Divider(color: AppColors.neutral400),
                _ReceiptLine(label: 'TOTAL', value: '¥3,197', bold: true),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 24,
          child: Container(
            width: 132,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.sage100,
              border: Border.all(color: AppColors.sage300, width: 2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x302E2B25),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.sage700,
                  size: 27,
                ),
                SizedBox(height: 12),
                Text(
                  '¥3,197',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'KASHA MART',
                  style: TextStyle(
                    color: AppColors.sage700,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// アプリ画面モック内で共通利用する角丸カード。
class _MockCard extends StatelessWidget {
  /// 通常カードの境界を既存 divider token に揃え、訴求カードだけ枠色を上書きする。
  const _MockCard({
    required this.color,
    required this.child,
    this.borderColor = AppColors.divider,
  });

  /// カードの背景色。
  final Color color;

  /// カードの枠線色。
  final Color borderColor;

  /// カード内へ表示する内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: appShadowSm,
      ),
      child: child,
    );
  }
}

/// 色付き円形背景へアイコンを収める共通部品。
class _RoundIcon extends StatelessWidget {
  /// 指定したアイコンと配色で円形アイコンを作る。
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  /// 表示する Material icon。
  final IconData icon;

  /// アイコンの前景色。
  final Color color;

  /// 円形背景の色。
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// 明細名と金額を1行で示すモック部品。
class _StatementRow extends StatelessWidget {
  /// 指定した明細名と金額を表示する。
  const _StatementRow({required this.label, required this.amount});

  /// 明細の表示名。
  final String label;

  /// 通貨記号を含む表示金額。
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.neutral700,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// レシート内の商品名と金額を1行で示すモック部品。
class _ReceiptLine extends StatelessWidget {
  /// 通常行を標準とし、合計行だけ明示的に太字へ切り替える。
  const _ReceiptLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  /// 商品または合計の表示名。
  final String label;

  /// 通貨記号を含む表示金額。
  final String value;

  /// 合計行として強調するかどうか。
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: bold ? 11 : 9,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: bold ? 12 : 9,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 取引の取得元・店名・金額をまとめる画面モック部品。
class _TransactionSourceCard extends StatelessWidget {
  /// 指定した取得元情報から取引カードを作る。
  const _TransactionSourceCard({
    required this.icon,
    required this.sourceLabel,
    required this.merchant,
    required this.amount,
  });

  /// 取得元を表す Material icon。
  final IconData icon;

  /// レシートやカード明細などの取得元名。
  final String sourceLabel;

  /// 取引先の表示名。
  final String merchant;

  /// 通貨記号を含む表示金額。
  final String amount;

  @override
  Widget build(BuildContext context) {
    return _MockCard(
      color: AppColors.neutral100,
      child: Row(
        children: [
          _RoundIcon(
            icon: icon,
            color: AppColors.primary,
            backgroundColor: AppColors.accent100,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceLabel,
                  style: const TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  merchant,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '2026/08/10',
                  style: TextStyle(
                    color: AppColors.neutral600,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 月次集計のカテゴリ別金額を横棒で示すモック部品。
class _CategoryBar extends StatelessWidget {
  /// 指定カテゴリの割合と配色から横棒を作る。
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  /// カテゴリの表示名。
  final String label;

  /// 通貨記号を含む表示金額。
  final String amount;

  /// 横棒の最大幅に対する割合。
  final double fraction;

  /// 横棒の色。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}
