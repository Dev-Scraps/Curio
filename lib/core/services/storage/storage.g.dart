// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(robustStorageService)
final robustStorageServiceProvider = RobustStorageServiceProvider._();

final class RobustStorageServiceProvider
    extends
        $FunctionalProvider<
          RobustStorageService,
          RobustStorageService,
          RobustStorageService
        >
    with $Provider<RobustStorageService> {
  RobustStorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'robustStorageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$robustStorageServiceHash();

  @$internal
  @override
  $ProviderElement<RobustStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RobustStorageService create(Ref ref) {
    return robustStorageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RobustStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RobustStorageService>(value),
    );
  }
}

String _$robustStorageServiceHash() =>
    r'2395dcd2c736e93ec291b1f723714585d6d24dba';

@ProviderFor(storageService)
final storageServiceProvider = StorageServiceProvider._();

final class StorageServiceProvider
    extends $FunctionalProvider<StorageService, StorageService, StorageService>
    with $Provider<StorageService> {
  StorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageServiceHash();

  @$internal
  @override
  $ProviderElement<StorageService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StorageService create(Ref ref) {
    return storageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageService>(value),
    );
  }
}

String _$storageServiceHash() => r'57d1d6d127dd92c606faee58b0eadd19c04c7a79';
