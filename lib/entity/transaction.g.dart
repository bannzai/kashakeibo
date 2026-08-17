// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
  id: json['id'] as String,
  userID: json['userID'] as String,
  type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
  amount: (json['amount'] as num).toInt(),
  category: $enumDecode(
    _$TransactionCategoryEnumMap,
    json['category'],
    unknownValue: TransactionCategory.other,
  ),
  title: json['title'] as String,
  transactionDate: const TimestampConverter().fromJson(
    json['transactionDate'] as Timestamp,
  ),
  transactionDateTimeZoneOffsetMinutes:
      (json['transactionDateTimeZoneOffsetMinutes'] as num?)?.toInt(),
  yearMonth: json['yearMonth'] as String,
  excludedFromAggregation: json['excludedFromAggregation'] as bool,
  confirmedDistinctTransactionIDs:
      (json['confirmedDistinctTransactionIDs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  serverCreatedDateTime: const ServerCreatedTimestamp().fromJson(
    json['serverCreatedDateTime'],
  ),
  serverUpdatedDateTime: const ServerUpdatedTimestamp().fromJson(
    json['serverUpdatedDateTime'],
  ),
);

Map<String, dynamic> _$TransactionToJson(
  _Transaction instance,
) => <String, dynamic>{
  'id': instance.id,
  'userID': instance.userID,
  'type': _$TransactionTypeEnumMap[instance.type]!,
  'amount': instance.amount,
  'category': _$TransactionCategoryEnumMap[instance.category]!,
  'title': instance.title,
  'transactionDate': const TimestampConverter().toJson(
    instance.transactionDate,
  ),
  'transactionDateTimeZoneOffsetMinutes':
      instance.transactionDateTimeZoneOffsetMinutes,
  'yearMonth': instance.yearMonth,
  'excludedFromAggregation': instance.excludedFromAggregation,
  'confirmedDistinctTransactionIDs': instance.confirmedDistinctTransactionIDs,
  'serverCreatedDateTime': const ServerCreatedTimestamp().toJson(
    instance.serverCreatedDateTime,
  ),
  'serverUpdatedDateTime': const ServerUpdatedTimestamp().toJson(
    instance.serverUpdatedDateTime,
  ),
};

const _$TransactionTypeEnumMap = {
  TransactionType.income: 'income',
  TransactionType.expense: 'expense',
};

const _$TransactionCategoryEnumMap = {
  TransactionCategory.food: 'food',
  TransactionCategory.eatingOut: 'eatingOut',
  TransactionCategory.dailyGoods: 'dailyGoods',
  TransactionCategory.transportation: 'transportation',
  TransactionCategory.subscription: 'subscription',
  TransactionCategory.salary: 'salary',
  TransactionCategory.other: 'other',
};
