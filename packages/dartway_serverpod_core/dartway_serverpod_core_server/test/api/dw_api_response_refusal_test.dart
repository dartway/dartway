import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:test/test.dart';

/// A rule saying no and a server breaking share the `error` field, so the only
/// thing separating them on the wire is [DwApiResponse.isRefusal]. Both halves
/// of that agreement are pinned here: what carries the flag, and what the JSON
/// looks like — the client's twin of this class reads exactly these keys.
void main() {
  group('what is a refusal', () {
    test('a rule refusing, with its own text', () {
      const response = DwApiResponse<bool>.refusal('This booking is gone');

      expect(response.isOk, isFalse);
      expect(response.isRefusal, isTrue);
      expect(response.error, 'This booking is gone');
    });

    test('a permission rule refusing', () {
      expect(const DwApiResponse<bool>.forbidden().isRefusal, isTrue);
    });
  });

  group('what is not', () {
    test('an operation the server has no config for', () {
      // Nobody decided anything: the call does not exist on this server, which
      // is a hole in the deployment and worth reporting as one.
      expect(
        const DwApiResponse<bool>.notConfigured(source: 'getOne').isRefusal,
        isFalse,
      );
    });

    test('an absent session', () {
      // An answer, but not one to show as it stands — its text carries a
      // source written for the logs. See the constructor's own note.
      expect(
        const DwApiResponse<bool>.notAuthenticated(source: 'getOne').isRefusal,
        isFalse,
      );
    });

    test('a plain failure built by hand', () {
      const response = DwApiResponse<bool>(
        isOk: false,
        value: null,
        error: 'Database error during save',
      );

      expect(response.isRefusal, isFalse);
    });
  });

  group('on the wire', () {
    test('a refusal is marked', () {
      final json = const DwApiResponse<bool>.refusal(
        'This booking is gone',
      ).toJsonForProtocol();

      expect(json['isRefusal'], isTrue);
      expect(json['error'], 'This booking is gone');
    });

    test('everything else carries no key at all', () {
      // Absent rather than `false`, so nothing grows for the responses that
      // are the overwhelming majority — and so an older client, which reads a
      // missing key as "not a refusal", is right about them.
      final failure = const DwApiResponse<bool>(
        isOk: false,
        value: null,
        error: 'Unexpected error while handling the getAll request',
      ).toJsonForProtocol();
      final success = const DwApiResponse<bool>(
        isOk: true,
        value: true,
      ).toJsonForProtocol();

      expect(failure.containsKey('isRefusal'), isFalse);
      expect(success.containsKey('isRefusal'), isFalse);
    });
  });
}
