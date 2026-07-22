// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/serverpod.dart';

/// Namespaced, transaction-scoped PostgreSQL advisory lock.
///
/// Acquisition is always non-blocking so a busy logical resource never holds
/// a database connection waiting inside PostgreSQL.
final class DwAdvisoryLock {
  DwAdvisoryLock({required this.namespace}) {
    if (namespace < 0 || namespace > 0x7fffffff) {
      throw ArgumentError.value(
        namespace,
        'namespace',
        'Must fit a positive signed 32-bit integer',
      );
    }
  }

  final int namespace;

  Future<bool> tryAcquire(
    Session session, {
    required int key,
    required Transaction transaction,
  }) async {
    final result = await session.db.unsafeQuery(
      '''
SELECT pg_try_advisory_xact_lock(
  @key::bigint # (@namespace::bigint << 32)
)
''',
      transaction: transaction,
      parameters: QueryParameters.named({'namespace': namespace, 'key': key}),
    );
    final acquired = result.single.single;
    if (acquired is! bool) {
      throw StateError('PostgreSQL returned an invalid advisory lock result');
    }
    return acquired;
  }
}

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
