import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What Apple told about the person, which it does **only at the very first
/// authorization** and never again: not in the identity token, not on the
/// next sign-in, not after a reinstall. The project decides what to do with
/// it — see [DwAppleSignInCall.signInWithApple].
final class DwAppleIntroduction {
  const DwAppleIntroduction({this.givenName, this.familyName, this.email});

  final String? givenName;
  final String? familyName;

  /// May be Apple's relay address when the person chose to hide theirs. The
  /// server gets the same e-mail from the token it verified, under
  /// `DwProviderClaim.email`.
  final String? email;

  /// Whether Apple said anything at all — false on every sign-in but the
  /// first.
  bool get isEmpty =>
      givenName == null && familyName == null && email == null;
}

/// Asks Apple for a credential. Replaced in tests; there is no other reason
/// to touch it.
typedef DwAppleCredentials =
    Future<AuthorizationCredentialAppleID> Function({
      required List<AppleIDAuthorizationScopes> scopes,
      required String nonce,
      WebAuthenticationOptions? webAuthenticationOptions,
    });

/// Sign in with Apple, as the app makes it happen.
abstract final class DwAppleSignIn {
  /// How the credential is asked for. A test replaces it; an app that drives
  /// the Apple flow itself replaces it too, and keeps everything else.
  static DwAppleCredentials credentials = _askApple;

  static Future<AuthorizationCredentialAppleID> _askApple({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
    WebAuthenticationOptions? webAuthenticationOptions,
  }) => SignInWithApple.getAppleIDCredential(
    scopes: scopes,
    nonce: nonce,
    webAuthenticationOptions: webAuthenticationOptions,
  );

  /// Whether this device can sign in with Apple at all — false on an Android
  /// build without `webAuthenticationOptions`, and on desktop.
  static Future<bool> isAvailable() => SignInWithApple.isAvailable();

  /// A nonce for one sign-in: 32 random bytes, base64url.
  ///
  /// Apple embeds what it is given, so the **hash** goes to Apple and the raw
  /// value to our server, which accepts either form and refuses a token
  /// carrying anything else. That is what makes the token this sign-in's and
  /// not a replay of another one.
  static String newNonce() {
    final random = Random.secure();
    return base64Url
        .encode([for (var i = 0; i < 32; i++) random.nextInt(256)])
        .replaceAll('=', '');
  }

  /// The nonce as Apple receives it.
  static String hashedNonce(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();
}

/// Signing in with Apple from the app's `dw`.
extension DwAppleSignInCall on DwFlutterCore {
  /// Runs the Apple flow and signs the session in, answering what the server
  /// said.
  ///
  /// The nonce is made here and checked by the server; Apple's one-time
  /// `authorizationCode` travels with the sign-in, because it is the only
  /// thing that can later revoke this person's tokens when they delete their
  /// account — an app that drops it cannot meet Apple's own rule.
  ///
  /// [registration] is what the project collects at sign-up. Apple's
  /// introduction — the name, once in a lifetime — is handed to
  /// [introduce], whose answer is merged into it, so the project names its
  /// own fields and the framework knows none of them:
  ///
  /// ```dart
  /// await dw.signInWithApple(
  ///   introduce: (person) => {
  ///     if (person.givenName case final name?) RegistrationKeys.firstName: name,
  ///   },
  /// );
  /// ```
  ///
  /// Throws [SignInWithAppleAuthorizationException] when the person cancels —
  /// the app decides whether that is worth a word on the screen.
  Future<DwCallResult<DwAuthSession>> signInWithApple({
    Map<String, String> registration = const {},
    Map<String, String> Function(DwAppleIntroduction person)? introduce,
    List<AppleIDAuthorizationScopes> scopes = const [
      AppleIDAuthorizationScopes.fullName,
      AppleIDAuthorizationScopes.email,
    ],
    WebAuthenticationOptions? webAuthenticationOptions,
  }) async {
    final nonce = DwAppleSignIn.newNonce();
    final credential = await DwAppleSignIn.credentials(
      scopes: scopes,
      nonce: DwAppleSignIn.hashedNonce(nonce),
      webAuthenticationOptions: webAuthenticationOptions,
    );
    final identityToken = credential.identityToken;
    if (identityToken == null) {
      // Apple answered without the one thing the server can check. Nothing to
      // send, and nothing to pretend about.
      throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.failed,
        message: 'Apple returned no identity token',
      );
    }
    final person = DwAppleIntroduction(
      givenName: credential.givenName,
      familyName: credential.familyName,
      email: credential.email,
    );
    final result = await command(
      DwSignInWithProvider(
        provider: DwAuthProvider.apple,
        idToken: identityToken,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
        registration: {
          ...registration,
          if (introduce != null && !person.isEmpty) ...introduce(person),
        },
      ),
    );
    if (result case DwCallOk<DwAuthSession>(:final value)) {
      await signIn(value);
    }
    return result;
  }
}
