import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/monthly/monthly_page.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_limit.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_notice.dart';
import 'package:kashakeibo/features/settings/settings_page.dart';
import 'package:kashakeibo/features/transaction_detail/transaction_detail_page.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:kashakeibo/provider/transaction_search.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 検索フォームで確定した検索条件。画面ローカルの状態で、Firestore へは
/// [searchedTransactionsProvider] の引数として渡す。
typedef _SearchCondition = ({
  DateTime? transactionDateFrom,
  DateTime? transactionDateTo,
  int? minimumAmount,
  int? maximumAmount,
  String? titleKeyword,
});

/// 未検索の状態 (条件なし)。この条件では Provider がクエリを発行せず空を返す。
const _SearchCondition _emptySearchCondition = (
  transactionDateFrom: null,
  transactionDateTo: null,
  minimumAmount: null,
  maximumAmount: null,
  titleKeyword: null,
);

/// 明細検索画面 (issue #73 の検索要件)。
///
/// 取引年月日 (範囲)・取引金額 (範囲)・取引先 (店名) で明細を検索し、
/// 結果を月次一覧と同じ行デザイン ([TransactionRow]) で取引日の新しい順に表示する。
/// 検索は「検索する」を押した時点の条件で実行し、入力のたびには実行しない
/// (入力中に Firestore のクエリを張り替えないため)。
/// 無料プランでは検索できる期間が制限され (features/paywall/free_plan_history_limit.dart)、
/// その旨の注記からペイウォールへ誘導する。
class TransactionSearchPage extends HookConsumerWidget {
  /// 利用規約・プライバシーポリシーを開く処理 (ペイウォールへ渡す)。
  final OpenExternalUri openExternalUri;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const TransactionSearchPage({
    required this.openExternalUri,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 入力中の条件 (フォームの状態)。検索の実行は searchCondition へ確定した時だけ行う。
    final transactionDateFrom = useState<DateTime?>(null);
    final transactionDateTo = useState<DateTime?>(null);
    final minimumAmountController = useTextEditingController();
    final maximumAmountController = useTextEditingController();
    final titleKeywordController = useTextEditingController();
    final searchCondition = useState(_emptySearchCondition);
    final validationMessage = useState<String?>(null);
    final isPremium = ref.watch(isPremiumProvider);
    // 画面を開いたまま月をまたいでも無料プランの下限が前月のまま残らないよう、次の月初に再ビルドする。
    // 依存配列は発火回数だけにして、再ビルドのたびに次の月初へ Timer を張り直す。
    // isPremium は下限を使うかどうかを変えるだけで月初の時刻を変えないため、依存に含めない。
    final monthBoundaryPassedCount = useState(0);
    useEffect(() {
      final monthBoundaryTimer = Timer(
        durationUntilNextMonthStart(now: DateTime.now()),
        () => monthBoundaryPassedCount.value++,
      );
      return monthBoundaryTimer.cancel;
    }, [monthBoundaryPassedCount.value]);
    final searchedTransactionsAsync = ref.watch(
      searchedTransactionsProvider(
        transactionDateFrom: searchCondition.value.transactionDateFrom,
        transactionDateTo: searchCondition.value.transactionDateTo,
        minimumAmount: searchCondition.value.minimumAmount,
        maximumAmount: searchCondition.value.maximumAmount,
        titleKeyword: searchCondition.value.titleKeyword,
        // 下限は月初の粒度のため、build のたびに DateTime.now() から計算し直しても同じ月の
        // あいだは同じ値になり、family のインスタンスが使い回される。月をまたいだ時
        // (monthBoundaryPassedCount の Timer が発火した時)・課金状態が変わった時だけ引数が変わり、
        // そのタイミングで検索し直される。
        oldestSearchableTransactionDate: isPremium
            ? null
            : oldestFreePlanHistoryDateTime(now: DateTime.now()),
      ),
    );
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;

    /// 入力中の条件を検証し、問題なければ検索条件として確定する。
    void submitSearch() {
      final selectedDateFrom = transactionDateFrom.value;
      final selectedDateTo = transactionDateTo.value;
      final minimumAmount = int.tryParse(minimumAmountController.text.trim());
      final maximumAmount = int.tryParse(maximumAmountController.text.trim());
      final titleKeyword = titleKeywordController.text.trim();
      if (selectedDateFrom != null &&
          selectedDateTo != null &&
          selectedDateTo.isBefore(selectedDateFrom)) {
        validationMessage.value = l10n.transactionSearchDateRangeInvalid;
        return;
      }
      if (minimumAmount != null &&
          maximumAmount != null &&
          maximumAmount < minimumAmount) {
        validationMessage.value = l10n.transactionSearchAmountRangeInvalid;
        return;
      }
      validationMessage.value = null;
      searchCondition.value = (
        transactionDateFrom: selectedDateFrom,
        // 終了日はその日いっぱいを含める (取引日時は時刻まで持つため)。
        transactionDateTo: selectedDateTo == null
            ? null
            : DateTime(
                selectedDateTo.year,
                selectedDateTo.month,
                selectedDateTo.day,
                23,
                59,
                59,
                999,
              ),
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        // 空欄は「条件なし」として扱い、未検索の状態 (_emptySearchCondition) と一致させる。
        titleKeyword: titleKeyword.isEmpty ? null : titleKeyword,
      );
    }

    /// 検索の全入力経路 (検索ボタン・各入力欄の検索キー) を1本化し、計測してから検索を確定する。
    void logAndSubmitSearch() {
      unawaited(logAnalyticsEvent(name: 'transaction_search_submit'));
      submitSearch();
    }

    /// 検索結果の先頭に置く見出し (取得中・エラー・案内文・件数表示)。
    Widget buildSearchResultHeader() => searchedTransactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // エラーメッセージは加工せずそのまま表示する
      // (`.claude/rules/coding-conventions.md`)。
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(error.toString()),
        ),
      ),
      data: (transactions) {
        if (searchCondition.value == _emptySearchCondition) {
          return _SearchMessage(
            message: l10n.transactionSearchConditionRequired,
          );
        }
        if (transactions.isEmpty) {
          return _SearchMessage(message: l10n.transactionSearchNoResults);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            l10n.transactionSearchResultCount(transactions.length),
            style: AppTextStyles.caption.copyWith(color: appColors.textMuted),
          ),
        );
      },
    );

    // 画面全体を1つのスクロールに載せる (キーボードで Scaffold が縮んだ時に、
    // 非スクロールのフォームが収まらず overflow するのを防ぐため)。
    // 件数の上限が無い検索結果のため、画面付近の行だけを組み立てる。
    // 先頭 (index 0) はフォームと検索結果の見出しで、それ以降が明細の行。
    // 取得中・エラーの間は行を持たず、見出しの位置に状態を表示する。
    final searchedTransactions = searchedTransactionsAsync.when(
      loading: () => const <Transaction>[],
      error: (error, _) => const <Transaction>[],
      data: (transactions) => transactions,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactionSearchTitle)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: searchedTransactions.length + 1,
          itemBuilder: (context, index) {
            if (index > 0) {
              final transaction = searchedTransactions[index - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  6,
                ),
                child: TransactionRow(
                  transaction: transaction,
                  onTap: () {
                    unawaited(
                      logAnalyticsEvent(
                        name: 'transaction_detail_open',
                        parameters: {'transactionID': transaction.id},
                      ),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => TransactionDetailPage(
                          transactionID: transaction.id,
                          logAnalyticsEvent: logAnalyticsEvent,
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.transactionSearchPeriod,
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: l10n.transactionSearchDateFrom,
                              selectedDate: transactionDateFrom.value,
                              onDateSelected: (selectedDate) {
                                transactionDateFrom.value = selectedDate;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _DateField(
                              label: l10n.transactionSearchDateTo,
                              selectedDate: transactionDateTo.value,
                              onDateSelected: (selectedDate) {
                                transactionDateTo.value = selectedDate;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.transactionSearchAmount,
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _AmountField(
                              label: l10n.transactionSearchMinimumAmount,
                              controller: minimumAmountController,
                              onSubmitted: logAndSubmitSearch,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _AmountField(
                              label: l10n.transactionSearchMaximumAmount,
                              controller: maximumAmountController,
                              onSubmitted: logAndSubmitSearch,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: titleKeywordController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: l10n.transactionSearchTitleKeyword,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (titleKeyword) => logAndSubmitSearch(),
                      ),
                      if (validationMessage.value != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            validationMessage.value!,
                            style: TextStyle(
                              fontSize: 12,
                              color: appColors.destructive,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: logAndSubmitSearch,
                              child: Text(l10n.transactionSearchSubmit),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () {
                              unawaited(
                                logAnalyticsEvent(
                                  name: 'transaction_search_clear',
                                ),
                              );
                              transactionDateFrom.value = null;
                              transactionDateTo.value = null;
                              minimumAmountController.clear();
                              maximumAmountController.clear();
                              titleKeywordController.clear();
                              validationMessage.value = null;
                              searchCondition.value = _emptySearchCondition;
                            },
                            child: Text(l10n.transactionSearchClear),
                          ),
                        ],
                      ),
                      // 無料プランで検索できるのは直近 freePlanHistoryMonthCount ヶ月だけのため、
                      // 結果が古い明細を含まない理由をフォームの直後で伝える。
                      if (!isPremium) ...[
                        const SizedBox(height: 14),
                        FreePlanHistoryNotice(
                          message: l10n.transactionSearchFreePlanHistoryLimit(
                            freePlanHistoryMonthCount,
                          ),
                          paywallTrigger: 'transaction_search_history_limit',
                          openExternalUri: openExternalUri,
                          logAnalyticsEvent: logAnalyticsEvent,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: buildSearchResultHeader(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 検索結果の代わりに表示する案内文 (条件未入力・0 件)。
class _SearchMessage extends StatelessWidget {
  /// 表示する文言。
  final String message;

  const _SearchMessage({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.appColors.textMuted,
        ),
      ),
    ),
  );
}

/// 日付ピッカーを開いて取引日の範囲の片側を選ぶ入力欄。未選択は「指定なし」を表示する。
class _DateField extends StatelessWidget {
  /// 入力欄の見出し (開始日 / 終了日)。
  final String label;

  /// 選択中の日付。未選択は null。
  final DateTime? selectedDate;

  /// 日付を選び直した時の処理。
  final ValueChanged<DateTime?> onDateSelected;

  const _DateField({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    final currentSelectedDate = selectedDate;
    return OutlinedButton(
      onPressed: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: currentSelectedDate ?? DateTime.now(),
          // 手動明細入力 (features/manual_entry) と同じ選択範囲に揃える。
          firstDate: DateTime(DateTime.now().year - 100),
          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        );
        if (pickedDate != null) {
          onDateSelected(pickedDate);
        }
      },
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: appColors.onSurface,
        side: BorderSide(color: appColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: appColors.textMuted),
          ),
          Text(
            currentSelectedDate == null
                ? l10n.transactionSearchDateUnset
                : DateFormat.yMd(
                    Localizations.localeOf(context).toString(),
                  ).format(currentSelectedDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

/// 金額範囲の片側を入力する数値入力欄。
class _AmountField extends StatelessWidget {
  /// 入力欄の見出し (最小 / 最大)。
  final String label;

  /// 入力値を保持するコントローラ。
  final TextEditingController controller;

  /// キーボードの確定操作で検索を実行する処理。
  final VoidCallback onSubmitted;

  const _AmountField({
    required this.label,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    // 金額は 0 以上の整数のみ (Transaction.amount が int)。
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      labelText: label,
      prefixText: '¥',
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onSubmitted: (amount) => onSubmitted(),
  );
}
