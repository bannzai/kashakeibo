import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/transaction.dart';

/// DEBUG ビルド限定の開発者メニュー。
///
/// 到達困難な状態 (明細データの投入・外部サービスの疎通確認) を、
/// 起動引数ではなくアプリ内メニューから作れるようにする
/// (~/.claude/rules/debug-menu-first-for-hard-to-reach-states.md のパターン)。
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
                await _showResultDialog(
                  context: context,
                  message: error.toString(),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Gemini 疎通確認'),
            subtitle: const Text('Firebase AI Logic 経由で generateContent を呼ぶ'),
            onTap: () async {
              String message;
              try {
                // Gemini Developer API (googleAI backend) を使う。App Check の
                // トークンは SDK が自動で添付する (documents/adr/0001-tech-stack.md)。
                // モデルは 2026-08 時点の推奨デフォルト gemini-3.7-flash
                // (https://firebase.google.com/docs/ai-logic/models 。2.5 系は 2026-10 に停止)。
                final response = await FirebaseAI.googleAI()
                    .generativeModel(model: 'gemini-3.7-flash')
                    .generateContent([
                      Content.text('「疎通確認OK」と日本語で短く返答してください。'),
                    ]);
                message = response.text ?? '(空のレスポンス)';
              } catch (error) {
                message = error.toString();
              }
              if (!context.mounted) {
                return;
              }
              await _showResultDialog(context: context, message: message);
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
    (
      type: TransactionType.expense,
      amount: 12800,
      category: TransactionCategory.entertainment,
      title: '重複疑いの明細 (計算対象外)',
      excludedFromAggregation: true,
    ),
  ];
  for (final (index, sample) in samples.indexed) {
    await addTransaction.call(
      type: sample.type,
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

/// 実行結果 (成功レスポンス・エラー) をそのまま表示するダイアログ。
Future<void> _showResultDialog({
  required BuildContext context,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    content: SingleChildScrollView(child: Text(message)),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('OK'),
      ),
    ],
  ),
);
