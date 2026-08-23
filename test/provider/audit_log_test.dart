// 操作履歴の読み取り範囲のテスト。
// FakeFirebaseFirestore に対してクエリを実行し、無料プランの下限日時
// (features/paywall/free_plan_history_limit.dart) より古い履歴を読み取らないことを検証する。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/audit_log.dart';
import 'package:kashakeibo/provider/audit_log.dart';

/// 記録時刻を指定した操作履歴を fake の Firestore に保存する。
///
/// serverCreatedDateTime は本来サーバーが書き込むフィールドのため、
/// 未変換の参照 (auditLogDocumentsReference) に直接 Timestamp を書いて時刻を作る。
Future<void> saveAuditLog({
  required FakeFirebaseFirestore firebaseFirestore,
  required String auditLogID,
  required DateTime serverCreatedDateTime,
}) async {
  await auditLogDocumentsReference(
    userID: 'user-id',
    firebaseFirestore: firebaseFirestore,
  ).doc(auditLogID).set({
    'userID': 'user-id',
    'operation': AuditLogOperation.transactionCreated.name,
    'transactionID': null,
    'imageObjectKey': null,
    'transactionTitle': null,
    'transactionAmount': null,
    'changedFieldNames': <String>[],
    AuditLogFirestoreKeys.serverCreatedDateTime: Timestamp.fromDate(
      serverCreatedDateTime,
    ),
  });
}

/// 操作履歴を 1 回読み取り、記録時刻の新しい順に ID を返す。
Future<List<String>> readAuditLogIDs({
  required FakeFirebaseFirestore firebaseFirestore,
  required DateTime? oldestServerCreatedDateTime,
}) async => (await auditLogsQuery(
  userID: 'user-id',
  oldestServerCreatedDateTime: oldestServerCreatedDateTime,
  firebaseFirestore: firebaseFirestore,
).get()).docs.map((doc) => doc.data().id).toList();

void main() {
  group('auditLogsQuery', () {
    test('下限日時を渡すと、それより古い操作履歴が結果に含まれない', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      for (final (auditLogID, serverCreatedDateTime) in [
        ('older', DateTime(2026, 5, 31, 23, 59)),
        ('oldest-free', DateTime(2026, 6, 1)),
        ('newer', DateTime(2026, 8, 20)),
      ]) {
        await saveAuditLog(
          firebaseFirestore: firebaseFirestore,
          auditLogID: auditLogID,
          serverCreatedDateTime: serverCreatedDateTime,
        );
      }

      expect(
        await readAuditLogIDs(
          firebaseFirestore: firebaseFirestore,
          oldestServerCreatedDateTime: DateTime(2026, 6),
        ),
        ['newer', 'oldest-free'],
      );
    });

    test('下限日時が null (プレミアム) なら全期間の操作履歴を返す', () async {
      final firebaseFirestore = FakeFirebaseFirestore();
      for (final (auditLogID, serverCreatedDateTime) in [
        ('older', DateTime(2025, 1, 10)),
        ('newer', DateTime(2026, 8, 20)),
      ]) {
        await saveAuditLog(
          firebaseFirestore: firebaseFirestore,
          auditLogID: auditLogID,
          serverCreatedDateTime: serverCreatedDateTime,
        );
      }

      expect(
        await readAuditLogIDs(
          firebaseFirestore: firebaseFirestore,
          oldestServerCreatedDateTime: null,
        ),
        ['newer', 'older'],
      );
    });
  });
}
