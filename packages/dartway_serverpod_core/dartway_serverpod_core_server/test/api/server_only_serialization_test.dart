import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/domain/api/dw_protocol_json.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// `scope=serverOnly` must hold on the way out: a field the schema marked
/// server-side never reaches a client.
///
/// The fixture is a real generated model rather than a hand-written double, and
/// that is the point of the suite. What is being tested is the agreement
/// between two maps the *generator* writes — `toJson` carries
/// `verificationHash`, `toJsonForProtocol` does not — and a double would only
/// assert that this test file agrees with itself. `DwAuthRequest` lives in this
/// package, so the check travels with the code it guards.
///
/// Why it is worth pinning: the leak is invisible from the app. The client
/// class has no field for a `serverOnly` column, so `fromJson` drops the key
/// and every screen looks right — while the value has already crossed the
/// network. Nothing fails, nothing is logged, and the only witness is the
/// response body.
///
/// `DwModelWrapper` and `DwAuthData` are absent here for a mechanical reason:
/// both resolve `className` through `Serverpod.instance` in their constructor,
/// so building one needs a booted server — the same limitation
/// `send_updates_test.dart` records. Their shared choice of serialiser is what
/// [dwJsonForProtocol] is, and it is tested directly below.
void main() {
  /// A request with every server-side field populated, so a leak has something
  /// to leak.
  DwAuthRequest authRequest() => DwAuthRequest(
    id: 7,
    requestType: DwAuthRequestType.login,
    userIdentifier: '+70000000000',
    authProvider: DwAuthProvider.phone,
    verificationHash: 'the-hash-that-must-not-travel',
  );

  group('the generator still marks the fixture serverOnly', () {
    // If this pair ever stops disagreeing, every assertion below would pass for
    // the wrong reason — a check against a field that is no longer serverOnly
    // proves nothing at all.
    test('toJson carries verificationHash and toJsonForProtocol does not', () {
      final request = authRequest();

      expect(request.toJson(), contains('verificationHash'));
      expect(request.toJsonForProtocol(), isNot(contains('verificationHash')));
    });
  });

  group('dwJsonForProtocol', () {
    test('drops the serverOnly field of a protocol-aware model', () {
      final json = dwJsonForProtocol(authRequest()) as Map<String, dynamic>;

      expect(json, isNot(contains('verificationHash')));
      // The ordinary fields still travel — stripping the row of everything
      // would pass the assertion above and break the app.
      expect(json['userIdentifier'], '+70000000000');
      expect(json['id'], 7);
    });
  });

  group('DwApiResponse', () {
    test('is the protocol serialiser Serverpod will actually call', () {
      // The encoder picks `toJsonForProtocol` only for objects that declare the
      // interface. Without this the envelope falls back to `toJson`, and since
      // it flattens its own contents, nothing below it is ever consulted.
      expect(
        const DwApiResponse<bool>(isOk: true, value: true),
        isA<ProtocolSerialization>(),
      );
    });

    test('strips the serverOnly field from a single value', () {
      final response = DwApiResponse<DwAuthRequest>(
        isOk: true,
        value: authRequest(),
      );

      final value = response.toJsonForProtocol()['value'];
      expect(value, isNot(contains('verificationHash')));
      expect(value['userIdentifier'], '+70000000000');
    });

    test('strips it from every element of a list value', () {
      final response = DwApiResponse<List<DwAuthRequest>>(
        isOk: true,
        value: [authRequest(), authRequest()],
      );

      final values = response.toJsonForProtocol()['value'] as List;
      expect(values, hasLength(2));
      for (final value in values) {
        expect(value, isNot(contains('verificationHash')));
      }
    });

    test('keeps the serverOnly field in the server-side toJson', () {
      // The two maps are not interchangeable, and this is the one that says so.
      // `toJson` still feeds caches, logs and the Redis hop between server
      // instances, where the full row is the correct answer.
      final response = DwApiResponse<DwAuthRequest>(
        isOk: true,
        value: authRequest(),
      );

      expect(response.toJson()['value'], contains('verificationHash'));
    });

    test('carries the plain envelope fields through unchanged', () {
      final response = DwApiResponse<DwAuthRequest>(
        isOk: false,
        value: null,
        error: 'nope',
        warning: 'careful',
      );

      final json = response.toJsonForProtocol();
      expect(json['isOk'], false);
      expect(json['value'], isNull);
      expect(json['error'], 'nope');
      expect(json['warning'], 'careful');
    });

    test('leaves a non-model value alone', () {
      // `getCount` and `delete` answer with an int and a bool; the walk must not
      // touch them.
      expect(
        const DwApiResponse<int>(isOk: true, value: 42).toJsonForProtocol(),
        containsPair('value', 42),
      );
    });
  });
}
