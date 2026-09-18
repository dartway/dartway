import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';

import 'dw_apple_client_secret.dart';
import 'dw_apple_endpoint.dart';
import 'dw_jwks_cache.dart';

/// What a project configures to let people sign in with one provider:
/// [DwGoogleSignIn] and [DwAppleSignIn]. The two are independent — a project
/// declares whichever it offers, and a provider it does not declare is a door
/// its server does not have.
sealed class DwSignInProvider {
  DwSignInProvider({
    required this.clientIds,
    required this.requireNonce,
    required this.clockSkew,
    DwJwksFetch? fetchKeys,
  }) : _fetchKeys = fetchKeys {
    if (clientIds.isEmpty || clientIds.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(
        clientIds,
        'clientIds',
        'a provider without client ids accepts tokens issued for any app',
      );
    }
  }

  /// The provider itself, as the app names it and as the identity is stored.
  DwAuthProvider get provider;

  /// Who the token must say issued it.
  Set<String> get issuers;

  /// Where the provider publishes its signing keys.
  Uri get keySetUri;

  /// Every client id of this app with the provider — **a list, because
  /// Android, iOS and the web each have their own**, and a server that knows
  /// only one of them turns away the users of the other platforms. The
  /// token's `aud` must be one of them: that is what makes it a token for
  /// this app rather than for any app of the provider.
  final List<String> clientIds;

  /// Whether a token without a nonce is refused. The app puts a nonce in the
  /// provider's request and sends the same one with
  /// `DwSignInWithProvider.nonce`; the server then knows the token was minted
  /// for this sign-in and not replayed from another one.
  final bool requireNonce;

  /// How far the provider's clock may stand from this server's.
  final Duration clockSkew;

  final DwJwksFetch? _fetchKeys;

  /// The provider's signing keys, fetched and kept between sign-ins.
  late final DwJwksCache keys = DwJwksCache(keySetUri, fetch: _fetchKeys);
}

/// Sign in with Google: an ID token from the Google sign-in SDK, RS256.
final class DwGoogleSignIn extends DwSignInProvider {
  DwGoogleSignIn({
    required super.clientIds,
    super.requireNonce = false,
    super.clockSkew = const Duration(minutes: 2),
    super.fetchKeys,
  });

  @override
  DwAuthProvider get provider => DwAuthProvider.google;

  /// Google issues tokens under both spellings and says so itself.
  @override
  Set<String> get issuers => const {
    'https://accounts.google.com',
    'accounts.google.com',
  };

  @override
  Uri get keySetUri => Uri.https('www.googleapis.com', '/oauth2/v3/certs');
}

/// The key a project downloads from Apple once — a `.p8` file — and the two
/// ids that say whose it is.
///
/// It exists for one thing: Apple's own endpoints take no password, only a
/// **client secret** signed with this key. Without it an app can sign people
/// in and cannot tell Apple when one of them leaves, which Apple requires of
/// an app that offers Sign in with Apple.
///
/// Keep the `.p8` in the secret store, never in the repository: it signs on
/// behalf of the whole team, and Apple hands it out once.
final class DwAppleSigningKey {
  DwAppleSigningKey({
    required this.teamId,
    required this.keyId,
    required this.privateKeyPem,
  }) {
    // Read now rather than at the first deletion: a key that does not parse
    // must stop a server from starting, not a person from leaving.
    _secretFor('probe');
  }

  /// The ten-character team id from the developer account.
  final String teamId;

  /// The id Apple gave the key, as in `AuthKey_<keyId>.p8`.
  final String keyId;

  /// The file's text, `-----BEGIN PRIVATE KEY-----` and all.
  final String privateKeyPem;

  final Map<String, DwAppleClientSecret> _secrets = {};

  DwAppleClientSecret _secretFor(String clientId) => _secrets.putIfAbsent(
    clientId,
    () => DwAppleClientSecret(
      teamId: teamId,
      keyId: keyId,
      clientId: clientId,
      privateKeyPem: privateKeyPem,
    ),
  );

  /// A freshly signed client secret for a call about [clientId] — the same
  /// client id the token was issued for, which is what Apple checks.
  String mintFor(String clientId) => _secretFor(clientId).mint();
}

/// Sign in with Apple: an identity token from the Apple sign-in flow, ES256.
///
/// Apple tells the person's name and e-mail **only at the very first
/// authorization**; the token carries the e-mail, the name never. An app that
/// wants the name sends it in `DwSignInWithProvider.registration` of that
/// first sign-in, or it is gone.
final class DwAppleSignIn extends DwSignInProvider {
  DwAppleSignIn({
    required super.clientIds,
    this.signingKey,
    super.requireNonce = true,
    super.clockSkew = const Duration(minutes: 2),
    super.fetchKeys,
    DwApplePost? post,
  }) : endpoint = DwAppleEndpoint(post: post);

  /// The `.p8` key, when the project has one. Without it the app signs in and
  /// nothing is kept for the revocation Apple asks for on deletion — see
  /// [DwAppleSigningKey].
  final DwAppleSigningKey? signingKey;

  /// Apple's `/auth/token` and `/auth/revoke`.
  final DwAppleEndpoint endpoint;

  @override
  DwAuthProvider get provider => DwAuthProvider.apple;

  @override
  Set<String> get issuers => const {'https://appleid.apple.com'};

  @override
  Uri get keySetUri => Uri.https('appleid.apple.com', '/auth/keys');
}
