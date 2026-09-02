// 明細詳細画面 (TransactionDetailPage) の Widget テスト。
// 明細の購読・元画像の取得・更新/削除の各機能 Provider を fake に差し替え、
// 表示 (金額・店名・出所チップ・元画像) と操作 (除外スイッチ・画像だけの削除・明細の削除) を検証する。
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/transaction_detail/transaction_detail_page.dart';
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

/// テスト対象の明細 ID。
const testTransactionID = 'tx-1';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required TransactionSource source,
  required String? sourceImageObjectKey,
  required bool analysisAdjustedByUser,
  required List<String> analysisInstructions,
  required bool excludedFromAggregation,
}) => Transaction(
  id: testTransactionID,
  userID: 'user-id',
  type: TransactionType.expense,
  source: source,
  amount: 1280,
  category: TransactionCategory.food,
  title: 'スーパーマーケット',
  transactionDate: DateTime(2026, 8, 16, 12),
  transactionDateTimeZoneOffsetMinutes: null,
  yearMonth: '2026-08',
  excludedFromAggregation: excludedFromAggregation,
  sourceImageObjectKey: sourceImageObjectKey,
  analysisAdjustedByUser: analysisAdjustedByUser,
  analysisInstructions: analysisInstructions,
);

/// Firestore へ書き込まず、除外フラグの更新呼び出しを記録する。
class RecordingUpdateTransactionExclusion extends UpdateTransactionExclusion {
  RecordingUpdateTransactionExclusion()
    : super(firebaseFirestore: FakeFirebaseFirestore());

  /// 更新に渡された除外フラグ。
  final List<bool> updatedExclusions = [];

  @override
  Future<void> call({
    required Transaction transaction,
    required bool excludedFromAggregation,
  }) async {
    updatedExclusions.add(excludedFromAggregation);
  }
}

/// Firestore へ書き込まず、画像だけの削除呼び出しを記録する。
class RecordingRemoveTransactionSourceImage
    extends RemoveTransactionSourceImage {
  RecordingRemoveTransactionSourceImage()
    : super(
        firebaseFirestore: FakeFirebaseFirestore(),
        deleteStoredImage: ({required imageObjectKey}) async {},
      );

  /// 画像削除を要求された明細の ID。
  final List<String> removedTransactionIDs = [];

  @override
  Future<void> call({required Transaction transaction}) async {
    removedTransactionIDs.add(transaction.id);
  }
}

/// Firestore へ書き込まず、明細の削除呼び出しを記録する。
class RecordingDeleteTransaction extends DeleteTransaction {
  RecordingDeleteTransaction()
    : super(
        firebaseFirestore: FakeFirebaseFirestore(),
        deleteStoredImage: ({required imageObjectKey}) async {},
      );

  /// 削除を要求された明細の ID。
  final List<String> deletedTransactionIDs = [];

  @override
  Future<void> call({required Transaction transaction}) async {
    deletedTransactionIDs.add(transaction.id);
  }
}

/// 明細詳細画面が依存する Provider をすべて fake に差し替えて開き、
/// 画面が閉じたことを [closedPageCount] で観測できるようにする。
Future<void> openTransactionDetailPage({
  required WidgetTester tester,
  required Transaction transaction,
  required RecordingUpdateTransactionExclusion updateTransactionExclusion,
  required RecordingRemoveTransactionSourceImage removeTransactionSourceImage,
  required RecordingDeleteTransaction deleteTransaction,
  required List<String> fetchedImageObjectKeys,
  required List<void> closedPages,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionProvider(
          transactionID: testTransactionID,
        ).overrideWith((ref) => Stream.value(transaction)),
        fetchStoredImageProvider.overrideWithValue(({
          required imageObjectKey,
        }) async {
          fetchedImageObjectKeys.add(imageObjectKey);
          return testImageBytes;
        }),
        updateTransactionExclusionProvider.overrideWithValue(
          updateTransactionExclusion,
        ),
        removeTransactionSourceImageProvider.overrideWithValue(
          removeTransactionSourceImage,
        ),
        deleteTransactionProvider.overrideWithValue(deleteTransaction),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) => TransactionDetailPage(
                        transactionID: testTransactionID,
                        logAnalyticsEvent:
                            ({required name, parameters}) async {},
                      ),
                    ),
                  );
                  closedPages.add(null);
                },
                child: const Text('open detail'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open detail'));
  await tester.pumpAndSettle();
}

