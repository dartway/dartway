import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Coordinates delivery with destructive app operations such as account deletion.
///
/// A thin wrapper over the framework's [DwAdvisoryLock] pinned to the push
/// module's own advisory namespace, so every recipient-scoped guard in the push
/// engine — worker claim, provider send, and `withRecipientLock` — takes the
/// exact same lock and cannot race each other.
final class DwPushRecipientLock {
  const DwPushRecipientLock();

  /// The advisory-lock namespace for recipient-scoped push work.
  ///
  /// The push module owns this number rather than the core reserving it: core
  /// keeps its own low-numbered namespaces (see [DwAdvisoryLockNamespace]) and a
  /// consumer of the primitive picks a value well clear of that range. `"PUSH"`
  /// in ASCII is a stable, collision-unlikely choice.
  ///
  /// The worker claim query takes this lock inline in raw SQL, so it must use
  /// the two-argument `pg_try_advisory_xact_lock(namespace, key)` form with this
  /// same namespace — the two-argument and single-argument advisory-lock spaces
  /// do not conflict in PostgreSQL.
  static const int namespace = 0x50555348; // "PUSH"

  static const DwAdvisoryLock _lock = DwAdvisoryLock();

  Future<bool> tryAcquire(
    Session session, {
    required int recipientId,
    required Transaction transaction,
  }) => _lock.tryLock(
    session,
    namespace: namespace,
    key: recipientId,
    transaction: transaction,
  );

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

/// Thrown when a recipient advisory lock could not be acquired within its wait
/// budget. Failing to take the lock is not an error for a guard, but a caller
/// that must make progress (account deletion) surfaces it instead of silently
/// proceeding without the guard.
final class DwAdvisoryLockUnavailableException implements Exception {
  const DwAdvisoryLockUnavailableException({
    required this.namespace,
    required this.key,
    required this.waited,
  });

  final int namespace;
  final int key;
  final Duration waited;

  @override
  String toString() =>
      'DwAdvisoryLockUnavailableException(namespace: $namespace, '
      'key: $key, waited: $waited)';
}
