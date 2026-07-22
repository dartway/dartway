// ignore_for_file: invalid_use_of_internal_member

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';
import 'dw_push_metrics.dart';
import 'dw_push_recipient_lock.dart';
import 'dw_push_provider_utils.dart';
import 'dw_push_runtime.dart';
import 'dw_push_transport.dart';

final class DwPushWorker {
  DwPushWorker({
    required DwPushConfig config,
    required DwPushMetrics metrics,
    required DwPushRecipientLock recipientLock,
    required DwPushRuntime runtime,
  }) : _config = config,
       _metrics = metrics,
       _recipientLock = recipientLock,
       _runtime = runtime;

  final DwPushConfig _config;
  final DwPushMetrics _metrics;
  final DwPushRecipientLock _recipientLock;
  final DwPushRuntime _runtime;
  final Random _random = Random.secure();

  /// Claims and processes one bounded batch using PostgreSQL `SKIP LOCKED`.
  Future<DwPushBatchResult> processBatch(
    Session session, {
    String workerName = 'default',
  }) async {
    if (await _runtime.isPaused(session, workerName)) {
      return const DwPushBatchResult.paused();
    }

    final leaseId = _newLeaseId();
    final deliveries = await _claim(session, leaseId, workerName);
    if (deliveries == null) {
      return const DwPushBatchResult.paused();
    }
    if (deliveries.isEmpty) {
      await _bestEffortRuntime(
        session,
        () => _runtime.markCompleted(session, workerName: workerName),
      );
      return const DwPushBatchResult(
        claimed: 0,
        delivered: 0,
        retried: 0,
        removed: 0,
        paused: false,
      );
    }

    await _bestEffortRuntime(
      session,
      () => _runtime.markClaimed(session, workerName: workerName),
    );

    final outcomes = <_DeliveryOutcome>[];
    for (
      var offset = 0;
      offset < deliveries.length;
      offset += _config.maxConcurrentDeliveries
    ) {
      final end = min(
        offset + _config.maxConcurrentDeliveries,
        deliveries.length,
      );
      outcomes.addAll(
        await Future.wait(
          deliveries
              .sublist(offset, end)
              .map((delivery) => _process(session, delivery, leaseId)),
        ),
      );
    }

    await _recordMetrics(session, outcomes);
    final runtimeError = outcomes
        .map((outcome) => outcome.runtimeError)
        .whereType<String>()
        .firstOrNull;
    await _bestEffortRuntime(
      session,
      () => runtimeError == null
          ? _runtime.markCompleted(session, workerName: workerName)
          : _runtime.markError(
              session,
              workerName: workerName,
              error: runtimeError,
            ),
    );

    return DwPushBatchResult(
      claimed: deliveries.length,
      delivered: outcomes.where((outcome) => outcome.delivered).length,
      retried: outcomes.where((outcome) => outcome.retried).length,
      removed: outcomes.where((outcome) => outcome.removed).length,
      paused: false,
    );
  }

  Future<List<DwPushDelivery>?> _claim(
    Session session,
    String leaseId,
    String workerName,
  ) => session.db.transaction((transaction) async {
    if (await _runtime.isPausedForClaim(
      session,
      workerName,
      transaction: transaction,
    )) {
      return null;
    }

    final now = _config.clock();
    final leaseExpiresAt = now.add(_config.leaseDuration);
    final highLimit = (_config.batchSize * 0.5).ceil();
    final normalLimit = min(
      (_config.batchSize * 0.3).ceil(),
      _config.batchSize - highLimit,
    );
    final bulkLimit = _config.batchSize - highLimit - normalLimit;
    final ids = <int>[];
    for (final lane in [
      (DwPushPriority.high, highLimit),
      (DwPushPriority.normal, normalLimit),
      (DwPushPriority.bulk, bulkLimit),
    ]) {
      if (lane.$2 == 0) continue;
      ids.addAll(
        await _claimIds(
          session,
          leaseId: leaseId,
          leaseExpiresAt: leaseExpiresAt,
          now: now,
          priority: lane.$1,
          limit: lane.$2,
          transaction: transaction,
        ),
      );
    }
    final remaining = _config.batchSize - ids.length;
    if (remaining > 0) {
      ids.addAll(
        await _claimIds(
          session,
          leaseId: leaseId,
          leaseExpiresAt: leaseExpiresAt,
          now: now,
          limit: remaining,
          transaction: transaction,
        ),
      );
    }
    if (ids.isEmpty) return const <DwPushDelivery>[];

    final rows = await DwPushDelivery.db.find(
      session,
      where: (table) => table.id.inSet(ids.toSet()),
      transaction: transaction,
    );
    final order = {
      for (var index = 0; index < ids.length; index++) ids[index]: index,
    };
    rows.sort((left, right) => order[left.id]!.compareTo(order[right.id]!));
    return rows;
  });

