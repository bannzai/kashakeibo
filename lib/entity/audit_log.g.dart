// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuditLog _$AuditLogFromJson(Map<String, dynamic> json) => _AuditLog(
  id: json['id'] as String,
  userID: json['userID'] as String,
  operation:
      $enumDecodeNullable(
        _$AuditLogOperationEnumMap,
        json['operation'],
        unknownValue: AuditLogOperation.unknown,
      ) ??
      AuditLogOperation.unknown,
  transactionID: json['transactionID'] as String?,
  imageObjectKey: json['imageObjectKey'] as String?,
  transactionTitle: json['transactionTitle'] as String?,
  transactionAmount: (json['transactionAmount'] as num?)?.toInt(),
  changedFieldNames:
      (json['changedFieldNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  serverCreatedDateTime: const ServerCreatedTimestamp().fromJson(
    json['serverCreatedDateTime'],
  ),
);

Map<String, dynamic> _$AuditLogToJson(_AuditLog instance) => <String, dynamic>{
  'id': instance.id,
  'userID': instance.userID,
  'operation': _$AuditLogOperationEnumMap[instance.operation]!,
  'transactionID': instance.transactionID,
  'imageObjectKey': instance.imageObjectKey,
  'transactionTitle': instance.transactionTitle,
  'transactionAmount': instance.transactionAmount,
  'changedFieldNames': instance.changedFieldNames,
  'serverCreatedDateTime': const ServerCreatedTimestamp().toJson(
    instance.serverCreatedDateTime,
  ),
};

const _$AuditLogOperationEnumMap = {
  AuditLogOperation.transactionCreated: 'transactionCreated',
  AuditLogOperation.transactionUpdated: 'transactionUpdated',
  AuditLogOperation.transactionDeleted: 'transactionDeleted',
  AuditLogOperation.transactionImageDeleted: 'transactionImageDeleted',
  AuditLogOperation.unknown: 'unknown',
};
