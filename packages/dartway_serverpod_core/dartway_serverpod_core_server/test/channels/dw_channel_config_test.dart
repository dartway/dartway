import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// [DwChannelConfig.allows] takes the caller's id as an argument and only hands
/// the session to `allowListen`, so every rule but a custom predicate can be
/// decided without a database. This double exists to prove that: if a test
/// below ever touches it, the decision reached for something it should not.
class UnusedSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('The channel decision must not read the session');
}

void main() {
  final session = UnusedSession();

  group('matching', () {
    test('a declaration governs every name starting with its prefix', () {
      const config = DwChannelConfig.public(prefix: 'chatPost_');

      expect(config.matches('chatPost_'), isTrue);
      expect(config.matches('chatPost_course12'), isTrue);
      expect(config.matches('chatPos'), isFalse);
      expect(config.matches('otherChatPost_course12'), isFalse);
    });
  });

  group('public', () {
    const config = DwChannelConfig.public(prefix: 'dwPublicUpdates');

    test('lets a caller with no session listen', () async {
      expect(
        await config.allows(session, 'dwPublicUpdates', userProfileId: null),
        isTrue,
      );
    });

    test('lets a signed-in caller listen too', () async {
      expect(
        await config.allows(session, 'dwPublicUpdates', userProfileId: 7),
        isTrue,
      );
    });
  });

  group('owner', () {
    const config = DwChannelConfig.owner(prefix: 'userUpdates');

    test('lets the user whose id the name ends with listen', () async {
      expect(
        await config.allows(session, 'userUpdates42', userProfileId: 42),
        isTrue,
      );
    });

    test('refuses another signed-in user — the hole this closes', () async {
      expect(
        await config.allows(session, 'userUpdates42', userProfileId: 7),
        isFalse,
      );
    });

    test('refuses a caller with no session', () async {
      expect(
        await config.allows(session, 'userUpdates42', userProfileId: null),
        isFalse,
      );
    });

    test('refuses a suffix that is not an id rather than throwing', () async {
      expect(
        await config.allows(session, 'userUpdatesAll', userProfileId: 42),
        isFalse,
      );
      // '4' is not 42, and a prefix match must not be mistaken for one.
      expect(
        await config.allows(session, 'userUpdates4', userProfileId: 42),
        isFalse,
      );
    });
  });

  group('guarded', () {
    test('is handed the part of the name after the prefix', () async {
      String? seenSuffix;
      final config = DwChannelConfig.guarded(
        prefix: 'chatPost_',
        allowListen: (_, suffix) async {
          seenSuffix = suffix;
          return true;
        },
      );

      await config.allows(
        session,
        'chatPost_course12_topic7',
        userProfileId: 1,
      );

      expect(seenSuffix, 'course12_topic7');
    });

    test('does not run the predicate for an anonymous caller', () async {
      var predicateRan = false;
      final config = DwChannelConfig.guarded(
        prefix: 'chatPost_',
        allowListen: (_, __) async {
          predicateRan = true;
          return true;
        },
      );

      expect(
        await config.allows(session, 'chatPost_c12', userProfileId: null),
        isFalse,
      );
      expect(
        predicateRan,
        isFalse,
        reason:
            'allowAnonymous is false, so the predicate never has to '
            'remember it might be called without a user',
      );
    });

    test('runs the predicate anonymously once it opts in', () async {
      final config = DwChannelConfig.guarded(
        prefix: 'chatPost_',
        allowAnonymous: true,
        allowListen: (_, suffix) async => suffix == 'public',
      );

      expect(
        await config.allows(session, 'chatPost_public', userProfileId: null),
        isTrue,
      );
      expect(
        await config.allows(session, 'chatPost_private', userProfileId: null),
        isFalse,
      );
    });
  });
}
