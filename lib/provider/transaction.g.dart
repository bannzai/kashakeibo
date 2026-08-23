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

String _$transactionHash() => r'f9d56522ad05702e58db5779f1475a516a345f04';

/// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
///
/// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
///
/// Copied from [transaction].
@ProviderFor(transaction)
const transactionProvider = TransactionFamily();

/// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
///
/// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
///
/// Copied from [transaction].
class TransactionFamily extends Family<AsyncValue<Transaction?>> {
  /// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
  ///
  /// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
  ///
  /// Copied from [transaction].
  const TransactionFamily();

  /// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
  ///
  /// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
  ///
  /// Copied from [transaction].
  TransactionProvider call({required String transactionID}) {
    return TransactionProvider(transactionID: transactionID);
  }

  @override
  TransactionProvider getProviderOverride(
    covariant TransactionProvider provider,
  ) {
    return call(transactionID: provider.transactionID);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'transactionProvider';
}

/// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
///
/// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
///
/// Copied from [transaction].
class TransactionProvider extends AutoDisposeStreamProvider<Transaction?> {
  /// 明細 1 件を購読するストリーム。明細詳細画面の表示に使う。
  ///
  /// 削除されたドキュメントは null として流れる (詳細画面はそれを受けて閉じる)。
  ///
  /// Copied from [transaction].
  TransactionProvider({required String transactionID})
    : this._internal(
        (ref) =>
            transaction(ref as TransactionRef, transactionID: transactionID),
        from: transactionProvider,
        name: r'transactionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$transactionHash,
        dependencies: TransactionFamily._dependencies,
        allTransitiveDependencies: TransactionFamily._allTransitiveDependencies,
        transactionID: transactionID,
      );

  TransactionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.transactionID,
  }) : super.internal();

  final String transactionID;

  @override
  Override overrideWith(
    Stream<Transaction?> Function(TransactionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TransactionProvider._internal(
        (ref) => create(ref as TransactionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        transactionID: transactionID,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Transaction?> createElement() {
    return _TransactionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionProvider && other.transactionID == transactionID;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, transactionID.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TransactionRef on AutoDisposeStreamProviderRef<Transaction?> {
  /// The parameter `transactionID` of this provider.
  String get transactionID;
}

class _TransactionProviderElement
    extends AutoDisposeStreamProviderElement<Transaction?>
    with TransactionRef {
  _TransactionProviderElement(super.provider);

  @override
  String get transactionID => (origin as TransactionProvider).transactionID;
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

String _$addTransactionHash() => r'9f1176491f5b3e36708c1e557d93db977a304e2c';

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
String _$updateTransactionExclusionHash() =>
    r'6c00ecdbe79242144942bb94c9424ef9b7639844';

/// 明細の計算対象除外フラグを更新する機能 Provider。
///
/// Copied from [updateTransactionExclusion].
@ProviderFor(updateTransactionExclusion)
final updateTransactionExclusionProvider =
    AutoDisposeProvider<UpdateTransactionExclusion>.internal(
      updateTransactionExclusion,
      name: r'updateTransactionExclusionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$updateTransactionExclusionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateTransactionExclusionRef =
    AutoDisposeProviderRef<UpdateTransactionExclusion>;
String _$removeTransactionSourceImageHash() =>
    r'8eabb594228a6cca59f3e792af2a77864aaedb4d';

/// 明細から元画像だけを外す機能 Provider。
///
/// Copied from [removeTransactionSourceImage].
@ProviderFor(removeTransactionSourceImage)
final removeTransactionSourceImageProvider =
    AutoDisposeProvider<RemoveTransactionSourceImage>.internal(
      removeTransactionSourceImage,
      name: r'removeTransactionSourceImageProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$removeTransactionSourceImageHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RemoveTransactionSourceImageRef =
    AutoDisposeProviderRef<RemoveTransactionSourceImage>;
String _$deleteTransactionHash() => r'12e77b402e74cca0a798152d832be4463d37febf';

/// 明細を元画像ごと削除する機能 Provider。
///
/// Copied from [deleteTransaction].
@ProviderFor(deleteTransaction)
final deleteTransactionProvider =
    AutoDisposeProvider<DeleteTransaction>.internal(
      deleteTransaction,
      name: r'deleteTransactionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$deleteTransactionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeleteTransactionRef = AutoDisposeProviderRef<DeleteTransaction>;
String _$mergeDuplicateTransactionsHash() =>
    r'031774b8cb072b5cddd00832a06a0cfb14fc652a';

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
    r'c954563add889f522d3590c48cffbcbcd997976e';

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
