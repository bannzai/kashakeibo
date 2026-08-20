// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_analysis_client.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AnalyzedTransaction {

/// 店名・サービス名 (摘要)。読み取れなかった場合は空文字。
 String get title;/// 金額 (日本円・税込・整数、1 以上)。
 int get amount;/// 取引日 ("YYYY-MM-DD")。年月日のいずれかが読み取れなかった場合は null。
 String? get transactionDate;/// 収入 / 支出。
@JsonKey(unknownEnumValue: TransactionType.expense) TransactionType get type;/// カテゴリ。
@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory get category;
/// Create a copy of AnalyzedTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AnalyzedTransactionCopyWith<AnalyzedTransaction> get copyWith => _$AnalyzedTransactionCopyWithImpl<AnalyzedTransaction>(this as AnalyzedTransaction, _$identity);

  /// Serializes this AnalyzedTransaction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AnalyzedTransaction&&(identical(other.title, title) || other.title == title)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.type, type) || other.type == type)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,amount,transactionDate,type,category);

@override
String toString() {
  return 'AnalyzedTransaction(title: $title, amount: $amount, transactionDate: $transactionDate, type: $type, category: $category)';
}


}

/// @nodoc
abstract mixin class $AnalyzedTransactionCopyWith<$Res>  {
  factory $AnalyzedTransactionCopyWith(AnalyzedTransaction value, $Res Function(AnalyzedTransaction) _then) = _$AnalyzedTransactionCopyWithImpl;
@useResult
$Res call({
 String title, int amount, String? transactionDate,@JsonKey(unknownEnumValue: TransactionType.expense) TransactionType type,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category
});




}
/// @nodoc
class _$AnalyzedTransactionCopyWithImpl<$Res>
    implements $AnalyzedTransactionCopyWith<$Res> {
  _$AnalyzedTransactionCopyWithImpl(this._self, this._then);

  final AnalyzedTransaction _self;
  final $Res Function(AnalyzedTransaction) _then;

/// Create a copy of AnalyzedTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? amount = null,Object? transactionDate = freezed,Object? type = null,Object? category = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,transactionDate: freezed == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,
  ));
}

}


