// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoProgressService)
final videoProgressServiceProvider = VideoProgressServiceProvider._();

final class VideoProgressServiceProvider
    extends
        $FunctionalProvider<
          VideoProgressService,
          VideoProgressService,
          VideoProgressService
        >
    with $Provider<VideoProgressService> {
  VideoProgressServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoProgressServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoProgressServiceHash();

  @$internal
  @override
  $ProviderElement<VideoProgressService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoProgressService create(Ref ref) {
    return videoProgressService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoProgressService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoProgressService>(value),
    );
  }
}

String _$videoProgressServiceHash() =>
    r'857572a2494a5c2a1918371fd07a581b3bba4438';
