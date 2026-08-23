// 明細検索画面 (TransactionSearchPage) のレイアウトの Widget テスト。
// 検索フォームと結果を1つのスクロールに載せているため、キーボードで表示領域が縮んでも
// overflow せず、フォームの下端 (検索ボタン・無料プランの注記) までスクロールで届くことを検証する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_limit.dart';
import 'package:kashakeibo/features/transaction_search/transaction_search_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction_search.dart';

/// Analytics を必要としないウィジェットテスト用の記録処理。
Future<void> discardAnalyticsEvent({
  required String name,
  Map<String, Object>? parameters,
}) async {}

/// 外部ブラウザを開かないウィジェットテスト用の処理。
Future<void> discardOpenExternalUri({required Uri uri}) async {}

/// 未検索 (条件なし) の検索を、Firestore を経由せず空の結果に差し替える。
///
/// 画面が渡す下限は無料プランの月初のため、テスト側も同じ値で family を特定する。
Override emptySearchResultOverride() => searchedTransactionsProvider(
  transactionDateFrom: null,
  transactionDateTo: null,
  minimumAmount: null,
  maximumAmount: null,
  titleKeyword: null,
  oldestSearchableTransactionDate: oldestFreePlanHistoryDateTime(
    now: DateTime.now(),
  ),
).overrideWith((ref) => Stream.value(const []));

void main() {
  testWidgets('検索画面: キーボードで表示領域が縮んでも overflow せず、フォームの下端までスクロールできる', (
    tester,
  ) async {
    // 縦 320 は、iPhone でソフトウェアキーボードが出た時に本文へ残る高さの目安。
    await tester.binding.setSurfaceSize(const Size(390, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emptySearchResultOverride(),
          isPremiumProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TransactionSearchPage(
            openExternalUri: discardOpenExternalUri,
            logAnalyticsEvent: discardAnalyticsEvent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizationsEn();
    // 未検索の案内は、フォームの下までスクロールしないと見えない位置にある。
    // 金額入力欄も Scrollable を持つため、画面全体のスクロール (最も外側) を指定する。
    await tester.scrollUntilVisible(
      find.text(l10n.transactionSearchConditionRequired),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    // 検索ボタンの文言は AppBar のタイトルと同じため、ボタンごと指定して探す。
    expect(
      find.widgetWithText(FilledButton, l10n.transactionSearchSubmit),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.transactionSearchFreePlanHistoryLimit(freePlanHistoryMonthCount),
      ),
      findsOneWidget,
    );
  });
}
