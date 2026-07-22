import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

void main() {
  group('DwPushRetryPolicy', () {
    final policy = DwPushRetryPolicy(
      maxAttempts: 4,
      initialDelay: Duration(seconds: 10),
      maximumDelay: Duration(minutes: 1),
      jitterFactor: 0,
    );

    test('uses capped exponential backoff', () {
      expect(policy.delayAfterFailure(1), const Duration(seconds: 10));
      expect(policy.delayAfterFailure(2), const Duration(seconds: 20));
      expect(policy.delayAfterFailure(3), const Duration(seconds: 40));
      expect(policy.delayAfterFailure(4), isNull);
    });

    test('rejects invalid configuration', () {
      expect(() => DwPushRetryPolicy(maxAttempts: 0), throwsArgumentError);
      expect(() => DwPushRetryPolicy(jitterFactor: 1.1), throwsArgumentError);
    });
  });
}
