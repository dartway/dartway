// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_session_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The session as reported to Studio: signed-in state, the matching declared
/// persona and whether a persona switch is in flight.

@ProviderFor(studioSessionState)
const studioSessionStateProvider = StudioSessionStateProvider._();

/// The session as reported to Studio: signed-in state, the matching declared
/// persona and whether a persona switch is in flight.

final class StudioSessionStateProvider
    extends
        $FunctionalProvider<
          StudioSessionState,
          StudioSessionState,
          StudioSessionState
        >
    with $Provider<StudioSessionState> {
  /// The session as reported to Studio: signed-in state, the matching declared
  /// persona and whether a persona switch is in flight.
  const StudioSessionStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studioSessionStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studioSessionStateHash();

  @$internal
  @override
  $ProviderElement<StudioSessionState> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StudioSessionState create(Ref ref) {
    return studioSessionState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudioSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudioSessionState>(value),
    );
  }
}

String _$studioSessionStateHash() =>
    r'2ff2c0bc808a834fda1e0b392a268c62a78cb663';
