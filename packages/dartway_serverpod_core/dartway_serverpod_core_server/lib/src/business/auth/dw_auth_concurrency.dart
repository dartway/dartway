import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

/// Database-level guards for the auth flow.
///
/// Every auth limit — verification attempts, request rate, one-time access
/// tokens — is decided by reading state and then writing it back. Under
/// Postgres' default READ COMMITTED isolation that pattern is racy: concurrent
/// requests all read the same pre-state, all pass the check and all proceed.
/// That is precisely how a brute-force limit gets bypassed — fire the attempts
/// in parallel and each one sees zero previous attempts.
///
/// The guards below make the decisive step atomic in the database, where it has
/// to be. They are deliberately **non-blocking**: a lock that waits would hold a
/// pooled connection while it queues, so an attacker hammering one identifier
/// could exhaust the connection pool and take the server down — trading a race
/// for a denial of service. Failing to take the lock means someone else is
/// already handling this identifier or request, which for a rate limit is not an
/// error condition but the answer: too fast.
abstract final class DwAuthConcurrency {
  /// Advisory-lock namespaces, so the two guards cannot collide on a key.
  static const _authRequestNamespace = 1;
  static const _identifierNamespace = 2;

  /// Tries to take the verification lock for one auth request.
  ///
  /// Returns `false` when another verification of the same request is already
  /// in flight — the caller must then refuse to evaluate the code, which is what
  /// stops parallel guesses from each reading a stale attempt count.
  static Future<bool> tryLockAuthRequest(
    Session session,
    int authRequestId, {
    required Transaction? transaction,
  }) => _tryAdvisoryLock(
    session,
    namespace: _authRequestNamespace,
    keyExpression: '@key',
    parameters: {'key': authRequestId},
    transaction: transaction,
    what: 'tryLockAuthRequest',
  );

  /// Tries to take the request-rate lock for one user identifier.
  ///
  /// Returns `false` when another auth request for the same identifier is
  /// already being processed. There is no row to lock here — the rows being
  /// counted do not exist yet — so the lock is keyed on a hash of the
  /// identifier.
  static Future<bool> tryLockIdentifier(
    Session session,
    String userIdentifier, {
    required Transaction? transaction,
  }) => _tryAdvisoryLock(
    session,
    namespace: _identifierNamespace,
    keyExpression: 'hashtext(@key)',
    parameters: {'key': userIdentifier},
    transaction: transaction,
    what: 'tryLockIdentifier',
  );

  /// Atomically claims a verified auth request, moving it to
  /// [DwAuthRequestStatus.completed].
  ///
  /// Returns `true` only for the caller that won the race. A second redemption
  /// of the same access token matches no rows and gets `false` — which is what
  /// makes the token single-use even when two requests arrive together.
  static Future<bool> claimVerifiedRequest(
    Session session,
    int authRequestId, {
    Transaction? transaction,
  }) async {
    final affectedRows = await session.db.unsafeExecute(
      'UPDATE "dw_auth_request" SET "status" = @completed '
      'WHERE "id" = @id AND "status" = @verified',
      parameters: QueryParameters.named({
        'id': authRequestId,
        'completed': DwAuthRequestStatus.completed.name,
        'verified': DwAuthRequestStatus.verified.name,
      }),
      transaction: transaction,
    );

    return affectedRows == 1;
  }

  static Future<bool> _tryAdvisoryLock(
    Session session, {
    required int namespace,
    required String keyExpression,
    required Map<String, Object?> parameters,
    required Transaction? transaction,
    required String what,
  }) async {
    if (transaction == null) {
      throw StateError(
        '$what requires an active transaction: a transaction-scoped advisory '
        'lock taken outside one is released immediately, so the guard would '
        'quietly buy nothing.',
      );
    }

    final result = await session.db.unsafeQuery(
      'SELECT pg_try_advisory_xact_lock($namespace, $keyExpression)',
      parameters: QueryParameters.named(parameters),
      transaction: transaction,
    );

    return result.first.first as bool;
  }
}
