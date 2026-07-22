// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';

final class DwPushRuntime {
  const DwPushRuntime(this._clock);

  final DwPushClock _clock;

  Future<bool> isPaused(Session session, String workerName) async {
    workerName = _normalizeWorkerName(workerName);
    final state = await DwPushRuntimeState.db.findFirstRow(
      session,
      where: (table) => table.workerName.equals(workerName),
    );
    if (state == null || !state.isPaused) return false;
    final pausedUntil = state.pausedUntil;
    final now = _clock();
    if (pausedUntil == null || pausedUntil.isAfter(now)) return true;
    await session.db.unsafeExecute('''
UPDATE "dw_push_runtime_state"
SET
  "isPaused" = FALSE,
  "pausedUntil" = NULL,
  "updatedAt" = @now
WHERE "workerName" = @workerName
  AND "isPaused" = TRUE
  AND "pausedUntil" IS NOT NULL
  AND "pausedUntil" <= @now
''', parameters: QueryParameters.named({'workerName': workerName, 'now': now}));
    return false;
  }

  /// Definitive pause check used by the claim transaction.
  ///
  /// The runtime row is locked until claim commits. A concurrent [pause]
  /// therefore either happens before this check (and prevents the claim) or
  /// after the claim transaction (and stops subsequent claims).
  Future<bool> isPausedForClaim(
    Session session,
    String workerName, {
    required Transaction transaction,
  }) async {
    workerName = _normalizeWorkerName(workerName);
    final now = _clock();
    await session.db.unsafeExecute(
      '''
INSERT INTO "dw_push_runtime_state"
  ("workerName", "isPaused", "updatedAt")
VALUES
  (@workerName, FALSE, @now)
ON CONFLICT ("workerName")
DO NOTHING
''',
      transaction: transaction,
      parameters: QueryParameters.named({'workerName': workerName, 'now': now}),
    );
    final state = await DwPushRuntimeState.db.findFirstRow(
      session,
      where: (table) => table.workerName.equals(workerName),
      transaction: transaction,
      lockMode: LockMode.forUpdate,
    );
    if (state == null || !state.isPaused) return false;
    final pausedUntil = state.pausedUntil;
    if (pausedUntil == null || pausedUntil.isAfter(now)) return true;
    await DwPushRuntimeState.db.updateById(
      session,
      state.id!,
      columnValues: (table) => [
        table.isPaused(false),
        table.pausedUntil(null),
        table.updatedAt(now),
      ],
      transaction: transaction,
    );
    return false;
  }

  Future<void> pause(
    Session session, {
    String workerName = 'default',
    DateTime? until,
  }) => _upsert(
    session,
    workerName: workerName,
    assignments: '''
"isPaused" = TRUE,
"pausedUntil" = @pausedUntil,
"updatedAt" = CASE
  WHEN "isPaused"
    AND ("pausedUntil" IS NULL OR "pausedUntil" > @now)
  THEN "updatedAt"
  ELSE @now
END
''',
    parameters: {'pausedUntil': until?.toUtc()},
  );

