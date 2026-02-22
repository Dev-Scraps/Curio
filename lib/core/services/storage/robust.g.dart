// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'robust.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Enhanced storage service with robust error handling, caching, and optimization

@ProviderFor(robustStorageService)
final robustStorageServiceProvider = RobustStorageServiceProvider._();

/// Enhanced storage service with robust error handling, caching, and optimization

final class RobustStorageServiceProvider
    extends
        $FunctionalProvider<
          RobustStorageService,
          RobustStorageService,
          RobustStorageService
        >
    with $Provider<RobustStorageService> {
  /// Enhanced storage service with robust error handling, caching, and optimization
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
