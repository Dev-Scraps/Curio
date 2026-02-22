// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlayerViewModel)
final playerViewModelProvider = PlayerViewModelProvider._();

final class PlayerViewModelProvider
    extends $NotifierProvider<PlayerViewModel, PlayerState> {
  PlayerViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playerViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playerViewModelHash();

  @$internal
  @override
  PlayerViewModel create() => PlayerViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlayerState>(value),
    );
  }
}

String _$playerViewModelHash() => r'41f229abc6fe92da094c9caa0e7e18f943fa415a';

abstract class _$PlayerViewModel extends $Notifier<PlayerState> {
  PlayerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PlayerState, PlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlayerState, PlayerState>,
              PlayerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
