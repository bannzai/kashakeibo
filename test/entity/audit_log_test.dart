// 監査ログ Entity のシリアライズと、旧データ・未知の値の読み取りのテスト。
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/entity/audit_log.dart';

void main() {
  group('AuditLog.fromJson', () {
    test('Firestore のフィールドから復元できる', () {
      final auditLog = AuditLog.fromJson({
        'id': 'audit-log-id',
        'userID': 'user-id',
        'operation': 'transactionUpdated',
        'transactionID': 'transaction-id',
        'imageObjectKey': null,
        'transactionTitle': 'スーパーマーケット',
        'transactionAmount': 1280,
        'changedFieldNames': ['excludedFromAggregation'],
        'serverCreatedDateTime': Timestamp.fromDate(DateTime(2026, 8, 23, 10)),
      });

      expect(auditLog.operation, AuditLogOperation.transactionUpdated);
      expect(auditLog.userID, 'user-id');
      expect(auditLog.transactionID, 'transaction-id');
      expect(auditLog.transactionTitle, 'スーパーマーケット');
      expect(auditLog.transactionAmount, 1280);
      expect(auditLog.changedFieldNames, ['excludedFromAggregation']);
      expect(auditLog.serverCreatedDateTime, DateTime(2026, 8, 23, 10));
    });

    test('未知の操作種別と欠損した操作種別は unknown として読む', () {
      expect(
        AuditLog.fromJson({
          'id': 'audit-log-id',
          'userID': 'user-id',
          'operation': 'transactionArchived',
          'transactionID': 'transaction-id',
          'imageObjectKey': null,
          'transactionTitle': null,
          'transactionAmount': null,
          'serverCreatedDateTime': null,
        }).operation,
        AuditLogOperation.unknown,
      );
      expect(
        AuditLog.fromJson({
          'id': 'audit-log-id',
          'userID': 'user-id',
          'transactionID': null,
          'imageObjectKey': null,
          'transactionTitle': null,
          'transactionAmount': null,
          'serverCreatedDateTime': null,
        }).operation,
        AuditLogOperation.unknown,
      );
    });

    test('変更フィールドが無いデータは空リストとして読む', () {
      expect(
        AuditLog.fromJson({
          'id': 'audit-log-id',
          'userID': 'user-id',
          'operation': 'transactionDeleted',
          'transactionID': 'transaction-id',
          'imageObjectKey': null,
          'transactionTitle': 'スーパーマーケット',
          'transactionAmount': 1280,
          'serverCreatedDateTime': null,
        }).changedFieldNames,
        isEmpty,
      );
    });
  });

  group('AuditLog.toJson', () {
    test('操作種別は enum 名の文字列で書き出す', () {
      final json = const AuditLog(
        id: 'audit-log-id',
        userID: 'user-id',
        operation: AuditLogOperation.transactionImageDeleted,
        transactionID: 'transaction-id',
        imageObjectKey: 'users/user-id/uuid.png',
        transactionTitle: 'スーパーマーケット',
        transactionAmount: 1280,
      ).toJson();

      expect(json['operation'], 'transactionImageDeleted');
      expect(json['imageObjectKey'], 'users/user-id/uuid.png');
      expect(json['changedFieldNames'], isEmpty);
    });

    test('記録時刻が未設定なら書き込み時にサーバータイムスタンプを使う', () {
      expect(
        const AuditLog(
          id: 'audit-log-id',
          userID: 'user-id',
          operation: AuditLogOperation.transactionCreated,
          transactionID: 'transaction-id',
          imageObjectKey: null,
          transactionTitle: 'スーパーマーケット',
          transactionAmount: 1280,
        ).toJson()['serverCreatedDateTime'],
        isA<FieldValue>(),
      );
    });
  });
}
