import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The sign-in providers the framework verifies tokens of.
///
/// The name of the value is what the identity is stored under
/// (`dw_identity.kind`), beside the phones and e-mails a code reaches.
enum DwAuthProvider { google, apple }

/// Signs in with a token an external provider issued for this app: a Google
/// ID token, an Apple identity token.
///
/// The app obtains [idToken] with the provider's own SDK and sends it here;
/// the server verifies its signature against the provider's published keys and
/// signs in the account of the subject it names, creating one the first time
/// (`DwAuthConfig.onExternalAccountCreated`). Verifying needs
/// `dartway_auth_providers_server` configured with the app's client ids: a
/// server without it refuses, as every unconfigured door does.
///
/// [nonce] is the raw nonce the app put in the provider's request, if it used
/// one — Apple's flow does, and the server checks that the token carries its
/// SHA-256. [registration] is what the project collects at sign-up, as in
/// [DwVerifyCode]: the provider tells a name and an e-mail only at the very
/// first sign-in, so an app that wants them sends them here with it.
final class DwSignInWithProvider extends DwActionCommand<DwAuthSession> {
  const DwSignInWithProvider({
    required this.provider,
    required this.idToken,
    this.nonce,
    this.authorizationCode,
    this.registration = const {},
  });

  final DwAuthProvider provider;

  /// The provider's signed token. Never stored: what is kept is the subject
  /// it proves.
  final String idToken;
  final String? nonce;

  /// Apple's one-time authorization code, when the app has it.
  ///
  /// It is what the server exchanges — once, at the first sign-in — for the
  /// refresh token that lets it revoke the person's tokens with Apple when
  /// they delete their account, which Apple requires of an app that offers
  /// Sign in with Apple. Without it the sign-in works and the deletion has
  /// nothing to revoke with.
  final String? authorizationCode;
  final Map<String, String> registration;

  @override
  String get dwTypeName => 'DwSignInWithProvider';

  @override
  Map<String, Object?> toJson() => {
    'provider': provider.name,
    'idToken': idToken,
    if (nonce != null) 'nonce': nonce,
    if (authorizationCode != null) 'authorizationCode': authorizationCode,
    if (registration.isNotEmpty) 'registration': registration,
  };

  static DwSignInWithProvider fromJson(Map<String, Object?> json) =>
      DwSignInWithProvider(
        provider: DwJsonCodec.decodeEnum(json['provider'], DwAuthProvider.values),
        idToken: json['idToken']! as String,
        nonce: json['nonce'] as String?,
        authorizationCode: json['authorizationCode'] as String?,
        registration: json['registration'] == null
            ? const {}
            : DwJsonCodec.decodeMap(json['registration'], (v) => v! as String),
      );

  @override
  bool operator ==(Object other) =>
      other is DwSignInWithProvider &&
      other.provider == provider &&
      other.idToken == idToken &&
      other.nonce == nonce &&
      other.authorizationCode == authorizationCode;

  @override
  int get hashCode => Object.hash(provider, idToken, nonce, authorizationCode);
}

/// The refusals of a sign-in with a provider, beside `DwCoreRefusal`.
enum DwProviderRefusal implements DwRefusalCode {
  /// The provider's token was not accepted: not signed by the provider, not
  /// issued for this app, expired, or carrying the wrong nonce. The app asks
  /// the provider for a fresh one and tries again; what exactly was wrong is
  /// in the server's log, not in the answer — it would be a hint to whoever
  /// is trying tokens. Field `idToken`.
  credentialRejected('dw.providerCredentialRejected'),

  /// The provider could not be reached for its signing keys, and the server
  /// holds none it trusts. Nothing is wrong with the token: the app may try
  /// again in a moment. Field `provider`.
  providerUnreachable('dw.providerUnreachable');

  const DwProviderRefusal(this.code);

  @override
  final String code;
}

/// The DTOs of signing in with a provider. Register them in the protocol both
/// sides build:
///
/// ```dart
/// final appProtocol = DwWireProtocol(
///   [...dwAuthProvidersProtocolEntries, ...appEntries],
///   include: DwWireProtocol.core,
/// );
/// ```
const List<DwProtocolEntry> dwAuthProvidersProtocolEntries = [
  DwProtocolEntry<DwSignInWithProvider>(
    'DwSignInWithProvider',
    DwSignInWithProvider.fromJson,
  ),
];
