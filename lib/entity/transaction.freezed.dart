// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Transaction {

/// ドキュメント ID (Firestore の自動生成 ID)。
 String get id;/// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
/// `.claude/rules/entity-parent-id-rules.md` 参照)。
 String get userID;/// 明細の種別 (収入 / 支出)。月次集計・複合インデックスの絞り込みに使う。
 TransactionType get type;/// 明細が登録された経路。
///
/// 出所フィールド追加前の明細に誤った出所を割り当てないため、欠損値と
/// 未知の値は [TransactionSource.unknown] として読む。
@JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown) TransactionSource get source;/// 金額 (日本円、整数)。
 int get amount;/// カテゴリ。未知の値は other として読む (enum 定義のコメント参照)。
@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory get category;/// 明細の表示名 (店名・摘要)。
 String get title;/// 取引日時。
@TimestampConverter() DateTime get transactionDate;/// 登録時の端末タイムゾーンの UTC オフセット (分)。
/// 端末のタイムゾーンが後から変わっても、[yearMonth] の導出基準と
/// 表示・日付グループ化の基準 ([transactionLocalDate]) を登録時の
/// カレンダー日で一致させるために保持する。
/// フィールドが無い旧データは null (現在の端末タイムゾーンで表示する)。
 int? get transactionDateTimeZoneOffsetMinutes;/// 取引月 ("2026-08" 形式)。月次一覧のクエリ用フィールド。
/// [transactionDate] のローカルタイムから [yearMonthFrom] で導出し、両者は常に一致させる。
 String get yearMonth;/// 集計の計算対象から除外するかどうか。重複明細の片方を残したまま
/// 集計に含めない、などの用途 (documents/PROJECT.md の MVP スコープ)。
 bool get excludedFromAggregation;/// 元画像 (レシート写真・スクショ) の R2 オブジェクトキー
/// (`users/{userID}/{uploadImageID}.{拡張子}`。lib/features/image_upload/README.md)。
/// 「元の画像に戻れる」ための紐付けで、手動入力・画像を削除した明細は null。
/// フィールドが無い旧データも null として読む。
 String? get sourceImageObjectKey;/// AI 解析 (自動取込) の結果をユーザーが修正して登録したか。
/// 出所の表示を「自動取込」「手調整」に分けるための記録 (documents/PROJECT.md の出所記録)。
/// 手動入力 (source manual) は解析を経ないため常に false。
/// 出所記録追加前の明細にはフィールドが無く、修正の有無を判別できないため
/// 「修正していない」側 (false) に倒して読む。
 bool get analysisAdjustedByUser;/// AI 解析に対してユーザーがチャットで出した追加指示の履歴 (出した順。issue #40)。
/// 「一番下の明細が読めていない」のような読み直しの指示を、登録後も明細から見返せるように残す。
/// 指示による読み直しは AI の再解析であり、[analysisAdjustedByUser] (フォームの手修正) とは別に記録する。
/// 追加指示を出していない明細・手動入力・フィールド追加前の旧データは空。
 List<String> get analysisInstructions;/// 重複候補として提示済みで、ユーザーが「別物として残す」と判断した明細 ID。
/// 相手側にも自身の ID を保存し、どちらを先に読み込んでも同じ候補を再提示しない。
/// フィールドが無い旧データは未判断として扱う。
 List<String> get confirmedDistinctTransactionIDs;@ServerCreatedTimestamp() DateTime? get serverCreatedDateTime;@ServerUpdatedTimestamp() DateTime? get serverUpdatedDateTime;
