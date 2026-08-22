// 撮影フロー画面 (CapturePage) の Widget テスト。
// アップロード・解析・画像削除・明細登録は Provider を fake に差し替え、
// 解析成功・解析失敗 (再試行 / 手動入力 / 取り直し) の各分岐で
// 画面の表示と登録内容 (出所・元画像のキー・手調整の記録) を検証する。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/capture/capture_page.dart';
import 'package:kashakeibo/features/capture/image_analysis_client.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// 1x1 の透過 PNG。Image.memory がデコードできる有効な画像として使う。
final testImageBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

/// アップロード後に Worker が返すオブジェクトキー。
const uploadedImageObjectKey = 'users/user-id/uuid.png';

/// 解析結果 1 件を返す。
ImageAnalysisResult buildImageAnalysisResult() => const ImageAnalysisResult(
  transactions: [
    AnalyzedTransaction(
      title: 'Corner Market',
      amount: 1280,
      transactionDate: '2026-08-16',
      type: TransactionType.expense,
      category: TransactionCategory.food,
    ),
  ],
);

/// 1 枚のスクショから複数の明細が読み取れた解析結果を返す。
ImageAnalysisResult buildMultipleImageAnalysisResult() =>
    const ImageAnalysisResult(
      transactions: [
        AnalyzedTransaction(
          title: 'Corner Market',
          amount: 1280,
          transactionDate: '2026-08-16',
          type: TransactionType.expense,
          category: TransactionCategory.food,
        ),
        AnalyzedTransaction(
          title: 'Metro Card',
          amount: 500,
          transactionDate: '2026-08-15',
          type: TransactionType.expense,
          category: TransactionCategory.transportation,
        ),
        AnalyzedTransaction(
          title: 'Coffee Stand',
          amount: 380,
          transactionDate: '2026-08-14',
          type: TransactionType.expense,
          category: TransactionCategory.eatingOut,
        ),
      ],
    );

/// AddTransaction に渡された 1 回分の登録内容。
typedef AddTransactionCall = ({
  TransactionType type,
  TransactionSource source,
  int amount,
  TransactionCategory category,
  String title,
  DateTime transactionDate,
  bool excludedFromAggregation,
  String? sourceImageObjectKey,
  bool analysisAdjustedByUser,
});

/// Firestore へ書き込まず、登録された値を呼ばれた順に記録する AddTransaction。
class RecordingAddTransaction implements AddTransaction {
  /// 登録の記録 (呼ばれた順)。
  final List<AddTransactionCall> calls = [];

  /// 登録のたびに記録の前に呼ばれる処理。例外を投げるとその登録が失敗する
  /// (複数明細の途中失敗の検証で差し替える)。
  Future<void> Function({required int callIndex})? onCall;

  @override
  String get userID => 'user-id';

  @override
  Future<void> call({
    required TransactionType type,
    required TransactionSource source,
    required int amount,
    required TransactionCategory category,
    required String title,
    required DateTime transactionDate,
    required bool excludedFromAggregation,
    required String? sourceImageObjectKey,
    required bool analysisAdjustedByUser,
  }) async {
    await onCall?.call(callIndex: calls.length);
    calls.add((
      type: type,
      source: source,
      amount: amount,
      category: category,
      title: title,
      transactionDate: transactionDate,
      excludedFromAggregation: excludedFromAggregation,
      sourceImageObjectKey: sourceImageObjectKey,
      analysisAdjustedByUser: analysisAdjustedByUser,
    ));
  }
}

/// アップロード・解析・画像削除・登録の呼び出しを記録する fake 一式。
class CaptureFakes {
  /// 解析結果を返す処理。例外を投げれば解析失敗の分岐になる。
  final Future<ImageAnalysisResult> Function() analyze;

  /// アップロードされた画像のバイト列と Content-Type。
  final List<String> uploadedImageContentTypes = [];

  /// 解析に渡されたオブジェクトキー。
  final List<String> analyzedImageObjectKeys = [];

  /// 削除されたオブジェクトキー。
  final List<String> deletedImageObjectKeys = [];

