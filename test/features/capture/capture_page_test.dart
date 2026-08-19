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
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/transaction.dart';

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

/// Firestore へ書き込まず、登録された値を記録する AddTransaction。
class RecordingAddTransaction implements AddTransaction {
  /// 登録の呼び出し回数。
  int callCount = 0;

  /// 登録された種別。
  TransactionType? type;

  /// 登録された出所。
  TransactionSource? source;

  /// 登録された金額。
  int? amount;

  /// 登録されたカテゴリ。
  TransactionCategory? category;

  /// 登録された表示名。
  String? title;

  /// 登録された取引日。
  DateTime? transactionDate;

  /// 登録された集計除外フラグ。
  bool? excludedFromAggregation;

  /// 登録された元画像のオブジェクトキー。
  String? sourceImageObjectKey;

  /// 登録された AI 解析結果の修正有無。
  bool? analysisAdjustedByUser;

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
    callCount++;
    this.type = type;
    this.source = source;
    this.amount = amount;
    this.category = category;
    this.title = title;
    this.transactionDate = transactionDate;
    this.excludedFromAggregation = excludedFromAggregation;
    this.sourceImageObjectKey = sourceImageObjectKey;
    this.analysisAdjustedByUser = analysisAdjustedByUser;
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: captureFakes.overrides,
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

    expect(captureFakes.addTransaction.callCount, 1);
    expect(captureFakes.addTransaction.type, TransactionType.expense);
    expect(captureFakes.addTransaction.source, TransactionSource.receipt);
    expect(captureFakes.addTransaction.amount, 1280);
    expect(captureFakes.addTransaction.category, TransactionCategory.food);
    expect(captureFakes.addTransaction.title, 'Corner Market');
    expect(captureFakes.addTransaction.transactionDate, DateTime(2026, 8, 16));
    expect(captureFakes.addTransaction.excludedFromAggregation, false);
    expect(
      captureFakes.addTransaction.sourceImageObjectKey,
      uploadedImageObjectKey,
    );
    // 初期値から変えていないので手調整ではない
    expect(captureFakes.addTransaction.analysisAdjustedByUser, false);
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
      captureFakes.addTransaction.title,
      AppLocalizationsEn().manualEntryDefaultTitle,
    );
    expect(captureFakes.addTransaction.analysisAdjustedByUser, false);
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
      captureFakes.addTransaction.transactionDate,
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
    expect(captureFakes.addTransaction.type, TransactionType.income);
    expect(captureFakes.addTransaction.category, TransactionCategory.salary);
    expect(captureFakes.addTransaction.analysisAdjustedByUser, true);
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

    expect(captureFakes.addTransaction.title, 'Neighborhood store');
    expect(captureFakes.addTransaction.analysisAdjustedByUser, true);
    expect(
      captureFakes.addTransaction.sourceImageObjectKey,
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

    expect(captureFakes.addTransaction.amount, 980);
    expect(captureFakes.addTransaction.source, TransactionSource.receipt);
    // 店名未入力は手動入力と同じ既定の表示名になる
    expect(
      captureFakes.addTransaction.title,
      AppLocalizationsEn().manualEntryDefaultTitle,
    );
    // 全項目がユーザー入力なので常に手調整
    expect(captureFakes.addTransaction.analysisAdjustedByUser, true);
    // アップロードは成功しているので元画像は明細に紐づく
    expect(
      captureFakes.addTransaction.sourceImageObjectKey,
      uploadedImageObjectKey,
    );
    expect(captureFlowResults, [CaptureFlowResult.registered]);
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
    expect(captureFakes.addTransaction.callCount, 0);
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
    expect(captureFakes.addTransaction.callCount, 0);
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
}
