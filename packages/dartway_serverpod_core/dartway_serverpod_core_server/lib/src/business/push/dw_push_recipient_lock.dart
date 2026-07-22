import 'package:dartway_serverpod_core_server/src/business/concurrency/dw_advisory_lock.dart';
import 'package:serverpod/serverpod.dart';

/// Coordinates delivery with destructive app operations such as account deletion.
final class DwPushRecipientLock {
  DwPushRecipientLock() : _lock = DwAdvisoryLock(namespace: namespace);

  // A fixed namespace separates these keys from unrelated single-key locks.
  static const int namespace = 0x44575053; // "DWPS"
  final DwAdvisoryLock _lock;

  Future<bool> tryAcquire(
    Session session, {
    required int recipientId,
    required Transaction transaction,
  }) => _lock.tryAcquire(session, key: recipientId, transaction: transaction);

  Future<void> acquireOrThrow(
    Session session, {
    required int recipientId,
    required Transaction transaction,
  }) async {
    if (await tryAcquire(
      session,
      recipientId: recipientId,
      transaction: transaction,
    )) {
      return;
    }
    throw DwAdvisoryLockUnavailableException(
      namespace: namespace,
      key: recipientId,
      waited: Duration.zero,
    );
  }
}
