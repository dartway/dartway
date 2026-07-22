// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';
import 'dw_push_metrics.dart';
import 'dw_push_queue.dart';
import 'dw_push_recipient_lock.dart';
import 'dw_push_recipient_state_store.dart';
import 'dw_push_runtime.dart';
import 'dw_push_worker.dart';

/// Optional DartWay component for compact and reliable push delivery.
final class DwPush {
  DwPush({required this.config})
    : _recipientLock = DwPushRecipientLock(),
      _metrics = DwPushMetrics(config.clock),
      _runtime = DwPushRuntime(config.clock) {
    queue = DwPushQueue(
      config: config,
      metrics: _metrics,
      recipientLock: _recipientLock,
    );
    recipientState = DwPushRecipientStateStore(
      config: config,
      recipientLock: _recipientLock,
    );
    worker = DwPushWorker(
      config: config,
      metrics: _metrics,
      recipientLock: _recipientLock,
      runtime: _runtime,
    );
  }

  final DwPushConfig config;
  final DwPushRecipientLock _recipientLock;
  final DwPushMetrics _metrics;
  final DwPushRuntime _runtime;

  late final DwPushQueue queue;
  late final DwPushRecipientStateStore recipientState;
  late final DwPushWorker worker;

  static const _recipientLockRetryDelay = Duration(milliseconds: 20);
  static const _recipientLockWaitTimeout = Duration(seconds: 30);

  bool _storageSettingsEnsured = false;

  Future<DwPushBatchResult> processBatch(
    Session session, {
    String workerName = 'default',
  }) async {
    await _ensureStorageSettings(session);
    return worker.processBatch(session, workerName: workerName);
  }

  /// Applies the recommended per-table autovacuum settings for the two
  /// high-churn push tables, once per process, before the first batch.
  ///
  /// The delete-and-bucket design turns over `dw_push_delivery` and
  /// `dw_push_message_recipient` rows quickly, so Postgres's default autovacuum
  /// thresholds (a fraction of table size) let dead tuples pile up under load.
  /// The module owns this rather than a manual migration checklist: the
  /// statement is idempotent, runs itself on every boot, and therefore survives
  /// the app regenerating its aggregated migration. A failure here (e.g. the DB
  /// role cannot `ALTER TABLE`) is logged and never blocks delivery.
  Future<void> _ensureStorageSettings(Session session) async {
    if (_storageSettingsEnsured) return;
    _storageSettingsEnsured = true;
    const tables = ['dw_push_delivery', 'dw_push_message_recipient'];
    for (final table in tables) {
      try {
        await session.db.unsafeExecute(
          'ALTER TABLE "$table" SET ('
          'autovacuum_vacuum_scale_factor = 0.01, '
          'autovacuum_vacuum_threshold = 100, '
          'autovacuum_analyze_scale_factor = 0.02, '
          'autovacuum_analyze_threshold = 100)',
        );
      } catch (error) {
        session.log(
          'DwPush: could not apply autovacuum settings to "$table": $error',
          level: LogLevel.warning,
        );
      }
    }
  }

  Future<void> pause(
    Session session, {
    String workerName = 'default',
    DateTime? until,
  }) => _runtime.pause(session, workerName: workerName, until: until);

  Future<Duration> resume(
    Session session, {
    String workerName = 'default',
    bool extendQueuedMessageLifetime = false,
  }) => _runtime.resume(
    session,
    workerName: workerName,
    extendQueuedMessageLifetime: extendQueuedMessageLifetime,
  );

  /// Runs [action] under the same lock used immediately before provider sends.
  ///
  /// Account deletion should delete the app user, call [queue.cancelRecipient]
  /// and [recipientState.clearRecipient] inside this transaction. When the
  /// transaction completes, no earlier delivery can still start a send.
  Future<T> withRecipientLock<T>(
    Session session, {
    required int recipientId,
    required Future<T> Function(Transaction transaction) action,
    Transaction? transaction,
  }) async {
    if (recipientId <= 0) {
      throw ArgumentError.value(recipientId, 'recipientId', 'Must be positive');
    }
    Future<T> run(Transaction transaction) async {
      final acquired = await _recipientLock.tryAcquire(
        session,
        recipientId: recipientId,
        transaction: transaction,
      );
      if (!acquired) {
        throw DwAdvisoryLockUnavailableException(
          namespace: DwPushRecipientLock.namespace,
          key: recipientId,
          waited: Duration.zero,
        );
      }
      return action(transaction);
    }

    if (transaction != null) return run(transaction);

    final stopwatch = Stopwatch()..start();
    while (true) {
      late T result;
      final acquired = await session.db.transaction((transaction) async {
        if (!await _recipientLock.tryAcquire(
          session,
          recipientId: recipientId,
          transaction: transaction,
        )) {
          return false;
        }
        result = await action(transaction);
        return true;
      });
      if (acquired) return result;
      if (stopwatch.elapsed >= _recipientLockWaitTimeout) {
        throw DwAdvisoryLockUnavailableException(
          namespace: DwPushRecipientLock.namespace,
          key: recipientId,
          waited: stopwatch.elapsed,
        );
      }
      await Future<void>.delayed(_recipientLockRetryDelay);
    }
  }

