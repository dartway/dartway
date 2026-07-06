// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'showcase_language_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Language of the passport content. The shell chrome itself stays English;
/// passports are bilingual for the Russian-speaking course and webinars.

@ProviderFor(ShowcaseLanguageState)
const showcaseLanguageStateProvider = ShowcaseLanguageStateProvider._();

/// Language of the passport content. The shell chrome itself stays English;
/// passports are bilingual for the Russian-speaking course and webinars.
final class ShowcaseLanguageStateProvider
    extends $NotifierProvider<ShowcaseLanguageState, ShowcaseLanguage> {
  /// Language of the passport content. The shell chrome itself stays English;
  /// passports are bilingual for the Russian-speaking course and webinars.
  const ShowcaseLanguageStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showcaseLanguageStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showcaseLanguageStateHash();

  @$internal
  @override
  ShowcaseLanguageState create() => ShowcaseLanguageState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowcaseLanguage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowcaseLanguage>(value),
    );
  }
}

String _$showcaseLanguageStateHash() =>
    r'ba9cb9d5b4fa07ef2bb5e3934c2af954c52ace63';

/// Language of the passport content. The shell chrome itself stays English;
/// passports are bilingual for the Russian-speaking course and webinars.

abstract class _$ShowcaseLanguageState extends $Notifier<ShowcaseLanguage> {
  ShowcaseLanguage build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ShowcaseLanguage, ShowcaseLanguage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ShowcaseLanguage, ShowcaseLanguage>,
              ShowcaseLanguage,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
