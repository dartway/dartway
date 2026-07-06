// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'showcase_user_switcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the club zone on session changes. State = busy flag.

@ProviderFor(ShowcaseUserSwitcher)
const showcaseUserSwitcherProvider = ShowcaseUserSwitcherProvider._();

/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the club zone on session changes. State = busy flag.
final class ShowcaseUserSwitcherProvider
    extends $NotifierProvider<ShowcaseUserSwitcher, bool> {
  /// Programmatic sign-in as a seeded persona: the regular OTP flow with the
  /// fixed dev code. No manual navigation — the router guards move the app
  /// between /auth and the club zone on session changes. State = busy flag.
  const ShowcaseUserSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showcaseUserSwitcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showcaseUserSwitcherHash();

  @$internal
  @override
  ShowcaseUserSwitcher create() => ShowcaseUserSwitcher();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showcaseUserSwitcherHash() =>
    r'26ca775450f779b9fe7969d78df5c0934d547463';

/// Programmatic sign-in as a seeded persona: the regular OTP flow with the
/// fixed dev code. No manual navigation — the router guards move the app
/// between /auth and the club zone on session changes. State = busy flag.

abstract class _$ShowcaseUserSwitcher extends $Notifier<bool> {
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
