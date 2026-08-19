import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/capture_page.dart';
import 'package:kashakeibo/features/paywall/paywall_page.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// DEBUG ビルド限定の開発者メニュー。
///
/// 到達困難な状態 (明細データの投入) を、起動引数ではなくアプリ内メニューから
/// 作れるようにする (~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md のパターン)。
/// DEBUG 限定のため文言は日本語固定で l10n の対象外とする。
class DebugSheet extends ConsumerWidget {
  const DebugSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addTransaction = ref.watch(addTransactionProvider);
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
                // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: SingleChildScrollView(
                      child: Text(error.toString()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('サンプルレシートで撮影フローを試す'),
            subtitle: const Text('端末カメラの無いシミュレータでも、描画したレシート画像で解析 → 確認 → 登録を通す'),
            onTap: () async {
              // シートを閉じてから撮影フロー画面を開くため、閉じる前に Navigator を確保する。
              final navigator = Navigator.of(context);
              final sampleReceiptImageBytes = await _renderSampleReceiptImage();
              if (!context.mounted) {
                return;
              }
              navigator.pop();
              final captureFlowResult = await navigator.push<CaptureFlowResult>(
                MaterialPageRoute<CaptureFlowResult>(
                  fullscreenDialog: true,
                  builder: (context) => CapturePage(
                    imageBytes: sampleReceiptImageBytes,
                    imageContentType: 'image/png',
                    logAnalyticsEvent: recordAnalyticsEvent,
                  ),
                ),
              );
              final navigatorContext = navigator.context;
              if (captureFlowResult == CaptureFlowResult.registered &&
                  navigatorContext.mounted) {
                showCaptureRegisteredToast(context: navigatorContext);
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
                  // アプリの ProviderScope とは独立した container で Offering・購入・復元だけを差し替える
                  // (入れ子の ProviderScope で override すると dependencies の宣言が要るため、独立 root にする)。
                  // 残量・プレミアム判定は実 Provider のまま
                  builder: (context) => UncontrolledProviderScope(
                    container: ProviderContainer(
                      overrides: [
                        premiumOfferingProvider.overrideWith(
                          (ref) async => _sampleOffering,
                        ),
                        purchasePremiumPackageProvider.overrideWithValue(
                          ({required package}) async => true,
                        ),
                        restorePurchasesProvider.overrideWithValue(
                          () async => false,
                        ),
                      ],
                    ),
                    child: PaywallPage(
                      openExternalUri: openExternalUri,
                      logAnalyticsEvent: recordAnalyticsEvent,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
Future<Uint8List> _renderSampleReceiptImage() async {
  const imageWidth = 600.0;
  const imageHeight = 900.0;
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      Paint()..color = const Color(0xFFFAF8F2),
    );
  var textTop = 40.0;
  void drawLine({required String text, double fontSize = 26}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: const Color(0xFF1E1E1E)),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imageWidth - 80);
    textPainter.paint(canvas, Offset(40, textTop));
    textTop += fontSize + 14;
  }

  drawLine(text: 'セブン-イレブン 三軒茶屋駅前店', fontSize: 34);
  drawLine(text: '東京都世田谷区三軒茶屋2-11-22');
  drawLine(text: '2026年08月16日(日) 12:34  レジ#3');
  drawLine(text: '------------------------------');
  drawLine(text: 'おにぎり 鮭            ¥150');
  drawLine(text: 'サンドイッチ           ¥398');
  drawLine(text: 'お茶 500ml            ¥140');
  drawLine(text: 'キャンディ            ¥120');
  drawLine(text: '------------------------------');
  drawLine(text: '小計                  ¥808');
  drawLine(text: '消費税(8%)             ¥64');
  drawLine(text: '合計                  ¥872', fontSize: 34);
  drawLine(text: 'お預り               ¥1,000');
  drawLine(text: 'お釣り                ¥128');
  drawLine(text: 'ありがとうございました');

  final receiptImage = await pictureRecorder.endRecording().toImage(
    imageWidth.toInt(),
    imageHeight.toInt(),
  );
  final pngByteData = await receiptImage.toByteData(
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
