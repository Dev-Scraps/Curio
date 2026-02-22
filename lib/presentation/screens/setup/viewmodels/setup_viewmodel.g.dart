// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SetupViewModel)
final setupViewModelProvider = SetupViewModelProvider._();

final class SetupViewModelProvider
    extends $NotifierProvider<SetupViewModel, SetupState> {
  SetupViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setupViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setupViewModelHash();

  @$internal
  @override
  SetupViewModel create() => SetupViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetupState>(value),
    );
  }
}

String _$setupViewModelHash() => r'08b2b25ea16ef68b520ce2dafbf9a2a4f2c7e3db';

abstract class _$SetupViewModel extends $Notifier<SetupState> {
  SetupState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SetupState, SetupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetupState, SetupState>,
              SetupState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