/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionCopyWith<Transaction> get copyWith => _$TransactionCopyWithImpl<Transaction>(this as Transaction, _$identity);

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.transactionDateTimeZoneOffsetMinutes, transactionDateTimeZoneOffsetMinutes) || other.transactionDateTimeZoneOffsetMinutes == transactionDateTimeZoneOffsetMinutes)&&(identical(other.yearMonth, yearMonth) || other.yearMonth == yearMonth)&&(identical(other.excludedFromAggregation, excludedFromAggregation) || other.excludedFromAggregation == excludedFromAggregation)&&(identical(other.sourceImageObjectKey, sourceImageObjectKey) || other.sourceImageObjectKey == sourceImageObjectKey)&&(identical(other.analysisAdjustedByUser, analysisAdjustedByUser) || other.analysisAdjustedByUser == analysisAdjustedByUser)&&const DeepCollectionEquality().equals(other.analysisInstructions, analysisInstructions)&&const DeepCollectionEquality().equals(other.confirmedDistinctTransactionIDs, confirmedDistinctTransactionIDs)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime)&&(identical(other.serverUpdatedDateTime, serverUpdatedDateTime) || other.serverUpdatedDateTime == serverUpdatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,type,source,amount,category,title,transactionDate,transactionDateTimeZoneOffsetMinutes,yearMonth,excludedFromAggregation,sourceImageObjectKey,analysisAdjustedByUser,const DeepCollectionEquality().hash(analysisInstructions),const DeepCollectionEquality().hash(confirmedDistinctTransactionIDs),serverCreatedDateTime,serverUpdatedDateTime);

@override
String toString() {
  return 'Transaction(id: $id, userID: $userID, type: $type, source: $source, amount: $amount, category: $category, title: $title, transactionDate: $transactionDate, transactionDateTimeZoneOffsetMinutes: $transactionDateTimeZoneOffsetMinutes, yearMonth: $yearMonth, excludedFromAggregation: $excludedFromAggregation, sourceImageObjectKey: $sourceImageObjectKey, analysisAdjustedByUser: $analysisAdjustedByUser, analysisInstructions: $analysisInstructions, confirmedDistinctTransactionIDs: $confirmedDistinctTransactionIDs, serverCreatedDateTime: $serverCreatedDateTime, serverUpdatedDateTime: $serverUpdatedDateTime)';
}


}

/// @nodoc
abstract mixin class $TransactionCopyWith<$Res>  {
  factory $TransactionCopyWith(Transaction value, $Res Function(Transaction) _then) = _$TransactionCopyWithImpl;
@useResult
$Res call({
 String id, String userID, TransactionType type,@JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown) TransactionSource source, int amount,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category, String title,@TimestampConverter() DateTime transactionDate, int? transactionDateTimeZoneOffsetMinutes, String yearMonth, bool excludedFromAggregation, String? sourceImageObjectKey, bool analysisAdjustedByUser, List<String> analysisInstructions, List<String> confirmedDistinctTransactionIDs,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime,@ServerUpdatedTimestamp() DateTime? serverUpdatedDateTime
});




}
/// @nodoc
class _$TransactionCopyWithImpl<$Res>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._self, this._then);

  final Transaction _self;
  final $Res Function(Transaction) _then;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userID = null,Object? type = null,Object? source = null,Object? amount = null,Object? category = null,Object? title = null,Object? transactionDate = null,Object? transactionDateTimeZoneOffsetMinutes = freezed,Object? yearMonth = null,Object? excludedFromAggregation = null,Object? sourceImageObjectKey = freezed,Object? analysisAdjustedByUser = null,Object? analysisInstructions = null,Object? confirmedDistinctTransactionIDs = null,Object? serverCreatedDateTime = freezed,Object? serverUpdatedDateTime = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TransactionSource,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,transactionDateTimeZoneOffsetMinutes: freezed == transactionDateTimeZoneOffsetMinutes ? _self.transactionDateTimeZoneOffsetMinutes : transactionDateTimeZoneOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,yearMonth: null == yearMonth ? _self.yearMonth : yearMonth // ignore: cast_nullable_to_non_nullable
