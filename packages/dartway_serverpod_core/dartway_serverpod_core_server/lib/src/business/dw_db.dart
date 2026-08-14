// The whole reason this file exists — see the class doc below. Concentrated
// here so no application has to write it.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/serverpod.dart';

/// Generic, model-agnostic database access — `dw.db(session)`.
///
/// **Not a duplicate of `session.db`, and here for a reason.** Serverpod
/// generates a repository per model (`ClubSession.db.find(...)`) and gives no
/// repository of a common type, so an operation shared by several models has to
/// reach for the generic `session.db.find<T>()` / `insertRow<T>` / `updateRow<T>`
/// — and every one of those is marked `@internal`. An application calling them
/// either repeats `// ignore_for_file: invalid_use_of_internal_member`, which is
/// reaching into another package's private surface, or writes a three-line
/// adapter per model whose bodies differ only in the model's name.
///
/// So the exposure is concentrated instead of multiplied: the `ignore` lives in
/// this file and nowhere else. When Serverpod changes those methods, one file
/// needs fixing rather than N applications — and this is the seam a replacement
/// for the ORM would be fitted into later.
///
/// Reach it through the core, never by constructing it: `dw.db(session).find<T>()`.
/// For a single known model prefer that model's own repository — it is typed,
/// public, and reads better. This is for the cases where the model is a type
/// parameter: a data migration, a background cleanup, an export.
///
/// ```dart
/// Future<int> purge<T extends TableRow>(Session session, Expression stale) async {
///   final db = dw.db(session);
///   final rows = await db.find<T>(where: stale);
///   for (final row in rows) {
///     await db.deleteRow<T>(row);
///   }
///   return rows.length;
/// }
/// ```
///
/// **Every method takes an optional [Transaction], and inside one it is not
/// optional in practice.** A call that omits it runs on its own connection, so
/// it does not see the uncommitted work around it and is not rolled back with
/// it — and under `serverpod_test` with database rollbacks enabled (the default)
/// it fails outright as a concurrent call. Pass `saveContext.transaction` when
/// you are inside a CRUD save hook.
///
/// The set is deliberately small: five operations, added to when something real
/// needs more. See `docs/DESIGN.md` — the core is a minimal contract.
class DwDb {
  /// Built by [DwCore.db]; applications do not construct it.
  const DwDb(this._session);

  final Session _session;

  /// The rows of [T] matching [where], or all of them when it is omitted.
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Order>? orderByList,
    bool orderDescending = false,
    Include? include,
    Transaction? transaction,
  }) => _session.db.find<T>(
    where: where,
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    orderByList: orderByList,
    orderDescending: orderDescending,
    include: include,
    transaction: transaction,
  );

  /// Inserts [row] and returns it with its assigned id.
  Future<T> insertRow<T extends TableRow>(T row, {Transaction? transaction}) =>
      _session.db.insertRow<T>(row, transaction: transaction);

  /// Updates [row], which must already carry its id.
  Future<T> updateRow<T extends TableRow>(T row, {Transaction? transaction}) =>
      _session.db.updateRow<T>(row, transaction: transaction);

  /// Deletes [row] and returns the row that was deleted.
  Future<T> deleteRow<T extends TableRow>(T row, {Transaction? transaction}) =>
      _session.db.deleteRow<T>(row, transaction: transaction);

  /// How many rows of [T] match [where] — without reading them.
  Future<int> count<T extends TableRow>({
    Expression? where,
    int? limit,
    Transaction? transaction,
  }) => _session.db.count<T>(
    where: where,
    limit: limit,
    transaction: transaction,
  );
}
