// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audit_log_client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuditLog {

/// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
 DateTime get occurredAt;/// 記録した操作の種別。
@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation get operation;/// 操作の対象になった明細の ID。
 String get transactionID;/// 操作時点の明細の表示名 (店名・摘要)。読み取れない記録では null。
 String? get transactionTitle;/// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
 int? get transactionAmount;/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。訂正以外の操作では空。
 List<String> get changedFieldNames;
/// Create a copy of AuditLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuditLogCopyWith<AuditLog> get copyWith => _$AuditLogCopyWithImpl<AuditLog>(this as AuditLog, _$identity);

  /// Serializes this AuditLog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuditLog&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.transactionID, transactionID) || other.transactionID == transactionID)&&(identical(other.transactionTitle, transactionTitle) || other.transactionTitle == transactionTitle)&&(identical(other.transactionAmount, transactionAmount) || other.transactionAmount == transactionAmount)&&const DeepCollectionEquality().equals(other.changedFieldNames, changedFieldNames));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,occurredAt,operation,transactionID,transactionTitle,transactionAmount,const DeepCollectionEquality().hash(changedFieldNames));

@override
String toString() {
  return 'AuditLog(occurredAt: $occurredAt, operation: $operation, transactionID: $transactionID, transactionTitle: $transactionTitle, transactionAmount: $transactionAmount, changedFieldNames: $changedFieldNames)';
}


}

/// @nodoc
abstract mixin class $AuditLogCopyWith<$Res>  {
  factory $AuditLogCopyWith(AuditLog value, $Res Function(AuditLog) _then) = _$AuditLogCopyWithImpl;
@useResult
$Res call({
 DateTime occurredAt,@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation operation, String transactionID, String? transactionTitle, int? transactionAmount, List<String> changedFieldNames
});




}
/// @nodoc
class _$AuditLogCopyWithImpl<$Res>
    implements $AuditLogCopyWith<$Res> {
  _$AuditLogCopyWithImpl(this._self, this._then);

  final AuditLog _self;
  final $Res Function(AuditLog) _then;

/// Create a copy of AuditLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? occurredAt = null,Object? operation = null,Object? transactionID = null,Object? transactionTitle = freezed,Object? transactionAmount = freezed,Object? changedFieldNames = null,}) {
  return _then(_self.copyWith(
occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as AuditLogOperation,transactionID: null == transactionID ? _self.transactionID : transactionID // ignore: cast_nullable_to_non_nullable
as String,transactionTitle: freezed == transactionTitle ? _self.transactionTitle : transactionTitle // ignore: cast_nullable_to_non_nullable
as String?,transactionAmount: freezed == transactionAmount ? _self.transactionAmount : transactionAmount // ignore: cast_nullable_to_non_nullable
as int?,changedFieldNames: null == changedFieldNames ? _self.changedFieldNames : changedFieldNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [AuditLog].
extension AuditLogPatterns on AuditLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuditLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuditLog value)  $default,){
final _that = this;
switch (_that) {
case _AuditLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuditLog value)?  $default,){
final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime occurredAt, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String transactionID,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
return $default(_that.occurredAt,_that.operation,_that.transactionID,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime occurredAt, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String transactionID,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames)  $default,) {final _that = this;
switch (_that) {
case _AuditLog():
return $default(_that.occurredAt,_that.operation,_that.transactionID,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime occurredAt, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String transactionID,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames)?  $default,) {final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
return $default(_that.occurredAt,_that.operation,_that.transactionID,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuditLog implements AuditLog {
  const _AuditLog({required this.occurredAt, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) required this.operation, required this.transactionID, required this.transactionTitle, required this.transactionAmount, final  List<String> changedFieldNames = const <String>[]}): _changedFieldNames = changedFieldNames;
  factory _AuditLog.fromJson(Map<String, dynamic> json) => _$AuditLogFromJson(json);

/// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
@override final  DateTime occurredAt;
/// 記録した操作の種別。
@override@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) final  AuditLogOperation operation;
/// 操作の対象になった明細の ID。
@override final  String transactionID;
/// 操作時点の明細の表示名 (店名・摘要)。読み取れない記録では null。
@override final  String? transactionTitle;
/// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
@override final  int? transactionAmount;
/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。訂正以外の操作では空。
 final  List<String> _changedFieldNames;
/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。訂正以外の操作では空。
@override@JsonKey() List<String> get changedFieldNames {
  if (_changedFieldNames is EqualUnmodifiableListView) return _changedFieldNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changedFieldNames);
}


/// Create a copy of AuditLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuditLogCopyWith<_AuditLog> get copyWith => __$AuditLogCopyWithImpl<_AuditLog>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuditLogToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuditLog&&(identical(other.occurredAt, occurredAt) || other.occurredAt == occurredAt)&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.transactionID, transactionID) || other.transactionID == transactionID)&&(identical(other.transactionTitle, transactionTitle) || other.transactionTitle == transactionTitle)&&(identical(other.transactionAmount, transactionAmount) || other.transactionAmount == transactionAmount)&&const DeepCollectionEquality().equals(other._changedFieldNames, _changedFieldNames));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,occurredAt,operation,transactionID,transactionTitle,transactionAmount,const DeepCollectionEquality().hash(_changedFieldNames));

@override
String toString() {
  return 'AuditLog(occurredAt: $occurredAt, operation: $operation, transactionID: $transactionID, transactionTitle: $transactionTitle, transactionAmount: $transactionAmount, changedFieldNames: $changedFieldNames)';
}


}

/// @nodoc
abstract mixin class _$AuditLogCopyWith<$Res> implements $AuditLogCopyWith<$Res> {
  factory _$AuditLogCopyWith(_AuditLog value, $Res Function(_AuditLog) _then) = __$AuditLogCopyWithImpl;
@override @useResult
$Res call({
 DateTime occurredAt,@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation operation, String transactionID, String? transactionTitle, int? transactionAmount, List<String> changedFieldNames
});




}
/// @nodoc
class __$AuditLogCopyWithImpl<$Res>
    implements _$AuditLogCopyWith<$Res> {
  __$AuditLogCopyWithImpl(this._self, this._then);

  final _AuditLog _self;
  final $Res Function(_AuditLog) _then;

/// Create a copy of AuditLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? occurredAt = null,Object? operation = null,Object? transactionID = null,Object? transactionTitle = freezed,Object? transactionAmount = freezed,Object? changedFieldNames = null,}) {
  return _then(_AuditLog(
occurredAt: null == occurredAt ? _self.occurredAt : occurredAt // ignore: cast_nullable_to_non_nullable
as DateTime,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as AuditLogOperation,transactionID: null == transactionID ? _self.transactionID : transactionID // ignore: cast_nullable_to_non_nullable
as String,transactionTitle: freezed == transactionTitle ? _self.transactionTitle : transactionTitle // ignore: cast_nullable_to_non_nullable
as String?,transactionAmount: freezed == transactionAmount ? _self.transactionAmount : transactionAmount // ignore: cast_nullable_to_non_nullable
as int?,changedFieldNames: null == changedFieldNames ? _self._changedFieldNames : changedFieldNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
