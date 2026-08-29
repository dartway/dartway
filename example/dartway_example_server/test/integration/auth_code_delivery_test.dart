import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _identifier = '+70000000042';

/// The core this suite booted. The example app keeps its own `dw` handle, set
/// by `initDartwayCore`; these tests build the core themselves to control the
/// sender, so they hold their own.
late DwCore<UserProfile> _dw;

/// The sender the booted config delegates to. `DwCore` is a singleton and
/// refuses a second initialisation, so a test swaps the sender here rather than
/// by rebooting the core.
late Future<void> Function(String verificationCode) _sendVerificationCode;

/// What the sign-in response says when delivery fails.
///
/// Sending the code is the only thing the caller asked for, so a delivery that
/// did not happen has to travel back with the response. For a long time it did
/// not: the send hung in `afterSaveSideEffects`, which nobody awaits, so the
/// screen said "code sent" for a code nobody sent.
void main() {
  withServerpod(
    'Given a verification code sender',
    (sessionBuilder, endpoints) {
      late Session session;

      setUpAll(_bootDartway);

      setUp(() async {
        session = sessionBuilder.build();
        await _wipeAuthTables(session);
        await UserProfile.db.insertRow(
          session,
          UserProfile(
            userIdentifier: _identifier,
            phone: _identifier,
            firstName: 'Delivery',
            agreedForMarketingCommunications: false,
            conditionsAcceptedAt: DateTime.now().toUtc(),
          ),
        );
      });

      tearDown(() async => _wipeAuthTables(session));

      test('one that delivers leaves the sign-in ok', () async {
        var sent = 0;
        _sendVerificationCode = (code) async => sent++;

        final response = await _openLoginRequest(session);

        expect(response.isOk, isTrue);
        expect(sent, 1);
      });

      test(
        'one that throws turns the sign-in into an error response',
        () async {
          _sendVerificationCode = (code) async =>
              throw StateError('550 sender address is not verified');

          final response = await _openLoginRequest(session);

          expect(response.isOk, isFalse);
        },
      );

      test('the failure message is one a sign-in screen can show', () async {
        _sendVerificationCode = (code) async =>
            throw StateError('550 sender address is not verified');

        final response = await _openLoginRequest(session);

        // Not the generic "Unexpected error while handling the saveModel
        // request for DwAuthRequest" a thrown hook produces, and not the
        // provider's complaint either — that one names the delivery
        // configuration, and this endpoint answers anonymous callers.
        expect(response.error, isNotNull);
        expect(response.error, isNot(contains('Unexpected error')));
        expect(response.error, isNot(contains('DwAuthRequest')));
        expect(response.error, isNot(contains('550')));
        expect(response.error, contains('verification code'));
        expect(response.error, contains('try again'));
      });

      test(
        'the request stays saved after a failed delivery, and the retry issues '
        'a fresh code',
        () async {
          // The documented trade: the transaction commits before delivery is
          // attempted, so the row survives an error response. Harmless because
          // the retry mints a new code — asserted here rather than left to be
          // inferred by the next reader.
          _sendVerificationCode = (code) async =>
              throw StateError('550 sender address is not verified');

          final failed = await _openLoginRequest(session);
          expect(failed.isOk, isFalse);

          final afterFailure = await DwAuthRequest.db.find(session);
          expect(afterFailure, hasLength(1));
          expect(afterFailure.single.verificationHash, isNotNull);

          final delivered = <String>[];
          _sendVerificationCode = (code) async => delivered.add(code);

          final retried = await _openLoginRequest(session);

          expect(retried.isOk, isTrue);
          expect(delivered, hasLength(1));

          final stored = await DwAuthRequest.db.find(session);
          expect(stored, hasLength(2));
          expect(
            stored.map((request) => request.verificationHash).toSet(),
            hasLength(2),
            reason: 'the retry must not reuse the undelivered code',
          );
        },
      );
    },
    runMode: 'test',
    applyMigrations: true,
    // The auth flow commits its own transactions; cleanup is explicit.
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Boots DartWay with a sender that delegates to [_sendVerificationCode], in
/// place of the example's console logger. `withServerpod` never calls `run`, so
/// the core is initialised here.
void _bootDartway() {
  _dw = DwCore.init<UserProfile>(
    userProfileTable: UserProfile.t,
    crudConfigurations: const [],
    dtoConfigurations: const [],
    channelConfigurations: const [],
    userProfileConstructor: (session, {required registrationRequest}) async =>
        throw UnsupportedError('Registration is outside this test suite'),
    dwAlerts: DwAlerts.init(),
    dwAuthConfig: DwAuthConfig<UserProfile>(
      passwords: const {
        'dwVerificationCodeSalt': 'test-verification-code-salt',
        'dwAuthKeySalt': 'test-auth-key-salt',
      },
      // The same form the example itself states in `initDartwayCore`: a test
      // config that folds differently from the app under test is testing
      // something the app does not do.
      normalizeIdentifier: DwIdentifierForm.folded,
      sendVerificationCodeMethod:
          (
            session, {
            required DwAuthRequest verificationRequest,
            required String verificationCode,
          }) => _sendVerificationCode(verificationCode),
    ),
  );
}

/// Opens a login request through the real save pipeline — the same config
/// lookup `DwCrudEndpoint.saveModel` performs — and hands back the response
/// rather than the model, because the response is what is under test.
Future<DwApiResponse<DwModelWrapper>> _openLoginRequest(Session session) async {
  final model = DwAuthRequest(
    createdAt: DateTime.now().toUtc(),
    requestType: DwAuthRequestType.login,
    authProvider: DwAuthProvider.phone,
    userIdentifier: _identifier,
    status: DwAuthRequestStatus.created,
  );
  final className = DwModelWrapper(object: model).dwMappingClassname;

  // The auth models live under DartWay's internal API, not the app's default.
  final saveConfig =
      (_dw.getCrudConfig(className) ??
              _dw.getCrudConfig(className, api: DwCoreConst.dartwayInternalApi))
          ?.saveConfig;

  if (saveConfig == null) {
    throw StateError('No save config for $className');
  }

  return saveConfig.save(session, model);
}

Future<void> _wipeAuthTables(Session session) async {
  await DwAuthVerification.db.deleteWhere(
    session,
    where: (t) => Constant.bool(true),
  );
  await DwAuthRequest.db.deleteWhere(
    session,
    where: (t) => Constant.bool(true),
  );
  await DwAuthKey.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await UserProfile.db.deleteWhere(session, where: (t) => Constant.bool(true));
}
