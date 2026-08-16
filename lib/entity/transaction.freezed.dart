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
 TransactionType get type;/// 金額 (日本円、整数)。
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
 bool get excludedFromAggregation;@ServerCreatedTimestamp() DateTime? get serverCreatedDateTime;@ServerUpdatedTimestamp() DateTime? get serverUpdatedDateTime;
/// Create a copy of Transaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionCopyWith<Transaction> get copyWith => _$TransactionCopyWithImpl<Transaction>(this as Transaction, _$identity);

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.transactionDateTimeZoneOffsetMinutes, transactionDateTimeZoneOffsetMinutes) || other.transactionDateTimeZoneOffsetMinutes == transactionDateTimeZoneOffsetMinutes)&&(identical(other.yearMonth, yearMonth) || other.yearMonth == yearMonth)&&(identical(other.excludedFromAggregation, excludedFromAggregation) || other.excludedFromAggregation == excludedFromAggregation)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime)&&(identical(other.serverUpdatedDateTime, serverUpdatedDateTime) || other.serverUpdatedDateTime == serverUpdatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,type,amount,category,title,transactionDate,transactionDateTimeZoneOffsetMinutes,yearMonth,excludedFromAggregation,serverCreatedDateTime,serverUpdatedDateTime);

@override
String toString() {
  return 'Transaction(id: $id, userID: $userID, type: $type, amount: $amount, category: $category, title: $title, transactionDate: $transactionDate, transactionDateTimeZoneOffsetMinutes: $transactionDateTimeZoneOffsetMinutes, yearMonth: $yearMonth, excludedFromAggregation: $excludedFromAggregation, serverCreatedDateTime: $serverCreatedDateTime, serverUpdatedDateTime: $serverUpdatedDateTime)';
}


}

/// @nodoc
abstract mixin class $TransactionCopyWith<$Res>  {
  factory $TransactionCopyWith(Transaction value, $Res Function(Transaction) _then) = _$TransactionCopyWithImpl;
@useResult
$Res call({
 String id, String userID, TransactionType type, int amount,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category, String title,@TimestampConverter() DateTime transactionDate, int? transactionDateTimeZoneOffsetMinutes, String yearMonth, bool excludedFromAggregation,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime,@ServerUpdatedTimestamp() DateTime? serverUpdatedDateTime
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userID = null,Object? type = null,Object? amount = null,Object? category = null,Object? title = null,Object? transactionDate = null,Object? transactionDateTimeZoneOffsetMinutes = freezed,Object? yearMonth = null,Object? excludedFromAggregation = null,Object? serverCreatedDateTime = freezed,Object? serverUpdatedDateTime = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,transactionDateTimeZoneOffsetMinutes: freezed == transactionDateTimeZoneOffsetMinutes ? _self.transactionDateTimeZoneOffsetMinutes : transactionDateTimeZoneOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,yearMonth: null == yearMonth ? _self.yearMonth : yearMonth // ignore: cast_nullable_to_non_nullable
as String,excludedFromAggregation: null == excludedFromAggregation ? _self.excludedFromAggregation : excludedFromAggregation // ignore: cast_nullable_to_non_nullable
as bool,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userID,  TransactionType type,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.userID,_that.type,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userID,  TransactionType type,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)  $default,) {final _that = this;
switch (_that) {
case _Transaction():
return $default(_that.id,_that.userID,_that.type,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userID,  TransactionType type,  int amount, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category,  String title, @TimestampConverter()  DateTime transactionDate,  int? transactionDateTimeZoneOffsetMinutes,  String yearMonth,  bool excludedFromAggregation, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime, @ServerUpdatedTimestamp()  DateTime? serverUpdatedDateTime)?  $default,) {final _that = this;
switch (_that) {
case _Transaction() when $default != null:
return $default(_that.id,_that.userID,_that.type,_that.amount,_that.category,_that.title,_that.transactionDate,_that.transactionDateTimeZoneOffsetMinutes,_that.yearMonth,_that.excludedFromAggregation,_that.serverCreatedDateTime,_that.serverUpdatedDateTime);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _Transaction extends Transaction {
  const _Transaction({required this.id, required this.userID, required this.type, required this.amount, @JsonKey(unknownEnumValue: TransactionCategory.other) required this.category, required this.title, @TimestampConverter() required this.transactionDate, required this.transactionDateTimeZoneOffsetMinutes, required this.yearMonth, required this.excludedFromAggregation, @ServerCreatedTimestamp() this.serverCreatedDateTime, @ServerUpdatedTimestamp() this.serverUpdatedDateTime}): super._();
  factory _Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);

/// ドキュメント ID (Firestore の自動生成 ID)。
@override final  String id;
/// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
/// `.claude/rules/entity-parent-id-rules.md` 参照)。
@override final  String userID;
/// 明細の種別 (収入 / 支出)。月次集計・複合インデックスの絞り込みに使う。
@override final  TransactionType type;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Transaction&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.category, category) || other.category == category)&&(identical(other.title, title) || other.title == title)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.transactionDateTimeZoneOffsetMinutes, transactionDateTimeZoneOffsetMinutes) || other.transactionDateTimeZoneOffsetMinutes == transactionDateTimeZoneOffsetMinutes)&&(identical(other.yearMonth, yearMonth) || other.yearMonth == yearMonth)&&(identical(other.excludedFromAggregation, excludedFromAggregation) || other.excludedFromAggregation == excludedFromAggregation)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime)&&(identical(other.serverUpdatedDateTime, serverUpdatedDateTime) || other.serverUpdatedDateTime == serverUpdatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,type,amount,category,title,transactionDate,transactionDateTimeZoneOffsetMinutes,yearMonth,excludedFromAggregation,serverCreatedDateTime,serverUpdatedDateTime);

