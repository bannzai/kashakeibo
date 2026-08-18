import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/transaction.dart';

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
        ],
      ),
    );
  }
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
    );
  }
}
