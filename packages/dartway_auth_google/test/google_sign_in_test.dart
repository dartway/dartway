import 'package:dartway_auth_google/dartway_auth_google.dart';
import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's half of Sign in with Google: what reaches the server, and what
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
      DwAuthSession(id: 9, token: 'session-token', isNewAccount: false),
    );
    server = DwFakeServer(protocol: protocol)
      ..registerToken('session-token', 9)
      ..onCommand<DwSignInWithProvider>((command, call) {
        received.add(command);
        return answer;
      });
    DwGoogleAuth.reset();
    DwGoogleAuth.authenticate = _account();
    // The SDK is not here; the nonce is what `initialize` would have left.
    DwGoogleAuth.rememberNonce('nonce-of-this-run');
  });

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

  test('sends the token with the nonce this run was initialised with, and '
      'signs the session in', () async {
    final core = await start();
    final result = await core.signInWithGoogle();

    expect(result, isA<DwCallOk<DwAuthSession>>());
    final sent = received.single;
    expect(sent.provider, DwAuthProvider.google);
    expect(sent.idToken, 'google-id-token');
    expect(sent.nonce, 'nonce-of-this-run');
    expect(
      sent.authorizationCode,
      isNull,
      reason: 'only Apple asks an app to carry one',
    );
    expect(core.client.accountId, 9);
  });

  test('what Google told reaches the project under the project\'s own field '
      'names', () async {
    final core = await start();
    await core.signInWithGoogle(
      registration: {'marketing': 'false'},
      introduce: (account) => {
        if (account.displayName case final name?) 'firstName': name,
        'email': account.email,
      },
    );
    expect(received.single.registration, {
      'marketing': 'false',
      'firstName': 'Ada Lovelace',
      'email': 'ada@example.com',
    });
  });

  test('without initialize there is no nonce, and nothing is sent: the '
      'server would refuse a token whose nonce the app cannot name', () async {
    DwGoogleAuth.reset();
    final core = await start();
    await expectLater(core.signInWithGoogle(), throwsStateError);
    expect(received, isEmpty);
  });

  test('a sign-in without an ID token is not sent anywhere, and says what is '
      'usually missing', () async {
    DwGoogleAuth.authenticate = _account(idToken: null);
    final core = await start();
    await expectLater(
      core.signInWithGoogle(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('serverClientId'),
        ),
      ),
    );
    expect(received, isEmpty);
  });

  test('a refusal is answered as a refusal, and nobody is signed in',
      () async {
    answer = DwCallRefused(
      DwCallRefusal(DwProviderRefusal.credentialRejected, field: 'idToken'),
    );
    final core = await start();
    expect(
      await core.signInWithGoogle(),
      isA<DwCallRefused<DwAuthSession>>(),
    );
    expect(core.client.accountId, isNull);
  });
}

/// Google as the test plays it.
DwGoogleAuthentication _account({String? idToken = 'google-id-token'}) =>
    () async => DwGoogleAccount(
      idToken: idToken,
      email: 'ada@example.com',
      displayName: 'Ada Lovelace',
      photoUrl: 'https://example.com/a.png',
    );
