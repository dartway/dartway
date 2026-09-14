import 'package:collection/collection.dart';

import '../db/dw_database_handle.dart';
import '../entity/dw_annotations.dart';
import 'dw_ddl_writer.dart';
import 'dw_database_schema.dart';

/// What a live database has, as a [DwDatabaseSchema], plus everything in it
/// that row classes cannot declare.
final class DwSchemaIntrospection {
  const DwSchemaIntrospection(this.schema, this.unmodelled);

  final DwDatabaseSchema schema;

  /// Objects the schema model has no place for — a partial index, a check
  /// constraint, a multi-column foreign key — described in words. They are
  /// left out of [schema] so a diff never proposes dropping them, and listed
  /// here so leaving them out is visible.
  final List<String> unmodelled;
}

/// Reads tables, columns, constraints and indexes from `pg_catalog`.
abstract final class DwSchemaIntrospector {
  /// Introspects the tables of [schemaName] (the current schema by default),
  /// except [excludeTables].
  static Future<DwSchemaIntrospection> read(
    DwDatabaseHandle db, {
    String? schemaName,
    Set<String> excludeTables = const {},
  }) async {
    final params = <String, Object?>{'schema': schemaName ?? ''};
    const schemaFilter =
        "n.nspname = coalesce(nullif(@schema::text, ''), current_schema())";

    final columnRows = await db.query('''
SELECT c.relname::text AS table_name,
       a.attname::text AS column_name,
       format_type(a.atttypid, a.atttypmod) AS sql_type,
       a.attnotnull AS not_null,
       pg_get_expr(d.adbin, d.adrelid) AS default_sql
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
WHERE $schemaFilter AND c.relkind IN ('r', 'p')
ORDER BY c.relname, a.attnum''', params: params);

    final constraintRows = await db.query('''
SELECT c.relname::text AS table_name,
       con.conname::text AS name,
       con.contype::text AS kind,
       ARRAY(
         SELECT a.attname::text
         FROM unnest(con.conkey) WITH ORDINALITY AS k(attnum, position)
         JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
         ORDER BY k.position
       ) AS columns,
       ref.relname::text AS referenced_table,
       ARRAY(
         SELECT a.attname::text
         FROM unnest(con.confkey) WITH ORDINALITY AS k(attnum, position)
         JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.attnum
         ORDER BY k.position
       ) AS referenced_columns,
       con.confdeltype::text AS on_delete
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_class ref ON ref.oid = con.confrelid
WHERE $schemaFilter AND c.relkind IN ('r', 'p') AND con.contype <> 'n'
ORDER BY c.relname, con.conname''', params: params);

    final indexRows = await db.query('''
SELECT t.relname::text AS table_name,
       i.relname::text AS name,
       ix.indisunique AS is_unique,
       ix.indexprs IS NOT NULL OR ix.indpred IS NOT NULL AS is_expression,
       ARRAY(
         SELECT a.attname::text
         FROM unnest(ix.indkey::int2[]) WITH ORDINALITY AS k(attnum, position)
         JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = k.attnum
         ORDER BY k.position
       ) AS columns
FROM pg_index ix
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE $schemaFilter AND t.relkind IN ('r', 'p')
  -- Indexes that implement a constraint belong to it. A foreign key also
  -- records the index it relies on, but does not own it.
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint con
    WHERE con.conindid = ix.indexrelid AND con.contype IN ('p', 'u', 'x')
  )
ORDER BY t.relname, i.relname''', params: params);

    final unmodelled = <String>[];
    final tables = <String, _TableBuilder>{};
    for (final row in columnRows) {
      final table = row.get<String>('table_name');
      if (excludeTables.contains(table)) continue;
      tables
          .putIfAbsent(table, () => _TableBuilder(table))
          .columns
          .add(
            _ColumnBuilder(
              row.get<String>('column_name'),
              row.get<String>('sql_type'),
              nullable: !row.get<bool>('not_null'),
              defaultSql: row.get<String?>('default_sql'),
            ),
          );
    }

    for (final row in constraintRows) {
      final table = tables[row.get<String>('table_name')];
      if (table == null) continue;
      final name = row.get<String>('name');
      final kind = row.get<String>('kind');
      final columns = row.get<List<Object?>>('columns').cast<String>();
      final column = columns.length == 1 ? table.column(columns.single) : null;
      switch (kind) {
        case 'p':
          final sequence = RegExp(r"^nextval\('.*_seq'::regclass\)$");
          if (column != null &&
              name == DwDdlWriter.primaryKeyName(table.name) &&
              column.sqlType == 'bigint' &&
              sequence.hasMatch(column.defaultSql ?? '')) {
            column
              ..primaryKey = true
              ..defaultSql = null;
          } else {
            unmodelled.add(
              'primary key $name on ${table.name}(${columns.join(', ')}) '
              'is not an "id bigserial" key',
            );
          }
        case 'u':
          if (column != null &&
              name == DwDdlWriter.uniqueName(table.name, column.name)) {
            column.unique = true;
          } else {
            unmodelled.add(
              'unique constraint $name on ${table.name}(${columns.join(', ')})',
            );
          }
        case 'f':
          final referencedColumns = row
              .get<List<Object?>>('referenced_columns')
              .cast<String>();
          final onDelete = switch (row.get<String>('on_delete')) {
            'a' => DwOnDelete.noAction,
            'r' => DwOnDelete.restrict,
            'c' => DwOnDelete.cascade,
            'n' => DwOnDelete.setNull,
            _ => null,
          };
          if (column != null &&
              name == DwDdlWriter.foreignKeyName(table.name, column.name) &&
              referencedColumns.length == 1 &&
              referencedColumns.single == 'id' &&
              onDelete != null) {
            column.references = DwForeignKey(
              row.get<String>('referenced_table'),
              onDelete: onDelete,
            );
          } else {
            unmodelled.add(
              'foreign key $name on ${table.name}(${columns.join(', ')})',
            );
          }
        default:
          unmodelled.add(
            '${_constraintKinds[kind] ?? 'constraint'} $name on ${table.name}',
          );
      }
    }

    for (final row in indexRows) {
      final table = tables[row.get<String>('table_name')];
      if (table == null) continue;
      final name = row.get<String>('name');
      if (row.get<bool>('is_expression')) {
        unmodelled.add('expression or partial index $name on ${table.name}');
        continue;
      }
      table.indexes.add(
        DwIndexSchema(
          name,
          row.get<List<Object?>>('columns').cast<String>(),
          unique: row.get<bool>('is_unique'),
        ),
      );
    }

    return DwSchemaIntrospection(
      DwDatabaseSchema.fromTables([
        for (final table in tables.values) table.build(),
      ]),
      List.unmodifiable(unmodelled),
    );
  }

  static const _constraintKinds = {
    'c': 'check constraint',
    'x': 'exclusion constraint',
    't': 'constraint trigger',
  };
}

final class _TableBuilder {
  _TableBuilder(this.name);

  final String name;
  final List<_ColumnBuilder> columns = [];
  final List<DwIndexSchema> indexes = [];

  _ColumnBuilder? column(String name) =>
      columns.firstWhereOrNull((column) => column.name == name);

  DwTableSchema build() => DwTableSchema(
    name,
    columns: [for (final column in columns) column.build()],
    indexes: indexes,
  );
}

final class _ColumnBuilder {
  _ColumnBuilder(
    this.name,
    this.sqlType, {
    required this.nullable,
    required this.defaultSql,
  });

  final String name;
  final String sqlType;
  final bool nullable;
  String? defaultSql;
  bool primaryKey = false;
  bool unique = false;
  DwForeignKey? references;

  DwColumnSchema build() => primaryKey
      ? DwColumnSchema.primaryKey(name)
      : DwColumnSchema(
          name,
          sqlType,
          nullable: nullable,
          unique: unique,
          defaultSql: defaultSql,
          references: references,
        );
}