  Future<Duration> resume(
    Session session, {
    String workerName = 'default',
    bool extendQueuedMessageLifetime = false,
  }) async {
    workerName = _normalizeWorkerName(workerName);
    return session.db.transaction((transaction) async {
      final state = await DwPushRuntimeState.db.findFirstRow(
        session,
        where: (table) => table.workerName.equals(workerName),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
      );
      if (state == null || !state.isPaused) return Duration.zero;

      final now = _clock();
      final pauseEndedAt =
          state.pausedUntil != null && state.pausedUntil!.isBefore(now)
          ? state.pausedUntil!
          : now;
      final pausedFor = pauseEndedAt.isAfter(state.updatedAt)
          ? pauseEndedAt.difference(state.updatedAt)
          : Duration.zero;
      if (extendQueuedMessageLifetime && pausedFor > Duration.zero) {
        final parameters = QueryParameters.named({
          'pauseStartedAt': state.updatedAt,
          'pauseEndedAt': pauseEndedAt,
        });
        await session.db.unsafeExecute(
          '''
WITH blocked AS MATERIALIZED (
  SELECT
    message."id",
    @pauseEndedAt - GREATEST(
      message."createdAt",
      message."scheduledAt",
      @pauseStartedAt
    ) AS extension
  FROM "dw_push_message" AS message
  WHERE message."expiresAt" > @pauseStartedAt
    AND GREATEST(
      message."createdAt",
      message."scheduledAt",
      @pauseStartedAt
    ) < @pauseEndedAt
    AND EXISTS (
      SELECT 1
      FROM "dw_push_delivery" AS delivery
      WHERE delivery."messageId" = message."id"
    )
)
UPDATE "dw_push_message" AS message
SET
  "scheduledAt" = message."scheduledAt" + blocked.extension,
  "expiresAt" = message."expiresAt" + blocked.extension
FROM blocked
WHERE message."id" = blocked."id"
''',
          transaction: transaction,
          parameters: parameters,
        );
        await session.db.unsafeExecute(
          '''
WITH blocked AS MATERIALIZED (
  SELECT
    delivery."id",
    @pauseEndedAt - GREATEST(
      delivery."createdAt",
      delivery."availableAt",
      @pauseStartedAt
    ) AS extension
  FROM "dw_push_delivery" AS delivery
  JOIN "dw_push_message" AS message
    ON message."id" = delivery."messageId"
  WHERE message."expiresAt" > @pauseStartedAt
    AND GREATEST(
      delivery."createdAt",
      delivery."availableAt",
      @pauseStartedAt
    ) < @pauseEndedAt
)
UPDATE "dw_push_delivery" AS delivery
SET "availableAt" = delivery."availableAt" + blocked.extension
FROM blocked
WHERE delivery."id" = blocked."id"
''',
          transaction: transaction,
          parameters: parameters,
        );
      }

      await DwPushRuntimeState.db.updateById(
        session,
        state.id!,
        columnValues: (table) => [
          table.isPaused(false),
          table.pausedUntil(null),
          table.updatedAt(now),
        ],
        transaction: transaction,
      );
      return pausedFor;
    });
  }

  Future<void> markClaimed(Session session, {required String workerName}) =>
      _upsert(
        session,
        workerName: workerName,
        assignments: '''
"lastClaimedAt" = @now,
"updatedAt" = @now
''',
      );

  Future<void> markCompleted(Session session, {required String workerName}) =>
      _upsert(
        session,
        workerName: workerName,
        assignments: '''
"lastCompletedAt" = @now,
"lastError" = NULL,
"updatedAt" = @now
''',
      );

  Future<void> markError(
    Session session, {
    required String workerName,
    required String error,
  }) => _upsert(
    session,
    workerName: workerName,
    assignments: '''
"lastErrorAt" = @now,
"lastError" = @error,
"updatedAt" = @now
''',
    parameters: {'error': error},
  );

  Future<void> _upsert(
    Session session, {
    required String workerName,
    required String assignments,
    Map<String, Object?> parameters = const {},
  }) async {
    workerName = _normalizeWorkerName(workerName);
    final now = _clock();
    await session.db.unsafeExecute('''
INSERT INTO "dw_push_runtime_state"
  ("workerName", "isPaused", "updatedAt")
VALUES
  (@workerName, FALSE, @now)
ON CONFLICT ("workerName")
DO NOTHING
''', parameters: QueryParameters.named({'workerName': workerName, 'now': now}));
    await session.db.unsafeExecute(
      '''
UPDATE "dw_push_runtime_state"
SET
$assignments
WHERE "workerName" = @workerName
''',
      parameters: QueryParameters.named({
        'workerName': workerName,
        'now': now,
        ...parameters,
      }),
    );
  }

  static String _normalizeWorkerName(String workerName) {
    final normalized = workerName.trim();
    if (normalized.isEmpty || normalized.length > 100) {
      throw ArgumentError.value(
        workerName,
        'workerName',
        'Must contain between 1 and 100 characters',
      );
    }
    return normalized;
  }
}