@override
String toString() {
  return 'Transaction(id: $id, userID: $userID, type: $type, amount: $amount, category: $category, title: $title, transactionDate: $transactionDate, transactionDateTimeZoneOffsetMinutes: $transactionDateTimeZoneOffsetMinutes, yearMonth: $yearMonth, excludedFromAggregation: $excludedFromAggregation, serverCreatedDateTime: $serverCreatedDateTime, serverUpdatedDateTime: $serverUpdatedDateTime)';
}


}

/// @nodoc
abstract mixin class _$TransactionCopyWith<$Res> implements $TransactionCopyWith<$Res> {
  factory _$TransactionCopyWith(_Transaction value, $Res Function(_Transaction) _then) = __$TransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, String userID, TransactionType type, int amount,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category, String title,@TimestampConverter() DateTime transactionDate, int? transactionDateTimeZoneOffsetMinutes, String yearMonth, bool excludedFromAggregation,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime,@ServerUpdatedTimestamp() DateTime? serverUpdatedDateTime
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userID = null,Object? type = null,Object? amount = null,Object? category = null,Object? title = null,Object? transactionDate = null,Object? transactionDateTimeZoneOffsetMinutes = freezed,Object? yearMonth = null,Object? excludedFromAggregation = null,Object? serverCreatedDateTime = freezed,Object? serverUpdatedDateTime = freezed,}) {
  return _then(_Transaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,transactionDate: null == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as DateTime,transactionDateTimeZoneOffsetMinutes: freezed == transactionDateTimeZoneOffsetMinutes ? _self.transactionDateTimeZoneOffsetMinutes : transactionDateTimeZoneOffsetMinutes // ignore: cast_nullable_to_non_nullable
as int?,yearMonth: null == yearMonth ? _self.yearMonth : yearMonth // ignore: cast_nullable_to_non_nullable
as String,excludedFromAggregation: null == excludedFromAggregation ? _self.excludedFromAggregation : excludedFromAggregation // ignore: cast_nullable_to_non_nullable
as bool,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,serverUpdatedDateTime: freezed == serverUpdatedDateTime ? _self.serverUpdatedDateTime : serverUpdatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
