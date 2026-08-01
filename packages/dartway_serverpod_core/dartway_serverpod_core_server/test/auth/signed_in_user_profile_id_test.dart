import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// A session carrying nothing but its resolved authentication.
///
/// That it is enough is the point: reading the caller's id touches only what
/// Serverpod has already cached on the session. Anything else this double is
/// asked for is a regression back to the database round trip this replaced.
class SessionWithAuthentication implements Session {
  SessionWithAuthentication(this.userIdentifier);

  SessionWithAuthentication.anonymous() : userIdentifier = null;

  final String? userIdentifier;

  @override
  AuthenticationInfo? get authenticated {
    final identifier = userIdentifier;
    if (identifier == null) return null;
    return AuthenticationInfo(identifier, const <Scope>{}, authId: 'test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Reading the signed-in id must not touch the session beyond '
    '`authenticated` — it is meant to cost nothing.',
  );
}

void main() {
  group('signedInUserProfileId', () {
    test('is the id the token was issued for', () {
      expect(SessionWithAuthentication('42').signedInUserProfileId, 42);
    });

    test('is null without a session', () {
      expect(
        SessionWithAuthentication.anonymous().signedInUserProfileId,
        isNull,
      );
    });

    test('is null when the identifier is not an id', () {
      // `AuthenticationInfo.userIdentifier` is a free-form string — the module
      // issuing it decides the shape, and serverpod_auth_user puts a UUID
      // there. Anything DartWay did not issue reads as "not signed in" rather
      // than throwing on a request that has nothing to do with us.
      expect(
        SessionWithAuthentication(
          '550e8400-e29b-41d4-a716-446655440000',
        ).signedInUserProfileId,
        isNull,
      );
    });
  });

  group('isUser', () {
    test('accepts the signed-in caller', () {
      expect(SessionWithAuthentication('42').isUser(42), isTrue);
    });

    test('rejects another user', () {
      expect(SessionWithAuthentication('42').isUser(7), isFalse);
    });

    test('rejects a caller with no session', () {
      expect(SessionWithAuthentication.anonymous().isUser(42), isFalse);
      // The trap the non-nullable parameter exists to prevent: written as
      // `model.ownerId == session.signedInUserProfileId` over a nullable
      // column, this case is `null == null` and grants access.
      expect(SessionWithAuthentication.anonymous().isUser(0), isFalse);
    });
  });
}
