// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuditLog _$AuditLogFromJson(Map<String, dynamic> json) => _AuditLog(
  occurredAt: DateTime.parse(json['occurredAt'] as String),
  operation:
      $enumDecodeNullable(
        _$AuditLogOperationEnumMap,
        json['operation'],
        unknownValue: AuditLogOperation.unknown,
      ) ??
      AuditLogOperation.unknown,
  transactionID: json['transactionID'] as String,
  transactionTitle: json['transactionTitle'] as String?,
  transactionAmount: (json['transactionAmount'] as num?)?.toInt(),
  changedFieldNames:
      (json['changedFieldNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
);

Map<String, dynamic> _$AuditLogToJson(_AuditLog instance) => <String, dynamic>{
  'occurredAt': instance.occurredAt.toIso8601String(),
  'operation': _$AuditLogOperationEnumMap[instance.operation]!,
  'transactionID': instance.transactionID,
  'transactionTitle': instance.transactionTitle,
  'transactionAmount': instance.transactionAmount,
  'changedFieldNames': instance.changedFieldNames,
};

const _$AuditLogOperationEnumMap = {
  AuditLogOperation.transactionCreated: 'transactionCreated',
  AuditLogOperation.transactionUpdated: 'transactionUpdated',
  AuditLogOperation.transactionDeleted: 'transactionDeleted',
  AuditLogOperation.transactionImageDeleted: 'transactionImageDeleted',
  AuditLogOperation.unknown: 'unknown',
};
