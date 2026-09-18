import 'dart:io';

import 'package:dartway_auth_providers_server/dartway_auth_providers_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestAnswer, DwTestDatabase, DwTestServer;
import 'package:test/test.dart';

import 'fixtures/provider_tokens.dart';
import 'support/fake_key_set.dart';

/// Signing in with a provider's token against a real server and database:
/// what the account becomes, what the project is told, and what a token that
/// does not hold up gets instead.
void main() {
  late FakeKeySet appleKeys;
  late _ProviderHarness club;

  setUp(() async {
    appleKeys = FakeKeySet(appleJwks);
    club = await _ProviderHarness.start(appleKeys);
  });
  tearDown(() => club.stop());

  Future<DwTestAnswer> signIn({
    DwAuthProvider provider = DwAuthProvider.apple,
    String token = appleToken,
    String? nonce = 'deadbeef',
    Map<String, String> registration = const {},
  }) => club.send(
    DwSignInWithProvider(
      provider: provider,
      idToken: token,
      nonce: nonce,
      registration: registration,
    ),
  );

  test('a token the provider signed makes an account, and the same token '
      'again signs into it', () async {
    final first = await signIn(registration: {'firstName': 'Ada'});
    final session = first.value(_signIn());
    expect(session.isNewAccount, isTrue);
    expect(session.token, isNotEmpty);

    // The project was told, once, with the claims the provider signed.
    final creation = club.created.single;
    expect(creation.accountId, session.id);
    expect(creation.provider, 'apple');
    expect(creation.subject, '000123.abc');
    expect(creation.registration, {
      'firstName': 'Ada',
      DwProviderClaim.email: 'ada@example.com',
      DwProviderClaim.emailVerified: 'true',
    });
    expect(
      await club.db.query(
        'SELECT kind, value FROM dw_identity WHERE account_id = @id',
        params: {'id': session.id},
      ),
      [
        isA<DwResultRow>()
            .having((r) => r.get<String>('kind'), 'kind', 'apple')
            .having((r) => r.get<String>('value'), 'value', '000123.abc'),
      ],
    );

    final again = await signIn();
    final second = again.value(_signIn());
    expect(second.id, session.id, reason: 'the same person, the same account');
    expect(second.isNewAccount, isFalse);
    expect(
      second.token,
      isNot(session.token),
      reason: 'a sign-in mints its own key; the first device keeps its own',
    );
    expect(club.created, hasLength(1));
  });

  test('the session it answers is a session: it signs calls, and the account '
      'it names is the one that was made', () async {
    final session = (await signIn()).value(_signIn());
    final signedOut = await club.send(const DwSignOut(), token: session.token);
    expect(signedOut.status, 200);
    expect(
      (await club.send(const DwSignOut(), token: session.token)).status,
      401,
      reason: 'the key it answered is a real one, and it was just revoked',
    );
  });

  test('an app may not write the server\'s own claims: what it sends under '
      'the dw. prefix is dropped', () async {
    await signIn(
      registration: {
        DwProviderClaim.email: 'boss@example.com',
        'firstName': 'Ada',
      },
    );
    expect(
      club.created.single.registration[DwProviderClaim.email],
      'ada@example.com',
      reason: 'the e-mail is the provider\'s, never the app\'s',
    );
  });

  test('a token that does not hold up is refused, and nothing is created',
      () async {
    final refused = await signIn(token: appleTokenUnsigned);
    expect(refused.refusal.code, DwProviderRefusal.credentialRejected.code);
    expect(refused.refusal.field, 'idToken');
    expect(club.created, isEmpty);
    expect(
      await club.db.query('SELECT 1 FROM dw_account'),
      isEmpty,
      reason: 'a refused sign-in leaves no account behind',
    );
  });

  test('a provider this server does not configure is a door it does not have',
      () async {
    final refused = await signIn(
      provider: DwAuthProvider.google,
      token: googleToken,
      nonce: null,
    );
    expect(refused.refusal.code, DwCoreRefusal.forbidden.code);
    expect(refused.refusal.field, 'provider');
  });

  test('a provider that cannot be reached is told apart from a bad token: '
      'the app may try again', () async {
    appleKeys.failWith = 'no route to host';
    final refused = await signIn();
    expect(refused.refusal.code, DwProviderRefusal.providerUnreachable.code);
    expect(refused.refusal.field, 'provider');
    expect(club.created, isEmpty);
  });

  test('a repeat of the very same call mints a new session rather than '
      'replaying the stored one', () async {
    final key = 'idem-${DateTime.now().microsecondsSinceEpoch}';
    final first = await club.send(_signIn(), key: key);
    final second = await club.send(_signIn(), key: key);
    final one = first.value(_signIn());
    final two = second.value(_signIn());
    expect(two.id, one.id);
    expect(
      two.token,
      isNot(one.token),
      reason: 'a token is a secret; a stored answer would hand it out twice',
    );
  });
}

