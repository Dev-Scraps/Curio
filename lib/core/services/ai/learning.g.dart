// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AI Learning Service - Calls Perplexity API directly
///
/// This service handles AI operations by calling the Perplexity API directly via HTTP.
/// It replaces the previous Python-based implementation.

@ProviderFor(AiLearningService)
final aiLearningServiceProvider = AiLearningServiceProvider._();

/// AI Learning Service - Calls Perplexity API directly
///
/// This service handles AI operations by calling the Perplexity API directly via HTTP.
/// It replaces the previous Python-based implementation.
final class AiLearningServiceProvider
    extends $NotifierProvider<AiLearningService, AiLearningService> {
  /// AI Learning Service - Calls Perplexity API directly
  ///
  /// This service handles AI operations by calling the Perplexity API directly via HTTP.
  /// It replaces the previous Python-based implementation.
  AiLearningServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiLearningServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiLearningServiceHash();

  @$internal
  @override
  AiLearningService create() => AiLearningService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiLearningService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiLearningService>(value),
    );
  }
}

String _$aiLearningServiceHash() => r'5b875e4033d1f534697bd2b531c31e95d75d71c8';

/// AI Learning Service - Calls Perplexity API directly
///
/// This service handles AI operations by calling the Perplexity API directly via HTTP.
/// It replaces the previous Python-based implementation.

abstract class _$AiLearningService extends $Notifier<AiLearningService> {
  AiLearningService build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AiLearningService, AiLearningService>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiLearningService, AiLearningService>,
              AiLearningService,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
