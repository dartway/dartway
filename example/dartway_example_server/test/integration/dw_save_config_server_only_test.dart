import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _testIdentifierPrefix = 'dw_server_only_test_';

/// `scope=serverOnly` has to hold in both directions, and only a real database
/// can show the second one.
///
/// Outbound: the column never reaches the client. Inbound: a save from that
/// client does not blank it. The two are the same mechanism seen from either
/// end — the client class has no such field, so the value is neither sent to it
/// nor sent back by it, and an update that writes the whole row would therefore
/// write `null` over it.
///
/// `UserProfile.testVerificationCode` is the fixture because it is a real
/// `serverOnly` column on a real table, and because getting it wrong is not
/// abstract: it is the fixed sign-in code for reviewer and demo accounts.
/// Leaking it hands over a login; blanking it locks those accounts out.
void main() {
  withServerpod('DwSaveConfig and scope=serverOnly', (
    sessionBuilder,
    endpoints,
  ) {
    setUp(() => _clearTestProfiles(sessionBuilder.build()));
    tearDown(() => _clearTestProfiles(sessionBuilder.build()));

    /// A stored profile that has a server-side code, so a save has something to
    /// destroy and a response has something to leak.
    Future<UserProfile> storedProfile(
      Session session, {
      required String suffix,
      String? testVerificationCode = 'THE-CODE',
    }) => UserProfile.db.insertRow(
      session,
      UserProfile(
        userIdentifier: '$_testIdentifierPrefix$suffix',
        phone: '$_testIdentifierPrefix$suffix',
        agreedForMarketingCommunications: false,
        conditionsAcceptedAt: DateTime.now().toUtc(),
        firstName: 'Ada',
        testVerificationCode: testVerificationCode,
      ),
    );

    /// The model as it comes back from a client.
    ///
    /// Round-tripped through `toJsonForProtocol` on purpose rather than by
    /// setting the field to null by hand: that map *is* what the client was
    /// given, so what survives the trip is exactly what a client is able to
    /// send back. The `serverOnly` field is not omitted by this helper — it is
    /// missing because the wire form never carried it.
    UserProfile asReturnedByClient(UserProfile stored) =>
        UserProfile.fromJson(stored.toJsonForProtocol());

    test('the wire form a client sends back has no serverOnly field', () {
      // The premise of every test below. If this stopped holding, they would
      // all keep passing while testing nothing.
      final profile = UserProfile(
        userIdentifier: 'x',
        phone: 'x',
        agreedForMarketingCommunications: false,
        conditionsAcceptedAt: DateTime.now().toUtc(),
        firstName: 'Ada',
        testVerificationCode: 'THE-CODE',
      );

      expect(profile.toJson(), contains('testVerificationCode'));
      expect(profile.toJsonForProtocol(), isNot(contains('testVerificationCode')));
      expect(asReturnedByClient(profile).testVerificationCode, isNull);
    });

    test('a client save leaves the serverOnly column as it was', () async {
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'plain_save');

      final response = await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
      ).save(
        session,
        asReturnedByClient(stored).copyWith(firstName: 'Grace'),
      );

      expect(response.isOk, isTrue);
      final reloaded = await UserProfile.db.findById(session, stored.id!);
      // The edit the client actually made goes through...
      expect(reloaded?.firstName, 'Grace');
      // ...and the column it could not see is untouched.
      expect(reloaded?.testVerificationCode, 'THE-CODE');
    });

    test('the locked update path protects the column too', () async {
      // A separate entry point into the same write, and the one a config with
      // state-dependent rules uses. Worth its own test: a fix applied to only
      // one of the two paths would look complete.
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'locked_save');

      final response = await DwSaveConfig<UserProfile>(
        lockInitialModelForUpdate: true,
        allowSave: (session, context) async => true,
      ).save(
        session,
        asReturnedByClient(stored).copyWith(firstName: 'Grace'),
      );

      expect(response.isOk, isTrue);
      final reloaded = await UserProfile.db.findById(session, stored.id!);
      expect(reloaded?.firstName, 'Grace');
      expect(reloaded?.testVerificationCode, 'THE-CODE');
    });

    test('a hook that assigns a serverOnly value writes it', () async {
      // The legitimate case the narrow rule exists to keep working: the server
      // computes the value itself, so it is not null on the way in and is
      // written like any other column.
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'hook_assigns');

      final response = await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
        beforeSaveTransaction: (session, context) async {
          context.currentModel = context.currentModel.copyWith(
            testVerificationCode: 'ROTATED',
          );
          return null;
        },
      ).save(session, asReturnedByClient(stored));

      expect(response.isOk, isTrue);
      expect(
        (await UserProfile.db.findById(
          session,
          stored.id!,
        ))?.testVerificationCode,
        'ROTATED',
      );
    });

    test('a hook cannot clear the column without the opt-out', () async {
      // The one case the narrow rule costs, stated as a test so it is a known
      // trade-off rather than a surprise.
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'hook_clears');

      await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
        beforeSaveTransaction: (session, context) async {
          context.currentModel = context.currentModel.copyWith(
            testVerificationCode: null,
          );
          return null;
        },
      ).save(session, asReturnedByClient(stored));

      expect(
        (await UserProfile.db.findById(
          session,
          stored.id!,
        ))?.testVerificationCode,
        'THE-CODE',
      );
    });

    test('allowServerOnlyOverwrite lets the column be cleared', () async {
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'opt_out');

      final response = await DwSaveConfig<UserProfile>(
        allowServerOnlyOverwrite: true,
        allowSave: (session, context) async => true,
      ).save(session, asReturnedByClient(stored));

      expect(response.isOk, isTrue);
      expect(
        (await UserProfile.db.findById(
          session,
          stored.id!,
        ))?.testVerificationCode,
        isNull,
      );
    });

    test('an insert still writes the serverOnly value', () async {
      // Inserts are outside the guard entirely — there is no stored row to
      // protect, and a skipped column here would silently drop the value.
      final session = sessionBuilder.build();

      final response = await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
      ).save(
        session,
        UserProfile(
          userIdentifier: '${_testIdentifierPrefix}insert',
          phone: '${_testIdentifierPrefix}insert',
          agreedForMarketingCommunications: false,
          conditionsAcceptedAt: DateTime.now().toUtc(),
          firstName: 'Ada',
          testVerificationCode: 'FRESH',
        ),
      );

      expect(response.isOk, isTrue);
      final inserted = await UserProfile.db.findFirstRow(
        session,
        where: (t) =>
            t.userIdentifier.equals('${_testIdentifierPrefix}insert'),
      );
      expect(inserted?.testVerificationCode, 'FRESH');
    });

    test('a save leaves an unrelated row alone', () async {
      // The column list is built per row. A bug that built it once and reused
      // it would show up as a neighbour losing its code.
      final session = sessionBuilder.build();
      final mine = await storedProfile(session, suffix: 'mine');
      final neighbour = await storedProfile(
        session,
        suffix: 'neighbour',
        testVerificationCode: 'NEIGHBOUR-CODE',
      );

      await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
      ).save(session, asReturnedByClient(mine).copyWith(firstName: 'Grace'));

      expect(
        (await UserProfile.db.findById(
          session,
          neighbour.id!,
        ))?.testVerificationCode,
        'NEIGHBOUR-CODE',
      );
    });

    test('a row whose serverOnly column is null saves normally', () async {
      // The gate that skips the work compares map sizes, and a null column is
      // missing from both maps — so this row takes the cheap path. It must
      // still save everything else.
      final session = sessionBuilder.build();
      final stored = await storedProfile(
        session,
        suffix: 'null_code',
        testVerificationCode: null,
      );

      final response = await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
      ).save(
        session,
        asReturnedByClient(stored).copyWith(firstName: 'Grace'),
      );

      expect(response.isOk, isTrue);
      final reloaded = await UserProfile.db.findById(session, stored.id!);
      expect(reloaded?.firstName, 'Grace');
      expect(reloaded?.testVerificationCode, isNull);
    });

    test('the save response does not carry the serverOnly column', () async {
      // The outbound half, end to end and through the real envelope:
      // DwApiResponse -> DwModelWrapper -> model. Only reachable with a booted
      // server, because the wrapper resolves its class name through
      // `Serverpod.instance` — which is why the unit suite in core_server stops
      // one level short of this.
      final session = sessionBuilder.build();
      final stored = await storedProfile(session, suffix: 'response');

      final response = await DwSaveConfig<UserProfile>(
        allowSave: (session, context) async => true,
      ).save(
        session,
        asReturnedByClient(stored).copyWith(firstName: 'Grace'),
      );

      final wire = response.toJsonForProtocol();
      expect(wire['value']['data'], isNot(contains('testVerificationCode')));
      for (final updated in wire['updatedModels'] as List) {
        expect(updated['data'], isNot(contains('testVerificationCode')));
      }
      // The encoder Serverpod actually runs over the result, as the last word:
      // no assertion about maps can rule out the string on the socket.
      expect(
        SerializationManager.encodeForProtocol(response),
        isNot(contains('testVerificationCode')),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<void> _clearTestProfiles(Session session) async {
  await session.db.unsafeExecute('''
DELETE FROM "user_profile"
WHERE "userIdentifier" LIKE @identifierPrefix
''', parameters: QueryParameters.named({
    'identifierPrefix': '$_testIdentifierPrefix%',
  }));
}
