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
  yearMonth: json['yearMonth'] as String,
  excludedFromAggregation: json['excludedFromAggregation'] as bool,
  serverCreatedDateTime: const ServerCreatedTimestamp().fromJson(
    json['serverCreatedDateTime'],
  ),
  serverUpdatedDateTime: const ServerUpdatedTimestamp().fromJson(
    json['serverUpdatedDateTime'],
  ),
);

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userID': instance.userID,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'amount': instance.amount,
      'category': _$TransactionCategoryEnumMap[instance.category]!,
      'title': instance.title,
      'transactionDate': const TimestampConverter().toJson(
        instance.transactionDate,
      ),
      'yearMonth': instance.yearMonth,
      'excludedFromAggregation': instance.excludedFromAggregation,
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
  TransactionCategory.dailyGoods: 'dailyGoods',
  TransactionCategory.transportation: 'transportation',
  TransactionCategory.utilities: 'utilities',
  TransactionCategory.communication: 'communication',
  TransactionCategory.housing: 'housing',
  TransactionCategory.medical: 'medical',
  TransactionCategory.entertainment: 'entertainment',
  TransactionCategory.clothing: 'clothing',
  TransactionCategory.education: 'education',
  TransactionCategory.salary: 'salary',
  TransactionCategory.other: 'other',
};
