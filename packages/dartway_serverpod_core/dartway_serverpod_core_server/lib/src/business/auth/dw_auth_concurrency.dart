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
/// These helpers make the decisive step atomic in the database, where it has to
/// be. Nothing above them can substitute for it.
abstract final class DwAuthConcurrency {
  /// Takes a row lock on the auth request for the rest of [transaction], so
  /// that concurrent verification attempts against the same request run one
  /// after another instead of all reading a stale attempt count.
  ///
  /// Requires an active transaction: `SELECT ... FOR UPDATE` outside one
  /// releases the lock immediately and would silently buy nothing — hence the
  /// hard failure rather than a quiet no-op.
  static Future<void> lockAuthRequest(
    Session session,
    int authRequestId, {
    required Transaction? transaction,
  }) async {
    if (transaction == null) {
      throw StateError(
        'lockAuthRequest requires an active transaction: without one the row '
        'lock is released immediately and the attempt limit stays bypassable.',
      );
    }

    await session.db.unsafeQuery(
      'SELECT "id" FROM "dw_auth_request" WHERE "id" = @id FOR UPDATE',
      parameters: QueryParameters.named({'id': authRequestId}),
      transaction: transaction,
    );
  }

  /// Serializes auth requests for one [userIdentifier] for the rest of
  /// [transaction].
  ///
  /// The rate limit counts recent requests for an identifier and then creates
  /// one more — the same read-then-write shape, but there is no single row to
  /// lock, since the rows being counted do not exist yet. A transaction-scoped
  /// advisory lock keyed on the identifier gives the same serialization and is
  /// released automatically when the transaction ends.
  static Future<void> lockIdentifier(
    Session session,
    String userIdentifier, {
    required Transaction? transaction,
  }) async {
    if (transaction == null) {
      throw StateError(
        'lockIdentifier requires an active transaction: an advisory lock taken '
        'outside one is released immediately and the rate limit stays racy.',
      );
    }

    await session.db.unsafeQuery(
      'SELECT pg_advisory_xact_lock(hashtext(@identifier)::bigint)',
      parameters: QueryParameters.named({'identifier': userIdentifier}),
      transaction: transaction,
    );
  }

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