  Future<List<int>> _claimIds(
    Session session, {
    required String leaseId,
    required DateTime leaseExpiresAt,
    required DateTime now,
    required int limit,
    required Transaction transaction,
    DwPushPriority? priority,
  }) async {
    final categoryFilter = _categoryFilter(priority);
    final claimedIds = <int>[];
    DateTime? cursorAvailableAt;
    int? cursorId;

    while (claimedIds.length < limit) {
      final cursorFilter = cursorAvailableAt == null
          ? (sql: 'TRUE', parameters: const <String, Object?>{})
          : (
              sql: '''
(ranked."availableAt", delivery."id") >
  (@cursorAvailableAt, @cursorId)
''',
              parameters: <String, Object?>{
                'cursorAvailableAt': cursorAvailableAt,
                'cursorId': cursorId,
              },
            );
      final result = await session.db.unsafeQuery(
        '''
WITH ranked AS MATERIALIZED (
  SELECT
    delivery."id",
    delivery."recipientId",
    delivery."availableAt",
    ROW_NUMBER() OVER (
      PARTITION BY delivery."recipientId"
      ORDER BY delivery."availableAt", delivery."id"
    ) AS recipient_rank
  FROM "dw_push_delivery" AS delivery
  JOIN "dw_push_message" AS message
    ON message."id" = delivery."messageId"
  WHERE delivery."availableAt" <= @now
    AND (delivery."leaseExpiresAt" IS NULL OR delivery."leaseExpiresAt" <= @now)
    AND NOT EXISTS (
      SELECT 1
      FROM "dw_push_delivery" AS active_delivery
      WHERE active_delivery."recipientId" = delivery."recipientId"
        AND active_delivery."leaseExpiresAt" > @now
    )
    AND ${categoryFilter.sql}
),
row_candidates AS MATERIALIZED (
  SELECT
    delivery."id",
    delivery."recipientId"
  FROM "dw_push_delivery" AS delivery
  JOIN ranked
    ON ranked."id" = delivery."id"
  WHERE ranked.recipient_rank = 1
    AND ${cursorFilter.sql}
  ORDER BY ranked."availableAt", delivery."id"
  FOR UPDATE OF delivery SKIP LOCKED
  LIMIT @batchSize
),
classified AS MATERIALIZED (
  SELECT
    row_candidates."id",
    row_candidates."recipientId",
    ranked."availableAt",
    pg_try_advisory_xact_lock(
      row_candidates."recipientId"::bigint #
        (@recipientLockNamespace::bigint << 32)
    ) AS acquired
  FROM row_candidates
  JOIN ranked
    ON ranked."id" = row_candidates."id"
),
leased AS (
  UPDATE "dw_push_delivery" AS delivery
  SET
    "leaseId" = @leaseId,
    "leaseExpiresAt" = @leaseExpiresAt
  FROM classified
  WHERE classified.acquired
    AND delivery."id" = classified."id"
  RETURNING delivery."id"
)
SELECT
  classified."id",
  classified."availableAt",
  leased."id"
FROM classified
LEFT JOIN leased
  ON leased."id" = classified."id"
ORDER BY classified."availableAt", classified."id"
''',
        transaction: transaction,
        parameters: QueryParameters.named({
          'now': now,
          'batchSize': limit - claimedIds.length,
          'leaseId': leaseId,
          'leaseExpiresAt': leaseExpiresAt,
          'recipientLockNamespace': DwPushRecipientLock.namespace,
          ...categoryFilter.parameters,
          ...cursorFilter.parameters,
        }),
      );
      if (result.isEmpty) break;

      for (final row in result) {
        cursorAvailableAt = row[1] as DateTime;
        cursorId = row[0] as int;
        if (row[2] != null) {
          claimedIds.add(row[2] as int);
        }
      }
    }

    return claimedIds;
  }

