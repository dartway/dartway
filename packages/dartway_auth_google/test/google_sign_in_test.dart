import 'package:dartway_auth_google/dartway_auth_google.dart';
import 'package:dartway_auth_providers_shared/dartway_auth_providers_shared.dart';
import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's half of Sign in with Google: the command it makes, and how the
/// app finishes a sign-up its project refused without asking Google again.
void main() {
  late int asked;

  setUp(() {
    asked = 0;
    DwGoogleAuth.reset();
    DwGoogleAuth.authenticate = _account(onAsked: () => asked++);
    // The SDK is not here; the nonce is what `initialize` would have left.
    DwGoogleAuth.rememberNonce('nonce-of-this-run');
  });

  test('makes the command with the token and the nonce this run was '
      'initialised with, and what Google told under the project\'s own field '
      'names', () async {
    final command = await DwGoogleAuth.signInCommand(
      registration: {'marketing': 'false'},
      introduce: (account) => {
        'firstName': ?account.displayName,
        'email': account.email,
      },
    );

    expect(command.provider, DwAuthProvider.google);
    expect(command.idToken, 'google-id-token');
    expect(command.nonce, 'nonce-of-this-run');
    expect(
      command.authorizationCode,
      isNull,
      reason: 'only Apple asks an app to carry one',
    );
    expect(command.registration, {
      'marketing': 'false',
      'firstName': 'Ada Lovelace',
      'email': 'ada@example.com',
    });
    expect(asked, 1);
  });

  test('without initialize there is no nonce, and Google is not asked: the '
      'server would refuse a token whose nonce the app cannot name', () async {
    DwGoogleAuth.reset();
    await expectLater(DwGoogleAuth.signInCommand(), throwsStateError);
    expect(asked, 0);
  });

  test('a sign-in without an ID token makes no command, and says what is '
      'usually missing', () async {
    DwGoogleAuth.authenticate = _account(idToken: null);
    await expectLater(
      DwGoogleAuth.signInCommand(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('serverClientId'),
        ),
      ),
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
      server = DwFakeServer(protocol: protocol)..registerToken('session', 9);
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
          DwAuthSession(id: 9, token: 'session', isNewAccount: false),
        );
      });
      final core = await start();
      await DwGoogleAuth.signInCommand();
      expect(received, isEmpty);
      expect(core.client.accountId, isNull);
    });

    test('a sign-up refused for consent is finished by re-sending the same '
        'token and nonce with the consent keys: Google is asked once '
        '(#374)', () async {
      server.onCommand<DwSignInWithProvider>((command, call) {
        received.add(command);
        return command.registration['terms'] == 'true'
            ? const DwCallOk(
                DwAuthSession(id: 9, token: 'session', isNewAccount: true),
              )
            : DwCallRefused(
                DwCallRefusal(_ClubRefusal.consentsRequired, field: 'consents'),
              );
      });
      final core = await start();

      final signIn = await DwGoogleAuth.signInCommand(
        introduce: (account) => {'firstName': account.displayName!},
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

      expect(asked, 1, reason: 'the token held in state is the one re-sent');
      expect(received, hasLength(2));
      final [first, again] = received;
      expect(again.idToken, first.idToken);
      expect(again.nonce, first.nonce);
      expect(again.registration, {
        'firstName': 'Ada Lovelace',
        'terms': 'true',
      });
      expect(core.client.accountId, 9);
    });
  });
}

enum _ClubRefusal with DwRefusalCodes { consentsRequired }

/// Google as the test plays it.
DwGoogleAuthentication _account({
  String? idToken = 'google-id-token',
  void Function()? onAsked,
}) => () async {
  onAsked?.call();
  return DwGoogleAccount(
    idToken: idToken,
    email: 'ada@example.com',
    displayName: 'Ada Lovelace',
    photoUrl: 'https://example.com/a.png',
  );
};
