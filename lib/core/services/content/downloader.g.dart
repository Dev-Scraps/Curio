// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DownloadService)
final downloadServiceProvider = DownloadServiceProvider._();

final class DownloadServiceProvider
    extends $NotifierProvider<DownloadService, List<DownloadTask>> {
  DownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadServiceHash();

  @$internal
  @override
  DownloadService create() => DownloadService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<DownloadTask> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<DownloadTask>>(value),
    );
  }
}

String _$downloadServiceHash() => r'358b5a8e3a94e5de8a5eb10f5c826cda8fb84bb7';

abstract class _$DownloadService extends $Notifier<List<DownloadTask>> {
  List<DownloadTask> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<DownloadTask>, List<DownloadTask>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<DownloadTask>, List<DownloadTask>>,
              List<DownloadTask>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
