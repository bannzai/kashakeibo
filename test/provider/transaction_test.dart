// 明細の更新・削除を行う機能 Provider (call クラス) のテスト。
// Firestore への読み書きは FakeFirebaseFirestore に対して行い、書き込み結果を読み戻して検証する。
// R2 の画像削除 (DeleteStoredImage) は呼び出しを記録する fake に差し替え、
// 画像削除と Firestore 更新の順序も合わせて確認する。
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/audit_log.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/audit_log.dart';
import 'package:kashakeibo/provider/transaction.dart';

/// テスト用の明細を組み立てる。
Transaction buildTransaction({
  required String id,
  required String? sourceImageObjectKey,
  required bool excludedFromAggregation,
}) => Transaction(
  id: id,
  userID: 'user-id',
  type: TransactionType.expense,
  source: TransactionSource.receipt,
  amount: 1280,
  category: TransactionCategory.food,
  title: 'スーパーマーケット',
  transactionDate: DateTime(2026, 8, 16, 12),
  transactionDateTimeZoneOffsetMinutes: 540,
  yearMonth: '2026-08',
  excludedFromAggregation: excludedFromAggregation,
  sourceImageObjectKey: sourceImageObjectKey,
  analysisAdjustedByUser: true,
);

/// テスト用の明細を fake の Firestore に保存する。
Future<void> saveTransaction({
  required Transaction transaction,
  required FakeFirebaseFirestore firebaseFirestore,
}) => transactionsReference(
  userID: transaction.userID,
  firebaseFirestore: firebaseFirestore,
).doc(transaction.id).set(transaction);

/// fake の Firestore に記録された監査ログをすべて読み戻す。
///
/// サーバータイムスタンプは fake では同一時刻になり得るため、順序ではなく
/// 操作種別と対象で絞り込んで検証する。
Future<List<AuditLog>> readAuditLogs({
  required FakeFirebaseFirestore firebaseFirestore,
}) async => (await auditLogsReference(
  userID: 'user-id',
  firebaseFirestore: firebaseFirestore,
).get()).docs.map((doc) => doc.data()).toList();

/// fake の Firestore から明細を読み戻す。削除済みなら null。
Future<Transaction?> readTransaction({
  required String transactionID,
  required FakeFirebaseFirestore firebaseFirestore,
}) async => (await transactionsReference(
  userID: 'user-id',
  firebaseFirestore: firebaseFirestore,
).doc(transactionID).get()).data();

