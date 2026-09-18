import 'package:dartway_auth_apple/dartway_auth_apple.dart';
import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's half of Sign in with Apple: what reaches the server, and what
/// the app is left holding afterwards.
void main() {
  final protocol = DwWireProtocol(
    dwAuthProvidersProtocolEntries,
    include: DwWireProtocol.core,
  );

  late DwFakeServer server;
  late List<DwSignInWithProvider> received;
  late DwCallResult<DwAuthSession> answer;

  setUp(() {
    received = [];
    answer = const DwCallOk(
      DwAuthSession(id: 7, token: 'session-token', isNewAccount: true),
    );
    server = DwFakeServer(protocol: protocol)
      ..registerToken('session-token', 7)
      ..onCommand<DwSignInWithProvider>((command, call) {
        received.add(command);
        return answer;
      });
    DwAppleSignIn.credentials = _credentials();
  });
  tearDown(() => DwAppleSignIn.credentials = _credentials());

  Future<DwFlutterCore> start() async {
    final core = DwFlutterCore(
      config: DwFlutterConfig(
        appVersion: '1.0.0+1',
        refusalText: (refusal) => refusal.code,
      ),
      protocol: protocol,
      baseUrl: server.baseUrl,
      httpTransport: server.httpTransport,
      liveConnector: server.liveConnector,
      tokenStore: DwMemoryTokenStore(),
      clientOptions: dwFakeClientOptions,
    );
    addTearDown(core.dispose);
    await core.init();
    return core;
  }

  test('sends the token, the raw nonce and the authorization code, and signs '
      'the session in', () async {
    String? nonceGivenToApple;
    DwAppleSignIn.credentials = _credentials(
      onAsked: (nonce) => nonceGivenToApple = nonce,
    );
    final core = await start();

    final result = await core.signInWithApple();

    expect(result, isA<DwCallOk<DwAuthSession>>());
    final sent = received.single;
    expect(sent.provider, DwAuthProvider.apple);
    expect(sent.idToken, 'apple-identity-token');
    expect(
      sent.authorizationCode,
      'apple-authorization-code',
      reason: 'without it the server has nothing to revoke with later',
    );
    expect(sent.nonce, isNotNull);
    expect(
      nonceGivenToApple,
      DwAppleSignIn.hashedNonce(sent.nonce!),
      reason: 'Apple gets the hash, the server gets the raw value',
    );
    expect(core.client.accountId, 7);
  });

  test('a nonce is never reused', () async {
    final core = await start();
    await core.signInWithApple();
    await core.signInWithApple();
    expect(received[0].nonce, isNot(received[1].nonce));
  });

  test("Apple's introduction reaches the project under the project's own "
      'field names, and only when Apple said something', () async {
    final core = await start();
    await core.signInWithApple(
      registration: {'marketing': 'true'},
      introduce: (person) => {
        if (person.givenName case final name?) 'firstName': name,
        if (person.familyName case final name?) 'lastName': name,
      },
    );
    expect(received.single.registration, {
      'marketing': 'true',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
    });

    DwAppleSignIn.credentials = _credentials(introduces: false);
    await core.signInWithApple(
      introduce: (person) => {'firstName': person.givenName ?? 'nobody'},
    );
    expect(
      received.last.registration,
      isEmpty,
      reason: 'a later sign-in tells nothing, and must not overwrite a name',
    );
  });

  test('a refusal is answered as a refusal, and nobody is signed in',
      () async {
    answer = DwCallRefused(
      DwCallRefusal(DwProviderRefusal.credentialRejected, field: 'idToken'),
    );
    final core = await start();
    final result = await core.signInWithApple();
    expect(result, isA<DwCallRefused<DwAuthSession>>());
    expect(core.client.accountId, isNull);
  });

  test('a credential without an identity token is not sent anywhere', () async {
    DwAppleSignIn.credentials = _credentials(withIdentityToken: false);
    final core = await start();
    await expectLater(
      core.signInWithApple(),
      throwsA(isA<SignInWithAppleAuthorizationException>()),
    );
    expect(received, isEmpty);
  });
}

/// Apple as the test plays it.
DwAppleCredentials _credentials({
  void Function(String nonce)? onAsked,
  bool introduces = true,
  bool withIdentityToken = true,
}) =>
    ({
      required List<AppleIDAuthorizationScopes> scopes,
      required String nonce,
      WebAuthenticationOptions? webAuthenticationOptions,
    }) async {
      onAsked?.call(nonce);
      return AuthorizationCredentialAppleID(
        userIdentifier: '000123.abc',
        givenName: introduces ? 'Ada' : null,
        familyName: introduces ? 'Lovelace' : null,
        email: introduces ? 'ada@example.com' : null,
        authorizationCode: 'apple-authorization-code',
        identityToken: withIdentityToken ? 'apple-identity-token' : null,
        state: null,
      );
    };
