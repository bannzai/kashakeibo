// 明細の出所表示 (transactionProvenanceLabel) のテスト。
// 撮影・取込の明細だけが「自動取込 / 手調整」を持ち、手動入力・出所不明は
// 出所名 (transactionSourceLabel) だけで表しきれるため null になることを確認する。
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/l10n/app_localizations_en.dart';
import 'package:kashakeibo/l10n/transaction_labels.dart';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required TransactionSource source,
  required bool analysisAdjustedByUser,
}) => Transaction(
  id: 'transaction-id',
  userID: 'user-id',
  type: TransactionType.expense,
  source: source,
  amount: 1280,
  category: TransactionCategory.food,
  title: 'スーパーマーケット',
  transactionDate: DateTime(2026, 8, 16, 12),
  transactionDateTimeZoneOffsetMinutes: null,
  yearMonth: '2026-08',
  excludedFromAggregation: false,
  sourceImageObjectKey: null,
  analysisAdjustedByUser: analysisAdjustedByUser,
);

void main() {
  final l10n = AppLocalizationsEn();

  group('transactionProvenanceLabel', () {
    test('レシート・スクショの明細は、未修正なら自動取込・修正済みなら手調整を返す', () {
      for (final source in [
        TransactionSource.receipt,
        TransactionSource.screenshot,
      ]) {
        expect(
          transactionProvenanceLabel(
            transaction: buildTransaction(
              source: source,
              analysisAdjustedByUser: false,
            ),
            l10n: l10n,
          ),
          l10n.transactionProvenanceAutomatic,
        );
        expect(
          transactionProvenanceLabel(
            transaction: buildTransaction(
              source: source,
              analysisAdjustedByUser: true,
            ),
            l10n: l10n,
          ),
          l10n.transactionProvenanceAdjusted,
        );
      }
    });

    test('手動入力・出所不明の明細は修正の有無によらず null を返す', () {
      for (final source in [
        TransactionSource.manual,
        TransactionSource.unknown,
      ]) {
        for (final analysisAdjustedByUser in [false, true]) {
          expect(
            transactionProvenanceLabel(
              transaction: buildTransaction(
                source: source,
                analysisAdjustedByUser: analysisAdjustedByUser,
              ),
              l10n: l10n,
            ),
            isNull,
          );
        }
      }
    });
  });

  group('transactionSourceLabel', () {
    test('出所ごとの表示名を返す', () {
      expect(
        transactionSourceLabel(source: TransactionSource.receipt, l10n: l10n),
        l10n.transactionSourceReceipt,
      );
      expect(
        transactionSourceLabel(
          source: TransactionSource.screenshot,
          l10n: l10n,
        ),
        l10n.transactionSourceScreenshot,
      );
      expect(
        transactionSourceLabel(source: TransactionSource.manual, l10n: l10n),
        l10n.transactionSourceManual,
      );
      expect(
        transactionSourceLabel(source: TransactionSource.unknown, l10n: l10n),
        l10n.transactionSourceUnknown,
      );
    });
  });
}