void main() {
  group('UpdateTransactionExclusion', () {
    test('計算対象から除外するフラグだけを更新し、他のフィールドは保つ', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );

      await UpdateTransactionExclusion(
        firebaseFirestore: firebaseFirestore,
      ).call(transaction: transaction, excludedFromAggregation: true);

      final updatedTransaction = await readTransaction(
        transactionID: 'transaction-id',
        firebaseFirestore: firebaseFirestore,
      );
      expect(updatedTransaction!.excludedFromAggregation, isTrue);
      expect(updatedTransaction.amount, 1280);
      expect(updatedTransaction.title, 'スーパーマーケット');
      expect(updatedTransaction.category, TransactionCategory.food);
      expect(updatedTransaction.source, TransactionSource.receipt);
      expect(updatedTransaction.sourceImageObjectKey, 'users/user-id/uuid.png');
      expect(updatedTransaction.analysisAdjustedByUser, isTrue);
      expect(updatedTransaction.yearMonth, '2026-08');
    });

    test('同じ値を書き込む再実行でも結果が変わらない (冪等)', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final updateTransactionExclusion = UpdateTransactionExclusion(
        firebaseFirestore: firebaseFirestore,
      );

      await updateTransactionExclusion.call(
        transaction: transaction,
        excludedFromAggregation: true,
      );
      await updateTransactionExclusion.call(
        transaction: transaction,
        excludedFromAggregation: true,
      );

      expect(
        (await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ))!.excludedFromAggregation,
        isTrue,
      );
    });
  });

  group('RemoveTransactionSourceImage', () {
    test('画像を削除してから明細の紐付けを外す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];
      String? sourceImageObjectKeyDuringImageDeletion;

      await RemoveTransactionSourceImage(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
          // 画像削除の時点ではまだ明細から画像を辿れる (逆順だと孤児画像が残る)
          sourceImageObjectKeyDuringImageDeletion = (await readTransaction(
            transactionID: 'transaction-id',
            firebaseFirestore: firebaseFirestore,
          ))?.sourceImageObjectKey;
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, ['users/user-id/uuid.png']);
      expect(sourceImageObjectKeyDuringImageDeletion, 'users/user-id/uuid.png');
      final updatedTransaction = await readTransaction(
        transactionID: 'transaction-id',
        firebaseFirestore: firebaseFirestore,
      );
      expect(updatedTransaction!.sourceImageObjectKey, isNull);
      // 明細自体は残り、他のフィールドも保たれる
      expect(updatedTransaction.amount, 1280);
      expect(updatedTransaction.title, 'スーパーマーケット');
    });

    test('同じ元画像を参照する明細が他にあれば R2 の画像は消さず、紐付けだけを外す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      // 1 枚のスクショから登録した 2 明細 (同じ元画像キーを共有)。
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/shared.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      await saveTransaction(
        transaction: buildTransaction(
          id: 'sibling-transaction-id',
          sourceImageObjectKey: 'users/user-id/shared.png',
          excludedFromAggregation: false,
        ),
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];

      await RemoveTransactionSourceImage(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, isEmpty);
      expect(
        (await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ))!.sourceImageObjectKey,
        isNull,
      );
      // もう片方の明細からは引き続き元画像を辿れる。
      expect(
        (await readTransaction(
          transactionID: 'sibling-transaction-id',
          firebaseFirestore: firebaseFirestore,
        ))!.sourceImageObjectKey,
        'users/user-id/shared.png',
      );
    });

    test('画像が無い明細では画像削除も書き込みも行わない', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];

      await RemoveTransactionSourceImage(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, isEmpty);
      expect(
        (await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ))!.sourceImageObjectKey,
        isNull,
      );
    });
  });

  group('DeleteTransaction', () {
    test('画像ありの明細は画像を削除してからドキュメントを削除する', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];
      Transaction? transactionDuringImageDeletion;

      await DeleteTransaction(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
          transactionDuringImageDeletion = await readTransaction(
            transactionID: 'transaction-id',
            firebaseFirestore: firebaseFirestore,
          );
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, ['users/user-id/uuid.png']);
      // 画像削除の時点ではドキュメントが残っている (画像 → ドキュメントの順)
      expect(transactionDuringImageDeletion, isNotNull);
      expect(
        await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ),
        isNull,
      );
    });

    test('同じ元画像を参照する明細が他にあれば R2 の画像は消さず、ドキュメントだけを削除する', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      // 1 枚のスクショから登録した 2 明細 (同じ元画像キーを共有)。
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/shared.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      await saveTransaction(
        transaction: buildTransaction(
          id: 'sibling-transaction-id',
          sourceImageObjectKey: 'users/user-id/shared.png',
          excludedFromAggregation: false,
        ),
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];

      await DeleteTransaction(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, isEmpty);
      expect(
        await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ),
        isNull,
      );
      // もう片方の明細からは引き続き元画像を辿れる。
      expect(
        (await readTransaction(
          transactionID: 'sibling-transaction-id',
          firebaseFirestore: firebaseFirestore,
        ))!.sourceImageObjectKey,
        'users/user-id/shared.png',
      );
    });

    test('画像なしの明細は画像削除を呼ばずにドキュメントだけを削除する', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final deletedImageObjectKeys = <String>[];

      await DeleteTransaction(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
        },
      ).call(transaction: transaction);

      expect(deletedImageObjectKeys, isEmpty);
      expect(
        await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ),
        isNull,
      );
    });

    test('削除済みの明細に再実行しても成功する (冪等)', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      final deletedImageObjectKeys = <String>[];
      final deleteTransaction = DeleteTransaction(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {
          deletedImageObjectKeys.add(imageObjectKey);
        },
      );

      // ドキュメントが存在しない状態でも例外にならない (Worker 側の画像削除も冪等)
      await deleteTransaction.call(transaction: transaction);
      await deleteTransaction.call(transaction: transaction);

      expect(deletedImageObjectKeys, [
        'users/user-id/uuid.png',
        'users/user-id/uuid.png',
      ]);
      expect(
        await readTransaction(
          transactionID: 'transaction-id',
          firebaseFirestore: firebaseFirestore,
        ),
        isNull,
      );
    });
  });

  group('監査ログ', () {
    test('明細の作成で作成の履歴が同じバッチに残る', () async {
      final firebaseFirestore = FakeFirebaseFirestore();

      await AddTransaction(
        userID: 'user-id',
        firebaseFirestore: firebaseFirestore,
      ).call(
        type: TransactionType.expense,
        source: TransactionSource.manual,
        amount: 980,
        category: TransactionCategory.food,
        title: 'コンビニ',
        transactionDate: DateTime(2026, 8, 23, 12),
        excludedFromAggregation: false,
        sourceImageObjectKey: null,
        analysisAdjustedByUser: false,
      );

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(1));
      expect(auditLogs.single.operation, AuditLogOperation.transactionCreated);
      expect(auditLogs.single.userID, 'user-id');
      expect(auditLogs.single.transactionTitle, 'コンビニ');
      expect(auditLogs.single.transactionAmount, 980);
      expect(auditLogs.single.changedFieldNames, isEmpty);
      // 履歴の対象 ID から作成された明細を辿れる。
      expect(
        (await readTransaction(
          transactionID: auditLogs.single.transactionID!,
          firebaseFirestore: firebaseFirestore,
        ))!.title,
        'コンビニ',
      );
    });

    test('計算対象の切替で訂正の履歴が残り、値が変わらない再実行では増えない', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      final updateTransactionExclusion = UpdateTransactionExclusion(
        firebaseFirestore: firebaseFirestore,
      );

      await updateTransactionExclusion.call(
        transaction: transaction,
        excludedFromAggregation: true,
      );
      await updateTransactionExclusion.call(
        transaction: transaction,
        excludedFromAggregation: true,
      );

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(1));
      expect(auditLogs.single.operation, AuditLogOperation.transactionUpdated);
      expect(auditLogs.single.transactionID, 'transaction-id');
      expect(auditLogs.single.changedFieldNames, [
        TransactionFirestoreKeys.excludedFromAggregation,
      ]);
    });

    test('元画像だけの削除で画像削除と訂正の履歴が残る', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );

      await RemoveTransactionSourceImage(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {},
      ).call(transaction: transaction);

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(2));
      final imageDeletionLog = auditLogs.singleWhere(
        (auditLog) =>
            auditLog.operation == AuditLogOperation.transactionImageDeleted,
      );
      expect(imageDeletionLog.imageObjectKey, 'users/user-id/uuid.png');
      expect(imageDeletionLog.transactionID, 'transaction-id');
      expect(
        auditLogs
            .singleWhere(
              (auditLog) =>
                  auditLog.operation == AuditLogOperation.transactionUpdated,
            )
            .changedFieldNames,
        [TransactionFirestoreKeys.sourceImageObjectKey],
      );
    });

    test('他の明細が参照する元画像では画像削除の履歴を残さない', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/shared.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );
      await saveTransaction(
        transaction: buildTransaction(
          id: 'sibling-transaction-id',
          sourceImageObjectKey: 'users/user-id/shared.png',
          excludedFromAggregation: false,
        ),
        firebaseFirestore: firebaseFirestore,
      );

      await RemoveTransactionSourceImage(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {},
      ).call(transaction: transaction);

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs.map((auditLog) => auditLog.operation), [
        AuditLogOperation.transactionUpdated,
      ]);
    });

    test('明細の削除で画像削除と削除の履歴が残る', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final transaction = buildTransaction(
        id: 'transaction-id',
        sourceImageObjectKey: 'users/user-id/uuid.png',
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: transaction,
        firebaseFirestore: firebaseFirestore,
      );

      await DeleteTransaction(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {},
      ).call(transaction: transaction);

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(2));
      // 明細が消えた後も、履歴から店名と金額を確認できる。
      final deletionLog = auditLogs.singleWhere(
        (auditLog) =>
            auditLog.operation == AuditLogOperation.transactionDeleted,
      );
      expect(deletionLog.transactionID, 'transaction-id');
      expect(deletionLog.transactionTitle, 'スーパーマーケット');
      expect(deletionLog.transactionAmount, 1280);
      expect(
        auditLogs
            .singleWhere(
              (auditLog) =>
                  auditLog.operation ==
                  AuditLogOperation.transactionImageDeleted,
            )
            .imageObjectKey,
        'users/user-id/uuid.png',
      );
    });

    test('重複候補のマージで残す側の訂正と削除側の削除の履歴が残る', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final primaryTransaction = buildTransaction(
        id: 'primary-transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      final duplicateTransaction = buildTransaction(
        id: 'duplicate-transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: primaryTransaction,
        firebaseFirestore: firebaseFirestore,
      );
      await saveTransaction(
        transaction: duplicateTransaction,
        firebaseFirestore: firebaseFirestore,
      );

      await MergeDuplicateTransactions(
        firebaseFirestore: firebaseFirestore,
        deleteStoredImage: ({required imageObjectKey}) async {},
      ).call(
        primaryTransaction: primaryTransaction,
        duplicateTransaction: duplicateTransaction,
      );

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(2));
      expect(
        auditLogs
            .singleWhere(
              (auditLog) =>
                  auditLog.operation == AuditLogOperation.transactionUpdated,
            )
            .transactionID,
        'primary-transaction-id',
      );
      expect(
        auditLogs
            .singleWhere(
              (auditLog) =>
                  auditLog.operation == AuditLogOperation.transactionDeleted,
            )
            .transactionID,
        'duplicate-transaction-id',
      );
    });

    test('別々の支出として残すと両方の明細に訂正の履歴が残り、再実行では増えない', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      final firstTransaction = buildTransaction(
        id: 'first-transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      final secondTransaction = buildTransaction(
        id: 'second-transaction-id',
        sourceImageObjectKey: null,
        excludedFromAggregation: false,
      );
      await saveTransaction(
        transaction: firstTransaction,
        firebaseFirestore: firebaseFirestore,
      );
      await saveTransaction(
        transaction: secondTransaction,
        firebaseFirestore: firebaseFirestore,
      );
      final keepBothTransactions = KeepBothTransactions(
        firebaseFirestore: firebaseFirestore,
      );

      await keepBothTransactions.call(
        firstTransaction: firstTransaction,
        secondTransaction: secondTransaction,
      );
      await keepBothTransactions.call(
        firstTransaction: firstTransaction,
        secondTransaction: secondTransaction,
      );

      final auditLogs = await readAuditLogs(
        firebaseFirestore: firebaseFirestore,
      );
      expect(auditLogs, hasLength(2));
      expect(auditLogs.map((auditLog) => auditLog.transactionID).toSet(), {
        'first-transaction-id',
        'second-transaction-id',
      });
      for (final auditLog in auditLogs) {
        expect(auditLog.operation, AuditLogOperation.transactionUpdated);
        expect(auditLog.changedFieldNames, [
          TransactionFirestoreKeys.confirmedDistinctTransactionIDs,
        ]);
      }
    });
  });
}
