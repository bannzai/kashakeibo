// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$storedImageHash() => r'c6b4750919b63fe7cbd86025e6a5e3b43f1e3ae0';

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

/// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
///
/// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
/// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
///
/// Copied from [storedImage].
@ProviderFor(storedImage)
const storedImageProvider = StoredImageFamily();

/// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
///
/// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
/// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
///
/// Copied from [storedImage].
class StoredImageFamily extends Family<AsyncValue<Uint8List>> {
  /// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
  ///
  /// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
  /// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
  ///
  /// Copied from [storedImage].
  const StoredImageFamily();

  /// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
  ///
  /// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
  /// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
  ///
  /// Copied from [storedImage].
  StoredImageProvider call({required String imageObjectKey}) {
    return StoredImageProvider(imageObjectKey: imageObjectKey);
  }

  @override
  StoredImageProvider getProviderOverride(
    covariant StoredImageProvider provider,
  ) {
    return call(imageObjectKey: provider.imageObjectKey);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'storedImageProvider';
}

/// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
///
/// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
/// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
///
/// Copied from [storedImage].
class StoredImageProvider extends AutoDisposeFutureProvider<Uint8List> {
  /// 明細に紐づく元画像のバイト列。明細詳細の元画像表示に使う。
  ///
  /// 同じオブジェクトキーの取得結果を Provider にキャッシュし、詳細画面の再表示のたびに
  /// Worker から取得し直さないようにする。画像を削除した時は呼び出し側で invalidate する。
  ///
  /// Copied from [storedImage].
  StoredImageProvider({required String imageObjectKey})
    : this._internal(
        (ref) =>
            storedImage(ref as StoredImageRef, imageObjectKey: imageObjectKey),
        from: storedImageProvider,
        name: r'storedImageProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$storedImageHash,
        dependencies: StoredImageFamily._dependencies,
        allTransitiveDependencies: StoredImageFamily._allTransitiveDependencies,
        imageObjectKey: imageObjectKey,
      );

  StoredImageProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.imageObjectKey,
  }) : super.internal();

  final String imageObjectKey;

  @override
  Override overrideWith(
    FutureOr<Uint8List> Function(StoredImageRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StoredImageProvider._internal(
        (ref) => create(ref as StoredImageRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        imageObjectKey: imageObjectKey,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Uint8List> createElement() {
    return _StoredImageProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StoredImageProvider &&
        other.imageObjectKey == imageObjectKey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, imageObjectKey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin StoredImageRef on AutoDisposeFutureProviderRef<Uint8List> {
  /// The parameter `imageObjectKey` of this provider.
  String get imageObjectKey;
}

class _StoredImageProviderElement
    extends AutoDisposeFutureProviderElement<Uint8List>
    with StoredImageRef {
  _StoredImageProviderElement(super.provider);

  @override
  String get imageObjectKey => (origin as StoredImageProvider).imageObjectKey;
}

String _$monthlyScanQuotaHash() => r'5cd0dd452be8b087429bfadb409cfcfe5cb4cc1f';

/// 今月のスキャン回数と無料枠 (残量チップ・ペイウォールの表示判定に使う)。
///
/// サインイン中のユーザーが変わると取り直す。解析のたびに Worker 側の回数が進むため、
/// 撮影フローの終了後などに [refresh] で取り直す (画面が unmount され得るコールバックから
/// 呼べるよう keepAlive にし、notifier を build 時に確保して使う。`.claude/rules/riverpod-rules.md`)。
///
/// Copied from [MonthlyScanQuota].
@ProviderFor(MonthlyScanQuota)
final monthlyScanQuotaProvider =
    AsyncNotifierProvider<MonthlyScanQuota, image_analysis.ScanQuota>.internal(
      MonthlyScanQuota.new,
      name: r'monthlyScanQuotaProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$monthlyScanQuotaHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MonthlyScanQuota = AsyncNotifier<image_analysis.ScanQuota>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
