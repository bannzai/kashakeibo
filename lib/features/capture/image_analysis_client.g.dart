// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_analysis_client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnalyzedTransaction _$AnalyzedTransactionFromJson(Map<String, dynamic> json) =>
    _AnalyzedTransaction(
      title: json['title'] as String,
      amount: (json['amount'] as num).toInt(),
      transactionDate: json['transactionDate'] as String?,
      type: $enumDecode(
        _$TransactionTypeEnumMap,
        json['type'],
        unknownValue: TransactionType.expense,
      ),
      category: $enumDecode(
        _$TransactionCategoryEnumMap,
        json['category'],
        unknownValue: TransactionCategory.other,
      ),
    );

Map<String, dynamic> _$AnalyzedTransactionToJson(
  _AnalyzedTransaction instance,
) => <String, dynamic>{
  'title': instance.title,
  'amount': instance.amount,
  'transactionDate': instance.transactionDate,
  'type': _$TransactionTypeEnumMap[instance.type]!,
  'category': _$TransactionCategoryEnumMap[instance.category]!,
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

_ImageAnalysisResult _$ImageAnalysisResultFromJson(Map<String, dynamic> json) =>
    _ImageAnalysisResult(
      transactions: (json['transactions'] as List<dynamic>)
          .map((e) => AnalyzedTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ImageAnalysisResultToJson(
  _ImageAnalysisResult instance,
) => <String, dynamic>{'transactions': instance.transactions};
