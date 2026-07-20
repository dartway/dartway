import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import '../../private/dw_singleton.dart';

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
  /// Tries to take the verification lock for one auth request.
  ///
  /// Returns `false` when another verification of the same request is already
  /// in flight — the caller must then refuse to evaluate the code, which is what
  /// stops parallel guesses from each reading a stale attempt count.
  static Future<bool> tryLockAuthRequest(
    Session session,
    int authRequestId, {
    required Transaction? transaction,
  }) => dw.advisoryLock.tryLock(
    session,
    namespace: DwAdvisoryLockNamespace.authRequest,
    key: authRequestId,
    transaction: transaction,
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
  }) => dw.advisoryLock.tryLock(
    session,
    namespace: DwAdvisoryLockNamespace.authIdentifier,
    key: userIdentifier,
    transaction: transaction,
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
}
