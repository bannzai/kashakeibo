// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audit_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuditLog {

/// ドキュメント ID (Firestore の自動生成 ID)。
 String get id;/// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
/// `.claude/rules/entity-parent-id-rules.md` 参照)。
 String get userID;/// 記録した操作の種別。
@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation get operation;/// 操作の対象になった明細の ID。明細に紐づかない操作では null。
 String? get transactionID;/// 削除した元画像の R2 オブジェクトキー。画像を伴わない操作では null。
 String? get imageObjectKey;/// 操作時点の明細の表示名 (店名・摘要)。削除済みの明細を履歴だけで識別できるよう保持する。
 String? get transactionTitle;/// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
 int? get transactionAmount;/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。
/// 訂正以外の操作では空。フィールドが無い旧データも空として読む。
 List<String> get changedFieldNames;/// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
@ServerCreatedTimestamp() DateTime? get serverCreatedDateTime;
/// Create a copy of AuditLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuditLogCopyWith<AuditLog> get copyWith => _$AuditLogCopyWithImpl<AuditLog>(this as AuditLog, _$identity);

  /// Serializes this AuditLog to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuditLog&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.transactionID, transactionID) || other.transactionID == transactionID)&&(identical(other.imageObjectKey, imageObjectKey) || other.imageObjectKey == imageObjectKey)&&(identical(other.transactionTitle, transactionTitle) || other.transactionTitle == transactionTitle)&&(identical(other.transactionAmount, transactionAmount) || other.transactionAmount == transactionAmount)&&const DeepCollectionEquality().equals(other.changedFieldNames, changedFieldNames)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,operation,transactionID,imageObjectKey,transactionTitle,transactionAmount,const DeepCollectionEquality().hash(changedFieldNames),serverCreatedDateTime);

@override
String toString() {
  return 'AuditLog(id: $id, userID: $userID, operation: $operation, transactionID: $transactionID, imageObjectKey: $imageObjectKey, transactionTitle: $transactionTitle, transactionAmount: $transactionAmount, changedFieldNames: $changedFieldNames, serverCreatedDateTime: $serverCreatedDateTime)';
}


}

/// @nodoc
abstract mixin class $AuditLogCopyWith<$Res>  {
  factory $AuditLogCopyWith(AuditLog value, $Res Function(AuditLog) _then) = _$AuditLogCopyWithImpl;
@useResult
$Res call({
 String id, String userID,@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation operation, String? transactionID, String? imageObjectKey, String? transactionTitle, int? transactionAmount, List<String> changedFieldNames,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userID = null,Object? operation = null,Object? transactionID = freezed,Object? imageObjectKey = freezed,Object? transactionTitle = freezed,Object? transactionAmount = freezed,Object? changedFieldNames = null,Object? serverCreatedDateTime = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as AuditLogOperation,transactionID: freezed == transactionID ? _self.transactionID : transactionID // ignore: cast_nullable_to_non_nullable
as String?,imageObjectKey: freezed == imageObjectKey ? _self.imageObjectKey : imageObjectKey // ignore: cast_nullable_to_non_nullable
as String?,transactionTitle: freezed == transactionTitle ? _self.transactionTitle : transactionTitle // ignore: cast_nullable_to_non_nullable
as String?,transactionAmount: freezed == transactionAmount ? _self.transactionAmount : transactionAmount // ignore: cast_nullable_to_non_nullable
as int?,changedFieldNames: null == changedFieldNames ? _self.changedFieldNames : changedFieldNames // ignore: cast_nullable_to_non_nullable
as List<String>,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userID, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String? transactionID,  String? imageObjectKey,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
return $default(_that.id,_that.userID,_that.operation,_that.transactionID,_that.imageObjectKey,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames,_that.serverCreatedDateTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userID, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String? transactionID,  String? imageObjectKey,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime)  $default,) {final _that = this;
switch (_that) {
case _AuditLog():
return $default(_that.id,_that.userID,_that.operation,_that.transactionID,_that.imageObjectKey,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames,_that.serverCreatedDateTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userID, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown)  AuditLogOperation operation,  String? transactionID,  String? imageObjectKey,  String? transactionTitle,  int? transactionAmount,  List<String> changedFieldNames, @ServerCreatedTimestamp()  DateTime? serverCreatedDateTime)?  $default,) {final _that = this;
switch (_that) {
case _AuditLog() when $default != null:
return $default(_that.id,_that.userID,_that.operation,_that.transactionID,_that.imageObjectKey,_that.transactionTitle,_that.transactionAmount,_that.changedFieldNames,_that.serverCreatedDateTime);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _AuditLog extends AuditLog {
  const _AuditLog({required this.id, required this.userID, @JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) required this.operation, required this.transactionID, required this.imageObjectKey, required this.transactionTitle, required this.transactionAmount, final  List<String> changedFieldNames = const <String>[], @ServerCreatedTimestamp() this.serverCreatedDateTime}): _changedFieldNames = changedFieldNames,super._();
  factory _AuditLog.fromJson(Map<String, dynamic> json) => _$AuditLogFromJson(json);

/// ドキュメント ID (Firestore の自動生成 ID)。
@override final  String id;
/// このドキュメントの所有ユーザー ID (親ドキュメントの ID。
/// `.claude/rules/entity-parent-id-rules.md` 参照)。
@override final  String userID;
/// 記録した操作の種別。
@override@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) final  AuditLogOperation operation;
/// 操作の対象になった明細の ID。明細に紐づかない操作では null。
@override final  String? transactionID;
/// 削除した元画像の R2 オブジェクトキー。画像を伴わない操作では null。
@override final  String? imageObjectKey;
/// 操作時点の明細の表示名 (店名・摘要)。削除済みの明細を履歴だけで識別できるよう保持する。
@override final  String? transactionTitle;
/// 操作時点の明細の金額 (日本円、整数)。[transactionTitle] と同じ理由で保持する。
@override final  int? transactionAmount;
/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。
/// 訂正以外の操作では空。フィールドが無い旧データも空として読む。
 final  List<String> _changedFieldNames;
/// 訂正で値が変わった Transaction のフィールド名
/// (lib/entity/transaction.dart の [TransactionFirestoreKeys])。
/// 訂正以外の操作では空。フィールドが無い旧データも空として読む。
@override@JsonKey() List<String> get changedFieldNames {
  if (_changedFieldNames is EqualUnmodifiableListView) return _changedFieldNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changedFieldNames);
}

/// 操作を記録したサーバー時刻 (履歴の「いつ」。一覧の並び順にも使う)。
@override@ServerCreatedTimestamp() final  DateTime? serverCreatedDateTime;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuditLog&&(identical(other.id, id) || other.id == id)&&(identical(other.userID, userID) || other.userID == userID)&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.transactionID, transactionID) || other.transactionID == transactionID)&&(identical(other.imageObjectKey, imageObjectKey) || other.imageObjectKey == imageObjectKey)&&(identical(other.transactionTitle, transactionTitle) || other.transactionTitle == transactionTitle)&&(identical(other.transactionAmount, transactionAmount) || other.transactionAmount == transactionAmount)&&const DeepCollectionEquality().equals(other._changedFieldNames, _changedFieldNames)&&(identical(other.serverCreatedDateTime, serverCreatedDateTime) || other.serverCreatedDateTime == serverCreatedDateTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userID,operation,transactionID,imageObjectKey,transactionTitle,transactionAmount,const DeepCollectionEquality().hash(_changedFieldNames),serverCreatedDateTime);

