// 明細の更新・削除を行う機能 Provider (call クラス) のテスト。
// Firestore への読み書きは FakeFirebaseFirestore に対して行い、書き込み結果を読み戻して検証する。
// R2 の画像削除 (DeleteStoredImage) は呼び出しを記録する fake に差し替え、
// 画像削除と Firestore 更新の順序も合わせて確認する。
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/transaction.dart';
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
}
