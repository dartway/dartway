import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// What Google signed in: the token the server verifies, and what Google
/// told about the person. The server learns the same facts from the token
/// itself; these are here so a project can fill its own sign-up fields.
///
/// A value type rather than the SDK's own account, so that the boundary can
/// be played by a test — the SDK's class cannot be built outside it.
final class DwGoogleAccount {
  const DwGoogleAccount({
    required this.idToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// The OpenID Connect token. `null` means the SDK signed in without one,
  /// which on Android is a missing `serverClientId`.
  final String? idToken;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Signs in with the Google SDK. Replaced in tests.
typedef DwGoogleAuthentication = Future<DwGoogleAccount> Function();

/// Every sign-in the Google SDK reports, whoever started it. Replaced in
/// tests.
typedef DwGoogleSignIns = Stream<DwGoogleAccount> Function();

/// Sign in with Google, as the app sets it up.
///
/// The SDK is initialised **once per run**, and the nonce it carries is fixed
/// at that moment — `GoogleSignIn.initialize(nonce:)` takes it, not
/// `authenticate()`. So the nonce here binds a token to this run of this app,
/// which is what it is for; [initialize] must therefore be called before the
/// first sign-in, in `main` beside the rest of the app's setup.
abstract final class DwGoogleAuth {
  /// How the SDK is asked to sign in. A test replaces it.
  static DwGoogleAuthentication authenticate = _askGoogle;

  static Future<DwGoogleAccount> _askGoogle() async {
    final account = await GoogleSignIn.instance.authenticate();
    return DwGoogleAccount(
      idToken: account.authentication.idToken,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  /// The sign-ins the SDK reports. A test replaces it.
  static DwGoogleSignIns signIns = _googleSignIns;

  static Stream<DwGoogleAccount> _googleSignIns() => GoogleSignIn
      .instance
      .authenticationEvents
      .where((event) => event is GoogleSignInAuthenticationEventSignIn)
      .map((event) {
        final account = (event as GoogleSignInAuthenticationEventSignIn).user;
        return DwGoogleAccount(
          idToken: account.authentication.idToken,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
        );
      });

  static String? _nonce;

  /// The nonce this run signs in with, once [initialize] has run.
  static String? get nonce => _nonce;

  /// Initialises the Google SDK with a fresh nonce, once.
  ///
  /// [clientId] is this platform's client id where the platform needs one in
  /// code (iOS, web); [serverClientId] is the **web** client id of the
  /// server, which is what Android needs to mint an ID token at all. Both are
  /// among the client ids the server is configured with — a token issued for
  /// a client id the server does not know is refused, which is the mistake
  /// this pair of arguments exists to prevent.
  static Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? hostedDomain,
  }) async {
    final nonce = _newNonce();
    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
      nonce: nonce,
      hostedDomain: hostedDomain,
    );
    _nonce = nonce;
  }

  /// Forgets the nonce — for tests, which initialise more than once.
  static void reset() => _nonce = null;

  /// Sets the nonce without touching the SDK: for a test, and for an app that
  /// calls `GoogleSignIn.initialize` itself and must tell us what it used.
  static void rememberNonce(String nonce) => _nonce = nonce;

  /// Runs the Google flow and answers the sign-in command it makes, sending
  /// nothing.
  ///
  /// The app sends it with `dw.command` and keeps the session it answers with
  /// `dw.signIn`, exactly as it does with a code. When the project refuses
  /// the sign-up — `consentsRequired` from its `onExternalAccountCreated` —
  /// the app keeps the command, shows its consent step, and sends
  /// [DwSignInWithProvider.withRegistration] with the consent keys: the same
  /// token and nonce, so Google is not asked again. The token lives about an
  /// hour; `dw.providerCredentialRejected` on a re-send means "ask Google
  /// again".
  ///
  /// [registration] is what the project collects at sign-up; the account
  /// Google signed in is handed to [introduce], whose answer is merged into
  /// it, so the project names its own fields:
  ///
  /// ```dart
  /// final signIn = await DwGoogleAuth.signInCommand(
  ///   introduce: (account) => {
  ///     if (account.displayName case final name?) RegistrationKeys.firstName: name,
  ///   },
  /// );
  /// final result = await dw.command(signIn);
  /// if (result case DwCallOk(value: final session)) await dw.signIn(session);
  /// ```
  ///
  /// Throws [GoogleSignInException] when the person cancels or the SDK
  /// refuses; [StateError] when [initialize] has not run, or Google signed in
  /// without an ID token.
  static Future<DwSignInWithProvider> signInCommand({
    Map<String, String> registration = const {},
    Map<String, String> Function(DwGoogleAccount account)? introduce,
  }) async {
    if (_nonce == null) throw _notInitialized();
    return _command(
      await authenticate(),
      registration: registration,
      introduce: introduce,
    );
  }

  /// The sign-in commands, one per sign-in Google reports, on every
  /// platform — the way an app signs in when the sign-in does not start from
  /// its own call.
  ///
  /// On the web it never does: Google signs a person in only from the button
  /// it draws itself ([DwGoogleSignInButton]), and `authenticate()` — so
  /// [signInCommand] — is not supported there. Everywhere else the SDK
  /// reports here the sign-ins [DwGoogleSignInButton] starts, so an app that
  /// listens here and shows that button needs nothing per platform. Such an
  /// app does not also call [signInCommand]: the SDK reports that sign-in
  /// here as well, and it would be sent twice.
  ///
  /// The listener:
  ///
  /// ```dart
  /// DwGoogleAuth.signInCommands(introduce: …).listen((signIn) async {
  ///   final result = await dw.command(signIn);
  ///   if (result case DwCallOk(value: final session)) await dw.signIn(session);
  /// }, onError: showError);
  /// ```
  ///
  /// [registration] and [introduce] are those of [signInCommand]. Errors
  /// come as events: [GoogleSignInException] when the SDK refuses or the
  /// person cancels (`GoogleSignInExceptionCode.canceled`), [StateError]
  /// for a sign-in made before [initialize] or without an ID token — the
  /// stream goes on after each.
  static Stream<DwSignInWithProvider> signInCommands({
    Map<String, String> registration = const {},
    Map<String, String> Function(DwGoogleAccount account)? introduce,
  }) => signIns().map(
    (account) =>
        _command(account, registration: registration, introduce: introduce),
  );

  static DwSignInWithProvider _command(
    DwGoogleAccount account, {
    required Map<String, String> registration,
    required Map<String, String> Function(DwGoogleAccount account)? introduce,
  }) {
    final nonce = _nonce;
    if (nonce == null) throw _notInitialized();
    final idToken = account.idToken;
    if (idToken == null) {
      // Without an ID token there is nothing the server can verify. It
      // usually means serverClientId is missing on Android.
      throw StateError(
        'Google signed in without an ID token: on Android this is a missing '
        'serverClientId in DwGoogleAuth.initialize()',
      );
    }
    return DwSignInWithProvider(
      provider: DwAuthProvider.google,
      idToken: idToken,
      nonce: nonce,
      registration: {
        ...registration,
        if (introduce != null) ...introduce(account),
      },
    );
  }

  static StateError _notInitialized() => StateError(
    'DwGoogleAuth.initialize() has not run: the Google SDK takes its '
    'nonce at initialisation, and the server refuses a token whose nonce '
    'the app cannot name',
  );

  static String _newNonce() {
    final random = Random.secure();
    return base64Url
        .encode([for (var i = 0; i < 32; i++) random.nextInt(256)])
        .replaceAll('=', '');
  }
}
