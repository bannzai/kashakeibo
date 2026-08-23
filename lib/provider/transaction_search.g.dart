// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchedTransactionsHash() =>
    r'ca0e07bb65b207c0f4881c6523bbc9cb6daf9a97';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
///
/// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
/// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
/// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
/// 月をまたいだ・課金状態が変わった時に再検索されない)。
/// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
///
/// Copied from [searchedTransactions].
@ProviderFor(searchedTransactions)
const searchedTransactionsProvider = SearchedTransactionsFamily();

/// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
///
/// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
/// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
/// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
/// 月をまたいだ・課金状態が変わった時に再検索されない)。
/// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
///
/// Copied from [searchedTransactions].
class SearchedTransactionsFamily extends Family<AsyncValue<List<Transaction>>> {
  /// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
  ///
  /// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
  /// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
  /// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
  /// 月をまたいだ・課金状態が変わった時に再検索されない)。
  /// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
  ///
  /// Copied from [searchedTransactions].
  const SearchedTransactionsFamily();

  /// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
  ///
  /// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
  /// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
  /// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
  /// 月をまたいだ・課金状態が変わった時に再検索されない)。
  /// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
  ///
  /// Copied from [searchedTransactions].
  SearchedTransactionsProvider call({
    required DateTime? transactionDateFrom,
    required DateTime? transactionDateTo,
    required int? minimumAmount,
    required int? maximumAmount,
    required String? titleKeyword,
    required DateTime? oldestSearchableTransactionDate,
  }) {
    return SearchedTransactionsProvider(
      transactionDateFrom: transactionDateFrom,
      transactionDateTo: transactionDateTo,
      minimumAmount: minimumAmount,
      maximumAmount: maximumAmount,
      titleKeyword: titleKeyword,
      oldestSearchableTransactionDate: oldestSearchableTransactionDate,
    );
  }

  @override
  SearchedTransactionsProvider getProviderOverride(
    covariant SearchedTransactionsProvider provider,
  ) {
    return call(
      transactionDateFrom: provider.transactionDateFrom,
      transactionDateTo: provider.transactionDateTo,
      minimumAmount: provider.minimumAmount,
      maximumAmount: provider.maximumAmount,
      titleKeyword: provider.titleKeyword,
      oldestSearchableTransactionDate: provider.oldestSearchableTransactionDate,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'searchedTransactionsProvider';
}

/// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
///
/// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
/// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
/// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
/// 月をまたいだ・課金状態が変わった時に再検索されない)。
/// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
///
/// Copied from [searchedTransactions].
class SearchedTransactionsProvider
    extends AutoDisposeStreamProvider<List<Transaction>> {
  /// 検索条件に一致する明細を取引日の新しい順で購読するストリーム。検索画面の一覧に使う。
  ///
  /// 無料プランの下限 ([oldestSearchableTransactionDate]) は、課金状態と現在時刻の両方で
  /// 変わる値のため、この Provider の中では計算せず family の引数として画面から受け取る
  /// (Provider 内で計算すると、初回に作られた family インスタンスが古い下限を保持し続け、
  /// 月をまたいだ・課金状態が変わった時に再検索されない)。
  /// 条件の意味と絞り込みの方法は [searchTransactions] を参照。
  ///
  /// Copied from [searchedTransactions].
  SearchedTransactionsProvider({
    required DateTime? transactionDateFrom,
    required DateTime? transactionDateTo,
    required int? minimumAmount,
    required int? maximumAmount,
    required String? titleKeyword,
    required DateTime? oldestSearchableTransactionDate,
  }) : this._internal(
         (ref) => searchedTransactions(
           ref as SearchedTransactionsRef,
           transactionDateFrom: transactionDateFrom,
           transactionDateTo: transactionDateTo,
           minimumAmount: minimumAmount,
           maximumAmount: maximumAmount,
           titleKeyword: titleKeyword,
           oldestSearchableTransactionDate: oldestSearchableTransactionDate,
         ),
         from: searchedTransactionsProvider,
         name: r'searchedTransactionsProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$searchedTransactionsHash,
         dependencies: SearchedTransactionsFamily._dependencies,
         allTransitiveDependencies:
             SearchedTransactionsFamily._allTransitiveDependencies,
         transactionDateFrom: transactionDateFrom,
         transactionDateTo: transactionDateTo,
         minimumAmount: minimumAmount,
         maximumAmount: maximumAmount,
         titleKeyword: titleKeyword,
         oldestSearchableTransactionDate: oldestSearchableTransactionDate,
       );

  SearchedTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.transactionDateFrom,
    required this.transactionDateTo,
    required this.minimumAmount,
    required this.maximumAmount,
    required this.titleKeyword,
    required this.oldestSearchableTransactionDate,
  }) : super.internal();

