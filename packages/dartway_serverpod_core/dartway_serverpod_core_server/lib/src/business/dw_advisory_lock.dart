import 'package:serverpod/serverpod.dart';

/// Framework-reserved namespaces for [DwAdvisoryLock].
///
/// Every subsystem that takes advisory locks gets its own namespace so their
/// keys cannot collide: two unrelated features that both lock on "user 42" must
/// not block each other. The framework reserves the low numbers below; an
/// application taking its own advisory locks should pick numbers well clear of
/// this range.
abstract final class DwAdvisoryLockNamespace {
  static const int authRequest = 1;
  static const int authIdentifier = 2;
}

/// Non-blocking, transaction-scoped Postgres advisory locks.
///
/// Reached through the core object — `dw.advisoryLock.tryLock(...)` — never
/// constructed or called statically, so every framework service lives under the
/// one `dw` root (the same name in the framework and in the app).
///
/// An advisory lock makes a decision atomic across concurrent requests when
/// there is no row to lock — the thing being counted or claimed may not exist
/// yet. It is keyed on a `(namespace, key)` pair instead of a table row; see
/// [DwAdvisoryLockNamespace] for why the namespace matters.
///
/// The lock is deliberately **non-blocking** ([tryLock] returns `false` rather
/// than waiting) and **transaction-scoped** (released automatically at
/// commit/rollback, never leaked). A blocking lock would hold a pooled
/// connection while it queues, so an attacker hammering one key could exhaust
/// the connection pool and take the server down — trading a race for a denial
/// of service. Failing to take the lock is not an error condition: it means
/// someone else is already handling this key, which for a guard is the answer,
/// not a fault.
///
/// This generalises the guard first written for the auth flow (see
/// `DwAuthConcurrency`, which now delegates here) so any subsystem — push
/// delivery, account deletion, outbound jobs — can reuse the same primitive
/// instead of hand-rolling raw advisory-lock SQL.
class DwAdvisoryLock {
  const DwAdvisoryLock();

  /// Tries to take the advisory lock for ([namespace], [key]) inside
  /// [transaction]. Returns `true` when this caller took the lock, `false` when
  /// it is already held by someone else.
  ///
  /// [key] must be an `int` (used directly) or a `String` (hashed to a 32-bit
  /// key with Postgres `hashtext`). A transaction is required: a
  /// transaction-scoped advisory lock taken outside one is released
  /// immediately, so the guard would quietly buy nothing — passing a `null`
  /// transaction throws rather than lock nothing silently.
  Future<bool> tryLock(
    Session session, {
    required int namespace,
    required Object key,
    required Transaction? transaction,
  }) async {
    if (transaction == null) {
      throw StateError(
        'DwAdvisoryLock.tryLock requires an active transaction: a '
        'transaction-scoped advisory lock taken outside one is released '
        'immediately, so the guard would quietly buy nothing.',
      );
    }

    final String keyExpression;
    final Map<String, Object?> parameters;
    if (key is int) {
      keyExpression = '@key';
      parameters = {'key': key};
    } else if (key is String) {
      // hashtext returns a 32-bit int, matching the two-argument
      // pg_try_advisory_xact_lock(int4, int4) form used below.
      keyExpression = 'hashtext(@key)';
      parameters = {'key': key};
    } else {
      throw ArgumentError.value(key, 'key', 'must be an int or a String');
    }

    final result = await session.db.unsafeQuery(
      'SELECT pg_try_advisory_xact_lock($namespace, $keyExpression)',
      parameters: QueryParameters.named(parameters),
      transaction: transaction,
    );

    return result.first.first as bool;
  }
}
