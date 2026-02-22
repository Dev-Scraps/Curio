// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'youtube.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(youtubeService)
final youtubeServiceProvider = YoutubeServiceProvider._();

final class YoutubeServiceProvider
    extends $FunctionalProvider<YoutubeService, YoutubeService, YoutubeService>
    with $Provider<YoutubeService> {
  YoutubeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'youtubeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$youtubeServiceHash();

  @$internal
  @override
  $ProviderElement<YoutubeService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  YoutubeService create(Ref ref) {
    return youtubeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(YoutubeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<YoutubeService>(value),
    );
  }
}

String _$youtubeServiceHash() => r'0b5340802fe69ba39604f6be2daa4c145ef98ab8';