/// Adds pattern-matching-related methods to [AnalyzedTransaction].
extension AnalyzedTransactionPatterns on AnalyzedTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AnalyzedTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AnalyzedTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AnalyzedTransaction value)  $default,){
final _that = this;
switch (_that) {
case _AnalyzedTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AnalyzedTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _AnalyzedTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  int amount,  String? transactionDate, @JsonKey(unknownEnumValue: TransactionType.expense)  TransactionType type, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AnalyzedTransaction() when $default != null:
return $default(_that.title,_that.amount,_that.transactionDate,_that.type,_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  int amount,  String? transactionDate, @JsonKey(unknownEnumValue: TransactionType.expense)  TransactionType type, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category)  $default,) {final _that = this;
switch (_that) {
case _AnalyzedTransaction():
return $default(_that.title,_that.amount,_that.transactionDate,_that.type,_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  int amount,  String? transactionDate, @JsonKey(unknownEnumValue: TransactionType.expense)  TransactionType type, @JsonKey(unknownEnumValue: TransactionCategory.other)  TransactionCategory category)?  $default,) {final _that = this;
switch (_that) {
case _AnalyzedTransaction() when $default != null:
return $default(_that.title,_that.amount,_that.transactionDate,_that.type,_that.category);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AnalyzedTransaction implements AnalyzedTransaction {
  const _AnalyzedTransaction({required this.title, required this.amount, required this.transactionDate, @JsonKey(unknownEnumValue: TransactionType.expense) required this.type, @JsonKey(unknownEnumValue: TransactionCategory.other) required this.category});
  factory _AnalyzedTransaction.fromJson(Map<String, dynamic> json) => _$AnalyzedTransactionFromJson(json);

/// 店名・サービス名 (摘要)。読み取れなかった場合は空文字。
@override final  String title;
/// 金額 (日本円・税込・整数、1 以上)。
@override final  int amount;
/// 取引日 ("YYYY-MM-DD")。年月日のいずれかが読み取れなかった場合は null。
@override final  String? transactionDate;
/// 収入 / 支出。
@override@JsonKey(unknownEnumValue: TransactionType.expense) final  TransactionType type;
/// カテゴリ。
@override@JsonKey(unknownEnumValue: TransactionCategory.other) final  TransactionCategory category;

/// Create a copy of AnalyzedTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AnalyzedTransactionCopyWith<_AnalyzedTransaction> get copyWith => __$AnalyzedTransactionCopyWithImpl<_AnalyzedTransaction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AnalyzedTransactionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AnalyzedTransaction&&(identical(other.title, title) || other.title == title)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.transactionDate, transactionDate) || other.transactionDate == transactionDate)&&(identical(other.type, type) || other.type == type)&&(identical(other.category, category) || other.category == category));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,amount,transactionDate,type,category);

@override
String toString() {
  return 'AnalyzedTransaction(title: $title, amount: $amount, transactionDate: $transactionDate, type: $type, category: $category)';
}


}

/// @nodoc
abstract mixin class _$AnalyzedTransactionCopyWith<$Res> implements $AnalyzedTransactionCopyWith<$Res> {
  factory _$AnalyzedTransactionCopyWith(_AnalyzedTransaction value, $Res Function(_AnalyzedTransaction) _then) = __$AnalyzedTransactionCopyWithImpl;
@override @useResult
$Res call({
 String title, int amount, String? transactionDate,@JsonKey(unknownEnumValue: TransactionType.expense) TransactionType type,@JsonKey(unknownEnumValue: TransactionCategory.other) TransactionCategory category
});




}
/// @nodoc
class __$AnalyzedTransactionCopyWithImpl<$Res>
    implements _$AnalyzedTransactionCopyWith<$Res> {
  __$AnalyzedTransactionCopyWithImpl(this._self, this._then);

  final _AnalyzedTransaction _self;
  final $Res Function(_AnalyzedTransaction) _then;

/// Create a copy of AnalyzedTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? amount = null,Object? transactionDate = freezed,Object? type = null,Object? category = null,}) {
  return _then(_AnalyzedTransaction(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,transactionDate: freezed == transactionDate ? _self.transactionDate : transactionDate // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TransactionType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as TransactionCategory,
  ));
}


}


/// @nodoc
mixin _$ImageAnalysisResult {

/// 抽出した明細。レシートは 1 枚 1 件。明細が写っていない画像では空。
 List<AnalyzedTransaction> get transactions;
/// Create a copy of ImageAnalysisResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageAnalysisResultCopyWith<ImageAnalysisResult> get copyWith => _$ImageAnalysisResultCopyWithImpl<ImageAnalysisResult>(this as ImageAnalysisResult, _$identity);

  /// Serializes this ImageAnalysisResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageAnalysisResult&&const DeepCollectionEquality().equals(other.transactions, transactions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(transactions));

@override
String toString() {
  return 'ImageAnalysisResult(transactions: $transactions)';
}


}

/// @nodoc
abstract mixin class $ImageAnalysisResultCopyWith<$Res>  {
  factory $ImageAnalysisResultCopyWith(ImageAnalysisResult value, $Res Function(ImageAnalysisResult) _then) = _$ImageAnalysisResultCopyWithImpl;
@useResult
$Res call({
 List<AnalyzedTransaction> transactions
});




}
/// @nodoc
class _$ImageAnalysisResultCopyWithImpl<$Res>
    implements $ImageAnalysisResultCopyWith<$Res> {
  _$ImageAnalysisResultCopyWithImpl(this._self, this._then);

  final ImageAnalysisResult _self;
  final $Res Function(ImageAnalysisResult) _then;

/// Create a copy of ImageAnalysisResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? transactions = null,}) {
  return _then(_self.copyWith(
transactions: null == transactions ? _self.transactions : transactions // ignore: cast_nullable_to_non_nullable
as List<AnalyzedTransaction>,
  ));
}

}


/// Adds pattern-matching-related methods to [ImageAnalysisResult].
extension ImageAnalysisResultPatterns on ImageAnalysisResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImageAnalysisResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImageAnalysisResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImageAnalysisResult value)  $default,){
final _that = this;
switch (_that) {
case _ImageAnalysisResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImageAnalysisResult value)?  $default,){
final _that = this;
switch (_that) {
case _ImageAnalysisResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AnalyzedTransaction> transactions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImageAnalysisResult() when $default != null:
return $default(_that.transactions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AnalyzedTransaction> transactions)  $default,) {final _that = this;
switch (_that) {
case _ImageAnalysisResult():
return $default(_that.transactions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AnalyzedTransaction> transactions)?  $default,) {final _that = this;
switch (_that) {
case _ImageAnalysisResult() when $default != null:
return $default(_that.transactions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ImageAnalysisResult implements ImageAnalysisResult {
  const _ImageAnalysisResult({required final  List<AnalyzedTransaction> transactions}): _transactions = transactions;
  factory _ImageAnalysisResult.fromJson(Map<String, dynamic> json) => _$ImageAnalysisResultFromJson(json);

/// 抽出した明細。レシートは 1 枚 1 件。明細が写っていない画像では空。
 final  List<AnalyzedTransaction> _transactions;
/// 抽出した明細。レシートは 1 枚 1 件。明細が写っていない画像では空。
@override List<AnalyzedTransaction> get transactions {
  if (_transactions is EqualUnmodifiableListView) return _transactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_transactions);
}


/// Create a copy of ImageAnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImageAnalysisResultCopyWith<_ImageAnalysisResult> get copyWith => __$ImageAnalysisResultCopyWithImpl<_ImageAnalysisResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageAnalysisResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImageAnalysisResult&&const DeepCollectionEquality().equals(other._transactions, _transactions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_transactions));

@override
String toString() {
  return 'ImageAnalysisResult(transactions: $transactions)';
}


}

/// @nodoc
abstract mixin class _$ImageAnalysisResultCopyWith<$Res> implements $ImageAnalysisResultCopyWith<$Res> {
  factory _$ImageAnalysisResultCopyWith(_ImageAnalysisResult value, $Res Function(_ImageAnalysisResult) _then) = __$ImageAnalysisResultCopyWithImpl;
@override @useResult
$Res call({
 List<AnalyzedTransaction> transactions
});




}
/// @nodoc
class __$ImageAnalysisResultCopyWithImpl<$Res>
    implements _$ImageAnalysisResultCopyWith<$Res> {
  __$ImageAnalysisResultCopyWithImpl(this._self, this._then);

  final _ImageAnalysisResult _self;
  final $Res Function(_ImageAnalysisResult) _then;

/// Create a copy of ImageAnalysisResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transactions = null,}) {
  return _then(_ImageAnalysisResult(
transactions: null == transactions ? _self._transactions : transactions // ignore: cast_nullable_to_non_nullable
as List<AnalyzedTransaction>,
  ));
}


}


/// @nodoc
mixin _$ScanQuota {

/// 今月 (UTC の暦月) の解析回数。プレミアムの解析も数える。
 int get monthlyScanCount;/// 無料プランの月あたり解析回数の上限。
 int get monthlyFreeScanLimit;
/// Create a copy of ScanQuota
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScanQuotaCopyWith<ScanQuota> get copyWith => _$ScanQuotaCopyWithImpl<ScanQuota>(this as ScanQuota, _$identity);

  /// Serializes this ScanQuota to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScanQuota&&(identical(other.monthlyScanCount, monthlyScanCount) || other.monthlyScanCount == monthlyScanCount)&&(identical(other.monthlyFreeScanLimit, monthlyFreeScanLimit) || other.monthlyFreeScanLimit == monthlyFreeScanLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,monthlyScanCount,monthlyFreeScanLimit);

@override
String toString() {
  return 'ScanQuota(monthlyScanCount: $monthlyScanCount, monthlyFreeScanLimit: $monthlyFreeScanLimit)';
}


}

/// @nodoc
abstract mixin class $ScanQuotaCopyWith<$Res>  {
  factory $ScanQuotaCopyWith(ScanQuota value, $Res Function(ScanQuota) _then) = _$ScanQuotaCopyWithImpl;
@useResult
$Res call({
 int monthlyScanCount, int monthlyFreeScanLimit
});




}
/// @nodoc
class _$ScanQuotaCopyWithImpl<$Res>
    implements $ScanQuotaCopyWith<$Res> {
  _$ScanQuotaCopyWithImpl(this._self, this._then);

  final ScanQuota _self;
  final $Res Function(ScanQuota) _then;

/// Create a copy of ScanQuota
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? monthlyScanCount = null,Object? monthlyFreeScanLimit = null,}) {
  return _then(_self.copyWith(
monthlyScanCount: null == monthlyScanCount ? _self.monthlyScanCount : monthlyScanCount // ignore: cast_nullable_to_non_nullable
as int,monthlyFreeScanLimit: null == monthlyFreeScanLimit ? _self.monthlyFreeScanLimit : monthlyFreeScanLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ScanQuota].
extension ScanQuotaPatterns on ScanQuota {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScanQuota value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScanQuota() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScanQuota value)  $default,){
final _that = this;
switch (_that) {
case _ScanQuota():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScanQuota value)?  $default,){
final _that = this;
switch (_that) {
case _ScanQuota() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int monthlyScanCount,  int monthlyFreeScanLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScanQuota() when $default != null:
return $default(_that.monthlyScanCount,_that.monthlyFreeScanLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int monthlyScanCount,  int monthlyFreeScanLimit)  $default,) {final _that = this;
switch (_that) {
case _ScanQuota():
return $default(_that.monthlyScanCount,_that.monthlyFreeScanLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int monthlyScanCount,  int monthlyFreeScanLimit)?  $default,) {final _that = this;
switch (_that) {
case _ScanQuota() when $default != null:
return $default(_that.monthlyScanCount,_that.monthlyFreeScanLimit);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScanQuota implements ScanQuota {
  const _ScanQuota({required this.monthlyScanCount, required this.monthlyFreeScanLimit});
  factory _ScanQuota.fromJson(Map<String, dynamic> json) => _$ScanQuotaFromJson(json);

/// 今月 (UTC の暦月) の解析回数。プレミアムの解析も数える。
@override final  int monthlyScanCount;
/// 無料プランの月あたり解析回数の上限。
@override final  int monthlyFreeScanLimit;

/// Create a copy of ScanQuota
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScanQuotaCopyWith<_ScanQuota> get copyWith => __$ScanQuotaCopyWithImpl<_ScanQuota>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScanQuotaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScanQuota&&(identical(other.monthlyScanCount, monthlyScanCount) || other.monthlyScanCount == monthlyScanCount)&&(identical(other.monthlyFreeScanLimit, monthlyFreeScanLimit) || other.monthlyFreeScanLimit == monthlyFreeScanLimit));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,monthlyScanCount,monthlyFreeScanLimit);

@override
String toString() {
  return 'ScanQuota(monthlyScanCount: $monthlyScanCount, monthlyFreeScanLimit: $monthlyFreeScanLimit)';
}


}

/// @nodoc
abstract mixin class _$ScanQuotaCopyWith<$Res> implements $ScanQuotaCopyWith<$Res> {
  factory _$ScanQuotaCopyWith(_ScanQuota value, $Res Function(_ScanQuota) _then) = __$ScanQuotaCopyWithImpl;
@override @useResult
$Res call({
 int monthlyScanCount, int monthlyFreeScanLimit
});




}
/// @nodoc
class __$ScanQuotaCopyWithImpl<$Res>
    implements _$ScanQuotaCopyWith<$Res> {
  __$ScanQuotaCopyWithImpl(this._self, this._then);

  final _ScanQuota _self;
  final $Res Function(_ScanQuota) _then;

/// Create a copy of ScanQuota
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? monthlyScanCount = null,Object? monthlyFreeScanLimit = null,}) {
  return _then(_ScanQuota(
monthlyScanCount: null == monthlyScanCount ? _self.monthlyScanCount : monthlyScanCount // ignore: cast_nullable_to_non_nullable
as int,monthlyFreeScanLimit: null == monthlyFreeScanLimit ? _self.monthlyFreeScanLimit : monthlyFreeScanLimit // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
