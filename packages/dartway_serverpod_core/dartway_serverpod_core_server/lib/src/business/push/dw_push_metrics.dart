// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';

final class DwPushMetrics {
  const DwPushMetrics(this._clock);

  final DwPushClock _clock;

  Future<void> increment(
    Session session, {
    required String category,
    required DwPushMetricOutcome outcome,
    int amount = 1,
    Transaction? transaction,
  }) async {
    if (amount <= 0) return;
    final now = _clock();
    final bucketStart = DateTime.utc(now.year, now.month, now.day, now.hour);

    await session.db.unsafeExecute(
      '''
INSERT INTO "dw_push_metric_bucket"
  ("bucketStart", "category", "outcome", "eventCount", "updatedAt")
VALUES
  (@bucketStart, @category, @outcome, @amount, @now)
ON CONFLICT ("bucketStart", "category", "outcome")
DO UPDATE SET
  "eventCount" = "dw_push_metric_bucket"."eventCount" + EXCLUDED."eventCount",
  "updatedAt" = EXCLUDED."updatedAt"
''',
      transaction: transaction,
      parameters: QueryParameters.named({
        'bucketStart': bucketStart,
        'category': category,
        'outcome': outcome.name,
        'amount': amount,
        'now': now,
      }),
    );
  }
}
