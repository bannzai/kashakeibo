import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/transaction_labels.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 明細詳細画面 (design_handoff_kashakeibo/README.md の 4「明細詳細」)。
///
/// 明細を snapshot listener で購読し、金額・店名・日付・カテゴリ、元画像
/// (拡大・画像だけの削除)、出所 (レシート/スクショ/手動 と 自動取込/手調整)、
/// 計算対象からの除外スイッチ、明細ごとの削除を提供する (issue #9)。
class TransactionDetailPage extends HookConsumerWidget {
  /// 表示する明細の ID。
  final String transactionID;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const TransactionDetailPage({
    required this.transactionID,
    required this.logAnalyticsEvent,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsync = ref.watch(
      transactionProvider(transactionID: transactionID),
    );
    final updateTransactionExclusion = ref.watch(
      updateTransactionExclusionProvider,
    );
    final removeTransactionSourceImage = ref.watch(
      removeTransactionSourceImageProvider,
    );
    final deleteTransaction = ref.watch(deleteTransactionProvider);
    final operationInProgress = useState(false);
    final l10n = AppLocalizations.of(context);

    /// Firestore / Worker への操作を 1 つずつ実行し、失敗はそのまま SnackBar に出す。
    Future<bool> runOperation({
      required Future<void> Function() operation,
    }) async {
      if (operationInProgress.value) {
        return false;
      }
      operationInProgress.value = true;
      try {
        await operation();
        return true;
      } catch (error) {
        if (context.mounted) {
          // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return false;
      } finally {
        if (context.mounted) {
          operationInProgress.value = false;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          l10n.transactionDetailTitle,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: transactionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error.toString()),
            ),
          ),
          data: (transaction) {
            if (transaction == null) {
              return Center(
                child: Text(
                  l10n.transactionDetailNotFound,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _TransactionHeadline(transaction: transaction),
                const SizedBox(height: 18),
                _SourceImageSection(
                  transaction: transaction,
                  operationInProgress: operationInProgress.value,
                  logAnalyticsEvent: logAnalyticsEvent,
                  onDeleteImage: () async {
                    unawaited(
                      logAnalyticsEvent(
                        name: 'transaction_image_delete',
                        parameters: {'transactionID': transaction.id},
                      ),
                    );
                    if (!await _confirmDestructiveOperation(
                      context: context,
                      title: l10n.transactionDetailDeleteImageConfirmationTitle,
                      message:
                          l10n.transactionDetailDeleteImageConfirmationMessage,
                    )) {
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    if (await runOperation(
                          operation: () => removeTransactionSourceImage.call(
                            transaction: transaction,
                          ),
                        ) &&
                        context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.transactionDetailImageDeleted),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 18),
                _TransactionInfoCard(
                  transaction: transaction,
                  operationInProgress: operationInProgress.value,
                  onExcludedFromAggregationChanged: (excludedFromAggregation) {
                    unawaited(
                      logAnalyticsEvent(
                        name: 'transaction_exclusion_toggle',
                        parameters: {
                          'transactionID': transaction.id,
                          // Firebase Analytics のパラメータ値は String / num のみのため文字列にする。
                          'excludedFromAggregation': excludedFromAggregation
                              .toString(),
                        },
                      ),
                    );
                    runOperation(
                      operation: () => updateTransactionExclusion.call(
                        transaction: transaction,
                        excludedFromAggregation: excludedFromAggregation,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: operationInProgress.value
                      ? null
                      : () async {
                          unawaited(
                            logAnalyticsEvent(
                              name: 'transaction_delete',
                              parameters: {'transactionID': transaction.id},
                            ),
                          );
                          if (!await _confirmDestructiveOperation(
                            context: context,
                            title:
                                l10n.transactionDetailDeleteConfirmationTitle,
                            message:
                                l10n.transactionDetailDeleteConfirmationMessage,
                          )) {
                            return;
                          }
                          if (!context.mounted) {
                            return;
                          }
                          // 削除後は画面を閉じるため、閉じる前の Scaffold へ通知を出す。
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          if (await runOperation(
                                operation: () => deleteTransaction.call(
                                  transaction: transaction,
                                ),
                              ) &&
                              context.mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(l10n.transactionDetailDeleted),
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.accent800,
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.transactionDetailDelete),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 金額 (34px w800 tnum) → 店名 (15px w700) → 日付・カテゴリ (11px) の見出し部。
class _TransactionHeadline extends StatelessWidget {
  /// 表示する明細。
  final Transaction transaction;

  const _TransactionHeadline({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: switch (transaction.type) {
                  TransactionType.income => '+¥',
                  TransactionType.expense => '¥',
                },
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600,
                ),
              ),
              TextSpan(
                text: NumberFormat.decimalPattern().format(transaction.amount),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.68,
            color: switch (transaction.type) {
              TransactionType.income => AppColors.sage700,
              TransactionType.expense => AppColors.onSurface,
            },
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          transaction.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          [
            DateFormat.yMMMEd(
              Localizations.localeOf(context).toString(),
            ).format(transaction.transactionLocalDate),
            categoryLabel(category: transaction.category, l10n: l10n),
            if (transaction.excludedFromAggregation)
              l10n.excludedFromAggregation,
          ].join(' · '),
          style: const TextStyle(fontSize: 11, color: AppColors.neutral600),
        ),
      ],
    );
  }
}

/// 元画像の表示 (高さ 170・radius 28、右下に「拡大」ピル)、注記、「画像だけを削除」。
/// 画像が無い明細はプレースホルダー (手動入力なら「手動入力のため元画像なし」) を表示する。
class _SourceImageSection extends ConsumerWidget {
  /// 表示する明細。
  final Transaction transaction;

  /// 他の操作の実行中 (削除ボタンを無効にする)。
  final bool operationInProgress;

  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  /// 「画像だけを削除」の処理。
  final VoidCallback onDeleteImage;

  const _SourceImageSection({
    required this.transaction,
    required this.operationInProgress,
    required this.logAnalyticsEvent,
    required this.onDeleteImage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sourceImageObjectKey = transaction.sourceImageObjectKey;
    if (sourceImageObjectKey == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.neutral200,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          switch (transaction.source) {
            TransactionSource.manual => l10n.transactionDetailNoImageManual,
            TransactionSource.receipt ||
            TransactionSource.screenshot ||
            TransactionSource.unknown => l10n.transactionDetailNoImage,
          },
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral600,
          ),
        ),
      );
    }

    final storedImageAsync = ref.watch(
      storedImageProvider(imageObjectKey: sourceImageObjectKey),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transactionDetailSourceImage,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 170,
            color: AppColors.neutral200,
            child: storedImageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // エラーメッセージは加工せずそのまま表示する (.claude/rules/coding-conventions.md)。
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              data: (imageBytes) => Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(imageBytes, fit: BoxFit.cover),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        unawaited(
                          logAnalyticsEvent(
                            name: 'transaction_image_zoom',
                            parameters: {'transactionID': transaction.id},
                          ),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (context) =>
                                _SourceImageZoomPage(imageBytes: imageBytes),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.onSurface,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.zoom_in, size: 16),
                      label: Text(
                        l10n.transactionDetailZoom,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.transactionDetailSourceImageNote,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.neutral600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: operationInProgress ? null : onDeleteImage,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent800,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.hide_image_outlined, size: 16),
              label: Text(
                l10n.transactionDetailDeleteImage,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 元画像をピンチ操作で拡大できる全画面表示。
class _SourceImageZoomPage extends StatelessWidget {
  /// 表示する画像。
  final Uint8List imageBytes;

  const _SourceImageZoomPage({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral900,
      appBar: AppBar(
        backgroundColor: AppColors.neutral900,
        foregroundColor: AppColors.neutral100,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.memory(imageBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// 出所チップと計算対象からの除外スイッチをまとめた情報カード。
class _TransactionInfoCard extends StatelessWidget {
  /// 表示する明細。
  final Transaction transaction;

  /// 他の操作の実行中 (スイッチを無効にする)。
  final bool operationInProgress;

  /// 除外スイッチの変更処理。
  final ValueChanged<bool> onExcludedFromAggregationChanged;

  const _TransactionInfoCard({
    required this.transaction,
    required this.operationInProgress,
    required this.onExcludedFromAggregationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provenanceLabel = transactionProvenanceLabel(
      transaction: transaction,
      l10n: l10n,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.transactionDetailProvenance,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ProvenanceChip(
                  label: transactionSourceLabel(
                    source: transaction.source,
                    l10n: l10n,
                  ),
                ),
                if (provenanceLabel != null) ...[
                  const SizedBox(width: 6),
                  _ProvenanceChip(label: provenanceLabel),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.transactionDetailExcludeFromAggregation,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.transactionDetailExcludeFromAggregationDescription,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.neutral600,
              ),
            ),
            activeThumbColor: AppColors.neutral100,
            activeTrackColor: AppColors.sage500,
            value: transaction.excludedFromAggregation,
            onChanged: operationInProgress
                ? null
                : onExcludedFromAggregationChanged,
          ),
        ],
      ),
    );
  }
}

/// 出所を表すピル状のチップ (sage-100 地 / sage-800 文字)。
class _ProvenanceChip extends StatelessWidget {
  /// 表示する文言。
  final String label;

  const _ProvenanceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.sage100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sage300),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.sage800,
        ),
      ),
    );
  }
}

/// 破壊的操作 (画像・明細の削除) の確認ダイアログを表示し、続行なら true を返す。
Future<bool> _confirmDestructiveOperation({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent800),
              child: Text(l10n.delete),
            ),
          ],
        ),
      ) ??
      false;
}
