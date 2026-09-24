import 'dart:convert';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

/// The `dw_command_outcome` row a stored outcome reads back as, for
/// `DwCallEndpoint`'s replay.
@internal
final class DwStoredOutcome {
  const DwStoredOutcome(this.type, this.status, this.result);

  final String type;
  final String status;
  final Object? result;
}

/// The stored outcome of [key] (and [accountId], part of its identity: two
/// accounts sending the same key clash with neither), or `null` when nothing
/// is recorded yet.
///
/// A free function, not a method of `DwCallEndpoint`: `DwCallContext` needs
/// the same read and write for `recordProvisionalOutcome`, and the context
/// cannot import the endpoint that owns it without a cycle.
@internal
Future<DwStoredOutcome?> dwStoredOutcome(
  DwDatabaseHandle db,
  String key,
  int? accountId,
) async {
  final rows = await db.query(
    'SELECT type, status, result FROM dw_command_outcome '
    'WHERE key = @key AND account_id IS NOT DISTINCT FROM @account::int8',
    params: {'key': key, 'account': accountId},
  );
  if (rows.isEmpty) return null;
  final row = rows.single;
  return DwStoredOutcome(
    row.get<String>('type'),
    row.get<String>('status'),
    row['result'],
  );
}

/// Records [key]'s outcome — the first writer wins, silently: two racing
/// sends of one key must settle on whichever reaches the table first, not
/// throw at the second. Overwriting an existing row (the ticket-then-delivery
/// case a `transactional: false` command's own provisional record needs) is
/// [dwOverwriteOutcome], a different statement on purpose — one write path
/// that guards a decided outcome, another that a handler declares knowingly
/// provisional.
@internal
Future<void> dwRecordOutcome(
  DwDatabaseHandle db,
  String key,
  int? accountId,
  String type,
  String status,
  Object? result,
) => db.execute(
  'INSERT INTO dw_command_outcome (key, account_id, type, status, result) '
  'VALUES (@key, @account::int8, @type, @status, @result::jsonb) '
  'ON CONFLICT ON CONSTRAINT dw_command_outcome_key DO NOTHING',
  params: {
    'key': key,
    'account': accountId,
    'type': type,
    'status': status,
    'result': result == null ? null : jsonEncode(result),
  },
);

/// Overwrites [key]'s already-recorded outcome with [status]/[result] — for a
/// `transactional: false` handler whose own transaction recorded a
/// provisional success (`DwCallContext.recordProvisionalOutcome`) that its
/// post-transaction work then proved wrong: a refusal from a delivery, say,
/// once the ticket it would have refused before existing is already real.
/// Does nothing if the row is gone (cleared by [dwClearOutcome] on the same
/// call, in the exception branch instead) — the two never both run.
@internal
Future<void> dwOverwriteOutcome(
  DwDatabaseHandle db,
  String key,
  int? accountId,
  String status,
  Object? result,
) => db.execute(
  'UPDATE dw_command_outcome SET status = @status, result = @result::jsonb '
  'WHERE key = @key AND account_id IS NOT DISTINCT FROM @account::int8',
  params: {
    'key': key,
    'account': accountId,
    'status': status,
    'result': result == null ? null : jsonEncode(result),
  },
);

/// Removes [key]'s already-recorded outcome — for a `transactional: false`
/// handler's provisional success proved wrong not by a refusal (a decided
/// answer, [dwOverwriteOutcome]) but by an ordinary exception: an incident is
/// never stored under the idempotency key at all (a retry gets its own alert
/// and its own incident id, not a replay of someone else's), so a
/// provisional row a bare exception invalidates is removed rather than
/// rewritten — a later resend of the same key runs the handler again, the
/// same as any other incident's.
@internal
Future<void> dwClearOutcome(
  DwDatabaseHandle db,
  String key,
  int? accountId,
) => db.execute(
  'DELETE FROM dw_command_outcome '
  'WHERE key = @key AND account_id IS NOT DISTINCT FROM @account::int8',
  params: {'key': key, 'account': accountId},
);
