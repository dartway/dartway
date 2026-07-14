// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_persona_switcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the app zone on session changes. State = busy flag.

@ProviderFor(StudioPersonaSwitcher)
const studioPersonaSwitcherProvider = StudioPersonaSwitcherProvider._();

/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the app zone on session changes. State = busy flag.
final class StudioPersonaSwitcherProvider
    extends $NotifierProvider<StudioPersonaSwitcher, bool> {
  /// Programmatic sign-in as a seeded persona: the regular OTP flow with the
  /// fixed dev code. No manual navigation — the router guards move the app
  /// between /auth and the app zone on session changes. State = busy flag.
  const StudioPersonaSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioPersonaSwitcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioPersonaSwitcherHash();

  @$internal
  @override
  StudioPersonaSwitcher create() => StudioPersonaSwitcher();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$studioPersonaSwitcherHash() =>
    r'e9126d8cab8aeaa6044f889f325af537ddc32121';

/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the app zone on session changes. State = busy flag.

abstract class _$StudioPersonaSwitcher extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
