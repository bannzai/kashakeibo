// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/transaction.dart';
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
  return AddTransaction(userID: userID);
}

/// 明細の新規作成 (`.claude/rules/coding-conventions.md` の call クラス)。
class AddTransaction {
  /// 明細の所有ユーザー ID。
  final String userID;

  AddTransaction({required this.userID});

  /// 明細を 1 件作成する。
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
    final documentReference = transactionsReference(userID: userID).doc();
    final serverWrite = documentReference.set(
      Transaction(
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
      ),
    );
    final localWrite = documentReference
        .snapshots(includeMetadataChanges: true)
        .firstWhere((snapshot) => snapshot.exists)
        .then<void>((_) {});
    // set の Future はオフライン中にサーバー同期を待ち続ける。ローカルキャッシュへの
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
  /// 同じ値を書き込む再実行は結果を変えないため冪等。削除済みなら何もしない。
  Future<void> call({
    required Transaction transaction,
    required bool excludedFromAggregation,
  }) => _updateLatestTransaction(
    firebaseFirestore: firebaseFirestore,
    transaction: transaction,
    update: (latestTransaction) => latestTransaction.copyWith(
      excludedFromAggregation: excludedFromAggregation,
    ),
  );
}

/// [transaction] のドキュメントを Firestore トランザクションで読み直し、最新の明細に
/// [update] を適用して書き戻す。削除済み (null) の場合は何もしない。
Future<void> _updateLatestTransaction({
  required FirebaseFirestore firebaseFirestore,
  required Transaction transaction,
  required Transaction Function(Transaction latestTransaction) update,
}) {
  final transactionReference = transactionsReference(
    userID: transaction.userID,
    firebaseFirestore: firebaseFirestore,
  ).doc(transaction.id);
  return firebaseFirestore.runTransaction((firestoreTransaction) async {
    final latestTransaction = (await firestoreTransaction.get(
      transactionReference,
    )).data();
    if (latestTransaction == null) {
      return;
    }
    firestoreTransaction.set(
      transactionReference,
      update(latestTransaction),
      SetOptions(merge: true),
    );
  });
}

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
  /// 再実行で同じ結果に収束するため冪等。逆順にすると明細から辿れない孤児画像が残る。
  /// 紐付けの解除は Firestore トランザクションで読み直した最新の明細に対して行い、
  /// 並行した他の変更 (計算対象除外の切替等) を巻き戻さない。
  Future<void> call({required Transaction transaction}) async {
    final sourceImageObjectKey = transaction.sourceImageObjectKey;
    if (sourceImageObjectKey == null) {
      return;
    }
    await deleteStoredImage(imageObjectKey: sourceImageObjectKey);
    await _updateLatestTransaction(
      firebaseFirestore: firebaseFirestore,
      transaction: transaction,
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

  /// [transaction] の元画像 (あれば) と Firestore ドキュメントを削除する。
  ///
  /// 画像の削除 → ドキュメントの削除の順で行う。どちらも対象が無くても成功するため、
  /// 途中で失敗しても再実行で同じ結果に収束する (冪等)。
  Future<void> call({required Transaction transaction}) async {
    final sourceImageObjectKey = transaction.sourceImageObjectKey;
    if (sourceImageObjectKey != null) {
      await deleteStoredImage(imageObjectKey: sourceImageObjectKey);
    }
    await transactionsReference(
      userID: transaction.userID,
      firebaseFirestore: firebaseFirestore,
    ).doc(transaction.id).delete();
  }
}

/// 重複候補 2 件を 1 件へ統合する機能 Provider。
@riverpod
MergeDuplicateTransactions mergeDuplicateTransactions(Ref ref) =>
    MergeDuplicateTransactions(
      deleteStoredImage: ref.watch(deleteStoredImageProvider),
    );

/// 重複候補 2 件を Firestore トランザクションで 1 件へ統合する。
class MergeDuplicateTransactions {
  /// Worker 経由で R2 の画像 1 件を削除する操作。
  final DeleteStoredImage deleteStoredImage;

  const MergeDuplicateTransactions({required this.deleteStoredImage});

  /// [primaryTransaction] を残し、[duplicateTransaction] を削除する。
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
    ).doc(primaryTransaction.id);
    final duplicateReference = transactionsReference(
      userID: duplicateTransaction.userID,
    ).doc(duplicateTransaction.id);

    // 削除側にだけ画像があれば残す側へ引き継ぎ、両方にあれば削除側の画像を消す対象として返す。
    final orphanedImageObjectKey = await FirebaseFirestore.instance
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
          firestoreTransaction.set(
            primaryReference,
            latestPrimaryTransaction.copyWith(
              confirmedDistinctTransactionIDs:
                  confirmedDistinctTransactionIDs.toList()..sort(),
              sourceImageObjectKey: inheritsDuplicateImage
                  ? latestDuplicateTransaction.sourceImageObjectKey
                  : latestPrimaryTransaction.sourceImageObjectKey,
            ),
            SetOptions(merge: true),
          );
          firestoreTransaction.delete(duplicateReference);
          return inheritsDuplicateImage
              ? null
              : latestDuplicateTransaction.sourceImageObjectKey;
        });
    // マージ確定後に削除側の画像を消す。ここで失敗しても明細の統合は完了しており、
    // 残った画像はアカウント削除時の全消去で回収される。
    if (orphanedImageObjectKey != null) {
      await deleteStoredImage(imageObjectKey: orphanedImageObjectKey);
    }
  }
}

/// 重複候補 2 件を別々の明細として残す機能 Provider。
@riverpod
KeepBothTransactions keepBothTransactions(Ref ref) =>
    const KeepBothTransactions();

/// 重複候補 2 件へ相互の ID を記録し、同じ候補を再提示しないようにする。
class KeepBothTransactions {
  const KeepBothTransactions();

  /// 2 件を「別物として残す」と Firestore トランザクションで確定する。
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
    ).doc(firstTransaction.id);
    final secondReference = transactionsReference(
      userID: secondTransaction.userID,
    ).doc(secondTransaction.id);

    await FirebaseFirestore.instance.runTransaction((
      firestoreTransaction,
    ) async {
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

      firestoreTransaction.set(
        firstReference,
        latestFirstTransaction.copyWith(
          confirmedDistinctTransactionIDs: <String>{
            ...latestFirstTransaction.confirmedDistinctTransactionIDs,
            latestSecondTransaction.id,
          }.toList()..sort(),
        ),
        SetOptions(merge: true),
      );
      firestoreTransaction.set(
        secondReference,
        latestSecondTransaction.copyWith(
          confirmedDistinctTransactionIDs: <String>{
            ...latestSecondTransaction.confirmedDistinctTransactionIDs,
            latestFirstTransaction.id,
          }.toList()..sort(),
        ),
        SetOptions(merge: true),
      );
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
