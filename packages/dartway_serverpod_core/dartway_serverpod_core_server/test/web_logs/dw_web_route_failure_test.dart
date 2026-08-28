import 'dart:convert';
import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('what a failing web route tells the caller', () {
    test('an exception written for us stays with us', () {
      // The caller of a webhook is not somebody we authenticated, and an
      // arbitrary exception carries whatever it carries — a query, a path, a
      // framework message. It used to be written straight into the response.
      final failure = DwWebServerLogger.failureFor(
        StateError('connection to db-prod-1 failed: SELECT token FROM users'),
      );

      expect(failure.statusCode, HttpStatus.internalServerError);
      expect(failure.message, isNot(contains('db-prod-1')));
      expect(failure.message, isNot(contains('SELECT')));
      expect(failure.alert, isTrue, reason: 'this one is an incident');
    });

    test('an exception written for the caller reaches them verbatim', () {
      final failure = DwWebServerLogger.failureFor(
        const DwPublicWebException('orderId is required'),
      );

      expect(failure.statusCode, HttpStatus.badRequest);
      expect(failure.message, 'orderId is required');
      // The route refusing on its own terms is not an incident, and alerting
      // on every malformed request trains people to stop reading alerts.
      expect(failure.alert, isFalse);
    });

    test('a public failure may name its own status', () {
      final failure = DwWebServerLogger.failureFor(
        const DwPublicWebException('unknown signature', statusCode: 401),
      );

      expect(failure.statusCode, 401);
      expect(failure.message, 'unknown signature');
    });
  });

  group('what reaches the log table', () {
    const keys = DwWebServerLogger.knownSensitiveKeys;

    Map<String, dynamic> sanitized(Object body) =>
        jsonDecode(DwWebServerLogger.sanitizeBody(jsonEncode(body), keys)!)
            as Map<String, dynamic>;

    test('a secret at the top level is hidden', () {
      expect(sanitized({'token': 'abc', 'id': 7})['token'], isNot('abc'));
      expect(sanitized({'token': 'abc', 'id': 7})['id'], 7);
    });

    test('a secret nested in a map is hidden', () {
      final out = sanitized({
        'auth': {'password': 'hunter2'},
      });

      expect((out['auth'] as Map)['password'], isNot('hunter2'));
    });

    test('a secret inside a list is hidden too', () {
      // The walk used to stop at maps. A payload keeps its secrets one level
      // inside an array as readily as under a key, and that one was written
      // into the log table intact with nothing failing.
      final out = sanitized({
        'items': [
          {'id': 1, 'token': 'leaked'},
          {'id': 2, 'nested': {'secret': 'also leaked'}},
        ],
      });

      final items = out['items'] as List;
      expect((items.first as Map)['token'], isNot('leaked'));
      expect((items.first as Map)['id'], 1);
      expect(((items[1] as Map)['nested'] as Map)['secret'], isNot('also leaked'));
    });

    test('a body that is not JSON is not logged at all', () {
      expect(DwWebServerLogger.sanitizeBody('not json', keys), isNull);
    });
  });
}