as String,excludedFromAggregation: null == excludedFromAggregation ? _self.excludedFromAggregation : excludedFromAggregation // ignore: cast_nullable_to_non_nullable
as bool,sourceImageObjectKey: freezed == sourceImageObjectKey ? _self.sourceImageObjectKey : sourceImageObjectKey // ignore: cast_nullable_to_non_nullable
as String?,analysisAdjustedByUser: null == analysisAdjustedByUser ? _self.analysisAdjustedByUser : analysisAdjustedByUser // ignore: cast_nullable_to_non_nullable
as bool,analysisInstructions: null == analysisInstructions ? _self.analysisInstructions : analysisInstructions // ignore: cast_nullable_to_non_nullable
as List<String>,confirmedDistinctTransactionIDs: null == confirmedDistinctTransactionIDs ? _self.confirmedDistinctTransactionIDs : confirmedDistinctTransactionIDs // ignore: cast_nullable_to_non_nullable
as List<String>,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,serverUpdatedDateTime: freezed == serverUpdatedDateTime ? _self.serverUpdatedDateTime : serverUpdatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Transaction].
extension TransactionPatterns on Transaction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Transaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Transaction value)  $default,){
final _that = this;
switch (_that) {
case _Transaction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Transaction value)?  $default,){
final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userID,  TransactionType type, @JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown)  TransactionSource source,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation,  String? sourceImageObjectKey,  bool analysisAdjustedByUser,  List<String> analysisInstructions,  List<String> confirmedDistinctTransactionIDs, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.userID,_that.type,_that.source,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.sourceImageObjectKey,_that.analysisAdjustedByUser,_that.analysisInstructions,_that.confirmedDistinctTransactionIDs,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userID,  TransactionType type, @JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown)  TransactionSource source,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation,  String? sourceImageObjectKey,  bool analysisAdjustedByUser,  List<String> analysisInstructions,  List<String> confirmedDistinctTransactionIDs, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)  $default,) {final _that = this;
switch (_that) {
case _Transaction():
return $default(_that.id,_that.userID,_that.type,_that.source,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.sourceImageObjectKey,_that.analysisAdjustedByUser,_that.analysisInstructions,_that.confirmedDistinctTransactionIDs,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userID,  TransactionType type, @JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown)  TransactionSource source,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation,  String? sourceImageObjectKey,  bool analysisAdjustedByUser,  List<String> analysisInstructions,  List<String> confirmedDistinctTransactionIDs, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)?  $default,) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.userID,_that.type,_that.source,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.sourceImageObjectKey,_that.analysisAdjustedByUser,_that.analysisInstructions,_that.confirmedDistinctTransactionIDs,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _Transaction extends Transaction {
  const _Transaction({required this.id, required this.userID, required this.type, @JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown) required this.source, required this.amount, @JsonKey(unknownEnumValue: TransactionCategory.other) required this.category, required this.title, @TimestampConverter() required this.transactionDate, required this.transactionDateTimeZoneOffsetMinutes, required this.yearMonth, required this.excludedFromAggregation, required this.sourceImageObjectKey, this.analysisAdjustedByUser = false, final  List<String> analysisInstructions = const <String>[], final  List<String> confirmedDistinctTransactionIDs = const <String>[], @ServerCreatedTimestamp() this.serverCreatedDateTime, @ServerUpdatedTimestamp() this.serverUpdatedDateTime}): _analysisInstructions = analysisInstructions,_confirmedDistinctTransactionIDs = confirmedDistinctTransactionIDs,super._();
  factory _Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

/// ドキュメント ID (Firestore の自動生成 ID)。
@override final  String id;
/// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
/// `.claude/rules/entity-parent-id-rules.md` 参照)。
@override final  String userID;
/// 明細の種別 (収入 / 支出)。月次集計・複合インデックスの絞り込みに使う。
@override final  TransactionType type;
/// 明細が登録された経路。
///
/// 出所フィールド追加前の明細に誤った出所を割り当てないため、欠損値と
/// 未知の値は [TransactionSource.unknown] として読む。
@override@JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown) final  TransactionSource source;
/// 金額 (日本円、整数)。
@override final  int amount;
/// カテゴリ。未知の値は other として読む (enum 定義のコメント参照)。
@override@JsonKey(unknownEnumValue: TransactionCategory.other) final  TransactionCategory category;
/// 明細の表示名 (店名・摘要)。
@override final  String title;
/// 取引日時。
@override@TimestampConverter() final  DateTime transactionDate;
/// 登録時の端末タイムゾーンの UTC オフセット (分)。
/// 端末のタイムゾーンが後から変わっても、[yearMonth] の導出基準と
/// 表示・日付グループ化の基準 ([transactionLocalDate]) を登録時の
/// カレンダー日で一致させるために保持する。
/// フィールドが無い旧データは null (現在の端末タイムゾーンで表示する)。
@override final  int? transactionDateTimeZoneOffsetMinutes;
/// 取引月 ("2026-08" 形式)。月次一覧のクエリ用フィールド。
/// [transactionDate] のローカルタイムから [yearMonthFrom] で導出し、両者は常に一致させる。
@override final  String yearMonth;
/// 集計の計算対象から除外するかどうか。重複明細の片方を残したまま
/// 集計に含めない、などの用途 (documents/PROJECT.md の MVP スコープ)。
@override final  bool excludedFromAggregation;
/// 元画像 (レシート写真・スクショ) の R2 オブジェクトキー
/// (`users/{userID}/{uploadImageID}.{拡張子}`。lib/features/image_upload/README.md)。
/// 「元の画像に戻れる」ための紐付けで、手動入力・画像を削除した明細は null。
/// フィールドが無い旧データも null として読む。
@override final  String? sourceImageObjectKey;
/// AI 解析 (自動取込) の結果をユーザーが修正して登録したか。
/// 出所の表示を「自動取込」「手調整」に分けるための記録 (documents/PROJECT.md の出所記録)。
/// 手動入力 (source manual) は解析を経ないため常に false。
/// 出所記録追加前の明細にはフィールドが無く、修正の有無を判別できないため
/// 「修正していない」側 (false) に倒して読む。
@override@JsonKey() final  bool analysisAdjustedByUser;
/// AI 解析に対してユーザーがチャットで出した追加指示の履歴 (出した順。issue #40)。
/// 「一番下の明細が読めていない」のような読み直しの指示を、登録後も明細から見返せるように残す。
/// 指示による読み直しは AI の再解析であり、[analysisAdjustedByUser] (フォームの手修正) とは別に記録する。
/// 追加指示を出していない明細・手動入力・フィールド追加前の旧データは空。
 final  List<String> _analysisInstructions;
