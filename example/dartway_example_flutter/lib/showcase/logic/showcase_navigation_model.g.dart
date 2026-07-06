// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'showcase_navigation_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Everything the top bar and the passport panel need, derived from the
/// current location and the spec registry.

@ProviderFor(showcaseNavigation)
const showcaseNavigationProvider = ShowcaseNavigationProvider._();

/// Everything the top bar and the passport panel need, derived from the
/// current location and the spec registry.

final class ShowcaseNavigationProvider
    extends
        $FunctionalProvider<
          ShowcaseNavigationModel,
          ShowcaseNavigationModel,
          ShowcaseNavigationModel
        >
    with $Provider<ShowcaseNavigationModel> {
  /// Everything the top bar and the passport panel need, derived from the
  /// current location and the spec registry.
  const ShowcaseNavigationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showcaseNavigationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showcaseNavigationHash();

  @$internal
  @override
  $ProviderElement<ShowcaseNavigationModel> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShowcaseNavigationModel create(Ref ref) {
    return showcaseNavigation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowcaseNavigationModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowcaseNavigationModel>(value),
    );
  }
}

String _$showcaseNavigationHash() =>
    r'941d5048756fd7b02c0ed3965d1157f769fcc706';
