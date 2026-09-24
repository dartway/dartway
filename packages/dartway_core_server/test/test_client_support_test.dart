import 'dart:async';

import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

void main() {
  group('dwWaitUntil', () {
    test('returns once the condition holds', () async {
      var checks = 0;
      await dwWaitUntil(() => ++checks == 3, interval: Duration.zero);
      expect(checks, 3);
    });

    test('awaits an asynchronous condition', () async {
      var ready = false;
      Timer(const Duration(milliseconds: 30), () => ready = true);
      await dwWaitUntil(() async => ready);
      expect(ready, isTrue);
    });

    test('names the reason when the time runs out', () {
      expect(
        dwWaitUntil(
          () => false,
          timeout: const Duration(milliseconds: 50),
          reason: 'the invoice goes live',
        ),
        throwsA(
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            contains('the invoice goes live'),
          ),
        ),
      );
    });
  });
}
