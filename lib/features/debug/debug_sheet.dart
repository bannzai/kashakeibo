import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/capture_page.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/features/paywall/paywall_page.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// DEBUG ビルド限定の開発者メニュー。
///
/// 到達困難な状態 (明細データの投入・スキャン残量 0) を、起動引数ではなくアプリ内メニューから
/// 作れるようにする (~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md のパターン)。
/// DEBUG 限定のため文言は日本語固定で l10n の対象外とする。
class DebugSheet extends HookConsumerWidget {
  const DebugSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addTransaction = ref.watch(addTransactionProvider);
    // Provider は build で確保し、await をまたぐコールバックからは ref に触れない
    // (`.claude/rules/riverpod-rules.md`)。
    final scanQuotaFuture = ref.watch(monthlyScanQuotaProvider.future);
    final monthlyScanQuota = ref.watch(monthlyScanQuotaProvider.notifier);
    final setDebugScanCount = ref.watch(setDebugScanCountProvider);
    // 残量設定の実行中。Worker の応答待ちに連打して pop が二重に走るのを防ぐ。
    final exhaustScanQuotaInProgress = useState(false);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('サンプル明細を追加'),
            subtitle: const Text('今月の明細 5 件 (計算対象外 1 件を含む) を書き込む'),
            onTap: () async {
              try {
                await _addSampleTransactions(addTransaction: addTransaction);
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                await _showErrorDialog(context: context, error: error);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('サンプルレシートで撮影フローを試す'),
            subtitle: const Text('端末カメラの無いシミュレータでも、描画したレシート画像で解析 → 確認 → 登録を通す'),
            onTap: () => _openCaptureFlowWithSampleImage(
              context: context,
              renderSampleImage: _renderSampleReceiptImage,
              transactionSource: TransactionSource.receipt,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('サンプル明細スクショで取込フローを試す'),
            subtitle: const Text(
              'カード明細風の画像 (取引 3 件) を描画し、複数明細の候補リスト (採用・破棄・修正 → 一括登録) を通す',
            ),
            onTap: () => _openCaptureFlowWithSampleImage(
              context: context,
              renderSampleImage: _renderSampleStatementScreenshotImage,
              transactionSource: TransactionSource.screenshot,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.battery_alert_outlined),
            enabled: !exhaustScanQuotaInProgress.value,
            title: const Text('スキャン残量を使い切る'),
            subtitle: const Text('今月のスキャン回数を無料枠の上限に設定し、残量 0 (ペイウォールが開く状態) を作る'),
            onTap: () async {
              exhaustScanQuotaInProgress.value = true;
              try {
                await _exhaustScanQuota(
                  context: context,
                  scanQuotaFuture: scanQuotaFuture,
                  setDebugScanCount: setDebugScanCount,
                  monthlyScanQuota: monthlyScanQuota,
                );
              } finally {
                // シートが閉じた後の setState を避ける (閉じていれば hook は破棄済み)。
                if (context.mounted) {
                  exhaustScanQuotaInProgress.value = false;
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('ペイウォールをサンプル価格で開く'),
            subtitle: const Text(
              'RevenueCat 未設定のビルドでも、月額 ¥480 / 年額 ¥3,800 の料金カードと購入 (mock で成功) の表示を確認する',
            ),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (context) => const _SamplePaywallPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 今月のスキャン回数を無料枠の上限に設定し、残量 0 の状態を作る (DEBUG 用)。
///
/// 使用回数は Cloudflare の Durable Object の中にしか無く外部から書き換えられないため、
/// dev 環境の Worker にだけ用意した DEBUG 経路 (POST /debug/scan-count) 経由で設定する。
/// 設定後は残量表示 (monthlyScanQuotaProvider) を取り直して画面に反映する。
/// 冪等: 何度実行しても残量 0 のまま。
Future<void> _exhaustScanQuota({
  required BuildContext context,
  required Future<ScanQuota> scanQuotaFuture,
  required SetDebugScanCount setDebugScanCount,
  required MonthlyScanQuota monthlyScanQuota,
}) async {
  // シートを閉じた後もスナックバーを出せるよう、閉じる前に Navigator と ScaffoldMessenger を確保する。
  final navigator = Navigator.of(context);
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  try {
    // 無料枠の上限は Worker が返す値を使う (クライアントに上限を持たせない)。
    final scanQuota = await scanQuotaFuture;
    final exhaustedScanQuota = await setDebugScanCount(
      monthlyScanCount: scanQuota.monthlyFreeScanLimit,
    );
    monthlyScanQuota.refresh();
    if (!context.mounted) {
      return;
    }
    navigator.pop();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          '今月のスキャン回数を ${exhaustedScanQuota.monthlyScanCount} 回 '
          '(無料枠 ${exhaustedScanQuota.monthlyFreeScanLimit} 回) に設定しました',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    await _showErrorDialog(context: context, error: error);
  }
}

/// 開発者メニューの操作が失敗した時に、エラーをそのまま表示するダイアログ。
Future<void> _showErrorDialog({
  required BuildContext context,
  required Object error,
}) {
  // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: SingleChildScrollView(child: Text(error.toString())),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// 描画したサンプル画像で取込フロー画面 (`CapturePage`) を開き、登録完了ならトーストを出す。
Future<void> _openCaptureFlowWithSampleImage({
  required BuildContext context,
  required Future<Uint8List> Function() renderSampleImage,
  required TransactionSource transactionSource,
}) async {
  // シートを閉じてから取込フロー画面を開くため、閉じる前に Navigator を確保する。
  final navigator = Navigator.of(context);
  final sampleImageBytes = await renderSampleImage();
  if (!context.mounted) {
    return;
  }
  navigator.pop();
  final captureFlowResult = await navigator.push<CaptureFlowResult>(
    MaterialPageRoute<CaptureFlowResult>(
      fullscreenDialog: true,
      builder: (context) => CapturePage(
        imageBytes: sampleImageBytes,
        imageContentType: 'image/png',
        transactionSource: transactionSource,
        logAnalyticsEvent: recordAnalyticsEvent,
      ),
    ),
  );
  final navigatorContext = navigator.context;
  if (captureFlowResult == CaptureFlowResult.registered &&
      navigatorContext.mounted) {
    showCaptureRegisteredToast(context: navigatorContext);
  }
}

/// サンプル Offering でペイウォールを表示する画面。
///
/// アプリの ProviderScope とは独立した container で Offering・購入・復元だけを差し替える
/// (入れ子の ProviderScope で override すると dependencies の宣言が要るため、独立 root にする)。
/// UncontrolledProviderScope は container を所有しないため、route の破棄と一緒に自前で dispose し、
/// 開閉を繰り返しても RevenueCat リスナーや keepAlive の状態が蓄積しないようにする。
class _SamplePaywallPage extends StatefulWidget {
  const _SamplePaywallPage();

  @override
  State<_SamplePaywallPage> createState() => _SamplePaywallPageState();
}

class _SamplePaywallPageState extends State<_SamplePaywallPage> {
  /// この画面が所有するサンプル差し替え用の container。
  final ProviderContainer sampleProviderContainer = ProviderContainer(
    overrides: [
      premiumOfferingProvider.overrideWith((ref) async => _sampleOffering),
      purchasePremiumPackageProvider.overrideWithValue(
        ({required package}) async => true,
      ),
      restorePurchasesProvider.overrideWithValue(() async => false),
    ],
  );

  @override
  void dispose() {
    sampleProviderContainer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: sampleProviderContainer,
      child: PaywallPage(
        openExternalUri: openExternalUri,
        logAnalyticsEvent: recordAnalyticsEvent,
      ),
    );
  }
}

/// ペイウォールの表示確認用のサンプル Offering (実商品と同じ識別子・価格。documents/PROJECT.md の課金設計)。
Package _buildSamplePackage({
  required PackageType packageType,
  required String productIdentifier,
  required double price,
  required String priceString,
}) => Package(
  packageType == PackageType.annual ? r'$rc_annual' : r'$rc_monthly',
  packageType,
  StoreProduct(
    productIdentifier,
    'カシャケイボ プレミアム',
    'プレミアム',
    price,
    priceString,
    'JPY',
  ),
  const PresentedOfferingContext('default', null, null),
);

final _sampleMonthlyPackage = _buildSamplePackage(
  packageType: PackageType.monthly,
  productIdentifier: 'kashakeibo_premium_monthly_480yen',
  price: 480,
  priceString: '¥480',
);

final _sampleAnnualPackage = _buildSamplePackage(
  packageType: PackageType.annual,
  productIdentifier: 'kashakeibo_premium_annual_3800yen',
  price: 3800,
  priceString: '¥3,800',
);

final _sampleOffering = Offering(
  'default',
  'サンプル',
  const {},
  [_sampleMonthlyPackage, _sampleAnnualPackage],
  monthly: _sampleMonthlyPackage,
  annual: _sampleAnnualPackage,
);

/// 解析の動作確認用に、レシート風の画像 (店名・明細行・合計・日付) を描画して PNG にする。
///
/// 端末カメラの無いシミュレータでも撮影フロー (アップロード → Gemini 解析) を通すための
/// 入力画像で、アセットを持たずにその場で描く。冪等 (同じ内容の画像を返す)。
Future<Uint8List> _renderSampleReceiptImage() => _renderTextLinesImage(
  lines: const [
    (text: 'セブン-イレブン 三軒茶屋駅前店', fontSize: 34.0),
    (text: '東京都世田谷区三軒茶屋2-11-22', fontSize: 26.0),
    (text: '2026年08月16日(日) 12:34  レジ#3', fontSize: 26.0),
    (text: '------------------------------', fontSize: 26.0),
    (text: 'おにぎり 鮭            ¥150', fontSize: 26.0),
    (text: 'サンドイッチ           ¥398', fontSize: 26.0),
    (text: 'お茶 500ml            ¥140', fontSize: 26.0),
    (text: 'キャンディ            ¥120', fontSize: 26.0),
    (text: '------------------------------', fontSize: 26.0),
    (text: '小計                  ¥808', fontSize: 26.0),
    (text: '消費税(8%)             ¥64', fontSize: 26.0),
    (text: '合計                  ¥872', fontSize: 34.0),
    (text: 'お預り               ¥1,000', fontSize: 26.0),
    (text: 'お釣り                ¥128', fontSize: 26.0),
    (text: 'ありがとうございました', fontSize: 26.0),
  ],
);

/// 複数明細の取込 (issue #8) の動作確認用に、カード明細のスクショ風の画像 (取引 3 件) を描画して PNG にする。
/// 冪等 (同じ内容の画像を返す)。
Future<Uint8List> _renderSampleStatementScreenshotImage() =>
    _renderTextLinesImage(
      lines: const [
        (text: 'カシャカード ご利用明細', fontSize: 34.0),
        (text: '2026年8月分', fontSize: 26.0),
        (text: '------------------------------', fontSize: 26.0),
        (text: '2026/08/14  Amazon.co.jp         ¥3,980', fontSize: 26.0),
        (text: '2026/08/15  モバイルSuica チャージ  ¥3,000', fontSize: 26.0),
        (text: '2026/08/16  鳥貴族 三軒茶屋店      ¥4,230', fontSize: 26.0),
        (text: '------------------------------', fontSize: 26.0),
        (text: 'ご利用合計              ¥11,210', fontSize: 34.0),
      ],
    );

/// 文字行を縦に並べた画像 (レシート・明細スクショ風) を描画して PNG にする。
/// アセットを持たずにその場で描く。冪等 (同じ内容の画像を返す)。
Future<Uint8List> _renderTextLinesImage({
  required List<({String text, double fontSize})> lines,
}) async {
  const imageWidth = 600.0;
  const imageHeight = 900.0;
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      Paint()..color = const Color(0xFFFAF8F2),
    );
  var textTop = 40.0;
  for (final line in lines) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: line.text,
        style: TextStyle(
          fontSize: line.fontSize,
          color: const Color(0xFF1E1E1E),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imageWidth - 80);
    textPainter.paint(canvas, Offset(40, textTop));
    textTop += line.fontSize + 14;
  }

  final renderedImage = await pictureRecorder.endRecording().toImage(
    imageWidth.toInt(),
    imageHeight.toInt(),
  );
  final pngByteData = await renderedImage.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return pngByteData!.buffer.asUint8List();
}

/// 動作確認用のサンプル明細を今月の日付で書き込む。
///
/// 冪等ではない: AddTransaction が自動生成 ID で毎回新規ドキュメントを作るため、
/// 実行のたびに 5 件追加される (開発時のデータ投入用途なので許容する)。
Future<void> _addSampleTransactions({
  required AddTransaction addTransaction,
}) async {
  final now = DateTime.now();
  final samples = [
    (
      type: TransactionType.income,
      amount: 280000,
      category: TransactionCategory.salary,
      title: '給与',
      excludedFromAggregation: false,
    ),
    (
      type: TransactionType.expense,
      amount: 3480,
      category: TransactionCategory.food,
      title: 'スーパーマーケット',
      excludedFromAggregation: false,
    ),
    (
      type: TransactionType.expense,
      amount: 880,
      category: TransactionCategory.dailyGoods,
      title: 'ドラッグストア',
      excludedFromAggregation: false,
    ),
    (
      type: TransactionType.expense,
      amount: 460,
      category: TransactionCategory.transportation,
      title: '電車',
      excludedFromAggregation: false,
    ),
    // デザインの重複候補の例 (鳥貴族 ¥4,230) に合わせた計算対象外サンプル。
    (
      type: TransactionType.expense,
      amount: 4230,
      category: TransactionCategory.eatingOut,
      title: '鳥貴族 三軒茶屋店 (重複疑い)',
      excludedFromAggregation: true,
    ),
  ];
  for (final (index, sample) in samples.indexed) {
    await addTransaction.call(
      type: sample.type,
      source: TransactionSource.manual,
      amount: sample.amount,
      category: sample.category,
      title: sample.title,
      // 一覧の並び (transactionDate 降順) を確認できるよう日付をずらす。
      // 月初に実行しても前月へはみ出さないよう 1 日で下限を打ち切る。
      transactionDate: DateTime(
        now.year,
        now.month,
        (now.day - index).clamp(1, now.day),
        12,
      ),
      excludedFromAggregation: sample.excludedFromAggregation,
      sourceImageObjectKey: null,
      analysisAdjustedByUser: false,
    );
  }
}