  /// 明細の登録記録。
  final RecordingAddTransaction addTransaction = RecordingAddTransaction();

  CaptureFakes({required this.analyze});

  /// CapturePage が依存する Provider の差し替え一式。
  List<Override> get overrides => [
    uploadCapturedImageProvider.overrideWithValue(({
      required imageBytes,
      required imageContentType,
      required uploadImageID,
    }) async {
      uploadedImageContentTypes.add(imageContentType);
      return uploadedImageObjectKey;
    }),
    analyzeUploadedImageProvider.overrideWithValue(({
      required imageObjectKey,
    }) async {
      analyzedImageObjectKeys.add(imageObjectKey);
      return analyze();
    }),
    deleteStoredImageProvider.overrideWithValue(({
      required imageObjectKey,
    }) async {
      deletedImageObjectKeys.add(imageObjectKey);
    }),
    addTransactionProvider.overrideWithValue(addTransaction),
  ];
}

/// CapturePage を push して開き、終了理由 (pop の戻り値) を [captureFlowResults] に記録する。
///
/// 解析中は脈打つアニメーションと Timer.periodic が動き pumpAndSettle が返らないため、
/// 固定回数の pump で解析完了まで進める。
Future<void> openCapturePage({
  required WidgetTester tester,
  required CaptureFakes captureFakes,
  required List<CaptureFlowResult?> captureFlowResults,
  required List<String> analyticsEvents,
  // 既定はレシート撮影経路。スクショ (複数明細) の検証だけが screenshot を渡す。
  TransactionSource transactionSource = TransactionSource.receipt,
  // 無料枠超過 → ペイウォールの分岐だけが使う課金 Provider の差し替え
  List<Override> purchaseOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...captureFakes.overrides, ...purchaseOverrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => captureFlowResults.add(
                  await showCapturePage(
                    context: context,
                    imageBytes: testImageBytes,
                    imageContentType: 'image/png',
                    transactionSource: transactionSource,
                    logAnalyticsEvent: ({required name, parameters}) async {
                      analyticsEvents.add(name);
                    },
                  ),
                ),
                child: const Text('open capture'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open capture'));
  await pumpUntilAnalysisFinished(tester: tester);
}

/// アップロード → 解析が終わるまでフレームを進める。
Future<void> pumpUntilAnalysisFinished({required WidgetTester tester}) async {
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  /// フォーム全体が 1 画面に収まるようにして、スクロール操作なしで検証できるようにする。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('解析成功: 解析結果が確認フォームの初期値になり、そのまま登録すると自動取込として保存する', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
    );
    await tester.pumpAndSettle();

    // アップロードしたキーがそのまま解析に渡る
    expect(captureFakes.uploadedImageContentTypes, ['image/png']);
    expect(captureFakes.analyzedImageObjectKeys, [uploadedImageObjectKey]);

    // 確認フォームに解析結果が初期値として入る
    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Corner Market'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1280'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Food'))
          .selected,
      isTrue,
    );

    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();

    expect(captureFakes.addTransaction.calls.length, 1);
    expect(
      captureFakes.addTransaction.calls.single.type,
      TransactionType.expense,
    );
    expect(
      captureFakes.addTransaction.calls.single.source,
      TransactionSource.receipt,
    );
    expect(captureFakes.addTransaction.calls.single.amount, 1280);
    expect(
      captureFakes.addTransaction.calls.single.category,
      TransactionCategory.food,
    );
    expect(captureFakes.addTransaction.calls.single.title, 'Corner Market');
    expect(
      captureFakes.addTransaction.calls.single.transactionDate,
      DateTime(2026, 8, 16),
    );
    expect(
      captureFakes.addTransaction.calls.single.excludedFromAggregation,
      false,
    );
    expect(
      captureFakes.addTransaction.calls.single.sourceImageObjectKey,
      uploadedImageObjectKey,
    );
    // 初期値から変えていないので手調整ではない
    expect(
      captureFakes.addTransaction.calls.single.analysisAdjustedByUser,
      false,
    );
    expect(captureFlowResults, [CaptureFlowResult.registered]);
    expect(captureFakes.deletedImageObjectKeys, isEmpty);
  });

  testWidgets('解析成功: 店名が読み取れず空のまま既定タイトルで登録しても手調整にしない', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => const ImageAnalysisResult(
        transactions: [
          AnalyzedTransaction(
            title: '',
            amount: 500,
            transactionDate: '2026-08-16',
            type: TransactionType.expense,
            category: TransactionCategory.food,
          ),
        ],
      ),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();

    // 空の店名は既定タイトルで補完されるが、ユーザーは修正していないので自動取込のまま
    expect(
      captureFakes.addTransaction.calls.single.title,
      AppLocalizationsEn().manualEntryDefaultTitle,
    );
    expect(
      captureFakes.addTransaction.calls.single.analysisAdjustedByUser,
      false,
    );
  });

  testWidgets('解析日が日付ピッカーの範囲外なら今日を初期値にする', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => const ImageAnalysisResult(
        transactions: [
          AnalyzedTransaction(
            title: 'Corner Market',
            amount: 500,
            transactionDate: '1900-01-01',
            type: TransactionType.expense,
            category: TransactionCategory.food,
          ),
        ],
      ),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();

    expect(
      captureFakes.addTransaction.calls.single.transactionDate,
      DateUtils.dateOnly(DateTime.now()),
    );
  });

  testWidgets('収支種別を切り替えると、新しい種別で選べないカテゴリは既定カテゴリへ寄せる', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
    );
    await tester.pumpAndSettle();

    // 支出・食費 → 収入へ切り替えると、食費は収入で選べないため給与になる
    await tester.tap(find.text(AppLocalizationsEn().monthlyIncome));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(
              ChoiceChip,
              AppLocalizationsEn().categorySalary,
            ),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();
    expect(
      captureFakes.addTransaction.calls.single.type,
      TransactionType.income,
    );
    expect(
      captureFakes.addTransaction.calls.single.category,
      TransactionCategory.salary,
    );
    expect(
      captureFakes.addTransaction.calls.single.analysisAdjustedByUser,
      true,
    );
  });

  testWidgets('解析成功: 初期値を書き換えて登録すると手調整として保存する', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: <String>[],
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Corner Market'),
      'Neighborhood store',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();

    expect(
      captureFakes.addTransaction.calls.single.title,
      'Neighborhood store',
    );
    expect(
      captureFakes.addTransaction.calls.single.analysisAdjustedByUser,
      true,
    );
    expect(
      captureFakes.addTransaction.calls.single.sourceImageObjectKey,
      uploadedImageObjectKey,
    );
    expect(captureFlowResults, [CaptureFlowResult.registered]);
  });

  testWidgets('解析失敗: エラー文をそのまま表示し、手動入力の空フォームから登録できる', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => throw StateError('解析エンドポイントが混み合っています'),
    );
    final captureFlowResults = <CaptureFlowResult?>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: <String>[],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().captureAnalysisFailedTitle),
      findsOneWidget,
    );
    // エラーメッセージは加工せずそのまま表示する
    expect(
      find.text(StateError('解析エンドポイントが混み合っています').toString()),
      findsOneWidget,
    );

    await tester.tap(find.text(AppLocalizationsEn().captureManualFallback));
    await tester.pumpAndSettle();

    // 空のフォームになる (店名・金額とも未入力)
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.widgetWithText(
                TextFormField,
                AppLocalizationsEn().manualEntryStore,
              ),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      isEmpty,
    );

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        AppLocalizationsEn().manualEntryAmount,
      ),
      '980',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureRegister));
    await tester.pumpAndSettle();

    expect(captureFakes.addTransaction.calls.single.amount, 980);
    expect(
      captureFakes.addTransaction.calls.single.source,
      TransactionSource.receipt,
    );
    // 店名未入力は手動入力と同じ既定の表示名になる
    expect(
      captureFakes.addTransaction.calls.single.title,
      AppLocalizationsEn().manualEntryDefaultTitle,
    );
    // 全項目がユーザー入力なので常に手調整
    expect(
      captureFakes.addTransaction.calls.single.analysisAdjustedByUser,
      true,
    );
    // アップロードは成功しているので元画像は明細に紐づく
    expect(
      captureFakes.addTransaction.calls.single.sourceImageObjectKey,
      uploadedImageObjectKey,
    );
    expect(captureFlowResults, [CaptureFlowResult.registered]);
  });

  testWidgets('無料枠超過 (402): ペイウォールを開き、購入でプレミアムになると同じ画像で解析をやり直す', (
    tester,
  ) async {
    useTallViewport(tester);
    var analyzeCallCount = 0;
    final captureFakes = CaptureFakes(
      analyze: () async {
        analyzeCallCount++;
        if (analyzeCallCount == 1) {
          throw const ScanQuotaExceededException(
            message: '今月の無料スキャン (50回) を使い切りました',
            scanQuota: ScanQuota(
              monthlyScanCount: 50,
              monthlyFreeScanLimit: 50,
            ),
          );
        }
        return buildImageAnalysisResult();
      },
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];
    final annualPackage = Package(
      r'$rc_annual',
      PackageType.annual,
      const StoreProduct(
        'kashakeibo_premium_annual_3800yen',
        '',
        'Premium',
        3800,
        '¥3,800',
        'JPY',
      ),
      const PresentedOfferingContext('default', null, null),
    );

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
      purchaseOverrides: [
        firebaseUserChangesProvider.overrideWith((ref) => Stream.value(null)),
        fetchScanQuotaProvider.overrideWithValue(
          () async =>
              const ScanQuota(monthlyScanCount: 50, monthlyFreeScanLimit: 50),
        ),
        isPremiumProvider.overrideWithValue(false),
        premiumOfferingProvider.overrideWith(
          (ref) async => Offering('default', '', const {}, [
            annualPackage,
          ], annual: annualPackage),
        ),
        purchasePremiumPackageProvider.overrideWithValue(
          ({required package}) async => true,
        ),
        restorePurchasesProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    // 失敗表示の上にペイウォールが開く
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);
    expect(analyticsEvents, contains('capture_scan_quota_exceeded'));

    await tester.tap(find.text(AppLocalizationsEn().paywallStartPremium));
    await pumpUntilAnalysisFinished(tester: tester);
    await tester.pumpAndSettle();

    // ペイウォールが閉じ、同じアップロード済みキーで解析だけをやり直して確認フォームに進む
    expect(find.text(AppLocalizationsEn().paywallTitle), findsNothing);
    expect(analyzeCallCount, 2);
    expect(captureFakes.uploadedImageContentTypes, hasLength(1));
    expect(captureFakes.analyzedImageObjectKeys, [
      uploadedImageObjectKey,
      uploadedImageObjectKey,
    ]);
    expect(find.text(AppLocalizationsEn().captureConfirmTitle), findsOneWidget);
  });

  testWidgets('無料枠超過 (402): ペイウォールを閉じると失敗表示に戻り、手動入力・取り直しを選べる', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => throw const ScanQuotaExceededException(
        message: '今月の無料スキャン (50回) を使い切りました',
        scanQuota: ScanQuota(monthlyScanCount: 50, monthlyFreeScanLimit: 50),
      ),
    );

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: <CaptureFlowResult?>[],
      analyticsEvents: <String>[],
      purchaseOverrides: [
        firebaseUserChangesProvider.overrideWith((ref) => Stream.value(null)),
        fetchScanQuotaProvider.overrideWithValue(
          () async =>
              const ScanQuota(monthlyScanCount: 50, monthlyFreeScanLimit: 50),
        ),
        isPremiumProvider.overrideWithValue(false),
        premiumOfferingProvider.overrideWith((ref) async => null),
        purchasePremiumPackageProvider.overrideWithValue(
          ({required package}) async => false,
        ),
        restorePurchasesProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsEn().paywallTitle), findsOneWidget);

    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsEn().paywallTitle), findsNothing);
    expect(
      find.text(AppLocalizationsEn().captureAnalysisFailedTitle),
      findsOneWidget,
    );
    // Worker のエラー文をそのまま表示する
    expect(find.text('今月の無料スキャン (50回) を使い切りました'), findsOneWidget);
    expect(
      find.text(AppLocalizationsEn().captureManualFallback),
      findsOneWidget,
    );
    expect(find.text(AppLocalizationsEn().captureRetake), findsOneWidget);
  });

  testWidgets('解析失敗: 「もう一度読み取る」で解析だけを再実行する (アップロードはやり直さない)', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => throw StateError('解析エンドポイントが混み合っています'),
    );

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: <CaptureFlowResult?>[],
      analyticsEvents: <String>[],
    );
    await tester.pumpAndSettle();

    expect(captureFakes.analyzedImageObjectKeys, hasLength(1));

    await tester.tap(find.text(AppLocalizationsEn().captureRetry));
    await pumpUntilAnalysisFinished(tester: tester);
    await tester.pumpAndSettle();

    expect(captureFakes.analyzedImageObjectKeys, [
      uploadedImageObjectKey,
      uploadedImageObjectKey,
    ]);
    // 同じ画像を使い回すのでアップロードは 1 回のまま
    expect(captureFakes.uploadedImageContentTypes, hasLength(1));
    expect(
      find.text(AppLocalizationsEn().captureAnalysisFailedTitle),
      findsOneWidget,
    );
  });

  testWidgets('解析結果が空の画像は解析失敗として扱う', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => const ImageAnalysisResult(transactions: []),
    );

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: <CaptureFlowResult?>[],
      analyticsEvents: <String>[],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().captureAnalysisFailedTitle),
      findsOneWidget,
    );
    expect(
      find.textContaining(AppLocalizationsEn().captureAnalysisNoTransactions),
      findsOneWidget,
    );
    expect(captureFakes.addTransaction.calls.length, 0);
  });

  testWidgets('「取り直す」はアップロード済み画像を削除して retake で閉じる', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: <String>[],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().captureRetake));
    await tester.pumpAndSettle();

    expect(captureFakes.deletedImageObjectKeys, [uploadedImageObjectKey]);
    expect(captureFlowResults, [CaptureFlowResult.retake]);
    expect(captureFakes.addTransaction.calls.length, 0);
  });

  testWidgets('閉じる (X) はアップロード済み画像を削除して cancelled で閉じる', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(captureFakes.deletedImageObjectKeys, [uploadedImageObjectKey]);
    expect(captureFlowResults, [CaptureFlowResult.cancelled]);
    expect(analyticsEvents, contains('capture_cancel'));
  });

  testWidgets('複数明細: 候補リストで 1 件を破棄して登録すると、採用した候補だけスクショの出所で保存する', (
    tester,
  ) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildMultipleImageAnalysisResult(),
    );
    final captureFlowResults = <CaptureFlowResult?>[];
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: analyticsEvents,
      transactionSource: TransactionSource.screenshot,
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppLocalizationsEn().captureCandidatesNote(3)),
      findsOneWidget,
    );
    // 既定は全件採用
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(
      find.text(AppLocalizationsEn().captureRegisterCount(3)),
      findsOneWidget,
    );

    // 2 件目 (Metro Card) のチェックを外して破棄する
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(analyticsEvents, contains('capture_candidate_toggle'));

    await tester.tap(find.text(AppLocalizationsEn().captureRegisterCount(2)));
    await tester.pumpAndSettle();

    expect(captureFakes.addTransaction.calls.map((call) => call.title), [
      'Corner Market',
      'Coffee Stand',
    ]);
    // 同じ画像から読み取った候補は出所も元画像のキーも共有する
    expect(
      captureFakes.addTransaction.calls.map((call) => call.source),
      everyElement(TransactionSource.screenshot),
    );
    expect(
      captureFakes.addTransaction.calls.map(
        (call) => call.sourceImageObjectKey,
      ),
      everyElement(uploadedImageObjectKey),
    );
    // 修正していない候補は手調整ではない
    expect(
      captureFakes.addTransaction.calls.map(
        (call) => call.analysisAdjustedByUser,
      ),
      everyElement(false),
    );
    expect(
      captureFakes.addTransaction.calls.first.transactionDate,
      DateTime(2026, 8, 16),
    );
    expect(captureFlowResults, [CaptureFlowResult.registered]);
  });

  testWidgets('複数明細: 修正シートで書き換えた候補だけ手調整として保存する', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildMultipleImageAnalysisResult(),
    );
    final analyticsEvents = <String>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: <CaptureFlowResult?>[],
      analyticsEvents: analyticsEvents,
      transactionSource: TransactionSource.screenshot,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(analyticsEvents, contains('capture_candidate_edit'));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Corner Market'),
      'Neighborhood store',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureCandidateApplyEdit));
    await tester.pumpAndSettle();

    // 修正した内容が候補カードに反映される
    expect(find.text('Neighborhood store'), findsOneWidget);

    await tester.tap(find.text(AppLocalizationsEn().captureRegisterCount(3)));
    await tester.pumpAndSettle();

    expect(captureFakes.addTransaction.calls.map((call) => call.title), [
      'Neighborhood store',
      'Metro Card',
      'Coffee Stand',
    ]);
    expect(
      captureFakes.addTransaction.calls.map(
        (call) => call.analysisAdjustedByUser,
      ),
      [true, false, false],
    );
  });

  testWidgets('複数明細: 登録の途中で失敗するとエラーを表示し、登録済みの候補は再登録しない', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildMultipleImageAnalysisResult(),
    );
    // 2 件目 (Metro Card) の登録だけ失敗させる
    captureFakes.addTransaction.onCall = ({required callIndex}) async {
      if (callIndex == 1) {
        throw StateError('明細の登録に失敗しました');
      }
    };
    final captureFlowResults = <CaptureFlowResult?>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: <String>[],
      transactionSource: TransactionSource.screenshot,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppLocalizationsEn().captureRegisterCount(3)));
    await tester.pumpAndSettle();

    // エラーメッセージは加工せずそのまま表示する
    expect(find.text(StateError('明細の登録に失敗しました').toString()), findsOneWidget);
    expect(captureFakes.addTransaction.calls.map((call) => call.title), [
      'Corner Market',
    ]);
    // 登録済みの候補はリストから消え、残りだけを再登録できる
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(captureFlowResults, isEmpty);

    captureFakes.addTransaction.onCall = null;
    await tester.tap(find.text(AppLocalizationsEn().captureRegisterCount(2)));
    await tester.pumpAndSettle();

    expect(captureFakes.addTransaction.calls.map((call) => call.title), [
      'Corner Market',
      'Metro Card',
      'Coffee Stand',
    ]);
    expect(captureFlowResults, [CaptureFlowResult.registered]);
  });

  testWidgets('複数明細: 一部を登録した後に閉じても、登録済み明細が参照する元画像は削除しない', (tester) async {
    useTallViewport(tester);
    final captureFakes = CaptureFakes(
      analyze: () async => buildMultipleImageAnalysisResult(),
    );
    // 2 件目の登録だけ失敗させ、1 件目が登録済みの状態で止める
    captureFakes.addTransaction.onCall = ({required callIndex}) async {
      if (callIndex == 1) {
        throw StateError('明細の登録に失敗しました');
      }
    };
    final captureFlowResults = <CaptureFlowResult?>[];

    await openCapturePage(
      tester: tester,
      captureFakes: captureFakes,
      captureFlowResults: captureFlowResults,
      analyticsEvents: <String>[],
      transactionSource: TransactionSource.screenshot,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().captureRegisterCount(3)));
    await tester.pumpAndSettle();
    expect(captureFakes.addTransaction.calls, hasLength(1));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(captureFlowResults, [CaptureFlowResult.cancelled]);
    expect(captureFakes.deletedImageObjectKeys, isEmpty);
  });
}
