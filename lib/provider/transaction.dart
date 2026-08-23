// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/audit_log.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/provider/audit_log.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/image.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction.g.dart';

/// `/users/{userID}/transactions` への未変換の参照。
CollectionReference<Map<String, dynamic>> transactionDocumentsReference({
  required String userID,
  FirebaseFirestore? firebaseFirestore,
}) => (firebaseFirestore ?? FirebaseFirestore.instance)
    .collection('users')
    .doc(userID)
    .collection('transactions');

/// `/users/{userID}/transactions` への参照 (Entity コンバータ適用済み)。
CollectionReference<Transaction> transactionsReference({
  required String userID,
  FirebaseFirestore? firebaseFirestore,
}) =>
    transactionDocumentsReference(
      userID: userID,
      firebaseFirestore: firebaseFirestore,
    ).withConverter(
      fromFirestore: Transaction.fromFirestore,
      toFirestore: Transaction.toFirestore,
    );

/// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
///
/// snapshot listener なので編集・追加はリアルタイムに反映され、
/// Firestore のオフラインキャッシュがあればオフラインでも動作する。
@riverpod
Stream<List<Transaction>> monthlyTransactions(
  Ref ref, {
  required String yearMonth,
}) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    return Stream.value(const []);
  }
  return transactionsReference(userID: userID)
      .where(TransactionFirestoreKeys.yearMonth, isEqualTo: yearMonth)
      .orderBy(TransactionFirestoreKeys.transactionDate, descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}

/// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
///
/// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
@riverpod
Stream<Transaction?> transaction(Ref ref, {required String transactionID}) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    return Stream.value(null);
  }
  return transactionsReference(
    userID: userID,
  ).doc(transactionID).snapshots().map((snapshot) => snapshot.data());
}

/// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
///
/// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
@riverpod
List<DuplicateCandidate> monthlyDuplicateCandidates(
  Ref ref, {
  required String yearMonth,
}) {
  final monthStart = DateTime.parse('$yearMonth-01');
  final transactions = <Transaction>[];
  for (final monthOffset in const [-1, 0, 1]) {
    final queryMonth = DateTime(
      monthStart.year,
      monthStart.month + monthOffset,
    );
    transactions.addAll(
      ref
              .watch(
                monthlyTransactionsProvider(
                  yearMonth: yearMonthFrom(dateTime: queryMonth),
                ),
              )
              .value ??
          const [],
    );
  }

  return duplicateCandidates(transactions: transactions)
      .where(
        (candidate) =>
            candidate.primaryTransaction.yearMonth == yearMonth ||
            candidate.duplicateTransaction.yearMonth == yearMonth,
      )
      .toList();
}

/// 明細を新規作成する機能 Provider。
@riverpod
AddTransaction addTransaction(Ref ref) {
  final userID = ref.watch(currentUserIDProvider);
  if (userID == null) {
    // サインイン完了 (SignInResolver) 後の画面からのみ利用される前提。
    throw StateError('サインイン前に AddTransaction は利用できない');
  }
  return AddTransaction(
    userID: userID,
    firebaseFirestore: FirebaseFirestore.instance,
  );
}

/// 明細の新規作成 (`.claude/rules/coding-conventions.md` の call クラス)。
class AddTransaction {
  /// 明細の所有ユーザー ID。
  final String userID;

  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  AddTransaction({required this.userID, required this.firebaseFirestore});

