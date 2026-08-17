import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/debug/debug_sheet.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/style/tokens.dart';

/// 月次一覧画面。月切替ヘッダー・収支サマリー・カテゴリ内訳・明細リストを表示する。
///
/// レイアウト・数値の書式は design_handoff_kashakeibo/README.md
/// (ホームの月切替ヘッダー・収支サマリーカード、レポートのカテゴリ横棒、
/// 明細タブの日付グループ行) に合わせる。
/// 集計はサマリードキュメントを持たず、購読中の当月明細からクライアント集計する
/// (`.claude/rules/firestore-aggregation-rules.md`)。
class MonthlyPage extends HookConsumerWidget {
  const MonthlyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 表示中の月 (月初日で保持)。ユーザーの月送り操作で変更する画面ローカル状態。
    final displayMonth = useState(
      DateTime(DateTime.now().year, DateTime.now().month),
    );
    final selectedYearMonth = yearMonthFrom(dateTime: displayMonth.value);
    final transactionsAsync = ref.watch(
      monthlyTransactionsProvider(yearMonth: selectedYearMonth),
    );
    final duplicateCandidateList = ref.watch(
      monthlyDuplicateCandidatesProvider(yearMonth: selectedYearMonth),
    );
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              displayMonth: displayMonth.value,
              onPreviousMonth: () {
                displayMonth.value = DateTime(
                  displayMonth.value.year,
                  displayMonth.value.month - 1,
                );
              },
              onNextMonth: () {
                displayMonth.value = DateTime(
                  displayMonth.value.year,
                  displayMonth.value.month + 1,
                );
              },
            ),
            Expanded(
              child: transactionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error.toString()),
                  ),
                ),
                data: (transactions) {
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _MonthlySummaryCard(transactions: transactions),
                      if (duplicateCandidateList.isNotEmpty)
                        _DuplicateCandidateBanner(
                          candidateCount: duplicateCandidateList.length,
                          onTap: () {
                            showModalBottomSheet<void>(
                              context: context,
                              useSafeArea: true,
                              isScrollControlled: true,
                              backgroundColor: AppColors.neutral100,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              builder: (context) => _DuplicateCandidateSheet(
                                candidate: duplicateCandidateList.first,
                              ),
                            );
                          },
                        ),
                      _CategoryBreakdownSection(transactions: transactions),
                      if (transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              l10n.monthlyTransactionsEmpty,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral600,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._groupedTransactionRows(
                          context: context,
                          transactions: transactions,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 月切替ヘッダー。左右の円形ゴーストボタンと中央の月ラベル
/// (「2026年8月」+ 英語表記の副題)。
///
/// DEBUG ビルドでは月ラベルの長押しで開発者メニュー (DebugSheet) を開く。
/// デザインに存在しない入口を画面に足さないための隠し操作 (features/debug/README.md)。
class _MonthHeader extends StatelessWidget {
  /// 表示中の月 (月初日)。
  final DateTime displayMonth;

  /// 前の月ボタンのコールバック。
  final VoidCallback onPreviousMonth;

  /// 次の月ボタンのコールバック。
  final VoidCallback onNextMonth;

  const _MonthHeader({
    required this.displayMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Row(
        children: [
          _CircleGhostButton(
            icon: Icons.chevron_left,
            tooltip: l10n.previousMonth,
            onPressed: onPreviousMonth,
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: kDebugMode
                  ? () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (context) => const DebugSheet(),
                      );
                    }
                  : null,
              child: Column(
                children: [
                  Text(
                    DateFormat.yMMMM(
                      Localizations.localeOf(context).toString(),
                    ).format(displayMonth),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'MMMM yyyy',
                      'en_US',
                    ).format(displayMonth).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.neutral600,
                      letterSpacing: 0.63,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CircleGhostButton(
            icon: Icons.chevron_right,
            tooltip: l10n.nextMonth,
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}

/// 34px の円形ゴーストボタン (枠線 divider・背景透明)。
class _CircleGhostButton extends StatelessWidget {
  /// 表示するアイコン。
  final IconData icon;

  /// アクセシビリティ用のツールチップ。
  final String tooltip;

  /// タップ時のコールバック。
  final VoidCallback onPressed;

  const _CircleGhostButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.neutral700,
          side: const BorderSide(color: AppColors.divider),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

/// 収支サマリーカード。支出を主表示、右に収入と残り (収入 - 支出) を添える。
class _MonthlySummaryCard extends StatelessWidget {
  /// 表示中の月の明細一覧。
  final List<Transaction> transactions;

  const _MonthlySummaryCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final incomeTotal = totalAmount(
      transactions: transactions,
      type: TransactionType.income,
    );
    final expenseTotal = totalAmount(
      transactions: transactions,
      type: TransactionType.expense,
    );
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(28),
        boxShadow: appShadowSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLabel(text: l10n.monthlyExpense),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '¥',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neutral600,
                        ),
                      ),
                      TextSpan(text: formatAmountNumber(amount: expenseTotal)),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.42,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryLabel(text: l10n.monthlyIncome),
              _SummarySubAmount(amount: incomeTotal),
            ],
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryLabel(text: l10n.monthlyBalance),
              _SummarySubAmount(
                amount: incomeTotal - expenseTotal,
                color: AppColors.sage700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 重複候補の件数を表示し、確認シートを開くバナー。
class _DuplicateCandidateBanner extends StatelessWidget {
  /// 未解決の重複候補数。
  final int candidateCount;

  /// バナーをタップした時の処理。
  final VoidCallback onTap;

  const _DuplicateCandidateBanner({
    required this.candidateCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: AppColors.sage100,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.sage300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.content_copy_rounded,
                  size: 20,
                  color: AppColors.sage700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.duplicateCandidateCount(candidateCount),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sage800,
                        ),
                      ),
                      Text(
                        l10n.duplicateCandidateReviewHint,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.sage700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.sage700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 重複候補 2 件を比較し、マージまたは別物として確定するシート。
class _DuplicateCandidateSheet extends HookConsumerWidget {
  /// 確認する重複候補。
  final DuplicateCandidate candidate;

  const _DuplicateCandidateSheet({required this.candidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mergeDuplicateTransactions = ref.watch(
      mergeDuplicateTransactionsProvider,
    );
    final keepBothTransactions = ref.watch(keepBothTransactionsProvider);
    final isSubmitting = useState(false);
    final operationError = useState<Object?>(null);
    final selectedTransactionID = useState(candidate.primaryTransaction.id);
    final l10n = AppLocalizations.of(context);

    Future<void> resolve({required Future<void> Function() operation}) async {
      isSubmitting.value = true;
      operationError.value = null;
      try {
        await operation();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (error) {
        if (context.mounted) {
          operationError.value = error;
          isSubmitting.value = false;
        }
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.duplicateCandidateTitle,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.duplicateCandidateDescription,
            style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
          ),
          const SizedBox(height: 16),
          _DuplicateTransactionCard(
            transaction: candidate.primaryTransaction,
            isSelected:
                selectedTransactionID.value == candidate.primaryTransaction.id,
            onTap: isSubmitting.value
                ? null
                : () {
                    selectedTransactionID.value =
                        candidate.primaryTransaction.id;
                  },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '≂',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage700,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.duplicateCandidateReason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sage700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DuplicateTransactionCard(
            transaction: candidate.duplicateTransaction,
            isSelected:
                selectedTransactionID.value ==
                candidate.duplicateTransaction.id,
            onTap: isSubmitting.value
                ? null
                : () {
                    selectedTransactionID.value =
                        candidate.duplicateTransaction.id;
                  },
          ),
          if (operationError.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                operationError.value.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accent800,
                ),
              ),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: isSubmitting.value
                ? null
                : () {
                    final keepPrimary =
                        selectedTransactionID.value ==
                        candidate.primaryTransaction.id;
                    resolve(
                      operation: () => mergeDuplicateTransactions.call(
                        primaryTransaction: keepPrimary
                            ? candidate.primaryTransaction
                            : candidate.duplicateTransaction,
                        duplicateTransaction: keepPrimary
                            ? candidate.duplicateTransaction
                            : candidate.primaryTransaction,
                      ),
                    );
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: isSubmitting.value
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.mergeDuplicateCandidate),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isSubmitting.value
                ? null
                : () {
                    resolve(
                      operation: () => keepBothTransactions.call(
                        firstTransaction: candidate.primaryTransaction,
                        secondTransaction: candidate.duplicateTransaction,
                      ),
                    );
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.onSurface,
              side: const BorderSide(color: AppColors.divider),
            ),
            child: Text(l10n.keepBothDuplicateCandidates),
          ),
        ],
      ),
    );
  }
}

/// 重複確認シート内で 1 件の明細を表示するカード。
class _DuplicateTransactionCard extends StatelessWidget {
  /// 表示する明細。
  final Transaction transaction;

  /// マージ後に残す明細として選択されているか。
  final bool isSelected;

  /// この明細を残す選択へ切り替える処理。
  final VoidCallback? onTap;

  const _DuplicateTransactionCard({
    required this.transaction,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(
              color: isSelected ? AppColors.sage700 : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected ? AppColors.sage700 : AppColors.neutral600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat.yMd(
                        Localizations.localeOf(context).toString(),
                      ).format(transaction.transactionLocalDate),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.neutral600,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).duplicateCandidateKeep,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sage700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '¥${formatAmountNumber(amount: transaction.amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// サマリーカードの項目ラベル (10px, neutral-600)。
class _SummaryLabel extends StatelessWidget {
  /// ラベル文言。
  final String text;

  const _SummaryLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 10, color: AppColors.neutral600),
    );
  }
}

/// サマリーカードの副金額 (収入・残り。12px w700 tnum)。
class _SummarySubAmount extends StatelessWidget {
  /// 表示する金額 (日本円)。
  final int amount;

  /// 金額の文字色。
  final Color? color;

  const _SummarySubAmount({required this.amount, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '¥${formatAmountNumber(amount: amount)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 支出のカテゴリ内訳 (金額の大きい順の横棒)。支出が無い月は非表示。
class _CategoryBreakdownSection extends StatelessWidget {
  /// 表示中の月の明細一覧。
  final List<Transaction> transactions;

  const _CategoryBreakdownSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    final expenseCategoryTotals = categoryTotals(
      transactions: transactions,
      type: TransactionType.expense,
    );
    if (expenseCategoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }
    // 棒の長さは最大カテゴリとの比率 (レポート画面の pct と同じ計算)。
    final maxCategoryAmount = expenseCategoryTotals.values.first;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoryBreakdown,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (final entry in expenseCategoryTotals.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      categoryLabel(category: entry.key, l10n: l10n),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.neutral200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: entry.value / maxCategoryAmount,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: categoryColor(category: entry.key),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 66,
                    child: Text(
                      '¥${formatAmountNumber(amount: entry.value)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
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

/// 明細を日付ごとにグループ化し、日付見出しと明細行の Widget 列を返す。
/// [transactions] は取引日時の降順で渡される前提 (クエリの orderBy と一致)。
List<Widget> _groupedTransactionRows({
  required BuildContext context,
  required List<Transaction> transactions,
}) {
  final rows = <Widget>[const SizedBox(height: 8)];
  DateTime? currentDate;
  for (final transaction in transactions) {
    final transactionDay = DateTime(
      // 表示・グループ化は登録時タイムゾーン基準の日付を使う
      // (yearMonth と見え方を一致させる。entity の transactionLocalDate 参照)。
      transaction.transactionLocalDate.year,
      transaction.transactionLocalDate.month,
      transaction.transactionLocalDate.day,
    );
    if (transactionDay != currentDate) {
      currentDate = transactionDay;
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
          child: Text(
            DateFormat.MMMEd(
              Localizations.localeOf(context).toString(),
            ).format(transactionDay),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral600,
            ),
          ),
        ),
      );
    }
    rows.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: _TransactionRow(transaction: transaction),
      ),
    );
  }
  return rows;
}

/// 明細リストの 1 行 (明細タブの行デザイン)。計算対象外の明細は opacity 0.45。
class _TransactionRow extends StatelessWidget {
  /// 表示する明細。
  final Transaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subTexts = [
      categoryLabel(category: transaction.category, l10n: l10n),
      if (transaction.excludedFromAggregation) l10n.excludedFromAggregation,
    ];
    return Opacity(
      opacity: transaction.excludedFromAggregation ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subTexts.join(' · '),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              switch (transaction.type) {
                TransactionType.income =>
                  '+¥${formatAmountNumber(amount: transaction.amount)}',
                TransactionType.expense =>
                  '-¥${formatAmountNumber(amount: transaction.amount)}',
              },
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                // 赤は使わない (デザイントークンに赤が存在しない)。収入のみセージで強調する。
                color: switch (transaction.type) {
                  TransactionType.income => AppColors.sage700,
                  TransactionType.expense => AppColors.onSurface,
                },
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 金額を桁区切り数字 ("1,234") に整形する。¥ 記号は表示側でスタイルを分けて付ける。
String formatAmountNumber({required int amount}) =>
    NumberFormat.decimalPattern().format(amount);

/// カテゴリの表示名を返す。
String categoryLabel({
  required TransactionCategory category,
  required AppLocalizations l10n,
}) => switch (category) {
  TransactionCategory.food => l10n.categoryFood,
  TransactionCategory.eatingOut => l10n.categoryEatingOut,
  TransactionCategory.dailyGoods => l10n.categoryDailyGoods,
  TransactionCategory.transportation => l10n.categoryTransportation,
  TransactionCategory.subscription => l10n.categorySubscription,
  TransactionCategory.salary => l10n.categorySalary,
  TransactionCategory.other => l10n.categoryOther,
};

/// カテゴリ横棒の色 (design_handoff_kashakeibo/README.md のレポート画面の割当)。
Color categoryColor({required TransactionCategory category}) =>
    switch (category) {
      TransactionCategory.food => AppColors.accent500,
      TransactionCategory.eatingOut => AppColors.accent400,
      TransactionCategory.dailyGoods => AppColors.sage500,
      TransactionCategory.transportation => AppColors.sage400,
      TransactionCategory.subscription => AppColors.neutral400,
      // 給与は支出の内訳には現れないが、色は sage 系に寄せておく。
      TransactionCategory.salary => AppColors.sage500,
      TransactionCategory.other => AppColors.neutral300,
    };