/// AI 解析に対してユーザーがチャットで出した追加指示の履歴 (出した順。issue #40)。
/// 「一番下の明細が読めていない」のような読み直しの指示を、登録後も明細から見返せるように残す。
/// 指示による読み直しは AI の再解析であり、[analysisAdjustedByUser] (フォームの手修正) とは別に記録する。
/// 追加指示を出していない明細・手動入力・フィールド追加前の旧データは空。
@override@JsonKey() List<String> get analysisInstructions {
  if (_analysisInstructions is EqualUnmodifiableListView) return _analysisInstructions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_analysisInstructions);
}

/// 重複候補として提示済みで、ユーザーが「別物として残す」と判断した明細 ID。
/// 相手側にも自身の ID を保存し、どちらを先に読み込んでも同じ候補を再提示しない。
/// フィールドが無い旧データは未判断として扱う。
 final  List<String> _confirmedDistinctTransactionIDs;
/// 重複候補として提示済みで、ユーザーが「別物として残す」と判断した明細 ID。
/// 相手側にも自身の ID を保存し、どちらを先に読み込んでも同じ候補を再提示しない。
/// フィールドが無い旧データは未判断として扱う。
@override@JsonKey() List<String> get confirmedDistinctTransactionIDs {
  if (_confirmedDistinctTransactionIDs is EqualUnmodifiableListView) return _confirmedDistinctTransactionIDs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_confirmedDistinctTransactionIDs);
}

@override@ServerCreatedTimestamp() final  DateTime? serverCreatedDateTime;
@override@ServerUpdatedTimestamp() final  DateTime? serverUpdatedDateTime;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionCopyWith<_Transaction> get copyWith => __$TransactionCopyWithImpl<_Transaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.type, type) || other.type == type)&&(identical(other.source, source) || other.source == source)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.transactionDateTimeZoneOffsetMinutes, transactionDateTimeZoneOffsetMinutes) || other.transactionDateTimeZoneOffsetMinutes == transactionDateTimeZoneOffsetMinutes)&&(identical(other.yearMonth, yearMonth) || other.yearMonth == yearMonth)&&(identical(other.excludedFromAggregation, excludedFromAggregation) || other.excludedFromAggregation == excludedFromAggregation)&&(identical(other.sourceImageObjectKey, sourceImageObjectKey) || other.sourceImageObjectKey == sourceImageObjectKey)&&(identical(other.analysisAdjustedByUser, analysisAdjustedByUser) || other.analysisAdjustedByUser == analysisAdjustedByUser)&&const DeepCollectionEquality().equals(other._analysisInstructions, _analysisInstructions)&&const DeepCollectionEquality().equals(other._confirmedDistinctTransactionIDs, _confirmedDistinctTransactionIDs)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime)&&(identical(other.serverUpdatedDateTime, serverUpdatedDateTime) || other.serverUpdatedDateTime == serverUpdatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,type,source,amount,category,title,transactionDate,transactionDateTimeZoneOffsetMinutes,yearMonth,excludedFromAggregation,sourceImageObjectKey,analysisAdjustedByUser,const DeepCollectionEquality().hash(_analysisInstructions),const DeepCollectionEquality().hash(_confirmedDistinctTransactionIDs),serverCreatedDateTime,serverUpdatedDateTime);