  /// 明細を 1 件作成し、作成の監査ログを同じバッチで残す。
  ///
  /// 冪等ではない: 明細の追加はユーザー操作 1 回 = 1 件の意味を持ち、
  /// Firestore の自動生成 ID で毎回新しいドキュメントを作るため。
  ///
  /// yearMonth はここで [transactionDate] から導出し、呼び出し側に渡させない。
  /// 両フィールドの食い違いを構造的に防ぐため。
  ///
  /// [sourceImageObjectKey] は撮影・取込フローでアップロード済みの元画像のキー
  /// (手動入力は null)。[analysisAdjustedByUser] は AI 解析結果をユーザーが修正したか。
  Future<void> call({
    required TransactionType type,
    required TransactionSource source,
    required int amount,
    required TransactionCategory category,
    required String title,
    required DateTime transactionDate,
    required bool excludedFromAggregation,
    required String? sourceImageObjectKey,
    required bool analysisAdjustedByUser,
  }) async {
    final documentReference = transactionsReference(
      userID: userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();
    final createdTransaction = Transaction(
      id: documentReference.id,
      userID: userID,
      type: type,
      source: source,
      amount: amount,
      category: category,
      title: title,
      transactionDate: transactionDate,
      // yearMonth の導出 (ローカルタイム基準) と後からの表示・グループ化を
      // 同じカレンダー日に揃えるため、登録時のオフセットを保存する。
      transactionDateTimeZoneOffsetMinutes: transactionDate
          .toLocal()
          .timeZoneOffset
          .inMinutes,
      yearMonth: yearMonthFrom(dateTime: transactionDate),
      excludedFromAggregation: excludedFromAggregation,
      sourceImageObjectKey: sourceImageObjectKey,
      analysisAdjustedByUser: analysisAdjustedByUser,
    );
    final auditLogReference = auditLogsReference(
      userID: userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();
    // 明細と履歴が食い違わないよう、同じバッチでアトミックに書き込む。
    final serverWrite =
        (firebaseFirestore.batch()
              ..set(documentReference, createdTransaction)
              ..set(
                auditLogReference,
                transactionAuditLog(
                  auditLogID: auditLogReference.id,
                  operation: AuditLogOperation.transactionCreated,
                  transaction: createdTransaction,
                  imageObjectKey: null,
                  changedFieldNames: const [],
                ),
              ))
            .commit();
    final localWrite = documentReference
        .snapshots(includeMetadataChanges: true)
        .firstWhere((snapshot) => snapshot.exists)
        .then<void>((_) {});
    // commit の Future はオフライン中にサーバー同期を待ち続ける。ローカルキャッシュへの
    // 反映を登録完了として扱い、サーバー同期は Firestore の永続キューに委ねる。
    await Future.any([serverWrite, localWrite]);
  }
}

/// 明細の計算対象除外フラグを更新する機能 Provider。
@riverpod
UpdateTransactionExclusion updateTransactionExclusion(Ref ref) =>
    UpdateTransactionExclusion(firebaseFirestore: FirebaseFirestore.instance);

/// 明細を集計の計算対象から除外する・戻す。
class UpdateTransactionExclusion {
  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  UpdateTransactionExclusion({required this.firebaseFirestore});

  /// [transaction] の excludedFromAggregation を [excludedFromAggregation] に更新する。
  ///
  /// 画面が保持する明細ではなく Firestore トランザクションで読み直した最新の明細に
  /// 対して copyWith するため、別端末の変更 (元画像の削除等) を古い値で巻き戻さない。
  /// 同じ値を書き込む再実行は書き込み自体を行わないため冪等。削除済みなら何もしない。
  Future<void> call({
    required Transaction transaction,
    required bool excludedFromAggregation,
  }) => _updateLatestTransaction(
    firebaseFirestore: firebaseFirestore,
    transaction: transaction,
    changedFieldNames: const [TransactionFirestoreKeys.excludedFromAggregation],
    update: (latestTransaction) => latestTransaction.copyWith(
      excludedFromAggregation: excludedFromAggregation,
    ),
  );
}

/// [transaction] のドキュメントを Firestore トランザクションで読み直し、最新の明細に
/// [update] を適用して書き戻し、同じトランザクションで訂正の監査ログを 1 件残す。
///
/// 削除済み (null) の場合と、[update] が最新の明細と同じ値を返した場合は何も書き込まない。
/// 値が変わらない再実行で履歴だけが増えないようにするため。
/// [changedFieldNames] には [update] が変更し得る Transaction のフィールド名を渡す。
Future<void> _updateLatestTransaction({
  required FirebaseFirestore firebaseFirestore,
  required Transaction transaction,
  required List<String> changedFieldNames,
  required Transaction Function(Transaction latestTransaction) update,
}) {
  final transactionReference = transactionsReference(
    userID: transaction.userID,
    firebaseFirestore: firebaseFirestore,
  ).doc(transaction.id);
  // 監査ログの参照はトランザクションの外で 1 度だけ作る。競合による再試行で
  // 同じ操作の履歴が複数件にならないようにするため。
  final auditLogReference = auditLogsReference(
    userID: transaction.userID,
    firebaseFirestore: firebaseFirestore,
  ).doc();
  return firebaseFirestore.runTransaction((firestoreTransaction) async {
    final latestTransaction = (await firestoreTransaction.get(
      transactionReference,
    )).data();
    if (latestTransaction == null) {
      return;
    }
    final updatedTransaction = update(latestTransaction);
    if (updatedTransaction == latestTransaction) {
      return;
    }
    firestoreTransaction.set(
      transactionReference,
      updatedTransaction,
      SetOptions(merge: true),
    );
    firestoreTransaction.set(
      auditLogReference,
      transactionAuditLog(
        auditLogID: auditLogReference.id,
        operation: AuditLogOperation.transactionUpdated,
        transaction: updatedTransaction,
        imageObjectKey: null,
        changedFieldNames: changedFieldNames,
      ),
    );
  });
}

/// R2 の画像削除が成功した後に、画像削除の監査ログを 1 件残す。
///
/// Worker への画像削除は Firestore の書き込みとアトミックにできないため、削除の成功後に
/// 記録する (削除されていない画像の履歴を残さない)。
/// 冪等ではない: 同じ画像に対する再実行は履歴を 1 件増やす。実行のたびに「削除した」
/// 事実を残すのが履歴の目的のため。
Future<void> _writeImageDeletionAuditLog({
  required FirebaseFirestore firebaseFirestore,
  required Transaction transaction,
  required String imageObjectKey,
}) {
  final auditLogReference = auditLogsReference(
    userID: transaction.userID,
    firebaseFirestore: firebaseFirestore,
  ).doc();
  return auditLogReference.set(
    transactionAuditLog(
      auditLogID: auditLogReference.id,
      operation: AuditLogOperation.transactionImageDeleted,
      transaction: transaction,
      imageObjectKey: imageObjectKey,
      changedFieldNames: const [],
    ),
  );
}

/// [imageObjectKey] を元画像として参照する明細が [excludedTransactionID] 以外にも存在するか。
///
/// 1 枚のスクショから複数の明細を登録した場合、同じ元画像キーを複数の明細が共有する
/// (lib/features/capture/README.md)。共有されている画像を R2 から消すと他の明細から
/// 元画像を辿れなくなるため、削除系の操作はこの判定で最後の参照の時だけ画像を消す。
Future<bool> _isImageReferencedByOtherTransaction({
  required FirebaseFirestore firebaseFirestore,
  required String userID,
  required String imageObjectKey,
  required String excludedTransactionID,
}) async =>
    (await transactionsReference(
              userID: userID,
              firebaseFirestore: firebaseFirestore,
            )
            .where(
              TransactionFirestoreKeys.sourceImageObjectKey,
              isEqualTo: imageObjectKey,
            )
            .limit(2)
            .get())
        .docs
        .any((snapshot) => snapshot.id != excludedTransactionID);

/// 明細から元画像だけを外す機能 Provider。
@riverpod
RemoveTransactionSourceImage removeTransactionSourceImage(Ref ref) =>
    RemoveTransactionSourceImage(
      firebaseFirestore: FirebaseFirestore.instance,
      deleteStoredImage: ref.watch(deleteStoredImageProvider),
    );

/// 明細を残したまま元画像を削除する (R2 の画像を消し、明細の紐付けを外す)。
class RemoveTransactionSourceImage {
  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  /// Worker 経由で R2 の画像 1 件を削除する操作。
  final DeleteStoredImage deleteStoredImage;

  RemoveTransactionSourceImage({
    required this.firebaseFirestore,
    required this.deleteStoredImage,
  });

  /// [transaction] の元画像を削除し、sourceImageObjectKey を null にする。
  ///
  /// 画像の削除 (対象が無くても成功) → 紐付けの解除の順で行い、途中で失敗しても
  /// 再実行で同じ結果に収束するため冪等 (画像削除の履歴だけは実行のたびに増える。
  /// [_writeImageDeletionAuditLog] 参照)。逆順にすると明細から辿れない孤児画像が残る。
  /// 他の明細が同じ元画像を参照している場合は R2 の画像は消さず、紐付けの解除だけを行う。
  /// 紐付けの解除は Firestore トランザクションで読み直した最新の明細に対して行い、
  /// 並行した他の変更 (計算対象除外の切替等) を巻き戻さない。
  Future<void> call({required Transaction transaction}) async {
    final sourceImageObjectKey = transaction.sourceImageObjectKey;
    if (sourceImageObjectKey == null) {
      return;
    }
    if (!await _isImageReferencedByOtherTransaction(
      firebaseFirestore: firebaseFirestore,
      userID: transaction.userID,
      imageObjectKey: sourceImageObjectKey,
      excludedTransactionID: transaction.id,
    )) {
      await deleteStoredImage(imageObjectKey: sourceImageObjectKey);
      await _writeImageDeletionAuditLog(
        firebaseFirestore: firebaseFirestore,
        transaction: transaction,
        imageObjectKey: sourceImageObjectKey,
      );
    }
    await _updateLatestTransaction(
      firebaseFirestore: firebaseFirestore,
      transaction: transaction,
      changedFieldNames: const [TransactionFirestoreKeys.sourceImageObjectKey],
      update: (latestTransaction) =>
          latestTransaction.copyWith(sourceImageObjectKey: null),
    );
  }
}

/// 明細を元画像ごと削除する機能 Provider。
@riverpod
DeleteTransaction deleteTransaction(Ref ref) => DeleteTransaction(
  firebaseFirestore: FirebaseFirestore.instance,
  deleteStoredImage: ref.watch(deleteStoredImageProvider),
);

/// 明細と、紐づく元画像を削除する。
class DeleteTransaction {
  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  /// Worker 経由で R2 の画像 1 件を削除する操作。
  final DeleteStoredImage deleteStoredImage;

  DeleteTransaction({
    required this.firebaseFirestore,
    required this.deleteStoredImage,
  });

  /// [transaction] の元画像 (あれば) と Firestore ドキュメントを削除し、削除の監査ログを
  /// ドキュメントの削除と同じバッチで残す。
  ///
  /// 画像の削除 → ドキュメントの削除の順で行う。どちらも対象が無くても成功するため、
  /// 途中で失敗しても再実行で同じ結果に収束する (冪等)。ただし削除の履歴は実行のたびに
  /// 1 件増える: 削除済みかどうかで分岐するには読み取りを伴う runTransaction が必要になり、
  /// オフラインで削除できなくなるため (WriteBatch はローカルキューに積まれる)。
  /// 他の明細が同じ元画像を参照している場合は R2 の画像は消さず、ドキュメントだけを削除する。
  Future<void> call({required Transaction transaction}) async {
    final sourceImageObjectKey = transaction.sourceImageObjectKey;
    if (sourceImageObjectKey != null &&
        !await _isImageReferencedByOtherTransaction(
          firebaseFirestore: firebaseFirestore,
          userID: transaction.userID,
          imageObjectKey: sourceImageObjectKey,
          excludedTransactionID: transaction.id,
        )) {
      await deleteStoredImage(imageObjectKey: sourceImageObjectKey);
      await _writeImageDeletionAuditLog(
        firebaseFirestore: firebaseFirestore,
        transaction: transaction,
        imageObjectKey: sourceImageObjectKey,
      );
    }
    final auditLogReference = auditLogsReference(
      userID: transaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();
    await (firebaseFirestore.batch()
          ..delete(
            transactionsReference(
              userID: transaction.userID,
              firebaseFirestore: firebaseFirestore,
            ).doc(transaction.id),
          )
          ..set(
            auditLogReference,
            transactionAuditLog(
              auditLogID: auditLogReference.id,
              operation: AuditLogOperation.transactionDeleted,
              transaction: transaction,
              imageObjectKey: null,
              changedFieldNames: const [],
            ),
          ))
        .commit();
  }
}

/// 重複候補 2 件を 1 件へ統合する機能 Provider。
@riverpod
MergeDuplicateTransactions mergeDuplicateTransactions(Ref ref) =>
    MergeDuplicateTransactions(
      firebaseFirestore: FirebaseFirestore.instance,
      deleteStoredImage: ref.watch(deleteStoredImageProvider),
    );

/// 重複候補 2 件を Firestore トランザクションで 1 件へ統合する。
class MergeDuplicateTransactions {
  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  /// Worker 経由で R2 の画像 1 件を削除する操作。
  final DeleteStoredImage deleteStoredImage;

  const MergeDuplicateTransactions({
    required this.firebaseFirestore,
    required this.deleteStoredImage,
  });

  /// [primaryTransaction] を残し、[duplicateTransaction] を削除する。
  /// 残す側の訂正と削除側の削除の監査ログを、同じ Firestore トランザクションで残す。
  ///
  /// 同じ操作が再実行され、削除対象が存在しない場合は成功済みとして終了するため冪等。
  /// 逆向きのマージや「別物として残す」が別端末から同時実行された場合も、
  /// Firestore の競合検知後に最新状態で再試行され、両方を削除しない。
  ///
  /// 元画像は残す側に無ければ削除側から引き継ぎ、残す側にもある場合は削除側の画像を
  /// R2 から消す (明細から辿れない画像を残さない)。
  Future<void> call({
    required Transaction primaryTransaction,
    required Transaction duplicateTransaction,
  }) async {
    _validateDifferentTransactions(
      firstTransaction: primaryTransaction,
      secondTransaction: duplicateTransaction,
    );
    final primaryReference = transactionsReference(
      userID: primaryTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc(primaryTransaction.id);
    final duplicateReference = transactionsReference(
      userID: duplicateTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc(duplicateTransaction.id);
    // 監査ログの参照はトランザクションの外で 1 度だけ作る。競合による再試行で
    // 同じ操作の履歴が複数件にならないようにするため。
    final primaryAuditLogReference = auditLogsReference(
      userID: primaryTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();
    final duplicateAuditLogReference = auditLogsReference(
      userID: duplicateTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();

    // 削除側にだけ画像があれば残す側へ引き継ぎ、両方にあれば削除側の画像を消す対象として返す。
    final orphanedImageObjectKey = await firebaseFirestore
        .runTransaction<String?>((firestoreTransaction) async {
          final primarySnapshot = await firestoreTransaction.get(
            primaryReference,
          );
          final duplicateSnapshot = await firestoreTransaction.get(
            duplicateReference,
          );
          final latestPrimaryTransaction = primarySnapshot.data();
          final latestDuplicateTransaction = duplicateSnapshot.data();

          // 同じ向きの再実行、または逆向きのマージが先に完了した状態。
          if (latestPrimaryTransaction == null ||
              latestDuplicateTransaction == null) {
            return null;
          }
          if (!isDuplicateCandidate(
            firstTransaction: latestPrimaryTransaction,
            secondTransaction: latestDuplicateTransaction,
          )) {
            throw StateError('明細が更新されたため、重複候補ではなくなりました');
          }

          final confirmedDistinctTransactionIDs =
              <String>{
                  ...latestPrimaryTransaction.confirmedDistinctTransactionIDs,
                  ...latestDuplicateTransaction.confirmedDistinctTransactionIDs,
                }
                ..remove(latestPrimaryTransaction.id)
                ..remove(latestDuplicateTransaction.id);
          final inheritsDuplicateImage =
              latestPrimaryTransaction.sourceImageObjectKey == null &&
              latestDuplicateTransaction.sourceImageObjectKey != null;
          final mergedPrimaryTransaction = latestPrimaryTransaction.copyWith(
            confirmedDistinctTransactionIDs:
                confirmedDistinctTransactionIDs.toList()..sort(),
            sourceImageObjectKey: inheritsDuplicateImage
                ? latestDuplicateTransaction.sourceImageObjectKey
                : latestPrimaryTransaction.sourceImageObjectKey,
          );
          firestoreTransaction.set(
            primaryReference,
            mergedPrimaryTransaction,
            SetOptions(merge: true),
          );
          firestoreTransaction.delete(duplicateReference);
          firestoreTransaction.set(
            primaryAuditLogReference,
            transactionAuditLog(
              auditLogID: primaryAuditLogReference.id,
              operation: AuditLogOperation.transactionUpdated,
              transaction: mergedPrimaryTransaction,
              imageObjectKey: null,
              changedFieldNames: [
                TransactionFirestoreKeys.confirmedDistinctTransactionIDs,
                if (inheritsDuplicateImage)
                  TransactionFirestoreKeys.sourceImageObjectKey,
              ],
            ),
          );
          firestoreTransaction.set(
            duplicateAuditLogReference,
            transactionAuditLog(
              auditLogID: duplicateAuditLogReference.id,
              operation: AuditLogOperation.transactionDeleted,
              transaction: latestDuplicateTransaction,
              imageObjectKey: null,
              changedFieldNames: const [],
            ),
          );
          return inheritsDuplicateImage
              ? null
              : latestDuplicateTransaction.sourceImageObjectKey;
        });
    // マージ確定後に削除側の画像を消す。ここで失敗しても明細の統合は完了しており、
    // 残った画像はアカウント削除時の全消去で回収される。
    // 他の明細 (同じスクショから登録した明細) が同じ画像を参照している場合は消さない。
    if (orphanedImageObjectKey != null &&
        !await _isImageReferencedByOtherTransaction(
          firebaseFirestore: firebaseFirestore,
          userID: duplicateTransaction.userID,
          imageObjectKey: orphanedImageObjectKey,
          excludedTransactionID: duplicateTransaction.id,
        )) {
      await deleteStoredImage(imageObjectKey: orphanedImageObjectKey);
      await _writeImageDeletionAuditLog(
        firebaseFirestore: firebaseFirestore,
        transaction: duplicateTransaction,
        imageObjectKey: orphanedImageObjectKey,
      );
    }
  }
}

/// 重複候補 2 件を別々の明細として残す機能 Provider。
@riverpod
KeepBothTransactions keepBothTransactions(Ref ref) =>
    KeepBothTransactions(firebaseFirestore: FirebaseFirestore.instance);

/// 重複候補 2 件へ相互の ID を記録し、同じ候補を再提示しないようにする。
class KeepBothTransactions {
  /// Firestore クライアント。
  final FirebaseFirestore firebaseFirestore;

  const KeepBothTransactions({required this.firebaseFirestore});

  /// 2 件を「別物として残す」と Firestore トランザクションで確定し、両明細の訂正の
  /// 監査ログを同じトランザクションで残す。
  ///
  /// 相互の ID が既に記録されていれば書き込まず終了するため冪等。
  Future<void> call({
    required Transaction firstTransaction,
    required Transaction secondTransaction,
  }) async {
    _validateDifferentTransactions(
      firstTransaction: firstTransaction,
      secondTransaction: secondTransaction,
    );
    final firstReference = transactionsReference(
      userID: firstTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc(firstTransaction.id);
    final secondReference = transactionsReference(
      userID: secondTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc(secondTransaction.id);
    // 監査ログの参照はトランザクションの外で 1 度だけ作る。競合による再試行で
    // 同じ操作の履歴が複数件にならないようにするため。
    final firstAuditLogReference = auditLogsReference(
      userID: firstTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();
    final secondAuditLogReference = auditLogsReference(
      userID: secondTransaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc();

    await firebaseFirestore.runTransaction((firestoreTransaction) async {
      final firstSnapshot = await firestoreTransaction.get(firstReference);
      final secondSnapshot = await firestoreTransaction.get(secondReference);
      final latestFirstTransaction = firstSnapshot.data();
      final latestSecondTransaction = secondSnapshot.data();

      // マージが先に完了した場合は、残った 1 件をそのまま正とする。
      if (latestFirstTransaction == null || latestSecondTransaction == null) {
        return;
      }
      final firstAlreadyConfirmed = latestFirstTransaction
          .confirmedDistinctTransactionIDs
          .contains(latestSecondTransaction.id);
      final secondAlreadyConfirmed = latestSecondTransaction
          .confirmedDistinctTransactionIDs
          .contains(latestFirstTransaction.id);
      if (firstAlreadyConfirmed && secondAlreadyConfirmed) {
        return;
      }
      if (!isDuplicateCandidate(
        firstTransaction: latestFirstTransaction,
        secondTransaction: latestSecondTransaction,
      )) {
        throw StateError('明細が更新されたため、重複候補ではなくなりました');
      }

      final confirmedFirstTransaction = latestFirstTransaction.copyWith(
        confirmedDistinctTransactionIDs: <String>{
          ...latestFirstTransaction.confirmedDistinctTransactionIDs,
          latestSecondTransaction.id,
        }.toList()..sort(),
      );
      final confirmedSecondTransaction = latestSecondTransaction.copyWith(
        confirmedDistinctTransactionIDs: <String>{
          ...latestSecondTransaction.confirmedDistinctTransactionIDs,
          latestFirstTransaction.id,
        }.toList()..sort(),
      );
      firestoreTransaction.set(
        firstReference,
        confirmedFirstTransaction,
        SetOptions(merge: true),
      );
      firestoreTransaction.set(
        secondReference,
        confirmedSecondTransaction,
        SetOptions(merge: true),
      );
      for (final (auditLogReference, confirmedTransaction) in [
        (firstAuditLogReference, confirmedFirstTransaction),
        (secondAuditLogReference, confirmedSecondTransaction),
      ]) {
        firestoreTransaction.set(
          auditLogReference,
          transactionAuditLog(
            auditLogID: auditLogReference.id,
            operation: AuditLogOperation.transactionUpdated,
            transaction: confirmedTransaction,
            imageObjectKey: null,
            changedFieldNames: const [
              TransactionFirestoreKeys.confirmedDistinctTransactionIDs,
            ],
          ),
        );
      }
    });
  }
}

void _validateDifferentTransactions({
  required Transaction firstTransaction,
  required Transaction secondTransaction,
}) {
  if (firstTransaction.id == secondTransaction.id) {
    throw ArgumentError('同じ明細同士は重複候補として操作できません');
  }
  if (firstTransaction.userID != secondTransaction.userID) {
    throw ArgumentError('異なるユーザーの明細同士は操作できません');
  }
}