  final DateTime? transactionDateFrom;
  final DateTime? transactionDateTo;
  final int? minimumAmount;
  final int? maximumAmount;
  final String? titleKeyword;
  final DateTime? oldestSearchableTransactionDate;

  @override
  Override overrideWith(
    Stream<List<Transaction>> Function(SearchedTransactionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchedTransactionsProvider._internal(
        (ref) => create(ref as SearchedTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        transactionDateFrom: transactionDateFrom,
        transactionDateTo: transactionDateTo,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        titleKeyword: titleKeyword,
        oldestSearchableTransactionDate: oldestSearchableTransactionDate,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Transaction>> createElement() {
    return _SearchedTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchedTransactionsProvider &&
        other.transactionDateFrom == transactionDateFrom &&
        other.transactionDateTo == transactionDateTo &&
        other.minimumAmount == minimumAmount &&
        other.maximumAmount == maximumAmount &&
        other.titleKeyword == titleKeyword &&
        other.oldestSearchableTransactionDate ==
            oldestSearchableTransactionDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, transactionDateFrom.hashCode);
    hash = _SystemHash.combine(hash, transactionDateTo.hashCode);
    hash = _SystemHash.combine(hash, minimumAmount.hashCode);
    hash = _SystemHash.combine(hash, maximumAmount.hashCode);
    hash = _SystemHash.combine(hash, titleKeyword.hashCode);
    hash = _SystemHash.combine(hash, oldestSearchableTransactionDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchedTransactionsRef
    on AutoDisposeStreamProviderRef<List<Transaction>> {
  /// The parameter `transactionDateFrom` of this provider.
  DateTime? get transactionDateFrom;

  /// The parameter `transactionDateTo` of this provider.
  DateTime? get transactionDateTo;

  /// The parameter `minimumAmount` of this provider.
  int? get minimumAmount;

  /// The parameter `maximumAmount` of this provider.
  int? get maximumAmount;

  /// The parameter `titleKeyword` of this provider.
  String? get titleKeyword;

  /// The parameter `oldestSearchableTransactionDate` of this provider.
  DateTime? get oldestSearchableTransactionDate;
}

class _SearchedTransactionsProviderElement
    extends AutoDisposeStreamProviderElement<List<Transaction>>
    with SearchedTransactionsRef {
  _SearchedTransactionsProviderElement(super.provider);

  @override
  DateTime? get transactionDateFrom =>
      (origin as SearchedTransactionsProvider).transactionDateFrom;
  @override
  DateTime? get transactionDateTo =>
      (origin as SearchedTransactionsProvider).transactionDateTo;
  @override
  int? get minimumAmount =>
      (origin as SearchedTransactionsProvider).minimumAmount;
  @override
  int? get maximumAmount =>
      (origin as SearchedTransactionsProvider).maximumAmount;
  @override
  String? get titleKeyword =>
      (origin as SearchedTransactionsProvider).titleKeyword;
  @override
  DateTime? get oldestSearchableTransactionDate =>
      (origin as SearchedTransactionsProvider).oldestSearchableTransactionDate;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