@override
String toString() {
  return 'Transaction(id: $id, userID: $userID, type: $type, source: $source, amount: $amount, category: $category, title: $title, transactionDate: $transactionDate, transactionDateTimeZoneOffsetMinutes: $transactionDateTimeZoneOffsetMinutes, yearMonth: $yearMonth, excludedFromAggregation: $excludedFromAggregation, sourceImageObjectKey: $sourceImageObjectKey, analysisAdjustedByUser: $analysisAdjustedByUser, analysisInstructions: $analysisInstructions, confirmedDistinctTransactionIDs: $confirmedDistinctTransactionIDs, serverCreatedDateTime: $serverCreatedDateTime, serverUpdatedDateTime: $serverUpdatedDateTime)';
}


}

/// @nodoc
abstract mixin class _$TransactionCopyWith<$Res> implements $TransactionCopyWith<$Res> {
  factory _$TransactionCopyWith(_Transaction value, $Res Function(_Transaction) _then) = __$TransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String userID, TransactionType type,@JsonKey(defaultValue: TransactionSource.unknown, unknownEnumValue: TransactionSource.unknown) TransactionSource source, int amount,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category, String title,@TimestampConverter() DateTime transactionDate, int? transactionDateTimeZoneOffsetMinutes, String yearMonth, bool excludedFromAggregation, String? sourceImageObjectKey, bool analysisAdjustedByUser, List<String> analysisInstructions, List<String> confirmedDistinctTransactionIDs,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime,@ServerUpdatedTimestamp() DateTime? serverUpdatedDateTime
});




}
/// @nodoc
class __$TransactionCopyWithImpl<$Res>
    implements _$TransactionCopyWith<$Res> {
  __$TransactionCopyWithImpl(this._self, this._then);

  final _Transaction _self;
  final $Res Function(_Transaction) _then;

/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userID = null,Object? type = null,Object? source = null,Object? amount = null,Object? category = null,Object? title = null,Object? transactionDate = null,Object? transactionDateTimeZoneOffsetMinutes = freezed,Object? yearMonth = null,Object? excludedFromAggregation = null,Object? sourceImageObjectKey = freezed,Object? analysisAdjustedByUser = null,Object? analysisInstructions = null,Object? confirmedDistinctTransactionIDs = null,Object? serverCreatedDateTime = freezed,Object? serverUpdatedDateTime = freezed,}) {
  return _then(_Transaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TransactionSource,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,transactionDateTimeZoneOffsetMinutes: freezed == transactionDateTimeZoneOffsetMinutes ? _self.transactionDateTimeZoneOffsetMinutes : transactionDateTimeZoneOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,yearMonth: null == yearMonth ? _self.yearMonth : yearMonth // ignore: cast_nullable_to_non_nullable
as String,excludedFromAggregation: null == excludedFromAggregation ? _self.excludedFromAggregation : excludedFromAggregation // ignore: cast_nullable_to_non_nullable
as bool,sourceImageObjectKey: freezed == sourceImageObjectKey ? _self.sourceImageObjectKey : sourceImageObjectKey // ignore: cast_nullable_to_non_nullable
as String?,analysisAdjustedByUser: null == analysisAdjustedByUser ? _self.analysisAdjustedByUser : analysisAdjustedByUser // ignore: cast_nullable_to_non_nullable
as bool,analysisInstructions: null == analysisInstructions ? _self._analysisInstructions : analysisInstructions // ignore: cast_nullable_to_non_nullable
as List<String>,confirmedDistinctTransactionIDs: null == confirmedDistinctTransactionIDs ? _self._confirmedDistinctTransactionIDs : confirmedDistinctTransactionIDs // ignore: cast_nullable_to_non_nullable
as List<String>,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,serverUpdatedDateTime: freezed == serverUpdatedDateTime ? _self.serverUpdatedDateTime : serverUpdatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