void main() {
  /// 画面全体が 1 画面に収まるようにして、スクロール操作なしで検証できるようにする。
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('自動取込の明細: 金額・店名・出所チップ (レシート / 自動取込) と元画像を表示する', (tester) async {
    useTallViewport(tester);
    final fetchedImageObjectKeys = <String>[];

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.receipt,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: false,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: fetchedImageObjectKeys,
      closedPages: <void>[],
    );

    expect(find.text('¥1,280', findRichText: true), findsOneWidget);
    expect(find.text('スーパーマーケット'), findsOneWidget);
    expect(
      find.text(AppLocalizationsEn().transactionSourceReceipt),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAutomatic),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAdjusted),
      findsNothing,
    );
    // 追加指示を出していない明細では指示の履歴を出さない
    expect(
      find.text(AppLocalizationsEn().transactionDetailAnalysisInstructions),
      findsNothing,
    );
    // 元画像は保存済みのオブジェクトキーで取得して表示する
    expect(fetchedImageObjectKeys, ['users/user-id/uuid.png']);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('解析結果を修正した明細は出所チップに手調整を表示する', (tester) async {
    useTallViewport(tester);

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.screenshot,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: true,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: <String>[],
      closedPages: <void>[],
    );

    expect(
      find.text(AppLocalizationsEn().transactionSourceScreenshot),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAdjusted),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAutomatic),
      findsNothing,
    );
  });

  testWidgets('撮影フローで AI へ追加指示を出した明細は、指示の履歴を出所の下に表示する', (tester) async {
    useTallViewport(tester);

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.screenshot,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: false,
        analysisInstructions: const ['一番下の明細が読めていない', '2件目の金額は税込で'],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: <String>[],
      closedPages: <void>[],
    );

    expect(
      find.text(AppLocalizationsEn().transactionDetailAnalysisInstructions),
      findsOneWidget,
    );
    expect(find.text('一番下の明細が読めていない'), findsOneWidget);
    expect(find.text('2件目の金額は税込で'), findsOneWidget);
  });

  testWidgets('手動入力の明細: 出所チップは手動のみで、元画像なしの案内を表示する', (tester) async {
    useTallViewport(tester);
    final fetchedImageObjectKeys = <String>[];

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.manual,
        sourceImageObjectKey: null,
        analysisAdjustedByUser: false,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: fetchedImageObjectKeys,
      closedPages: <void>[],
    );

    expect(
      find.text(AppLocalizationsEn().transactionSourceManual),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAutomatic),
      findsNothing,
    );
    expect(
      find.text(AppLocalizationsEn().transactionProvenanceAdjusted),
      findsNothing,
    );
    expect(
      find.text(AppLocalizationsEn().transactionDetailNoImageManual),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(fetchedImageObjectKeys, isEmpty);
    // 画像が無い明細には「画像だけを削除」を出さない
    expect(
      find.text(AppLocalizationsEn().transactionDetailDeleteImage),
      findsNothing,
    );
  });

  testWidgets('計算対象から除外するスイッチを入れると除外フラグを更新する', (tester) async {
    useTallViewport(tester);
    final updateTransactionExclusion = RecordingUpdateTransactionExclusion();

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.receipt,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: false,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: updateTransactionExclusion,
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: <String>[],
      closedPages: <void>[],
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(updateTransactionExclusion.updatedExclusions, [true]);
  });

  testWidgets('「画像だけを削除」は確認ダイアログで承諾した時だけ実行する', (tester) async {
    useTallViewport(tester);
    final removeTransactionSourceImage =
        RecordingRemoveTransactionSourceImage();

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.receipt,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: false,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: removeTransactionSourceImage,
      deleteTransaction: RecordingDeleteTransaction(),
      fetchedImageObjectKeys: <String>[],
      closedPages: <void>[],
    );

    // キャンセルした場合は削除しない
    await tester.tap(
      find.text(AppLocalizationsEn().transactionDetailDeleteImage),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        AppLocalizationsEn().transactionDetailDeleteImageConfirmationTitle,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().cancel));
    await tester.pumpAndSettle();
    expect(removeTransactionSourceImage.removedTransactionIDs, isEmpty);

    // 承諾した場合だけ削除する
    await tester.tap(
      find.text(AppLocalizationsEn().transactionDetailDeleteImage),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().delete));
    await tester.pumpAndSettle();

    expect(removeTransactionSourceImage.removedTransactionIDs, [
      testTransactionID,
    ]);
    expect(
      find.text(AppLocalizationsEn().transactionDetailImageDeleted),
      findsOneWidget,
    );
  });

  testWidgets('「明細を削除」は確認ダイアログで承諾すると明細を削除して画面を閉じる', (tester) async {
    useTallViewport(tester);
    final deleteTransaction = RecordingDeleteTransaction();
    final closedPages = <void>[];

    await openTransactionDetailPage(
      tester: tester,
      transaction: buildTransaction(
        source: TransactionSource.receipt,
        sourceImageObjectKey: 'users/user-id/uuid.png',
        analysisAdjustedByUser: false,
        analysisInstructions: const [],
        excludedFromAggregation: false,
      ),
      updateTransactionExclusion: RecordingUpdateTransactionExclusion(),
      removeTransactionSourceImage: RecordingRemoveTransactionSourceImage(),
      deleteTransaction: deleteTransaction,
      fetchedImageObjectKeys: <String>[],
      closedPages: closedPages,
    );

    // キャンセルした場合は削除も画面を閉じることもしない
    await tester.tap(find.text(AppLocalizationsEn().transactionDetailDelete));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().transactionDetailDeleteConfirmationTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(AppLocalizationsEn().cancel));
    await tester.pumpAndSettle();
    expect(deleteTransaction.deletedTransactionIDs, isEmpty);
    expect(closedPages, isEmpty);

    await tester.tap(find.text(AppLocalizationsEn().transactionDetailDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().delete));
    await tester.pumpAndSettle();

    expect(deleteTransaction.deletedTransactionIDs, [testTransactionID]);
    expect(closedPages, hasLength(1));
    expect(
      find.text(AppLocalizationsEn().transactionDetailTitle),
      findsNothing,
    );
  });
}