@override
String toString() {
  return 'AuditLog(id: $id, userID: $userID, operation: $operation, transactionID: $transactionID, imageObjectKey: $imageObjectKey, transactionTitle: $transactionTitle, transactionAmount: $transactionAmount, changedFieldNames: $changedFieldNames, serverCreatedDateTime: $serverCreatedDateTime)';
}


}

/// @nodoc
abstract mixin class _$AuditLogCopyWith<$Res> implements $AuditLogCopyWith<$Res> {
  factory _$AuditLogCopyWith(_AuditLog value, $Res Function(_AuditLog) _then) = __$AuditLogCopyWithImpl;
@override @useResult
$Res call({
 String id, String userID,@JsonKey(defaultValue: AuditLogOperation.unknown, unknownEnumValue: AuditLogOperation.unknown) AuditLogOperation operation, String? transactionID, String? imageObjectKey, String? transactionTitle, int? transactionAmount, List<String> changedFieldNames,@ServerCreatedTimestamp() DateTime? serverCreatedDateTime
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userID = null,Object? operation = null,Object? transactionID = freezed,Object? imageObjectKey = freezed,Object? transactionTitle = freezed,Object? transactionAmount = freezed,Object? changedFieldNames = null,Object? serverCreatedDateTime = freezed,}) {
  return _then(_AuditLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userID: null == userID ? _self.userID : userID // ignore: cast_nullable_to_non_nullable
as String,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as AuditLogOperation,transactionID: freezed == transactionID ? _self.transactionID : transactionID // ignore: cast_nullable_to_non_nullable
as String?,imageObjectKey: freezed == imageObjectKey ? _self.imageObjectKey : imageObjectKey // ignore: cast_nullable_to_non_nullable
as String?,transactionTitle: freezed == transactionTitle ? _self.transactionTitle : transactionTitle // ignore: cast_nullable_to_non_nullable
as String?,transactionAmount: freezed == transactionAmount ? _self.transactionAmount : transactionAmount // ignore: cast_nullable_to_non_nullable
as int?,changedFieldNames: null == changedFieldNames ? _self._changedFieldNames : changedFieldNames // ignore: cast_nullable_to_non_nullable
as List<String>,serverCreatedDateTime: freezed == serverCreatedDateTime ? _self.serverCreatedDateTime : serverCreatedDateTime // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
