import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import 'test_tools/serverpod_test_tools.dart';

/// An auth key has no expiry and nothing deletes it on its own, so ending a
/// user's access is something the server has to do on purpose. These tests
/// cover both ways it happens: [DwAuth.revokeAuthKeys] when the app knows the
/// account is over, and [DwOrphanedAuthKeyCleanup] when nobody said so.
void main() {
  // Before anything registers: a missing database is knowable here, and
  // `withServerpod` silences the output that would have said so.
  requireTestDatabase();

  withServerpod('Given auth keys in the database', (sessionBuilder, endpoints) {
    late Session session;
    late int userProfileId;
    late int otherUserProfileId;

    setUp(() async {
      initDartwayCore(
        passwords: const {
          'dwVerificationCodeSalt': 'test-verification-code-salt',
          'dwAuthKeySalt': 'test-auth-key-salt',
        },
      );

      session = sessionBuilder.build();
      await _wipeAuthTables(session);

      userProfileId = await _createProfile(session, '+70000000001');
      otherUserProfileId = await _createProfile(session, '+70000000002');
    });

    tearDown(() async => _wipeAuthTables(session));

    group('revokeAuthKeys', () {
      test('deletes every key the user holds', () async {
        // Two, because signing in on a second device is the normal case and
        // revoking one device's key is not what this method is for.
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);

        final revoked = await dw.auth!.revokeAuthKeys(
          session,
          userProfileId: userProfileId,
        );

        expect(revoked, 2);
        expect(await _keyCountFor(session, userProfileId), 0);
      });

      test('leaves other users signed in', () async {
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);
        await dw.auth!.signInUser(
          session,
          otherUserProfileId,
          updateSession: false,
        );

        await dw.auth!.revokeAuthKeys(session, userProfileId: userProfileId);

        expect(await _keyCountFor(session, otherUserProfileId), 1);
      });

      test('leaves nothing behind for the token to match against', () async {
        // What makes revocation immediate: the client's token is
        // `${id}:${key}`, the server stores only a hash, and
        // `dwAuthenticationHandler` looks the row up on *every* request. There
        // is no signed token that can outlive the row it points at.
        //
        // The handler itself is not driven here on purpose: it opens its own
        // session, and `withServerpod` keeps test data in a transaction that a
        // second session cannot see — it would report "not authenticated" for
        // a key that is plainly there, and prove nothing either way.
        final authKey = await dw.auth!.signInUser(
          session,
          userProfileId,
          updateSession: false,
        );

        expect(await DwAuthKey.db.findById(session, authKey.id!), isNotNull);

        await dw.auth!.revokeAuthKeys(session, userProfileId: userProfileId);

        expect(await DwAuthKey.db.findById(session, authKey.id!), isNull);
      });

      test('revoking a user with no keys is not an error', () async {
        expect(
          await dw.auth!.revokeAuthKeys(session, userProfileId: userProfileId),
          0,
        );
      });
    });

    group('DwOrphanedAuthKeyCleanup', () {
      test('deletes keys whose profile is gone', () async {
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);

        // Deleting the profile without revoking — the mistake the job exists
        // for. Until 0.3.0 this token kept working forever.
        await UserProfile.db.deleteWhere(
          session,
          where: (t) => t.id.equals(userProfileId),
        );

        await DwOrphanedAuthKeyCleanup().run(session);

        expect(await _keyCountFor(session, userProfileId), 0);
      });

      test('leaves keys of existing profiles alone', () async {
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);
        await dw.auth!.signInUser(
          session,
          otherUserProfileId,
          updateSession: false,
        );

        await UserProfile.db.deleteWhere(
          session,
          where: (t) => t.id.equals(userProfileId),
        );

        await DwOrphanedAuthKeyCleanup().run(session);

        expect(await _keyCountFor(session, otherUserProfileId), 1);
      });

      test('does nothing when every profile is still there', () async {
        await dw.auth!.signInUser(session, userProfileId, updateSession: false);

        await DwOrphanedAuthKeyCleanup().run(session);

        expect(await _keyCountFor(session, userProfileId), 1);
      });
    });
  }, testServerOutputMode: testServerOutputMode);
}

Future<int> _createProfile(Session session, String identifier) async {
  final profile = await UserProfile.db.insertRow(
    session,
    UserProfile(
      userIdentifier: identifier,
      phone: identifier,
      firstName: 'Test',
      agreedForMarketingCommunications: false,
      conditionsAcceptedAt: DateTime.now().toUtc(),
    ),
  );
  return profile.id!;
}

Future<int> _keyCountFor(Session session, int userProfileId) =>
    DwAuthKey.db.count(session, where: (t) => t.userId.equals(userProfileId));

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
