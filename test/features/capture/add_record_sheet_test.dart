// 「記録する」シート (AddRecordSheet) の Widget テスト。
// 入力経路の 3 行が並び、タップで選ばれた経路が返ることを検証する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/features/capture/add_record_sheet.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';

/// 「記録する」シートを開き、選ばれた入力経路を [addRecordOptions] に記録する。
Future<void> openAddRecordSheet({
  required WidgetTester tester,
  required List<AddRecordOption?> addRecordOptions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => addRecordOptions.add(
                await showAddRecordSheet(context: context),
              ),
              child: const Text('open add record'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open add record'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('カメラで撮影・写真とスクショから選ぶ・手動で入力の 3 行を表示する', (tester) async {
    final addRecordOptions = <AddRecordOption?>[];

    await openAddRecordSheet(
      tester: tester,
      addRecordOptions: addRecordOptions,
    );

    expect(
      find.text(AppLocalizationsEn().captureReceiptWithCamera),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().capturePickFromPhotoLibrary),
      findsOneWidget,
    );
    expect(
      find.text(AppLocalizationsEn().capturePickFromPhotoLibraryDescription),
      findsOneWidget,
    );
    expect(find.text(AppLocalizationsEn().manualEntryOpen), findsOneWidget);
  });

  testWidgets('「写真・スクショから選ぶ」のタップで photoLibrary が返る', (tester) async {
    final addRecordOptions = <AddRecordOption?>[];

    await openAddRecordSheet(
      tester: tester,
      addRecordOptions: addRecordOptions,
    );
    await tester.tap(
      find.text(AppLocalizationsEn().capturePickFromPhotoLibrary),
    );
    await tester.pumpAndSettle();

    expect(addRecordOptions, [AddRecordOption.photoLibrary]);
  });

  testWidgets('「カメラで撮影」のタップで camera が返る', (tester) async {
    final addRecordOptions = <AddRecordOption?>[];

    await openAddRecordSheet(
      tester: tester,
      addRecordOptions: addRecordOptions,
    );
    await tester.tap(find.text(AppLocalizationsEn().captureReceiptWithCamera));
    await tester.pumpAndSettle();

    expect(addRecordOptions, [AddRecordOption.camera]);
  });
}