  ({String sql, Map<String, Object?> parameters}) _categoryFilter(
    DwPushPriority? priority,
  ) {
    if (priority == null) return (sql: 'TRUE', parameters: const {});

    final selected = _config.categoryPriorities.entries
        .where((entry) => entry.value == priority)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (priority == DwPushPriority.normal) {
      final exceptional = _config.categoryPriorities.entries
          .where((entry) => entry.value != DwPushPriority.normal)
          .map((entry) => entry.key)
          .toList(growable: false);
      if (exceptional.isEmpty) return (sql: 'TRUE', parameters: const {});
      return _categoryListFilter(exceptional, negate: true);
    }
    if (selected.isEmpty) return (sql: 'FALSE', parameters: const {});
    return _categoryListFilter(selected);
  }

  ({String sql, Map<String, Object?> parameters}) _categoryListFilter(
    List<String> categories, {
    bool negate = false,
  }) {
    final parameters = <String, Object?>{};
    final placeholders = <String>[];
    for (var index = 0; index < categories.length; index++) {
      final name = 'priorityCategory$index';
      placeholders.add('@$name');
      parameters[name] = categories[index];
    }
    final operator = negate ? 'NOT IN' : 'IN';
    return (
      sql: 'message."category" $operator (${placeholders.join(', ')})',
      parameters: parameters,
    );
  }

  Future<_DeliveryOutcome> _process(
    Session session,
    DwPushDelivery claimed,
    String leaseId,
  ) async {
    var sendStarted = false;
    try {
      final outcome = await session.db.transaction((transaction) async {
        final recipientLockAcquired = await _recipientLock.tryAcquire(
          session,
          recipientId: claimed.recipientId,
          transaction: transaction,
        );
        if (!recipientLockAcquired) {
          await _releaseLeaseAfterLockContention(
            session,
            deliveryId: claimed.id!,
            leaseId: leaseId,
            transaction: transaction,
          );
          return const _DeliveryOutcome.ignored();
        }
        final delivery = await DwPushDelivery.db.findById(
          session,
          claimed.id!,
          transaction: transaction,
          lockMode: LockMode.forUpdate,
        );
        if (delivery == null || delivery.leaseId != leaseId) {
          return const _DeliveryOutcome.ignored();
        }

        final message = await DwPushMessage.db.findById(
          session,
          delivery.messageId,
          transaction: transaction,
        );
        if (message == null) {
          await DwPushDelivery.db.deleteRow(
            session,
            delivery,
            transaction: transaction,
          );
          return const _DeliveryOutcome(
            category: '_missing_message',
            metric: DwPushMetricOutcome.failed,
            removed: true,
          );
        }

        final payload = _payload(message);
        if (!message.expiresAt.isAfter(_config.clock())) {
          await DwPushDelivery.db.deleteRow(
            session,
            delivery,
            transaction: transaction,
          );
          return _DeliveryOutcome(
            category: message.category,
            metric: DwPushMetricOutcome.expired,
            removed: true,
          );
        }

        final recipient = await _config.recipientResolver.resolve(
          session,
          recipientId: delivery.recipientId,
          payload: payload,
          transaction: transaction,
        );
        if (recipient.targets.isEmpty) {
          await DwPushDelivery.db.deleteRow(
            session,
            delivery,
            transaction: transaction,
          );
          return _DeliveryOutcome(
            category: message.category,
            metric: DwPushMetricOutcome.skipped,
            removed: true,
          );
        }

        final attemptNumber = delivery.attemptCount + 1;
        await DwPushDelivery.db.updateById(
          session,
          delivery.id!,
          columnValues: (table) => [table.attemptCount(attemptNumber)],
          transaction: transaction,
        );
        delivery.attemptCount = attemptNumber;
        final attempt = DwPushDeliveryAttempt(
          deliveryId: delivery.id!,
          recipientId: delivery.recipientId,
          attemptNumber: attemptNumber,
          payload: payload,
          targets: recipient.targets,
        );
        sendStarted = true;
        final transportResult = await _config.transport.send(session, attempt);
        _verifyTransportResult(attempt, transportResult);

        if (transportResult.wasDelivered) {
          await DwPushDelivery.db.deleteRow(
            session,
            delivery,
            transaction: transaction,
          );
          return _DeliveryOutcome(
            category: message.category,
            metric: DwPushMetricOutcome.delivered,
            delivered: true,
            removed: true,
            invalidTargets: transportResult.invalidTargets,
            recipientId: delivery.recipientId,
          );
        }

        final policyDelay = transportResult.shouldRetry
            ? _config.retryPolicy.delayAfterFailure(delivery.attemptCount)
            : null;
        final providerDelay = transportResult.retryAfter;
        final retryDelay = policyDelay == null
            ? null
            : providerDelay != null && providerDelay > policyDelay
            ? providerDelay
            : policyDelay;
        if (retryDelay != null) {
          await _reschedule(
            session,
            delivery,
            retryDelay,
            _transportError(transportResult),
            transaction,
          );
          return _DeliveryOutcome(
            category: message.category,
            metric: DwPushMetricOutcome.retryScheduled,
            retried: true,
            invalidTargets: transportResult.invalidTargets,
            recipientId: delivery.recipientId,
          );
        }

        await DwPushDelivery.db.deleteRow(
          session,
          delivery,
          transaction: transaction,
        );
        return _DeliveryOutcome(
          category: message.category,
          metric: DwPushMetricOutcome.failed,
          removed: true,
          invalidTargets: transportResult.invalidTargets,
          recipientId: delivery.recipientId,
        );
      });

      await _invalidateBestEffort(session, outcome);
      return outcome;
    } catch (error, stackTrace) {
      session.log(
        'Push delivery ${claimed.id} failed unexpectedly '
        '(${dwPushSafeExceptionCode(error)})',
        level: LogLevel.error,
        stackTrace: stackTrace,
      );
      return _recoverAfterException(
        session,
        claimed,
        leaseId,
        error,
        sendStarted: sendStarted,
      );
    }
  }

