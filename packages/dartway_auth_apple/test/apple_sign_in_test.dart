import 'package:dartway_auth_apple/dartway_auth_apple.dart';
import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's half of Sign in with Apple: the command it makes, and how the
/// app finishes a sign-up its project refused without asking Apple again —
/// which would lose the name Apple tells only once.
void main() {
  late List<String> noncesGivenToApple;

  setUp(() {
    noncesGivenToApple = [];
    DwAppleSignIn.credentials = _credentials(onAsked: noncesGivenToApple.add);
  });
  tearDown(() => DwAppleSignIn.credentials = _credentials());

  test('makes the command with the token, the raw nonce and the '
      'authorization code', () async {
    final command = await DwAppleSignIn.signInCommand();

    expect(command.provider, DwAuthProvider.apple);
    expect(command.idToken, 'apple-identity-token');
    expect(
      command.authorizationCode,
      'apple-authorization-code',
      reason: 'without it the server has nothing to revoke with later',
    );
    expect(command.nonce, isNotNull);
    expect(
      noncesGivenToApple.single,
      DwAppleSignIn.hashedNonce(command.nonce!),
      reason: 'Apple gets the hash, the server gets the raw value',
    );
  });

  test('a nonce is never reused across two calls', () async {
    final first = await DwAppleSignIn.signInCommand();
    final second = await DwAppleSignIn.signInCommand();
    expect(first.nonce, isNot(second.nonce));
    expect(noncesGivenToApple[0], isNot(noncesGivenToApple[1]));
  });

  test("Apple's introduction reaches the project under the project's own "
      'field names, and only when Apple said something', () async {
    final command = await DwAppleSignIn.signInCommand(
      registration: {'marketing': 'true'},
      introduce: (person) => {
        'firstName': ?person.givenName,
        'lastName': ?person.familyName,
      },
    );
    expect(command.registration, {
      'marketing': 'true',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
    });

    DwAppleSignIn.credentials = _credentials(introduces: false);
    final later = await DwAppleSignIn.signInCommand(
      introduce: (person) => {'firstName': person.givenName ?? 'nobody'},
    );
    expect(
      later.registration,
      isEmpty,
      reason: 'a later sign-in tells nothing, and must not overwrite a name',
    );
  });

  test('a credential without an identity token makes no command', () async {
    DwAppleSignIn.credentials = _credentials(withIdentityToken: false);
    await expectLater(
      DwAppleSignIn.signInCommand(),
      throwsA(isA<SignInWithAppleAuthorizationException>()),
    );
  });

  group('sent through dw', () {
    final protocol = DwWireProtocol(
      dwAuthProvidersProtocolEntries,
      include: DwWireProtocol.core,
    );

    late DwFakeServer server;
    late List<DwSignInWithProvider> received;

    setUp(() {
      received = [];
      server = DwFakeServer(protocol: protocol)..registerToken('session', 7);
    });

    Future<DwFlutterCore> start() async {
      final core = DwFlutterCore(
        config: DwFlutterConfig(
          appVersion: '1.0.0+1',
          refusalText: (refusal) => refusal.code,
          readLoadingBuilder: (context) => const SizedBox(),
          readFailedBuilder: (context, error, retry) => const SizedBox(),
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

    test('making the command sends nothing', () async {
      server.onCommand<DwSignInWithProvider>((command, call) {
        received.add(command);
        return const DwCallOk(
          DwAuthSession(id: 7, token: 'session', isNewAccount: false),
        );
      });
      final core = await start();
      await DwAppleSignIn.signInCommand();
      expect(received, isEmpty);
      expect(core.client.accountId, isNull);
    });

    test('a sign-up refused for consent is finished by re-sending the same '
        'token, nonce, code and introduced name with the consent keys: Apple '
        'is asked once (#374)', () async {
      server.onCommand<DwSignInWithProvider>((command, call) {
        received.add(command);
        return command.registration['terms'] == 'true'
            ? const DwCallOk(
                DwAuthSession(id: 7, token: 'session', isNewAccount: true),
              )
            : DwCallRefused(
                DwCallRefusal(_ClubRefusal.consentsRequired, field: 'consents'),
              );
      });
      final core = await start();

      final signIn = await DwAppleSignIn.signInCommand(
        introduce: (person) => {'firstName': ?person.givenName},
      );
      final refused = await core.command(signIn);
      expect(
        refused,
        isA<DwCallRefused<DwAuthSession>>().having(
          (r) => r.refusal.code,
          'code',
          'consentsRequired',
        ),
      );
      expect(core.client.accountId, isNull);

      final result = await core.command(
        signIn.withRegistration({'terms': 'true'}),
      );
      if (result case DwCallOk(value: final session)) {
        await core.signIn(session);
      }

      expect(
        noncesGivenToApple,
        hasLength(1),
        reason: 'a second run would lose the name for good',
      );
      expect(received, hasLength(2));
      final [first, again] = received;
      expect(again.idToken, first.idToken);
      expect(again.nonce, first.nonce);
      expect(again.authorizationCode, 'apple-authorization-code');
      expect(again.registration, {'firstName': 'Ada', 'terms': 'true'});
      expect(core.client.accountId, 7);
    });
  });
}

enum _ClubRefusal with DwRefusalCodes { consentsRequired }

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
