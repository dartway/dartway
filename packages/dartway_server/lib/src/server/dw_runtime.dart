import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_alert_sink.dart';
import '../alerts/dw_server_logger.dart';
import '../auth/dw_account_service.dart';
import '../auth/dw_auth_config.dart';
import '../auth/dw_session_cache.dart';
import '../context/dw_call_context.dart';
import '../jobs/dw_job_queue.dart';
import '../live/dw_live_connection.dart';
import '../live/dw_live_hub.dart';

/// What the running parts of a server share: the database, the live hub, the
/// session cache, the alert gate, and the way contexts are made and their
/// effects delivered.
@internal
final class DwRuntime {
  DwRuntime({
    required this.protocol,
    required this.auth,
    required this.db,
    required this.hub,
    required this.sessions,
    required this.alerts,
    required this.log,
    required this.jobsFor,
  });

  final DwWireProtocol protocol;
  final DwAuthConfig auth;
  final DwDatabaseHandle db;
  final DwLiveHub hub;
  final DwSessionCache sessions;
  final DwAlertGate alerts;
  final DwServerLogger log;
  final DwJobQueue Function(DwRuntimeContext ctx) jobsFor;

  DwRuntimeContext context({
    required String scope,
    required DwContextKind kind,
    DwDatabaseHandle? db,
    int? accountId,
    int? keyId,
  }) => DwRuntimeContext(
    db: db ?? this.db,
    kind: kind,
    protocol: protocol,
    log: log.scoped(scope),
    jobs: jobsFor,
    accounts: (ctx) => DwAccountService.ofContext(ctx, this),
    accountId: accountId,
    keyId: keyId,
  );

  /// Delivers the committed effects of [ctx] and returns the updates its
  /// caller's response carries.
  ///
  /// Revocations go first, so nothing published by the same call reaches a
  /// subscriber whose access it removed — the caller's own connection
  /// included, whose response then carries only what it still listens to.
  /// [author] is the caller's live connection when the response carries the
  /// updates (see [DwLiveHub.publish]).
  DwUpdateTransport deliver(DwRuntimeContext ctx, {DwLiveConnection? author}) {
    final effects = ctx.rootEffects;
    if (effects.isEmpty) return DwUpdateTransport.empty;
    for (final keyId in effects.revokedKeys) {
      revokeKey(keyId, author: author);
    }
    for (final (channel, accountId) in effects.revocations) {
      hub.revokeChannel(channel, accountId);
    }
    final updates = hub.publish(effects.publications, author: author);
    effects.clear();
    return updates;
  }

  /// A session key was revoked and the revocation has committed: the next
  /// call with its token reads the database again, and live connections
  /// holding it lose their session.
  void revokeKey(int keyId, {DwLiveConnection? author}) {
    sessions.revoke(keyId);
    hub.revokeKey(keyId, author: author);
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
