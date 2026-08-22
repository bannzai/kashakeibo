import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/l10n/app_localizations.dart';
import 'package:kashakeibo/l10n/transaction_labels.dart';
import 'package:kashakeibo/provider/transaction.dart';
import 'package:kashakeibo/style/app_theme.dart';
import 'package:kashakeibo/style/tokens.dart';
import 'package:kashakeibo/utils/analytics/analytics.dart';

/// 手動明細入力シートを表示し、登録完了時は true を返す。
///
/// キャンセルの記録は dismiss 経路 (閉じるボタン・背景タップ・スワイプ) によらず、
/// ここで一度だけ行う。
Future<bool?> showManualEntrySheet({
  required BuildContext context,
  required LogAnalyticsEvent logAnalyticsEvent,
}) async {
  final registered = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ManualEntrySheet(logAnalyticsEvent: logAnalyticsEvent),
  );
  if (registered != true) {
    unawaited(logAnalyticsEvent(name: 'manual_entry_cancel'));
  }
  return registered;
}

/// 金額・日付・店名・カテゴリ・収支種別を入力して明細を登録するシート。
class ManualEntrySheet extends HookConsumerWidget {
  /// Analytics イベントを記録する処理。
  final LogAnalyticsEvent logAnalyticsEvent;

  const ManualEntrySheet({required this.logAnalyticsEvent, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addTransaction = ref.watch(addTransactionProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final amountController = useTextEditingController();
    final titleController = useTextEditingController();
    // 現金支出のクイック入力が主用途なので、収支種別は支出を初期選択する。
    final transactionType = useState(TransactionType.expense);
    final transactionCategory = useState(TransactionCategory.food);
    // デザイン仕様で日付の初期値は今日と定義されているため。
    final transactionDate = useState(DateUtils.dateOnly(DateTime.now()));
    final submitting = useState(false);
    final registrationComplete = useState(false);
    final registrationError = useState<Object?>(null);
    final l10n = AppLocalizations.of(context);
    final appColors = context.appColors;
    final availableCategories = switch (transactionType.value) {
      TransactionType.expense => const [
        TransactionCategory.food,
        TransactionCategory.eatingOut,
        TransactionCategory.dailyGoods,
        TransactionCategory.transportation,
        TransactionCategory.subscription,
        TransactionCategory.other,
      ],
      TransactionType.income => const [
        TransactionCategory.salary,
        TransactionCategory.other,
      ],
    };

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.manualEntryTitle,
                      style: AppTextStyles.screenTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: submitting.value
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.manualEntryAmount,
                  prefixText: '¥ ',
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return l10n.manualEntryAmountRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: l10n.manualEntryStore),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.manualEntryType,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<TransactionType>(
                segments: [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text(l10n.monthlyExpense),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text(l10n.monthlyIncome),
                  ),
                ],
                selected: {transactionType.value},
                onSelectionChanged: submitting.value
                    ? null
                    : (selection) {
                        transactionType.value = selection.single;
                        transactionCategory.value = switch (selection.single) {
                          TransactionType.expense => TransactionCategory.food,
                          TransactionType.income => TransactionCategory.salary,
                        };
                      },
              ),
              const SizedBox(height: 18),
              Text(
                l10n.manualEntryCategory,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final category in availableCategories)
                    ChoiceChip(
                      label: Text(
                        categoryLabel(category: category, l10n: l10n),
                      ),
                      selected: transactionCategory.value == category,
                      onSelected: submitting.value
                          ? null
                          : (_) {
                              transactionCategory.value = category;
                            },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                l10n.manualEntryDate,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: submitting.value
                    ? null
                    : () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: transactionDate.value,
                          // 家計簿の手動入力で扱う十分な範囲として、過去100年から
                          // 未来1年までを選択可能にする。
                          firstDate: DateTime(DateTime.now().year - 100),
                          lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                        );
                        if (context.mounted && selectedDate != null) {
                          transactionDate.value = selectedDate;
                        }
                      },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(transactionDate.value),
                ),
              ),
              if (registrationError.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    registrationError.value.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: submitting.value
                    ? null
                    : () async {
                        unawaited(
                          logAnalyticsEvent(name: 'manual_entry_register'),
                        );
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        submitting.value = true;
                        registrationError.value = null;
                        try {
                          await addTransaction.call(
                            type: transactionType.value,
                            source: TransactionSource.manual,
                            amount: int.parse(amountController.text),
                            category: transactionCategory.value,
                            title: titleController.text.trim().isEmpty
                                ? l10n.manualEntryDefaultTitle
                                : titleController.text.trim(),
                            transactionDate: transactionDate.value,
                            excludedFromAggregation: false,
                            // 手動入力は画像を持たず、AI 解析も経ない。
                            sourceImageObjectKey: null,
                            analysisAdjustedByUser: false,
                          );
                          if (context.mounted) {
                            // PopScope が送信中の外部 dismiss を防ぐ一方、登録完了後の
                            // この pop は許可するため、更新後のフレームを待つ。
                            registrationComplete.value = true;
                            await WidgetsBinding.instance.endOfFrame;
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          registrationError.value = error;
                          submitting.value = false;
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: submitting.value
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          color: appColors.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(l10n.manualEntryRegister),
              ),
            ],
          ),
        ),
      ),
    );
    return PopScope(
      canPop: !submitting.value || registrationComplete.value,
      child: content,
    );
  }
}
