import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:test/test.dart';

void main() {
  group('DwPushTransportResult', () {
    test('a successful target completes the recipient delivery', () {
      final result = DwPushTransportResult([
        const DwPushTargetResult(
          target: 'old-token',
          status: DwPushTargetStatus.invalid,
        ),
        const DwPushTargetResult(
          target: 'active-token',
          status: DwPushTargetStatus.sent,
        ),
      ]);

      expect(result.shouldRetry, isFalse);
      expect(result.wasDelivered, isTrue);
      expect(result.invalidTargets, ['old-token']);
    });

    test(
      'retries only when no target succeeded and a failure is transient',
      () {
        final result = DwPushTransportResult([
          const DwPushTargetResult(
            target: 'token-a',
            status: DwPushTargetStatus.retryableFailure,
          ),
          const DwPushTargetResult(
            target: 'token-b',
            status: DwPushTargetStatus.permanentFailure,
          ),
        ]);

        expect(result.shouldRetry, isTrue);
        expect(result.wasDelivered, isFalse);
      },
    );

    test('keeps the longest provider retry-after delay', () {
      final result = DwPushTransportResult([
        const DwPushTargetResult(
          target: 'token-a',
          status: DwPushTargetStatus.retryableFailure,
          retryAfter: Duration(minutes: 1),
        ),
        const DwPushTargetResult(
          target: 'token-b',
          status: DwPushTargetStatus.retryableFailure,
          retryAfter: Duration(minutes: 3),
        ),
      ]);

      expect(result.retryAfter, const Duration(minutes: 3));
    });

    test('rejects retry-after on a terminal target outcome', () {
      expect(
        () => DwPushTransportResult([
          const DwPushTargetResult(
            target: 'token',
            status: DwPushTargetStatus.permanentFailure,
            retryAfter: Duration(minutes: 1),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate target results', () {
      expect(
        () => DwPushTransportResult([
          const DwPushTargetResult(
            target: 'same-token',
            status: DwPushTargetStatus.sent,
          ),
          const DwPushTargetResult(
            target: 'same-token',
            status: DwPushTargetStatus.invalid,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}