  Future<void> _releaseLeaseAfterLockContention(
    Session session, {
    required int deliveryId,
    required String leaseId,
    required Transaction transaction,
  }) async {
    await session.db.unsafeExecute(
      '''
UPDATE "dw_push_delivery"
SET
  "leaseId" = NULL,
  "leaseExpiresAt" = NULL
WHERE "id" = @deliveryId
  AND "leaseId" = @leaseId
''',
      transaction: transaction,
      parameters: QueryParameters.named({
        'deliveryId': deliveryId,
        'leaseId': leaseId,
      }),
    );
  }

  Future<_DeliveryOutcome> _recoverAfterException(
    Session session,
    DwPushDelivery claimed,
    String leaseId,
    Object error, {
    required bool sendStarted,
  }) async {
    final runtimeError = dwPushSafeExceptionCode(error);
    try {
      return await session.db.transaction((transaction) async {
        final delivery = await DwPushDelivery.db.findById(
          session,
          claimed.id!,
          transaction: transaction,
          lockMode: LockMode.forUpdate,
        );
        if (delivery == null || delivery.leaseId != leaseId) {
          return _DeliveryOutcome.ignored(runtimeError: runtimeError);
        }
        final message = await DwPushMessage.db.findById(
          session,
          delivery.messageId,
          transaction: transaction,
        );
        final category = message?.category ?? '_missing_message';
        final completedAttempts = delivery.attemptCount + (sendStarted ? 1 : 0);
        final retryDelay = sendStarted
            ? _config.retryPolicy.delayAfterFailure(completedAttempts)
            : delivery.attemptCount == 0
            ? _config.retryPolicy.initialDelay
            : _config.retryPolicy.delayAfterFailure(delivery.attemptCount) ??
                  _config.retryPolicy.maximumDelay;
        if (retryDelay == null ||
            message == null ||
            !message.expiresAt.isAfter(_config.clock())) {
          await DwPushDelivery.db.deleteRow(
            session,
            delivery,
            transaction: transaction,
          );
          return _DeliveryOutcome(
            category: category,
            metric: DwPushMetricOutcome.failed,
            removed: true,
            runtimeError: runtimeError,
          );
        }
        await _reschedule(
          session,
          delivery,
          retryDelay,
          runtimeError,
          transaction,
          attemptCount: sendStarted ? completedAttempts : null,
        );
        return _DeliveryOutcome(
          category: category,
          metric: DwPushMetricOutcome.retryScheduled,
          retried: true,
          runtimeError: runtimeError,
        );
      });
    } catch (recoveryError, stackTrace) {
      session.log(
        'Failed to recover push delivery ${claimed.id}; its lease will expire '
        '(${dwPushSafeExceptionCode(recoveryError)})',
        level: LogLevel.error,
        stackTrace: stackTrace,
      );
      return _DeliveryOutcome.ignored(runtimeError: runtimeError);
    }
  }

