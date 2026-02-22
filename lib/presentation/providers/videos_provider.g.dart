// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for liked videos

@ProviderFor(likedVideos)
final likedVideosProvider = LikedVideosProvider._();

/// Provider for liked videos

final class LikedVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Video>>,
          List<Video>,
          FutureOr<List<Video>>
        >
    with $FutureModifier<List<Video>>, $FutureProvider<List<Video>> {
  /// Provider for liked videos
  LikedVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'likedVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$likedVideosHash();

  @$internal
  @override
  $FutureProviderElement<List<Video>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Video>> create(Ref ref) {
    return likedVideos(ref);
  }
}

String _$likedVideosHash() => r'c7985a6ea4fa1a9f7d3371d2ba51b116940b0a08';

/// Provider for watch later videos

@ProviderFor(watchLaterVideos)
final watchLaterVideosProvider = WatchLaterVideosProvider._();

/// Provider for watch later videos

final class WatchLaterVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Video>>,
          List<Video>,
          FutureOr<List<Video>>
        >
    with $FutureModifier<List<Video>>, $FutureProvider<List<Video>> {
  /// Provider for watch later videos
  WatchLaterVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchLaterVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchLaterVideosHash();

  @$internal
  @override
  $FutureProviderElement<List<Video>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Video>> create(Ref ref) {
    return watchLaterVideos(ref);
  }
}

String _$watchLaterVideosHash() => r'54ad0c2d207daa1a315d29245266af72d459495f';

/// Provider for playlist videos

@ProviderFor(playlistVideos)
final playlistVideosProvider = PlaylistVideosFamily._();

/// Provider for playlist videos

final class PlaylistVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Video>>,
          List<Video>,
          FutureOr<List<Video>>
        >
    with $FutureModifier<List<Video>>, $FutureProvider<List<Video>> {
  /// Provider for playlist videos
  PlaylistVideosProvider._({
    required PlaylistVideosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'playlistVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playlistVideosHash();

  @override
  String toString() {
    return r'playlistVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Video>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Video>> create(Ref ref) {
    final argument = this.argument as String;
    return playlistVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlaylistVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playlistVideosHash() => r'be55da8269512e752083cf18f3b1753c15e11198';

/// Provider for playlist videos

final class PlaylistVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Video>>, String> {
  PlaylistVideosFamily._()
    : super(
        retry: null,
        name: r'playlistVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for playlist videos

  PlaylistVideosProvider call(String playlistId) =>
      PlaylistVideosProvider._(argument: playlistId, from: this);

  @override
  String toString() => r'playlistVideosProvider';
}

/// Provider for downloaded videos

@ProviderFor(downloadedVideos)
final downloadedVideosProvider = DownloadedVideosProvider._();

/// Provider for downloaded videos

final class DownloadedVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Video>>,
          List<Video>,
          FutureOr<List<Video>>
        >
    with $FutureModifier<List<Video>>, $FutureProvider<List<Video>> {
  /// Provider for downloaded videos
  DownloadedVideosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadedVideosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadedVideosHash();

  @$internal
  @override
  $FutureProviderElement<List<Video>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Video>> create(Ref ref) {
    return downloadedVideos(ref);
  }
}

String _$downloadedVideosHash() => r'f5b161d73887e4898fcc5598b65097f617717d5d';
