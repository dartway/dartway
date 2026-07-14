// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the phone-based auth flow on top of the DartWay framework auth:
/// a [DwAuthRequest] (login/register, phone provider) is sent, the server
/// replies `pendingVerification`, the user enters the code, and a
/// [DwAuthVerification] exchanges it for an access token that completes the
/// request and signs the user in.

@ProviderFor(AuthState)
const authStateProvider = AuthStateProvider._();

/// Drives the phone-based auth flow on top of the DartWay framework auth:
/// a [DwAuthRequest] (login/register, phone provider) is sent, the server
/// replies `pendingVerification`, the user enters the code, and a
/// [DwAuthVerification] exchanges it for an access token that completes the
/// request and signs the user in.
final class AuthStateProvider
    extends $NotifierProvider<AuthState, AuthStateModel> {
  /// Drives the phone-based auth flow on top of the DartWay framework auth:
  /// a [DwAuthRequest] (login/register, phone provider) is sent, the server
  /// replies `pendingVerification`, the user enters the code, and a
  /// [DwAuthVerification] exchanges it for an access token that completes the
  /// request and signs the user in.
  const AuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  AuthState create() => AuthState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthStateModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthStateModel>(value),
    );
  }
}

String _$authStateHash() => r'ba79f187ae646627099d089e96c22007096dc036';

/// Drives the phone-based auth flow on top of the DartWay framework auth:
/// a [DwAuthRequest] (login/register, phone provider) is sent, the server
/// replies `pendingVerification`, the user enters the code, and a
/// [DwAuthVerification] exchanges it for an access token that completes the
/// request and signs the user in.

abstract class _$AuthState extends $Notifier<AuthStateModel> {
  AuthStateModel build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AuthStateModel, AuthStateModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthStateModel, AuthStateModel>,
              AuthStateModel,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
