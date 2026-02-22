// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LanguageNotifier)
final languageProvider = LanguageNotifierProvider._();

final class LanguageNotifierProvider
    extends $AsyncNotifierProvider<LanguageNotifier, Locale> {
  LanguageNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$languageNotifierHash();

  @$internal
  @override
  LanguageNotifier create() => LanguageNotifier();
}

String _$languageNotifierHash() => r'a5ec4d582252cfa2675004061113b12e4108d092';

abstract class _$LanguageNotifier extends $AsyncNotifier<Locale> {
  FutureOr<Locale> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale>, Locale>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale>, Locale>,
              AsyncValue<Locale>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(supportedLocales)
final supportedLocalesProvider = SupportedLocalesProvider._();

final class SupportedLocalesProvider
    extends $FunctionalProvider<List<Locale>, List<Locale>, List<Locale>>
    with $Provider<List<Locale>> {
  SupportedLocalesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportedLocalesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportedLocalesHash();

  @$internal
  @override
  $ProviderElement<List<Locale>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Locale> create(Ref ref) {
    return supportedLocales(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Locale> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Locale>>(value),
    );
  }
}

String _$supportedLocalesHash() => r'f7f0155a76f025e5d2353349a95da353d81cc678';

@ProviderFor(localizationDelegates)
final localizationDelegatesProvider = LocalizationDelegatesProvider._();

final class LocalizationDelegatesProvider
    extends
        $FunctionalProvider<
          List<LocalizationsDelegate<dynamic>>,
          List<LocalizationsDelegate<dynamic>>,
          List<LocalizationsDelegate<dynamic>>
        >
    with $Provider<List<LocalizationsDelegate<dynamic>>> {
  LocalizationDelegatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localizationDelegatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localizationDelegatesHash();

  @$internal
  @override
  $ProviderElement<List<LocalizationsDelegate<dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<LocalizationsDelegate<dynamic>> create(Ref ref) {
    return localizationDelegates(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<LocalizationsDelegate<dynamic>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<List<LocalizationsDelegate<dynamic>>>(value),
    );
  }
}

String _$localizationDelegatesHash() =>
    r'4bcad011f2a391a66ab664b1a118c82352cfabc1';
