import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _identifier = '+70000000002';
const _password = 'correct-horse-battery-staple';
const _wrongPassword = 'incorrect-horse';

/// Stands in for the backend an app migrates off: an unsalted SHA-256 digest,
/// tagged so it can be told apart from bcrypt. Naive on purpose — that is what
/// a legacy format usually is, and why users must be moved off it.
class _LegacySha256Verifier extends DwPasswordVerifier {
  const _LegacySha256Verifier();

  static String hashOf(String password) =>
      'sha256\$${sha256.convert(utf8.encode(password))}';

  @override
  bool matches(String storedHash) => storedHash.startsWith('sha256\$');

  @override
  Future<bool> verify(String password, String storedHash) async =>
      hashOf(password) == storedHash;
}

void main() {
  withServerpod(
    'Given a user whose password was hashed by the old backend',
    (sessionBuilder, endpoints) {
      late Session session;
      late int userId;

      setUp(() async {
        initDartwayCore(
          passwords: const {
            'dwVerificationCodeSalt': 'test-verification-code-salt',
            'dwAuthKeySalt': 'test-auth-key-salt',
          },
          legacyPasswordVerifiers: const [_LegacySha256Verifier()],
        );

        session = sessionBuilder.build();
        await _wipeTables(session);

        final profile = await UserProfile.db.insertRow(
          session,
          UserProfile(
            userIdentifier: _identifier,
            phone: _identifier,
            firstName: 'Migrated',
            agreedForMarketingCommunications: false,
            conditionsAcceptedAt: DateTime.now().toUtc(),
          ),
        );
        userId = profile.id!;
      });

      tearDown(() async => _wipeTables(session));

      test('the old password signs them in', () async {
        await _seedHash(session, userId, _LegacySha256Verifier.hashOf(_password));

        final request = await _signIn(session, _password);

        expect(request.status, DwAuthRequestStatus.verified);
      });

      test('signing in rewrites the hash in bcrypt — once, and for good', () async {
        await _seedHash(session, userId, _LegacySha256Verifier.hashOf(_password));

        await _signIn(session, _password);

        // The plaintext exists only during a sign-in, so this is the only moment
        // the hash could be migrated at all.
        final stored = await _storedHash(session, userId);
        expect(stored, startsWith(r'$2'), reason: 'the hash should now be bcrypt');

        // And the upgraded row is readable by the active hasher: the second
        // sign-in never touches the legacy path.
        final again = await _signIn(session, _password);
        expect(again.status, DwAuthRequestStatus.verified);
      });

      test('a wrong password is rejected and the hash is left alone', () async {
        final legacyHash = _LegacySha256Verifier.hashOf(_password);
        await _seedHash(session, userId, legacyHash);

        final request = await _signIn(session, _wrongPassword);

        expect(request.status, DwAuthRequestStatus.failed);
        expect(request.failReason, DwAuthFailReason.invalidPassword);
        expect(await _storedHash(session, userId), legacyHash);
      });

      test('a hash nobody can read fails the login instead of crashing it', () async {
        // The format of some third system, never registered as a verifier. Before
        // the strategies existed this reached BCrypt.checkpw and threw, turning a
        // failed login into a 500.
        await _seedHash(session, userId, 'argon2id\$v=19\$m=65536,t=3,p=4\$deadbeef');

        final request = await _signIn(session, _password);

        expect(request.status, DwAuthRequestStatus.failed);
        expect(request.failReason, DwAuthFailReason.invalidPassword);
      });

      test('a bcrypt password still works — the default path is untouched', () async {
        await DwCore.instance.auth!.setUserPassword(
          session,
          userId: userId,
          newPassword: _password,
        );

        final request = await _signIn(session, _password);

        expect(request.status, DwAuthRequestStatus.verified);
        expect(await _storedHash(session, userId), startsWith(r'$2'));
      });
    },
    runMode: 'test',
    applyMigrations: true,
    // The upgrade is a real write during a real sign-in: it cannot be observed
    // inside a transaction that is rolled back afterwards.
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Seeds a hash the way a migration does: import what you cannot reverse.
Future<void> _seedHash(Session session, int userId, String hash) =>
    DwCore.instance.auth!.setUserPassword(
      session,
      userId: userId,
      newPasswordHash: hash,
    );

Future<String> _storedHash(Session session, int userId) async {
  final row = await DwUserPassword.db.findFirstRow(
    session,
    where: (t) => t.userId.equals(userId),
  );
  return row!.passwordHash;
}

/// Presents a password the way a client does: an auth request through the real
/// save pipeline, which is what resolves the CRUD config and runs verification.
Future<DwAuthRequest> _signIn(Session session, String password) => _save(
  session,
  DwAuthRequest(
    createdAt: DateTime.now().toUtc(),
    requestType: DwAuthRequestType.login,
    authProvider: DwAuthProvider.phone,
    userIdentifier: _identifier,
    password: password,
    status: DwAuthRequestStatus.created,
  ),
);

/// Runs a model through the real save pipeline — exactly what
/// `DwCrudEndpoint.saveModel` does, so the config under test is the one that runs.
Future<T> _save<T extends TableRow>(Session session, T model) async {
  final wrapper = DwModelWrapper(object: model);
  final className = wrapper.dwMappingClassname;

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

Future<void> _wipeTables(Session session) async {
  await DwUserPassword.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await DwAuthKey.db.deleteWhere(session, where: (t) => Constant.bool(true));
  await UserProfile.db.deleteWhere(session, where: (t) => Constant.bool(true));
}
