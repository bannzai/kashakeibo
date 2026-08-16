import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/debug/debug_sheet.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/provider/transaction.dart';

/// 月次一覧画面。収入・支出・カテゴリ内訳のサマリーと当月の明細リストを表示する。
///
/// サマリーはサマリードキュメントを持たず、購読中の当月明細からクライアント集計する
/// (`.claude/rules/firestore-aggregation-rules.md`)。
class MonthlyPage extends HookConsumerWidget {
  const MonthlyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 表示中の月 (月初日で保持)。ユーザーの月送り操作で変更する画面ローカル状態。
    final displayMonth = useState(
      DateTime(DateTime.now().year, DateTime.now().month),
    );
    final transactionsAsync = ref.watch(
      monthlyTransactionsProvider(
        yearMonth: yearMonthFrom(dateTime: displayMonth.value),
      ),
    );
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.previousMonth,
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                displayMonth.value = DateTime(
                  displayMonth.value.year,
                  displayMonth.value.month - 1,
                );
              },
            ),
            Text(
              DateFormat.yMMMM(
                Localizations.localeOf(context).toString(),
              ).format(displayMonth.value),
            ),
            IconButton(
              tooltip: l10n.nextMonth,
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                displayMonth.value = DateTime(
                  displayMonth.value.year,
                  displayMonth.value.month + 1,
                );
              },
            ),
          ],
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const DebugSheet(),
                );
              },
            ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error.toString()),
          ),
        ),
        data: (transactions) => ListView(
          children: [
            _MonthlySummarySection(transactions: transactions),
            _CategoryBreakdownSection(transactions: transactions),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.monthlyTransactionsEmpty)),
              )
            else
              ...transactions.map(
                (transaction) => _TransactionListTile(transaction: transaction),
              ),
          ],
        ),
      ),
    );
  }
}

/// 収入・支出・収支の月次サマリー。
class _MonthlySummarySection extends StatelessWidget {
  /// 表示中の月の明細一覧。
  final List<Transaction> transactions;

  const _MonthlySummarySection({required this.transactions});

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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _SummaryItem(
              label: l10n.monthlyIncome,
              amount: incomeTotal,
              color: Colors.green,
            ),
            _SummaryItem(
              label: l10n.monthlyExpense,
              amount: expenseTotal,
              color: Colors.red,
            ),
            _SummaryItem(
              label: l10n.monthlyBalance,
              amount: incomeTotal - expenseTotal,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

/// サマリーの 1 項目 (ラベルと金額)。
class _SummaryItem extends StatelessWidget {
  /// 項目名 (収入・支出・収支)。
  final String label;

  /// 表示する金額 (日本円)。
  final int amount;

  /// 金額の文字色。
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            formatAmount(amount: amount),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// 支出のカテゴリ内訳 (金額の大きい順)。
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoryBreakdown,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in expenseCategoryTotals.entries)
                Chip(
                  label: Text(
                    '${categoryLabel(category: entry.key, l10n: l10n)} '
                    '${formatAmount(amount: entry.value)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 明細リストの 1 行。
class _TransactionListTile extends StatelessWidget {
  /// 表示する明細。
  final Transaction transaction;

  const _TransactionListTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedAmount = switch (transaction.type) {
      TransactionType.income => '+${formatAmount(amount: transaction.amount)}',
      TransactionType.expense => '-${formatAmount(amount: transaction.amount)}',
    };
    return ListTile(
      title: Text(transaction.title),
      subtitle: Row(
        children: [
          Text(categoryLabel(category: transaction.category, l10n: l10n)),
          const SizedBox(width: 8),
          Text(
            DateFormat.Md(
              Localizations.localeOf(context).toString(),
            ).format(transaction.transactionDate),
          ),
          if (transaction.excludedFromAggregation) ...[
            const SizedBox(width: 8),
            Text(
              l10n.excludedFromAggregation,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        signedAmount,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: transaction.excludedFromAggregation
              ? Theme.of(context).colorScheme.outline
              : switch (transaction.type) {
                  TransactionType.income => Colors.green,
                  TransactionType.expense => Colors.red,
                },
        ),
      ),
    );
  }
}

/// 金額を "¥1,234" 形式で整形する。
String formatAmount({required int amount}) =>
    '¥${NumberFormat.decimalPattern().format(amount)}';

/// カテゴリの表示名を返す。
String categoryLabel({
  required TransactionCategory category,
  required AppLocalizations l10n,
}) => switch (category) {
  TransactionCategory.food => l10n.categoryFood,
  TransactionCategory.dailyGoods => l10n.categoryDailyGoods,
  TransactionCategory.transportation => l10n.categoryTransportation,
  TransactionCategory.utilities => l10n.categoryUtilities,
  TransactionCategory.communication => l10n.categoryCommunication,
  TransactionCategory.housing => l10n.categoryHousing,
  TransactionCategory.medical => l10n.categoryMedical,
  TransactionCategory.entertainment => l10n.categoryEntertainment,
  TransactionCategory.clothing => l10n.categoryClothing,
  TransactionCategory.education => l10n.categoryEducation,
  TransactionCategory.salary => l10n.categorySalary,
  TransactionCategory.other => l10n.categoryOther,
};
