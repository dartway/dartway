import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_alerts.dart';
import '../alerts/dw_logger.dart';
import '../auth/dw_accounts.dart';
import '../auth/dw_auth.dart';
import '../channels/dw_hub.dart';
import '../context/dw_context.dart';
import '../jobs/dw_jobs.dart';
import '../protocol/dw_connection.dart';

/// What the running parts of a server share: the database, the hub, the alert
/// gate and the way contexts are made.
@internal
final class DwRuntime {
  DwRuntime({
    required this.protocol,
    required this.auth,
    required this.db,
    required this.hub,
    required this.alerts,
    required this.log,
    required this.jobsFor,
  });

  final DwProtocol protocol;
  final DwAuth auth;
  final DwDb db;
  final DwHub hub;
  final DwAlertGate alerts;
  final DwLogger log;
  final DwJobs Function(DwCallContext ctx) jobsFor;

  DwCallContext context({
    required String scope,
    DwDb? db,
    int? accountId,
    int? keyId,
    DwConnection? connection,
  }) => DwCallContext(
    db: db ?? this.db,
    protocol: protocol,
    log: log.scoped(scope),
    jobs: jobsFor,
    accounts: (ctx) => DwAccounts.ofContext(ctx, auth, hub),
    isPublishable: (item) => protocol.knows(item.runtimeType),
    accountId: accountId,
    keyId: keyId,
    connection: connection,
  );

  /// Delivers the committed effects of [ctx].
  void deliver(DwCallContext ctx) {
    if (ctx.rootEffects.isEmpty) return;
    hub.deliver(ctx.rootEffects);
    ctx.rootEffects.clear();
  }
}

/// A 32-bit FNV-1a hash of [text], for advisory lock keys. Collisions only
/// serialise unrelated work; they never merge it.
@internal
int dwLockKey(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
    hash ^= unit >> 8;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  // Signed int4, the argument type of pg_advisory_xact_lock(int4, int4).
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}

/// Advisory lock namespaces of the framework (first argument of the two-key
/// lock). Projects should keep clear of the 0x4457xxxx range.
@internal
abstract final class DwLockSpace {
  static const int identifier = 0x44570001;
  static const int idempotencyKey = 0x44570002;
}

/// Whether [error] means "run the transaction again".
@internal
bool dwIsRetryableTransactionError(Object error) =>
    error is DwSerializationFailure ||
    (error is DwDatabaseException && error.code == '40P01');