  Future<void> _reschedule(
    Session session,
    DwPushDelivery delivery,
    Duration delay,
    String error,
    Transaction transaction, {
    int? attemptCount,
  }) async {
    await DwPushDelivery.db.updateById(
      session,
      delivery.id!,
      columnValues: (table) => [
        table.availableAt(_config.clock().add(delay)),
        table.leaseId(null),
        table.leaseExpiresAt(null),
        table.lastError(_truncate(error, 2000)),
        if (attemptCount != null) table.attemptCount(attemptCount),
      ],
      transaction: transaction,
    );
  }

  DwPushPayload _payload(DwPushMessage message) => DwPushPayload(
    messageId: message.id!,
    category: message.category,
    title: message.title,
    body: message.body,
    imageUrl: message.imageUrl,
    data: Map.unmodifiable(message.data ?? const {}),
    expiresAt: message.expiresAt,
  );

  void _verifyTransportResult(
    DwPushDeliveryAttempt attempt,
    DwPushTransportResult result,
  ) {
    const equality = SetEquality<String>();
    final expected = attempt.targets.toSet();
    final actual = result.results.map((item) => item.target).toSet();
    if (!equality.equals(expected, actual)) {
      throw StateError(
        'Push transport must return exactly one result for every target',
      );
    }
  }

  String _transportError(DwPushTransportResult result) {
    final codes = result.results
        .map((item) => item.errorCode)
        .whereType<String>()
        .toSet();
    return codes.isEmpty ? 'Retryable push transport failure' : codes.join(',');
  }

  Future<void> _invalidateBestEffort(
    Session session,
    _DeliveryOutcome outcome,
  ) async {
    if (outcome.recipientId == null || outcome.invalidTargets.isEmpty) return;
    try {
      await session.db.transaction((transaction) async {
        final acquired = await _recipientLock.tryAcquire(
          session,
          recipientId: outcome.recipientId!,
          transaction: transaction,
        );
        if (!acquired) return;
        await _config.recipientResolver.invalidateTargets(
          session,
          recipientId: outcome.recipientId!,
          targets: outcome.invalidTargets,
          transaction: transaction,
        );
      });
    } catch (error, stackTrace) {
      session.log(
        'Failed to invalidate push provider targets '
        '(${dwPushSafeExceptionCode(error)})',
        level: LogLevel.warning,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _recordMetrics(
    Session session,
    List<_DeliveryOutcome> outcomes,
  ) async {
    final counts = <(String, DwPushMetricOutcome), int>{};
    for (final outcome in outcomes) {
      final metric = outcome.metric;
      if (metric == null) continue;
      counts.update(
        (outcome.category, metric),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    for (final entry in counts.entries) {
      try {
        await _metrics.increment(
          session,
          category: entry.key.$1,
          outcome: entry.key.$2,
          amount: entry.value,
        );
      } catch (error, stackTrace) {
        session.log(
          'Failed to record push delivery metric '
          '(${dwPushSafeExceptionCode(error)})',
          level: LogLevel.warning,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _bestEffortRuntime(
    Session session,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      session.log(
        'Failed to update push runtime state '
        '(${dwPushSafeExceptionCode(error)})',
        level: LogLevel.warning,
        stackTrace: stackTrace,
      );
    }
  }

  String _newLeaseId() {
    final bytes = List.generate(16, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _truncate(String value, int maximum) =>
      value.length <= maximum ? value : value.substring(0, maximum);
}

final class _DeliveryOutcome {
  const _DeliveryOutcome({
    required this.category,
    required this.metric,
    this.delivered = false,
    this.retried = false,
    this.removed = false,
    this.invalidTargets = const [],
    this.recipientId,
    this.runtimeError,
  });

  const _DeliveryOutcome.ignored({this.runtimeError})
    : category = '',
      metric = null,
      delivered = false,
      retried = false,
      removed = false,
      invalidTargets = const [],
      recipientId = null;

  final String category;
  final DwPushMetricOutcome? metric;
  final bool delivered;
  final bool retried;
  final bool removed;
  final List<String> invalidTargets;
  final int? recipientId;
  final String? runtimeError;
}
