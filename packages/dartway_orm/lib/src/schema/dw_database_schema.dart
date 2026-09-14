import 'dart:convert';

import 'package:collection/collection.dart';

import '../entity/dw_annotations.dart';
import '../entity/dw_table_def.dart';

/// A database schema: the tables an application owns.
///
/// Built from the tables of row classes it is the *target* the migrations must
/// reach; built by introspection it is what a database *has*. Both are the same
/// value type so they compare with `==` and diff with one function.
final class DwDatabaseSchema {
  DwDatabaseSchema(Iterable<DwTableDef> tables)
    : this.fromTables([for (final table in tables) table.tableSchema]);

  DwDatabaseSchema.fromTables(Iterable<DwTableSchema> tables)
    : tables = List.unmodifiable(tables.sortedBy((table) => table.name)) {
    final seen = <String>{};
    for (final table in this.tables) {
      if (!seen.add(table.name)) {
        throw ArgumentError('table "${table.name}" is declared twice');
      }
    }
  }

  /// Sorted by name, so equal schemas are equal lists.
  final List<DwTableSchema> tables;

  DwTableSchema? table(String name) =>
      tables.firstWhereOrNull((table) => table.name == name);

  @override
  bool operator ==(Object other) =>
      other is DwDatabaseSchema &&
      const ListEquality<DwTableSchema>().equals(other.tables, tables);

  @override
  int get hashCode => const ListEquality<DwTableSchema>().hash(tables);

  @override
  String toString() => 'DwDatabaseSchema(${tables.join(', ')})';
}

/// One table: its columns in declaration order and its indexes.
final class DwTableSchema {
  DwTableSchema(
    this.name, {
    required List<DwColumnSchema> columns,
    List<DwIndexSchema> indexes = const [],
  }) : columns = List.unmodifiable(columns),
       indexes = List.unmodifiable(indexes.sortedBy((index) => index.name)) {
    dwCheckIdentifier(name);
    final seen = <String>{};
    for (final column in columns) {
      if (!seen.add(column.name)) {
        throw ArgumentError('column "$name.${column.name}" is declared twice');
      }
      // The constraint names the DDL gives; checked here so a long pair of
      // names fails at declaration, not halfway through a migration.
      if (column.unique) dwCheckIdentifier('${name}_${column.name}_key');
      if (column.references != null) {
        dwCheckIdentifier('${name}_${column.name}_fkey');
      }
    }
    for (final index in indexes) {
      for (final column in index.columns) {
        if (!seen.contains(column)) {
          throw ArgumentError(
            'index "${index.name}" names column "$column", which "$name" does not have',
          );
        }
      }
    }
  }

  final String name;

  /// In declaration order. Order is part of the table (`SELECT *`, `COPY`),
  /// but two tables that differ only in column order are the same schema:
  /// see [==].
  final List<DwColumnSchema> columns;

  /// Sorted by name.
  final List<DwIndexSchema> indexes;

  DwColumnSchema? column(String name) =>
      columns.firstWhereOrNull((column) => column.name == name);

  DwIndexSchema? index(String name) =>
      indexes.firstWhereOrNull((index) => index.name == name);

  /// Column order is ignored: `ADD COLUMN` always appends, so a table grown by
  /// migrations and the same table declared at once differ in order and are
  /// still the same schema.
  @override
  bool operator ==(Object other) =>
      other is DwTableSchema &&
      other.name == name &&
      const UnorderedIterableEquality<DwColumnSchema>().equals(
        other.columns,
        columns,
      ) &&
      const ListEquality<DwIndexSchema>().equals(other.indexes, indexes);

  @override
  int get hashCode => Object.hash(
    name,
    const UnorderedIterableEquality<DwColumnSchema>().hash(columns),
    const ListEquality<DwIndexSchema>().hash(indexes),
  );

  @override
  String toString() => 'DwTableSchema($name, $columns, $indexes)';
}

/// One column.
///
/// A [primaryKey] column is always `id bigserial primary key`; its sequence
/// default is implied and never listed in [defaultSql].
final class DwColumnSchema {
  DwColumnSchema(
    this.name,
    this.sqlType, {
    this.nullable = false,
    this.primaryKey = false,
    this.unique = false,
    this.defaultSql,
    this.references,
  }) {
    dwCheckIdentifier(name);
    if (primaryKey &&
        (nullable || unique || defaultSql != null || references != null)) {
      throw ArgumentError('primary key "$name" cannot carry other constraints');
    }
  }

  /// `id bigserial primary key`.
  factory DwColumnSchema.primaryKey([String name = 'id']) =>
      DwColumnSchema(name, 'bigint', primaryKey: true);

  final String name;

  /// As `format_type` spells it: `bigint`, `text`, `timestamp with time zone`.
  final String sqlType;
  final bool nullable;
  final bool primaryKey;
  final bool unique;
  final String? defaultSql;
  final DwForeignKey? references;

  DwColumnSchema copyWith({
    String? name,
    String? sqlType,
    bool? nullable,
    bool? unique,
    String? Function()? defaultSql,
    DwForeignKey? Function()? references,
  }) => DwColumnSchema(
    name ?? this.name,
    sqlType ?? this.sqlType,
    nullable: nullable ?? this.nullable,
    primaryKey: primaryKey,
    unique: unique ?? this.unique,
    defaultSql: defaultSql == null ? this.defaultSql : defaultSql(),
    references: references == null ? this.references : references(),
  );

  @override
  bool operator ==(Object other) =>
      other is DwColumnSchema &&
      other.name == name &&
      other.sqlType == sqlType &&
      other.nullable == nullable &&
      other.primaryKey == primaryKey &&
      other.unique == unique &&
      other.defaultSql == defaultSql &&
      other.references == references;

  @override
  int get hashCode => Object.hash(
    name,
    sqlType,
    nullable,
    primaryKey,
    unique,
    defaultSql,
    references,
  );

  @override
  String toString() {
    final buffer = StringBuffer('$name $sqlType');
    if (primaryKey) buffer.write(' primary key');
    if (!nullable && !primaryKey) buffer.write(' not null');
    if (unique) buffer.write(' unique');
    if (defaultSql != null) buffer.write(' default $defaultSql');
    if (references case final references?) {
      buffer.write(
        ' references ${references.tableName} on delete ${references.onDelete.sql}',
      );
    }
    return buffer.toString();
  }
}

/// A plain index over columns, by SQL column names.
final class DwIndexSchema {
  DwIndexSchema(this.name, List<String> columns, {this.unique = false})
    : columns = List.unmodifiable(columns) {
    dwCheckIdentifier(name);
    if (columns.isEmpty) throw ArgumentError('index "$name" has no columns');
  }

  final String name;
  final List<String> columns;
  final bool unique;

  @override
  bool operator ==(Object other) =>
      other is DwIndexSchema &&
      other.name == name &&
      other.unique == unique &&
      const ListEquality<String>().equals(other.columns, columns);

  @override
  int get hashCode =>
      Object.hash(name, unique, const ListEquality<String>().hash(columns));

  @override
  String toString() =>
      '${unique ? 'unique ' : ''}index $name(${columns.join(', ')})';
}

/// Postgres silently truncates identifiers past 63 bytes, and a truncated
/// name no longer matches its declaration on the next diff: refuse it here.
void dwCheckIdentifier(String identifier) {
  if (identifier.isEmpty) throw ArgumentError('empty SQL identifier');
  if (utf8.encode(identifier).length > 63) {
    throw ArgumentError(
      'SQL identifier "$identifier" is longer than 63 bytes; Postgres would truncate it',
    );
  }
}
