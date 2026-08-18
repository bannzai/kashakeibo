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

String _$monthlyDuplicateCandidatesHash() =>
    r'b953e2a344ac4d10a2c48cd713e19625c1126500';

/// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
///
/// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
///
/// Copied from [monthlyDuplicateCandidates].
@ProviderFor(monthlyDuplicateCandidates)
const monthlyDuplicateCandidatesProvider = MonthlyDuplicateCandidatesFamily();

/// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
///
/// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
///
/// Copied from [monthlyDuplicateCandidates].
class MonthlyDuplicateCandidatesFamily
    extends Family<List<DuplicateCandidate>> {
  /// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
  ///
  /// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
  ///
  /// Copied from [monthlyDuplicateCandidates].
  const MonthlyDuplicateCandidatesFamily();

  /// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
  ///
  /// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
  ///
  /// Copied from [monthlyDuplicateCandidates].
  MonthlyDuplicateCandidatesProvider call({required String yearMonth}) {
    return MonthlyDuplicateCandidatesProvider(yearMonth: yearMonth);
  }

  @override
  MonthlyDuplicateCandidatesProvider getProviderOverride(
    covariant MonthlyDuplicateCandidatesProvider provider,
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
  String? get name => r'monthlyDuplicateCandidatesProvider';
}

/// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
///
/// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
///
/// Copied from [monthlyDuplicateCandidates].
class MonthlyDuplicateCandidatesProvider
    extends AutoDisposeProvider<List<DuplicateCandidate>> {
  /// 表示月と隣接月の明細から、表示月に関係する重複候補を返す。
  ///
  /// 月末と翌月初の明細も前後 3 日以内の判定対象に含めるため、前月・当月・翌月を購読する。
  ///
  /// Copied from [monthlyDuplicateCandidates].
  MonthlyDuplicateCandidatesProvider({required String yearMonth})
    : this._internal(
        (ref) => monthlyDuplicateCandidates(
          ref as MonthlyDuplicateCandidatesRef,
          yearMonth: yearMonth,
        ),
        from: monthlyDuplicateCandidatesProvider,
        name: r'monthlyDuplicateCandidatesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$monthlyDuplicateCandidatesHash,
        dependencies: MonthlyDuplicateCandidatesFamily._dependencies,
        allTransitiveDependencies:
            MonthlyDuplicateCandidatesFamily._allTransitiveDependencies,
        yearMonth: yearMonth,
      );

  MonthlyDuplicateCandidatesProvider._internal(
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
    List<DuplicateCandidate> Function(MonthlyDuplicateCandidatesRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MonthlyDuplicateCandidatesProvider._internal(
        (ref) => create(ref as MonthlyDuplicateCandidatesRef),
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
  AutoDisposeProviderElement<List<DuplicateCandidate>> createElement() {
    return _MonthlyDuplicateCandidatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MonthlyDuplicateCandidatesProvider &&
        other.yearMonth == yearMonth;
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
mixin MonthlyDuplicateCandidatesRef
    on AutoDisposeProviderRef<List<DuplicateCandidate>> {
  /// The parameter `yearMonth` of this provider.
  String get yearMonth;
}

class _MonthlyDuplicateCandidatesProviderElement
    extends AutoDisposeProviderElement<List<DuplicateCandidate>>
    with MonthlyDuplicateCandidatesRef {
  _MonthlyDuplicateCandidatesProviderElement(super.provider);

  @override
  String get yearMonth =>
      (origin as MonthlyDuplicateCandidatesProvider).yearMonth;
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
String _$mergeDuplicateTransactionsHash() =>
    r'0c6949ac73defcb882f3344efb723126870bddd1';

/// 重複候補 2 件を 1 件へ統合する機能 Provider。
///
/// Copied from [mergeDuplicateTransactions].
@ProviderFor(mergeDuplicateTransactions)
final mergeDuplicateTransactionsProvider =
    AutoDisposeProvider<MergeDuplicateTransactions>.internal(
      mergeDuplicateTransactions,
      name: r'mergeDuplicateTransactionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$mergeDuplicateTransactionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MergeDuplicateTransactionsRef =
    AutoDisposeProviderRef<MergeDuplicateTransactions>;
String _$keepBothTransactionsHash() =>
    r'dcf6691be761dddb442db074b852ceddc1a2bd66';

/// 重複候補 2 件を別々の明細として残す機能 Provider。
///
/// Copied from [keepBothTransactions].
@ProviderFor(keepBothTransactions)
final keepBothTransactionsProvider =
    AutoDisposeProvider<KeepBothTransactions>.internal(
      keepBothTransactions,
      name: r'keepBothTransactionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$keepBothTransactionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KeepBothTransactionsRef = AutoDisposeProviderRef<KeepBothTransactions>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
