// ignore_for_file: invalid_use_of_internal_member

import 'dart:collection';

import 'package:dartway_push_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_push_contracts.dart';
import 'dw_push_recipient_lock.dart';

/// Bounded generic state for app-owned throttling and aggregation decisions.
final class DwPushRecipientStateStore {
  const DwPushRecipientStateStore({
    required DwPushConfig config,
    required DwPushRecipientLock recipientLock,
  }) : _config = config,
       _recipientLock = recipientLock;

  final DwPushConfig _config;
  final DwPushRecipientLock _recipientLock;

  /// Atomically opens a throttle window when its previous window has elapsed.
  Future<bool> tryAcquire(
    Session session, {
    required int recipientId,
    required String stateKey,
    required Duration interval,
    Map<String, String> metadata = const {},
    Transaction? transaction,
  }) async {
    final normalizedKey = stateKey.trim();
    if (recipientId <= 0) {
      throw ArgumentError.value(recipientId, 'recipientId', 'Must be positive');
    }
    if (normalizedKey.isEmpty || normalizedKey.length > 100) {
      throw ArgumentError.value(
        stateKey,
        'stateKey',
        'Must contain between 1 and 100 characters',
      );
    }
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive');
    }
    if (metadata.length > 50) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Must contain at most 50 entries',
      );
    }
    var metadataCharacters = 0;
    for (final entry in metadata.entries) {
      if (entry.key.isEmpty || entry.key.length > 128) {
        throw ArgumentError.value(
          entry.key,
          'metadata key',
          'Must contain between 1 and 128 characters',
        );
      }
      if (entry.value.length > 4096) {
        throw ArgumentError.value(
          entry.value,
          'metadata value',
          'Must contain at most 4096 characters',
        );
      }
      metadataCharacters += entry.key.length + entry.value.length;
    }
    if (metadataCharacters > 16384) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Keys and values must contain at most 16384 characters in total',
      );
    }
    final safeMetadata = UnmodifiableMapView(Map.of(metadata));

    Future<bool> action(Transaction tx) async {
      final recipientLockAcquired = await _recipientLock.tryAcquire(
        session,
        recipientId: recipientId,
        transaction: tx,
      );
      if (!recipientLockAcquired) return false;
      final now = _config.clock();
      final existing = await DwPushRecipientState.db.findFirstRow(
        session,
        where: (table) =>
            table.recipientId.equals(recipientId) &
            table.stateKey.equals(normalizedKey),
        transaction: tx,
        lockMode: LockMode.forUpdate,
      );
      if (existing != null && existing.nextAllowedAt.isAfter(now)) {
        return false;
      }

      final nextAllowedAt = now.add(interval);
      if (existing == null) {
        await DwPushRecipientState.db.insertRow(
          session,
          DwPushRecipientState(
            recipientId: recipientId,
            stateKey: normalizedKey,
            nextAllowedAt: nextAllowedAt,
            metadata: safeMetadata.isEmpty ? null : safeMetadata,
            updatedAt: now,
          ),
          transaction: tx,
        );
      } else {
        await DwPushRecipientState.db.updateById(
          session,
          existing.id!,
          columnValues: (table) => [
            table.nextAllowedAt(nextAllowedAt),
            table.metadata(safeMetadata.isEmpty ? null : safeMetadata),
            table.updatedAt(now),
          ],
          transaction: tx,
        );
      }
      return true;
    }

    return transaction == null
        ? session.db.transaction(action)
        : action(transaction);
  }

  Future<int> clearRecipient(
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
      final deleted = await DwPushRecipientState.db.deleteWhere(
        session,
        where: (table) => table.recipientId.equals(recipientId),
        transaction: tx,
      );
      return deleted.length;
    }

    return transaction == null
        ? session.db.transaction(action)
        : action(transaction);
  }
}