  /// Delivery progress for one message, computed on demand from row counts.
  ///
  /// Deliberately carries no hot per-message counter: it runs two `COUNT(*)`s,
  /// so an admin dashboard can poll it without contending with the worker. See
  /// [DwPushCampaignProgress] for the snapshot-vs-live-gauge tradeoff.
  Future<DwPushCampaignProgress> campaignProgress(
    Session session, {
    required int messageId,
  }) async {
    final rows = await session.db.unsafeQuery(
      '''
SELECT
  (SELECT COUNT(*)::bigint FROM "dw_push_message_recipient"
     WHERE "messageId" = @messageId),
  (SELECT COUNT(*)::bigint FROM "dw_push_delivery"
     WHERE "messageId" = @messageId)
''',
      parameters: QueryParameters.named({'messageId': messageId}),
    );
    final row = rows.single;
    return DwPushCampaignProgress(
      total: row[0] as int,
      remaining: row[1] as int,
    );
  }

  /// Removes expired queue work and bounded operational data.
  Future<DwPushCleanupResult> cleanup(Session session) async {
    final now = config.clock();
    final messageExpiryCutoff = now.subtract(config.idempotencyRetention);
    final metricsCutoff = now.subtract(config.metricsRetention);
    final recipientStateCutoff = now.subtract(config.recipientStateRetention);

    final expiredDeliveries = await session.db.transaction((transaction) async {
      final removedByCategory = await session.db.unsafeQuery(
        '''
WITH expired AS (
  SELECT delivery."id"
  FROM "dw_push_delivery" AS delivery
  JOIN "dw_push_message" AS message
    ON message."id" = delivery."messageId"
  WHERE message."expiresAt" <= @now
  FOR UPDATE OF delivery SKIP LOCKED
  LIMIT 10000
),
removed AS (
  DELETE FROM "dw_push_delivery" AS delivery
  USING expired
  WHERE delivery."id" = expired."id"
  RETURNING delivery."messageId"
)
SELECT message."category", COUNT(*)::bigint
FROM removed
JOIN "dw_push_message" AS message
  ON message."id" = removed."messageId"
GROUP BY message."category"
''',
        transaction: transaction,
        parameters: QueryParameters.named({'now': now}),
      );

      var removedCount = 0;
      for (final row in removedByCategory) {
        final amount = row[1] as int;
        removedCount += amount;
        await _metrics.increment(
          session,
          category: row[0] as String,
          outcome: DwPushMetricOutcome.expired,
          amount: amount,
          transaction: transaction,
        );
      }
      return removedCount;
    });
    final messageRecipients = await session.db.unsafeExecute('''
WITH removable AS (
  SELECT recipient."id"
  FROM "dw_push_message_recipient" AS recipient
  JOIN "dw_push_message" AS message
    ON message."id" = recipient."messageId"
  WHERE (
    message."expiresAt" <= @now
    OR message."audienceClosedAt" IS NOT NULL
  )
    AND NOT EXISTS (
      SELECT 1
      FROM "dw_push_delivery" AS delivery
      WHERE delivery."messageId" = message."id"
    )
  FOR UPDATE OF recipient SKIP LOCKED
  LIMIT 10000
)
DELETE FROM "dw_push_message_recipient" AS recipient
USING removable
WHERE recipient."id" = removable."id"
''', parameters: QueryParameters.named({'now': now}));
    final orphanedMessages = await session.db.unsafeExecute(
      '''
WITH orphaned AS (
  SELECT message."id"
  FROM "dw_push_message" AS message
  WHERE (
    message."expiresAt" <= @messageExpiryCutoff
    OR message."audienceClosedAt" <= @messageExpiryCutoff
  )
    AND NOT EXISTS (
      SELECT 1
      FROM "dw_push_delivery" AS delivery
      WHERE delivery."messageId" = message."id"
    )
    AND NOT EXISTS (
      SELECT 1
      FROM "dw_push_message_recipient" AS recipient
      WHERE recipient."messageId" = message."id"
    )
  FOR UPDATE OF message SKIP LOCKED
  LIMIT 10000
)
DELETE FROM "dw_push_message" AS message
USING orphaned
WHERE message."id" = orphaned."id"
''',
      parameters: QueryParameters.named({
        'messageExpiryCutoff': messageExpiryCutoff,
      }),
    );
    final metricBuckets = await session.db.unsafeExecute('''
WITH old_buckets AS (
  SELECT "id"
  FROM "dw_push_metric_bucket"
  WHERE "bucketStart" < @metricsCutoff
  FOR UPDATE SKIP LOCKED
  LIMIT 10000
)
DELETE FROM "dw_push_metric_bucket" AS bucket
USING old_buckets
WHERE bucket."id" = old_buckets."id"
''', parameters: QueryParameters.named({'metricsCutoff': metricsCutoff}));
    final recipientStates = await session.db.unsafeExecute(
      '''
WITH old_states AS (
  SELECT "id"
  FROM "dw_push_recipient_state"
  WHERE "updatedAt" < @recipientStateCutoff
    AND "nextAllowedAt" < @now
  FOR UPDATE SKIP LOCKED
  LIMIT 10000
)
DELETE FROM "dw_push_recipient_state" AS state
USING old_states
WHERE state."id" = old_states."id"
''',
      parameters: QueryParameters.named({
        'recipientStateCutoff': recipientStateCutoff,
        'now': now,
      }),
    );

    return DwPushCleanupResult(
      expiredDeliveries: expiredDeliveries,
      messageRecipients: messageRecipients,
      orphanedMessages: orphanedMessages,
      metricBuckets: metricBuckets,
      recipientStates: recipientStates,
    );
  }
}
