// ignore_for_file: invalid_use_of_internal_member

import 'package:collection/collection.dart';
import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';
import 'dw_push_metrics.dart';
import 'dw_push_recipient_lock.dart';

final class DwPushQueue {
  DwPushQueue({
    required DwPushConfig config,
    required DwPushMetrics metrics,
    required DwPushRecipientLock recipientLock,
  }) : _config = config,
       _metrics = metrics,
       _recipientLock = recipientLock;

  final DwPushConfig _config;
  final DwPushMetrics _metrics;
  final DwPushRecipientLock _recipientLock;

  Future<DwPushQueueHealth> health(Session session) async {
    final pendingDeliveries = await DwPushDelivery.db.count(session);
    final oldest = await DwPushDelivery.db.findFirstRow(
      session,
      orderBy: (table) => table.availableAt,
    );
    return DwPushQueueHealth(
      pendingDeliveries: pendingDeliveries,
      oldestAvailableAt: oldest?.availableAt,
    );
  }

  /// Stores content once and inserts only missing recipient deliveries.
  Future<DwPushEnqueueResult> enqueue(
    Session session, {
    required DwPushMessageInput message,
    required Iterable<int> recipientIds,
    Transaction? transaction,
  }) async {
    final recipients = recipientIds.toSet();
    if (recipients.isEmpty) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Must contain at least one recipient',
      );
    }
    if (recipients.any((recipientId) => recipientId <= 0)) {
      throw ArgumentError.value(
        recipientIds,
        'recipientIds',
        'Recipient IDs must be positive',
      );
    }

    Future<DwPushEnqueueResult> action(Transaction tx) async {
      final now = _config.clock();
      final insertedMessages = await DwPushMessage.db.insert(
        session,
        [
          DwPushMessage(
            deduplicationKey: message.deduplicationKey,
            category: message.category,
            title: message.title,
            body: message.body,
            imageUrl: message.imageUrl,
            data: message.data.isEmpty ? null : message.data,
            createdAt: now,
            scheduledAt: message.scheduledAt,
            expiresAt: message.expiresAt,
          ),
        ],
        transaction: tx,
        ignoreConflicts: true,
      );

      final storedMessage =
          insertedMessages.firstOrNull ??
          await DwPushMessage.db.findFirstRow(
            session,
            where: (table) =>
                table.deduplicationKey.equals(message.deduplicationKey),
            transaction: tx,
            lockMode: LockMode.forUpdate,
          );
      if (storedMessage == null) {
        throw StateError('Failed to load an idempotent push message');
      }
      _verifySameMessage(storedMessage, message);

      final messageId = storedMessage.id!;
      if (storedMessage.audienceClosedAt != null ||
          !storedMessage.expiresAt.isAfter(now)) {
        return DwPushEnqueueResult(
          messageId: messageId,
          insertedDeliveries: 0,
          // A terminal message suppresses the complete requested audience,
          // even when no physical membership or delivery row remains.
          existingDeliveries: recipients.length,
        );
      }

      var insertedDeliveryCount = 0;
      final recipientList = recipients.toList(growable: false);
      for (
        var offset = 0;
        offset < recipientList.length;
        offset += _config.enqueueChunkSize
      ) {
        final end = (offset + _config.enqueueChunkSize).clamp(
          0,
          recipientList.length,
        );
        final recipientChunk = recipientList.sublist(offset, end);
        final insertedMemberships = await DwPushMessageRecipient.db.insert(
          session,
          [
            for (final recipientId in recipientChunk)
              DwPushMessageRecipient(
                messageId: messageId,
                recipientId: recipientId,
                createdAt: now,
              ),
          ],
          transaction: tx,
          ignoreConflicts: true,
        );
        if (insertedMemberships.isEmpty) continue;
        final inserted = await DwPushDelivery.db.insert(
          session,
          [
            for (final membership in insertedMemberships)
              DwPushDelivery(
                messageId: messageId,
                recipientId: membership.recipientId,
                availableAt: message.scheduledAt,
                createdAt: now,
              ),
          ],
          transaction: tx,
          ignoreConflicts: true,
        );
        insertedDeliveryCount += inserted.length;
      }

      await _metrics.increment(
        session,
        category: message.category,
        outcome: DwPushMetricOutcome.queued,
        amount: insertedDeliveryCount,
        transaction: tx,
      );

      return DwPushEnqueueResult(
        messageId: messageId,
        insertedDeliveries: insertedDeliveryCount,
        existingDeliveries: recipients.length - insertedDeliveryCount,
      );
    }

    final result = transaction == null
        ? await session.db.transaction(action)
        : await action(transaction);

    return result;
  }

  Future<int> cancelMessage(
    Session session,
    int messageId, {
    Transaction? transaction,
  }) async {
    Future<int> action(Transaction tx) async {
      final message = await DwPushMessage.db.findById(
        session,
        messageId,
        transaction: tx,
        lockMode: LockMode.forUpdate,
      );
      if (message != null && message.audienceClosedAt == null) {
        await DwPushMessage.db.updateById(
          session,
          messageId,
          columnValues: (table) => [table.audienceClosedAt(_config.clock())],
          transaction: tx,
        );
      }
      final removed = await DwPushDelivery.db.deleteWhere(
        session,
        where: (table) => table.messageId.equals(messageId),
        transaction: tx,
      );
      if (message != null && removed.isNotEmpty) {
        await _metrics.increment(
          session,
          category: message.category,
          outcome: DwPushMetricOutcome.cancelled,
          amount: removed.length,
          transaction: tx,
        );
      }
      return removed.length;
    }

    return transaction == null
        ? session.db.transaction(action)
        : action(transaction);
  }

  /// Cancels an idempotently enqueued message without exposing module tables.
  Future<int> cancelByDeduplicationKey(
    Session session,
    String deduplicationKey, {
    Transaction? transaction,
  }) async {
    final normalizedKey = deduplicationKey.trim();
    if (normalizedKey.isEmpty || normalizedKey.length > 200) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
        'Must contain between 1 and 200 characters',
      );
    }

    Future<int> action(Transaction tx) async {
      final message = await DwPushMessage.db.findFirstRow(
        session,
        where: (table) => table.deduplicationKey.equals(normalizedKey),
        transaction: tx,
        lockMode: LockMode.forUpdate,
      );
      if (message == null) return 0;
      return cancelMessage(session, message.id!, transaction: tx);
    }

    return transaction == null
        ? session.db.transaction(action)
        : action(transaction);
  }

  Future<int> cancelRecipient(
    Session session,
    int recipientId, {
    Transaction? transaction,
  }) async {
    if (recipientId <= 0) {
      throw ArgumentError.value(recipientId, 'recipientId', 'Must be positive');
    }
    Future<int> action(Transaction tx) async {
      await _recipientLock.acquireOrThrow(
        session,
        recipientId: recipientId,
        transaction: tx,
      );
      final removedByCategory = await session.db.unsafeQuery(
        '''
WITH removed AS (
  DELETE FROM "dw_push_delivery"
  WHERE "recipientId" = @recipientId
  RETURNING "messageId"
)
SELECT message."category", COUNT(*)::bigint
FROM removed
JOIN "dw_push_message" AS message
  ON message."id" = removed."messageId"
GROUP BY message."category"
''',
        transaction: tx,
        parameters: QueryParameters.named({'recipientId': recipientId}),
      );
      var removedCount = 0;
      for (final row in removedByCategory) {
        final amount = row[1] as int;
        removedCount += amount;
        await _metrics.increment(
          session,
          category: row[0] as String,
          outcome: DwPushMetricOutcome.cancelled,
          amount: amount,
          transaction: tx,
        );
      }
      await DwPushMessageRecipient.db.deleteWhere(
        session,
        where: (table) => table.recipientId.equals(recipientId),
        transaction: tx,
      );
      return removedCount;
    }

    return transaction == null
        ? session.db.transaction(action)
        : action(transaction);
  }

  void _verifySameMessage(DwPushMessage stored, DwPushMessageInput input) {
    const mapEquality = MapEquality<String, String>();
    if (stored.category != input.category ||
        stored.title != input.title ||
        stored.body != input.body ||
        stored.imageUrl != input.imageUrl ||
        !mapEquality.equals(stored.data ?? const {}, input.data)) {
      throw StateError(
        'Push deduplication key "${input.deduplicationKey}" was reused '
        'with different content',
      );
    }
  }
}
