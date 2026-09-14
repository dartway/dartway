import 'package:meta/meta.dart';

import '../entity/dw_annotations.dart';
import '../query/dw_table_column.dart';
import 'dw_database_schema.dart';

/// DDL text for schema values.
///
/// Every identifier is quoted, and every constraint gets the name Postgres
/// would have picked itself (`<table>_<column>_key`, `_fkey`, `_pkey`), given
/// explicitly: introspection then reads back exactly what was declared, and
/// a later migration can drop a constraint by a name it can compute.
@internal
abstract final class DwDdlWriter {
  static String createTable(DwTableSchema table) {
    final name = dwQuoteIdentifier(table.name);
    final lines = [
      for (final column in table.columns)
        '  ${_columnDefinition(table.name, column)}',
    ];
    final statements = [
      'CREATE TABLE $name (\n${lines.join(',\n')}\n)',
      for (final index in table.indexes) createIndex(table.name, index),
    ];
    return '${statements.join(';\n')};';
  }

  static String dropTable(String table) =>
      'DROP TABLE ${dwQuoteIdentifier(table)};';

  static String addColumn(
    String table,
    DwColumnSchema column, {
    String? backfill,
  }) {
    final name = dwQuoteIdentifier(table);
    if (backfill == null) {
      return 'ALTER TABLE $name ADD COLUMN ${_columnDefinition(table, column)};';
    }
    if (column.nullable) {
      throw ArgumentError(
        'a backfill is for a NOT NULL column; "${column.name}" is nullable',
      );
    }
    return [
      'ALTER TABLE $name ADD COLUMN '
          '${_columnDefinition(table, column.copyWith(nullable: true))}',
      'UPDATE $name SET ${dwQuoteIdentifier(column.name)} = $backfill',
      'ALTER TABLE $name ALTER COLUMN ${dwQuoteIdentifier(column.name)} SET NOT NULL',
    ].join(';\n').withSemicolon;
  }

  static String dropColumn(String table, String column) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} DROP COLUMN ${dwQuoteIdentifier(column)};';

  static String renameColumn(String table, String from, String to) {
    dwCheckIdentifier(to);
    return 'ALTER TABLE ${dwQuoteIdentifier(table)} RENAME COLUMN ${dwQuoteIdentifier(from)} TO ${dwQuoteIdentifier(to)};';
  }

  static String alterColumnNullability(
    String table,
    String column, {
    required bool nullable,
    String? backfill,
  }) {
    final name = dwQuoteIdentifier(table);
    final quoted = dwQuoteIdentifier(column);
    if (nullable) {
      if (backfill != null) {
        throw ArgumentError('a backfill is only for making a column NOT NULL');
      }
      return 'ALTER TABLE $name ALTER COLUMN $quoted DROP NOT NULL;';
    }
    return [
      if (backfill != null)
        'UPDATE $name SET $quoted = $backfill WHERE $quoted IS NULL',
      'ALTER TABLE $name ALTER COLUMN $quoted SET NOT NULL',
    ].join(';\n').withSemicolon;
  }

  static String alterColumnDefault(
    String table,
    String column,
    String? defaultSql,
  ) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} ALTER COLUMN ${dwQuoteIdentifier(column)} '
      '${defaultSql == null ? 'DROP DEFAULT' : 'SET DEFAULT $defaultSql'};';

  static String alterColumnType(
    String table,
    String column,
    String sqlType, {
    String? using,
  }) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} ALTER COLUMN ${dwQuoteIdentifier(column)} '
      'TYPE $sqlType${using == null ? '' : ' USING $using'};';

  static String addForeignKey(
    String table,
    String column,
    DwForeignKey references,
  ) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} ADD ${_foreignKey(table, column, references)};';

  static String dropForeignKey(String table, String column) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} DROP CONSTRAINT '
      '${dwQuoteIdentifier(foreignKeyName(table, column))};';

  static String addUnique(String table, String column) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} ADD CONSTRAINT '
      '${dwQuoteIdentifier(uniqueName(table, column))} UNIQUE (${dwQuoteIdentifier(column)});';

  static String dropUnique(String table, String column) =>
      'ALTER TABLE ${dwQuoteIdentifier(table)} DROP CONSTRAINT '
      '${dwQuoteIdentifier(uniqueName(table, column))};';

  static String createIndex(String table, DwIndexSchema index) =>
      'CREATE ${index.unique ? 'UNIQUE ' : ''}INDEX ${dwQuoteIdentifier(index.name)} '
      'ON ${dwQuoteIdentifier(table)} (${index.columns.map(dwQuoteIdentifier).join(', ')});';

  static String dropIndex(String name) =>
      'DROP INDEX ${dwQuoteIdentifier(name)};';

  static String uniqueName(String table, String column) =>
      '${table}_${column}_key';

  static String foreignKeyName(String table, String column) =>
      '${table}_${column}_fkey';

  static String primaryKeyName(String table) => '${table}_pkey';

  static String _columnDefinition(String table, DwColumnSchema column) {
    final name = dwQuoteIdentifier(column.name);
    if (column.primaryKey) {
      return '$name bigserial CONSTRAINT ${dwQuoteIdentifier(primaryKeyName(table))} PRIMARY KEY';
    }
    final parts = [
      name,
      column.sqlType,
      if (!column.nullable) 'NOT NULL',
      if (column.defaultSql case final defaultSql?) 'DEFAULT $defaultSql',
      if (column.unique)
        'CONSTRAINT ${dwQuoteIdentifier(uniqueName(table, column.name))} UNIQUE',
      if (column.references case final references?)
        'CONSTRAINT ${dwQuoteIdentifier(foreignKeyName(table, column.name))} '
            'REFERENCES ${dwQuoteIdentifier(references.tableName)} ("id") '
            'ON DELETE ${references.onDelete.sql}',
    ];
    return parts.join(' ');
  }

  static String _foreignKey(
    String table,
    String column,
    DwForeignKey references,
  ) =>
      'CONSTRAINT ${dwQuoteIdentifier(foreignKeyName(table, column))} '
      'FOREIGN KEY (${dwQuoteIdentifier(column)}) '
      'REFERENCES ${dwQuoteIdentifier(references.tableName)} ("id") '
      'ON DELETE ${references.onDelete.sql}';
}

extension on String {
  String get withSemicolon => '$this;';
}
