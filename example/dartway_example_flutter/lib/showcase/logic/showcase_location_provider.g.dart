// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'showcase_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Current app location observed from OUTSIDE the router widget tree
/// (the shell lives in MaterialApp.builder where GoRouterState.of is not
/// available), so we listen to the router delegate directly.

@ProviderFor(ShowcaseLocation)
const showcaseLocationProvider = ShowcaseLocationProvider._();

/// Current app location observed from OUTSIDE the router widget tree
/// (the shell lives in MaterialApp.builder where GoRouterState.of is not
/// available), so we listen to the router delegate directly.
final class ShowcaseLocationProvider
    extends $NotifierProvider<ShowcaseLocation, String> {
  /// Current app location observed from OUTSIDE the router widget tree
  /// (the shell lives in MaterialApp.builder where GoRouterState.of is not
  /// available), so we listen to the router delegate directly.
  const ShowcaseLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showcaseLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showcaseLocationHash();

  @$internal
  @override
  ShowcaseLocation create() => ShowcaseLocation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$showcaseLocationHash() => r'e97e83c481f4ec617191dea87e729b325ed951eb';

/// Current app location observed from OUTSIDE the router widget tree
/// (the shell lives in MaterialApp.builder where GoRouterState.of is not
/// available), so we listen to the router delegate directly.

abstract class _$ShowcaseLocation extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
