// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$monthlyTransactionsHash() =>
    r'80a3e313a06b0182a144120e9a90c683ca307aa2';

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

/// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
///
/// snapshot listener なので編集・追加はリアルタイムに反映され、
/// Firestore のオフラインキャッシュがあればオフラインでも動作する。
///
/// Copied from [monthlyTransactions].
@ProviderFor(monthlyTransactions)
const monthlyTransactionsProvider = MonthlyTransactionsFamily();

/// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
///
/// snapshot listener なので編集・追加はリアルタイムに反映され、
/// Firestore のオフラインキャッシュがあればオフラインでも動作する。
///
/// Copied from [monthlyTransactions].
class MonthlyTransactionsFamily extends Family<AsyncValue<List<Transaction>>> {
  /// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
  ///
  /// snapshot listener なので編集・追加はリアルタイムに反映され、
  /// Firestore のオフラインキャッシュがあればオフラインでも動作する。
  ///
  /// Copied from [monthlyTransactions].
  const MonthlyTransactionsFamily();

  /// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
  ///
  /// snapshot listener なので編集・追加はリアルタイムに反映され、
  /// Firestore のオフラインキャッシュがあればオフラインでも動作する。
  ///
  /// Copied from [monthlyTransactions].
  MonthlyTransactionsProvider call({required String yearMonth}) {
    return MonthlyTransactionsProvider(yearMonth: yearMonth);
  }

  @override
  MonthlyTransactionsProvider getProviderOverride(
    covariant MonthlyTransactionsProvider provider,
  ) {
    return call(yearMonth: provider.yearMonth);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'monthlyTransactionsProvider';
}

/// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
///
/// snapshot listener なので編集・追加はリアルタイムに反映され、
/// Firestore のオフラインキャッシュがあればオフラインでも動作する。
///
/// Copied from [monthlyTransactions].
class MonthlyTransactionsProvider
    extends AutoDisposeStreamProvider<List<Transaction>> {
  /// 指定月 (yearMonth: "2026-08" 形式) の明細一覧を取引日時の降順で購読するストリーム。
  ///
  /// snapshot listener なので編集・追加はリアルタイムに反映され、
  /// Firestore のオフラインキャッシュがあればオフラインでも動作する。
  ///
  /// Copied from [monthlyTransactions].
  MonthlyTransactionsProvider({required String yearMonth})
    : this._internal(
        (ref) => monthlyTransactions(
          ref as MonthlyTransactionsRef,
          yearMonth: yearMonth,
        ),
        from: monthlyTransactionsProvider,
        name: r'monthlyTransactionsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$monthlyTransactionsHash,
        dependencies: MonthlyTransactionsFamily._dependencies,
        allTransitiveDependencies:
            MonthlyTransactionsFamily._allTransitiveDependencies,
        yearMonth: yearMonth,
      );

  MonthlyTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.yearMonth,
  }) : super.internal();

  final String yearMonth;

  @override
  Override overrideWith(
    Stream<List<Transaction>> Function(MonthlyTransactionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MonthlyTransactionsProvider._internal(
        (ref) => create(ref as MonthlyTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        yearMonth: yearMonth,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Transaction>> createElement() {
    return _MonthlyTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyTransactionsProvider && other.yearMonth == yearMonth;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, yearMonth.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MonthlyTransactionsRef
    on AutoDisposeStreamProviderRef<List<Transaction>> {
  /// The parameter `yearMonth` of this provider.
  String get yearMonth;
}

class _MonthlyTransactionsProviderElement
    extends AutoDisposeStreamProviderElement<List<Transaction>>
    with MonthlyTransactionsRef {
  _MonthlyTransactionsProviderElement(super.provider);

  @override
  String get yearMonth => (origin as MonthlyTransactionsProvider).yearMonth;
}

String _$addTransactionHash() => r'8bb1be0d245a4fe91bdbc76dd9b47a4aec24a87f';

/// 明細を新規作成する機能 Provider。
///
/// Copied from [addTransaction].
@ProviderFor(addTransaction)
final addTransactionProvider = AutoDisposeProvider<AddTransaction>.internal(
  addTransaction,
  name: r'addTransactionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$addTransactionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AddTransactionRef = AutoDisposeProviderRef<AddTransaction>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
