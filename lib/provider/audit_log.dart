// cloud_firestore の Transaction クラスと Entity の Transaction が衝突するため hide する。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/entity/audit_log.dart';
import 'package:kashakeibo/entity/transaction.dart';
import 'package:kashakeibo/features/paywall/free_plan_history_limit.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:kashakeibo/provider/purchase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audit_log.g.dart';

/// 履歴画面が一度に購読する監査ログの最大件数。
///
/// 履歴は「直近の操作を後から確認する」用途
/// (documents/adr/0003-denshi-choubo-hozon-hou-youken-jissou.md の訂正削除履歴) で、
/// 全期間を遡る導線を持たないため、1 画面のスクロールで足りる件数に抑えて
/// 読み取り数を一定にする。
const int auditLogDisplayLimit = 200;

/// `/users/{userID}/auditLogs` への未変換の参照。
CollectionReference<Map<String, dynamic>> auditLogDocumentsReference({
  required String userID,
  FirebaseFirestore? firebaseFirestore,
}) => (firebaseFirestore ?? FirebaseFirestore.instance)
    .collection('users')
    .doc(userID)
    .collection('auditLogs');

/// `/users/{userID}/auditLogs` への参照 (Entity コンバータ適用済み)。
CollectionReference<AuditLog> auditLogsReference({
  required String userID,
  FirebaseFirestore? firebaseFirestore,
}) =>
    auditLogDocumentsReference(
      userID: userID,
      firebaseFirestore: firebaseFirestore,
    ).withConverter(
      fromFirestore: AuditLog.fromFirestore,
      toFirestore: AuditLog.toFirestore,
    );

/// 明細に対する操作の監査ログを組み立てる。
///
/// 削除された明細も履歴だけで識別できるよう、操作時点の店名・金額を写し取る。
AuditLog transactionAuditLog({
  required String auditLogID,
  required AuditLogOperation operation,
  required Transaction transaction,
  required String? imageObjectKey,
  required List<String> changedFieldNames,
}) => AuditLog(
  id: auditLogID,
  userID: transaction.userID,
  operation: operation,
  transactionID: transaction.id,
  imageObjectKey: imageObjectKey,
  transactionTitle: transaction.title,
  transactionAmount: transaction.amount,
  changedFieldNames: changedFieldNames,
);

/// 操作履歴を新しい順に読み取るクエリ。
///
/// [oldestServerCreatedDateTime] は無料プランで表示できる最古の記録時刻
/// (プレミアムは制限なしのため null)。非 null の場合はそれより古い履歴を読み取らず、
/// 操作履歴が「全期間の履歴」の制限の迂回経路にならないようにする
/// (制限の基準と UI ガードだけで守る方針は features/paywall/free_plan_history_limit.dart を参照)。
/// 範囲条件と並び順が同じフィールドのため複合インデックスは要らない。
Query<AuditLog> auditLogsQuery({
  required String userID,
  required DateTime? oldestServerCreatedDateTime,
  FirebaseFirestore? firebaseFirestore,
}) {
  Query<AuditLog> query = auditLogsReference(
    userID: userID,
    firebaseFirestore: firebaseFirestore,
  );
  if (oldestServerCreatedDateTime != null) {
    query = query.where(
      AuditLogFirestoreKeys.serverCreatedDateTime,
      isGreaterThanOrEqualTo: Timestamp.fromDate(oldestServerCreatedDateTime),
    );
  }
  return query
      .orderBy(AuditLogFirestoreKeys.serverCreatedDateTime, descending: true)
      .limit(auditLogDisplayLimit);
}

/// 操作履歴を新しい順に購読するストリーム。履歴画面の一覧に使う。
///
/// snapshot listener なので、履歴画面を開いたまま行った操作もそのまま追加される。
/// サーバータイムスタンプが確定するまでの書き込み直後のログは
/// [AuditLog.serverCreatedDateTime] が null で流れる (Firestore の並び順では末尾になり、
/// 無料プランの範囲条件からも外れるため、確定するまで一覧に出ない)。
@riverpod
Stream<List<AuditLog>> auditLogs(Ref ref) {
  final userID = ref.watch(currentUserIDProvider);
  final isPremium = ref.watch(isPremiumProvider);
  if (userID == null) {
    return Stream.value(const []);
  }
  return auditLogsQuery(
    userID: userID,
    oldestServerCreatedDateTime: isPremium
        ? null
        : oldestFreePlanHistoryDateTime(now: DateTime.now()),
  ).snapshots().map(
    (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
  );
}
