import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  test('defaults worker delivery concurrency to four', () {
    final config = DwPushConfig(
      recipientResolver: const _RecipientResolver(),
      transport: const _Transport(),
    );

    expect(config.maxConcurrentDeliveries, 4);
  });

  test('cleanup result keeps the new membership count source-compatible', () {
    const result = DwPushCleanupResult(
      expiredDeliveries: 1,
      orphanedMessages: 2,
      metricBuckets: 3,
      recipientStates: 4,
    );

    expect(result.messageRecipients, 0);
  });
}

final class _RecipientResolver extends DwPushRecipientResolver {
  const _RecipientResolver();

  @override
  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  }) async => DwPushRecipient(const []);
}

final class _Transport implements DwPushTransport {
  const _Transport();

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) async => DwPushTransportResult(const []);
}
