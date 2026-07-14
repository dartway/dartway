import 'package:dartway_starter_server/src/dartway/dartway_core.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Limits configured on `DwAuthConfig` — mirrored here so the assertions read
/// against the same numbers the server enforces.
const _maxVerificationAttempts = 5;
const _maxAuthRequestsPerIdentifier = 5;

const _identifier = '+70000000001';
const _knownCode = '123456';
const _wrongCode = '000000';

void main() {
  withServerpod(
    'Given the DartWay auth flow',
    (sessionBuilder, endpoints) {
      late Session session;

      setUp(() async {
        // `withServerpod` builds its own Serverpod and never calls `run`, so
        // DartWay has to be booted here. This is why `initDartwayCore` takes a
        // passwords map rather than the whole Serverpod.
        initDartwayCore(
          passwords: const {
            'dwVerificationCodeSalt': 'test-verification-code-salt',
            'dwAuthKeySalt': 'test-auth-key-salt',
          },
        );

        session = sessionBuilder.build();
        await _wipeAuthTables(session);

        // The example hands out `UserProfile.testVerificationCode` when it is
        // set (the store-reviewer mechanism), so the code is knowable here.
        await UserProfile.db.insertRow(
          session,
          UserProfile(
            userIdentifier: _identifier,
            phone: _identifier,
            firstName: 'Test',
            agreedForMarketingCommunications: false,
            conditionsAcceptedAt: DateTime.now().toUtc(),
            testVerificationCode: _knownCode,
          ),
        );
      });

      tearDown(() async => _wipeAuthTables(session));

      group('verification attempts', () {
        test('the code is accepted and yields an access token', () async {
          final request = await _openLoginRequest(session);
          expect(request.status, DwAuthRequestStatus.pendingVerification);

          final verification = await _verify(session, request, _knownCode);

          expect(verification.failReason, isNull);
          expect(verification.accessToken, isNotNull);
        });

        test('a wrong code is rejected and the request survives', () async {
          final request = await _openLoginRequest(session);

          final verification = await _verify(session, request, _wrongCode);

          expect(
            verification.failReason,
            DwAuthFailReason.invalidVerificationCode,
          );
          expect(await _statusOf(session, request), isNot(
            DwAuthRequestStatus.failed,
          ));
        });

        test(
          'the request is burned after $_maxVerificationAttempts wrong codes, '
          'and the right code no longer works',
          () async {
            final request = await _openLoginRequest(session);

            for (var i = 0; i < _maxVerificationAttempts; i++) {
              await _verify(session, request, _wrongCode);
            }

            expect(await _statusOf(session, request), DwAuthRequestStatus.failed);

            final afterBurn = await _verify(session, request, _knownCode);
            expect(afterBurn.failReason, DwAuthFailReason.tooManyAttempts);
            expect(afterBurn.accessToken, isNull);
          },
        );

        test(
          'parallel guesses cannot outrun the attempt limit',
          () async {
            final request = await _openLoginRequest(session);

            // The regression this guards: the limit used to be a read-then-write
            // decision (count previous attempts, compare, proceed). Fired in
            // parallel under READ COMMITTED, every attempt read "0 previous" and
            // every attempt got to guess — the brute-force protection came off
            // with a bit of concurrency. Twenty guesses at once must still buy
            // no more than the configured five.
            //
            // What matters is how many actually got to *check the code*: an
            // attempt that could not take the lock is refused outright
            // (rateLimited) and learns nothing.
            final verifications = await Future.wait([
              for (var i = 0; i < 20; i++) _verify(session, request, _wrongCode),
            ]);

            final guessesEvaluated = verifications
                .where(
                  (v) => v.failReason == DwAuthFailReason.invalidVerificationCode,
                )
                .length;

            expect(guessesEvaluated, lessThanOrEqualTo(_maxVerificationAttempts));
          },
        );
      });

      group('access token', () {
        test('is single use', () async {
          final request = await _openLoginRequest(session);
          final token = (await _verify(session, request, _knownCode)).accessToken!;

          final first = await _redeem(session, token);
          expect(first.status, DwAuthRequestStatus.verified);

          final second = await _redeem(session, token);
          expect(second.status, DwAuthRequestStatus.failed);
          expect(second.failReason, DwAuthFailReason.invalidAccessToken);
        });

        test(
          'two parallel redemptions sign in exactly once',
          () async {
            final request = await _openLoginRequest(session);
            final token =
                (await _verify(session, request, _knownCode)).accessToken!;

            // Same regression, sharper stakes: both redemptions used to read
            // `verified` and both were signed in, so a "single-use" token handed
            // out two sessions.
            final results = await Future.wait([
              _redeem(session, token),
              _redeem(session, token),
            ]);

            final signedIn = results
                .where((r) => r.status == DwAuthRequestStatus.verified)
                .length;

            expect(signedIn, 1);
          },
        );
      });

      group('request rate limit', () {
        test(
          'parallel requests for one identifier respect the limit',
          () async {
            // Eight at once against a limit of five. Kept below the database
            // connection pool on purpose: more concurrent transactions than the
            // pool can serve would fail on the pool, not on the limit, and the
            // test would be measuring the wrong thing.
            final requests = await Future.wait([
              for (var i = 0; i < 8; i++) _openLoginRequest(session),
            ]);

            final accepted = requests
                .where(
                  (r) => r.status == DwAuthRequestStatus.pendingVerification,
                )
                .length;

            expect(accepted, lessThanOrEqualTo(_maxAuthRequestsPerIdentifier));
            expect(
              requests.any((r) => r.failReason == DwAuthFailReason.rateLimited),
              isTrue,
            );
          },
        );
      });
    },
    runMode: 'test',
    applyMigrations: true,
    // Concurrency cannot be observed inside a single rolled-back transaction:
    // these tests need real, separately committed ones. Cleanup is explicit.
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Runs a model through the real save pipeline: resolve its CRUD config and
/// call `save`, which is exactly what `DwCrudEndpoint.saveModel` does. The
/// configs under test are therefore the ones that run.
Future<T> _save<T extends TableRow>(Session session, T model) async {
  final wrapper = DwModelWrapper(object: model);
  final className = wrapper.dwMappingClassname;

  // The auth models are registered under DartWay's internal API, not the app's
  // default one — the same lookup the CRUD endpoint performs.
  final saveConfig =
      (DwCore.instance.getCrudConfig(className) ??
              DwCore.instance.getCrudConfig(
                className,
                api: DwCoreConst.dartwayInternalApi,
              ))
          ?.saveConfig;

  if (saveConfig == null) {
    throw StateError('No save config for $className');
  }

  final response = await saveConfig.save(session, model);
  final saved = response.value?.object;

  if (saved == null) {
    throw StateError('save failed: ${response.error ?? 'no model returned'}');
  }
  return saved as T;
}

Future<DwAuthRequest> _openLoginRequest(Session session) => _save(
  session,
  DwAuthRequest(
    createdAt: DateTime.now().toUtc(),
    requestType: DwAuthRequestType.login,
    authProvider: DwAuthProvider.phone,
    userIdentifier: _identifier,
    status: DwAuthRequestStatus.created,
  ),
);

Future<DwAuthVerification> _verify(
  Session session,
  DwAuthRequest request,
  String code,
) => _save(
  session,
  DwAuthVerification(
    dwAuthRequestId: request.id!,
    createdAt: DateTime.now().toUtc(),
    verificationCode: code,
  ),
);

/// Presents an access token as a fresh auth request — how a client redeems it.
Future<DwAuthRequest> _redeem(Session session, String accessToken) => _save(
  session,
  DwAuthRequest(
    createdAt: DateTime.now().toUtc(),
    requestType: DwAuthRequestType.login,
    authProvider: DwAuthProvider.phone,
    userIdentifier: _identifier,
    accessToken: accessToken,
    status: DwAuthRequestStatus.created,
  ),
);

Future<DwAuthRequestStatus> _statusOf(
  Session session,
  DwAuthRequest request,
) async {
  final fresh = await DwAuthRequest.db.findById(session, request.id!);
  return fresh!.status;
}

Future<void> _wipeAuthTables(Session session) async {
  await DwAuthVerification.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await DwAuthRequest.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await DwAuthKey.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await UserProfile.db.deleteWhere(session, where: (t) => Constant.bool(true));
}
