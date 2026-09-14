import 'package:meta/meta.dart';

import '../db/dw_database_handle.dart';
import '../db/dw_result_row.dart';
import '../entity/dw_annotations.dart';
import '../schema/dw_ddl_writer.dart';
import '../schema/dw_database_schema.dart';
import 'dw_migration_errors.dart';

/// One migration: Dart code that moves the schema (and data) one step.
///
/// A migration never imports row classes — they change, and an old
/// migration must still run in six months. It describes tables with schema
/// literals and works on data with SQL.
abstract class DwDatabaseMigration {
  const DwDatabaseMigration();

  /// `YYYYMMDD_HHMMSS_name`, unique within its namespace.
  String get id;

  /// A hash of the migration's source, written by `create` and refreshed by
  /// `rehash`. The ledger stores it on apply; an applied migration whose
  /// checksum no longer matches refuses the next run (SPEC §6.3).
  ///
  /// It is a declared member rather than something computed at runtime
  /// because a compiled server has no sources to hash.
  String get checksum;

  /// Migrations that must be applied first; may name other namespaces.
  List<DwMigrationRef> get dependsOn => const [];

  /// `false` only for statements Postgres refuses inside a transaction
  /// (`CREATE INDEX CONCURRENTLY`, `ALTER TYPE … ADD VALUE`). Such a
  /// migration is recorded `dirty` before it starts, so a crash halfway is
  /// visible and blocks the next run until someone looks.
  bool get transactional => true;

  Future<void> up(DwMigrationContext m);

  /// Irreversible unless overridden. `m.noop()` is the explicit answer for a
  /// migration that has nothing to undo.
  Future<void> down(DwMigrationContext m) => m.irreversible();

  @override
  String toString() => '$runtimeType($id)';
}

/// A migration named across namespaces.
final class DwMigrationRef {
  const DwMigrationRef(this.namespace, this.id);

  final String namespace;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is DwMigrationRef && other.namespace == namespace && other.id == id;

  @override
  int get hashCode => Object.hash(namespace, id);

  @override
  String toString() => '$namespace/$id';
}

/// What a migration can do: DDL helpers generated from schema values, raw SQL,
/// and untyped queries.
///
/// Inside a transactional migration every call runs in the migration's
/// transaction.
final class DwMigrationContext {
  @internal
  DwMigrationContext(this._db);

  final DwDatabaseHandle _db;

  /// Runs SQL; without [params] the text may hold several statements.
  Future<int> sql(String sql, {Map<String, Object?> params = const {}}) =>
      _db.execute(sql, params: params);

  Future<List<DwResultRow>> query(
    String sql, {
    Map<String, Object?> params = const {},
  }) => _db.query(sql, params: params);

  /// Creates the table with its columns, constraints and indexes.
  Future<void> createTable(DwTableSchema table) =>
      _script(DwDdlWriter.createTable(table));

  Future<void> dropTable(String table) => _script(DwDdlWriter.dropTable(table));

  /// Adds [column]. A `NOT NULL` column without a default cannot be added to
  /// a table that has rows; give [backfill], an SQL expression computed for
  /// every existing row, and the column is added nullable, filled, and then
  /// made `NOT NULL` — in this migration's transaction.
  Future<void> addColumn(
    String table,
    DwColumnSchema column, {
    String? backfill,
  }) => _script(DwDdlWriter.addColumn(table, column, backfill: backfill));

  Future<void> dropColumn(String table, String column) =>
      _script(DwDdlWriter.dropColumn(table, column));

  Future<void> renameColumn(String table, String from, String to) =>
      _script(DwDdlWriter.renameColumn(table, from, to));

  /// Changes nullability. Making a column `NOT NULL` fails on existing nulls
  /// unless [backfill] gives the SQL expression to write into them first.
  Future<void> alterColumnNullability(
    String table,
    String column, {
    required bool nullable,
    String? backfill,
  }) => _script(
    DwDdlWriter.alterColumnNullability(
      table,
      column,
      nullable: nullable,
      backfill: backfill,
    ),
  );

  /// Sets the column default, or drops it when [defaultSql] is `null`.
  Future<void> alterColumnDefault(
    String table,
    String column,
    String? defaultSql,
  ) => _script(DwDdlWriter.alterColumnDefault(table, column, defaultSql));

  /// Changes the column type; [using] converts existing values when Postgres
  /// has no implicit cast.
  Future<void> alterColumnType(
    String table,
    String column,
    String sqlType, {
    String? using,
  }) => _script(
    DwDdlWriter.alterColumnType(table, column, sqlType, using: using),
  );

  Future<void> addForeignKey(
    String table,
    String column,
    DwForeignKey references,
  ) => _script(DwDdlWriter.addForeignKey(table, column, references));

  Future<void> dropForeignKey(String table, String column) =>
      _script(DwDdlWriter.dropForeignKey(table, column));

  Future<void> addUnique(String table, String column) =>
      _script(DwDdlWriter.addUnique(table, column));

  Future<void> dropUnique(String table, String column) =>
      _script(DwDdlWriter.dropUnique(table, column));

  Future<void> createIndex(String table, DwIndexSchema index) =>
      _script(DwDdlWriter.createIndex(table, index));

  Future<void> dropIndex(String name) => _script(DwDdlWriter.dropIndex(name));

  /// The answer of `down` for a migration that cannot be undone.
  Future<Never> irreversible() async => throw const DwIrreversibleMigration();

  /// The answer of `down` for a migration with nothing to undo.
  Future<void> noop() async {}

  Future<void> _script(String sql) => _db.execute(sql);
}