/// The call the acceptance tests make, and the shape its answer is read in.
DwSignInWithProvider _signIn() => const DwSignInWithProvider(
  provider: DwAuthProvider.apple,
  idToken: appleToken,
  nonce: 'deadbeef',
);

typedef _Creation = ({
  int accountId,
  String provider,
  String subject,
  Map<String, String> registration,
});

/// A server with Sign in with Apple configured and nothing else, on its own
/// throwaway database.
final class _ProviderHarness {
  _ProviderHarness._(this._database, this.server);

  final DwTestDatabase _database;
  final DwTestServer server;
  final List<_Creation> created = [];

  static Future<_ProviderHarness> start(FakeKeySet appleKeys) async {
    final DwDatabaseConfig admin;
    try {
      admin = DwDatabaseConfig.fromEnvironment(Platform.environment);
    } on ArgumentError catch (error) {
      throw StateError(
        'The dartway_auth_providers_server suites need a Postgres server: set '
        'DW_DATABASE_HOST, _PORT, _NAME, _USER, _PASSWORD and _SSL. ($error)',
      );
    }
    final database = await DwTestDatabase.create(
      admin: admin,
      prefix: 'providers_test',
    );
    late final _ProviderHarness harness;
    try {
      final server = await DwTestServer.start(
        DwAppServer(
          protocol: DwWireProtocol(
            dwAuthProvidersProtocolEntries,
            include: DwWireProtocol.core,
          ),
          migrations: const [],
          handlers: const [],
          database: database.config,
          auth: DwAuthConfig(
            normalize: (kind, raw) => raw.trim().toLowerCase(),
            deliverCode: (ctx, kind, identifier, code) async {},
            onExternalAccountCreated:
                (ctx, accountId, provider, subject, registration) async {
                  harness.created.add((
                    accountId: accountId,
                    provider: provider,
                    subject: subject,
                    registration: registration,
                  ));
                },
          ),
          modules: [
            DwSignInProvidersModule([
              DwAppleSignIn(
                clientIds: const ['com.club.app'],
                fetchKeys: appleKeys.fetch,
              ),
            ]),
          ],
          logger: const _SilentLogger(),
        ),
      );
      return harness = _ProviderHarness._(database, server);
    } catch (_) {
      await database.drop();
      rethrow;
    }
  }

  DwDatabaseHandle get db => server.db;

  Future<DwTestAnswer> send(
    DwServerCall<Object?> call, {
    String? token,
    String? key,
  }) async {
    final caller = server.caller(token: token);
    try {
      return await caller.call(call, key: key);
    } finally {
      caller.close();
    }
  }

  Future<void> stop() async {
    await server.stop();
    await _database.drop();
  }
}

final class _SilentLogger implements DwServerLogger {
  const _SilentLogger();

  @override
  void log(
    DwLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (Platform.environment['DW_TEST_LOG'] != null) {
      stderr.writeln('${level.name} $message${error == null ? '' : ': $error'}');
    }
  }

  @override
  DwServerLogger scoped(String scope) => this;
}
