import 'package:meta/meta.dart';

import '../entity/dw_annotations.dart';
import '../schema/dw_database_schema.dart';
import '../schema/dw_schema_diff.dart';
import 'dw_migration_checksum.dart';
import 'dw_migration_project.dart';

/// Writes migration drafts and the registration list as Dart source.
///
/// A change that [DwSchemaChange.requiresDecision] is written as a call to
/// `decisionRequired(...)`, a function that does not exist: the draft does
/// not compile until the author replaces the call with what they decided.
/// A runtime throw would only surface when the migration runs; a compile
/// error surfaces in the editor, in `dart analyze` and in every build, and
/// cannot be deployed by accident.
@internal
abstract final class DwDraftWriter {
  /// `m<id>.dart`: a file name must start with a letter to be a valid Dart
  /// library name, and an id starts with its date.
  static String fileName(String id) => 'm$id.dart';

  /// The first line of every migration: a sealed file is never reformatted.
  static const formatterOff = '// dart format off';

  /// The source of a migration moving the schema by [changes], importing
  /// [project]'s ORM library, formatted for [project] and then sealed with its
  /// checksum.
  ///
  /// Formatted, then marked `// dart format off`, then sealed. The checksum
  /// ignores whitespace but not the commas the formatter adds and removes
  /// when it wraps or joins an argument list — and a formatter release
  /// changes where it wraps — so `dart format lib`, the most routine command
  /// in a Dart project, broke the seal of every migration it reached, and the
  /// server refused to start (#291). The marker makes the formatter skip the
  /// file, `--set-exit-if-changed` included.
  static String migration({
    required String id,
    required String className,
    required List<DwSchemaChange> changes,
    required DwMigrationProject project,
  }) {
    final decisions = changes.where((change) => change.requiresDecision).length;
    final buffer = StringBuffer()
      ..writeln(
        '// Draft written by `migrate create`. Review it before applying:',
      )
      ..writeln('// from now on it is an ordinary migration, and it is yours.');
    if (decisions > 0) {
      buffer
        ..writeln('//')
        ..writeln(
          '// $decisions decision${decisions == 1 ? '' : 's'} required: every '
          '`decisionRequired(...)` call',
        )
        ..writeln(
          '// below must be replaced with the change you choose; the file does not',
        )
        ..writeln('// compile until then.');
    }
    buffer
      ..writeln("import '${project.ormLibrary}';")
      ..writeln()
      ..writeln('final class $className extends DwDatabaseMigration {')
      ..writeln('  const $className();')
      ..writeln()
      ..writeln('  @override')
      ..writeln("  String get id => '$id';")
      ..writeln()
      ..writeln('  @override')
      ..writeln("  String get checksum => '';")
      ..writeln()
      ..writeln('  @override')
      ..writeln('  Future<void> up(DwMigrationContext m) async {');
    if (changes.isEmpty) {
      buffer.writeln(
        '    // No schema changes. Data work goes here: m.sql(...), m.query(...).',
      );
    }
    for (final change in changes) {
      _write(buffer, change, changes);
    }
    buffer.writeln('  }');
    if (changes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('  @override')
        ..writeln('  Future<void> down(DwMigrationContext m) async {');
      final inverses = [for (final change in changes.reversed) change.inverse];
      for (final change in inverses) {
        _write(buffer, change, inverses);
      }
      buffer.writeln('  }');
    }
    buffer.writeln('}');
    return DwMigrationChecksum.seal(
      '$formatterOff\n${project.format(buffer.toString())}',
    );
  }

  /// The registration file: every migration of [classesById] (id → class
  /// name), in id order, importing and formatted as [project] needs.
  static String registration({
    required String variable,
    required Map<String, String> classesById,
    required DwMigrationProject project,
  }) {
    final ids = classesById.keys.toList()..sort();
    final buffer = StringBuffer()
      ..writeln(
        '// Maintained by `migrate create`: one entry per migration file in this',
      )
      ..writeln('// directory, in id order.')
      ..writeln("import '${project.ormLibrary}';")
      ..writeln();
    for (final id in ids) {
      buffer.writeln("import '${fileName(id)}';");
    }
    buffer
      ..writeln()
      ..writeln('final List<DwDatabaseMigration> $variable = [');
    for (final id in ids) {
      buffer.writeln('  const ${classesById[id]}(),');
    }
    buffer.writeln('];');
    return project.format(buffer.toString());
  }

  static void _write(
    StringBuffer buffer,
    DwSchemaChange change,
    List<DwSchemaChange> all,
  ) {
    final table = _string(change.table);
    void call(String code) => buffer.writeln('    await m.$code;');
    void decide(String question, List<String> reasons, List<String> options) {
      buffer.writeln('    // DECISION REQUIRED: $question');
      for (final reason in reasons) {
        buffer.writeln('    // $reason');
      }
      buffer.writeln(
        '    // Replace the call below with${options.length == 1 ? '' : ' one of'}:',
      );
      for (final option in options) {
        buffer.writeln('    //   await m.$option;');
      }
      buffer.writeln('    decisionRequired(${_string(question)});');
    }

    switch (change) {
      case DwCreateTable(:final schema):
        call('createTable(${_table(schema, indent: 4)})');
      case DwDropTable(:final schema, isInverse: true):
        call('dropTable(${_string(schema.name)})');
      case DwDropTable(:final schema):
        decide(
          'drop table ${schema.name}',
          [
            'The row classes no longer declare it. Dropping loses its rows; if it was',
            'renamed, rename it with m.sql(\'ALTER TABLE ... RENAME TO ...\') instead.',
          ],
          ['dropTable(${_string(schema.name)})'],
        );
      case DwAddColumn(:final column) when change.requiresDecision:
        decide(
          'add NOT NULL column ${change.table}.${column.name}',
          [
            'It has no default, and existing rows need a value. Give an SQL',
            'expression computed for each existing row, or a default.',
          ],
          [
            'addColumn($table, ${_column(column)}, backfill: \'<SQL expression>\')',
            for (final dropped in all.whereType<DwDropColumn>())
              if (dropped.table == change.table && !dropped.isInverse)
                'renameColumn($table, ${_string(dropped.column.name)}, ${_string(column.name)})',
          ],
        );
      case DwAddColumn(:final column):
        call('addColumn($table, ${_column(column)})');
      case DwDropColumn(:final column, isInverse: true):
        call('dropColumn($table, ${_string(column.name)})');
      case DwDropColumn(:final column):
        decide(
          'drop column ${change.table}.${column.name}',
          [
            'The row classes no longer declare it. Dropping loses its values; if it',
            'was renamed, rename it (and delete the matching add below).',
          ],
          [
            'dropColumn($table, ${_string(column.name)})',
            for (final added in all.whereType<DwAddColumn>())
              if (added.table == change.table)
                'renameColumn($table, ${_string(column.name)}, ${_string(added.column.name)})',
          ],
        );
      case DwAlterColumnType(:final column, :final from, :final to):
        decide(
          'change type of ${change.table}.$column from $from to $to',
          [
            'Existing values must convert; Postgres refuses when no implicit cast',
            'exists. Give a USING expression when it does not.',
          ],
          [
            'alterColumnType($table, ${_string(column)}, ${_string(to)}, '
                'using: ${_string('${_quote(column)}::$to')})',
          ],
        );
      case DwAlterColumnNullability(:final column, nullable: true):
        call(
          'alterColumnNullability($table, ${_string(column)}, nullable: true)',
        );
      case DwAlterColumnNullability(:final column):
        decide(
          'make ${change.table}.$column NOT NULL',
          [
            'Existing rows may hold nulls. Give an SQL expression to fill them,',
            'or drop the backfill if the column has none.',
          ],
          [
            'alterColumnNullability($table, ${_string(column)}, nullable: false, '
                'backfill: \'<SQL expression>\')',
          ],
        );
      case DwAlterColumnDefault(:final column, :final to):
        call(
          'alterColumnDefault($table, ${_string(column)}, ${to == null ? 'null' : _string(to)})',
        );
      case DwAddUnique(:final column):
        call('addUnique($table, ${_string(column)})');
      case DwDropUnique(:final column):
        call('dropUnique($table, ${_string(column)})');
      case DwAddForeignKey(:final column, :final references):
        call(
          'addForeignKey($table, ${_string(column)}, ${_references(references)})',
        );
      case DwDropForeignKey(:final column):
        call('dropForeignKey($table, ${_string(column)})');
      case DwCreateIndex(:final index):
        call('createIndex($table, ${_index(index)})');
      case DwDropIndex(:final index):
        call('dropIndex(${_string(index.name)})');
    }
  }

  static String _table(DwTableSchema table, {required int indent}) {
    final pad = ' ' * indent;
    final buffer = StringBuffer('DwTableSchema(\n')
      ..writeln('$pad  ${_string(table.name)},')
      ..writeln('$pad  columns: [');
    for (final column in table.columns) {
      buffer.writeln('$pad    ${_column(column)},');
    }
    buffer.write('$pad  ],\n');
    if (table.indexes.isNotEmpty) {
      buffer.writeln('$pad  indexes: [');
      for (final index in table.indexes) {
        buffer.writeln('$pad    ${_index(index)},');
      }
      buffer.write('$pad  ],\n');
    }
    buffer.write('$pad)');
    return buffer.toString();
  }

  static String _column(DwColumnSchema column) {
    if (column.primaryKey) {
      return column.name == 'id'
          ? 'DwColumnSchema.primaryKey()'
          : 'DwColumnSchema.primaryKey(${_string(column.name)})';
    }
    final arguments = [
      _string(column.name),
      _string(column.sqlType),
      if (column.nullable) 'nullable: true',
      if (column.unique) 'unique: true',
      if (column.defaultSql case final defaultSql?)
        'defaultSql: ${_string(defaultSql)}',
      if (column.references case final references?)
        'references: ${_references(references)}',
    ];
    return 'DwColumnSchema(${arguments.join(', ')})';
  }

  static String _references(DwForeignKey references) =>
      'DwForeignKey(${_string(references.tableName)}, '
      'onDelete: DwOnDelete.${references.onDelete.name})';

  static String _index(DwIndexSchema index) =>
      'DwIndexSchema(${_string(index.name)}, '
      '[${index.columns.map(_string).join(', ')}]'
      '${index.unique ? ', unique: true' : ''})';

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  /// A Dart string literal: single-quoted unless the text holds a single
  /// quote and no double one, with `\` and `$` escaped.
  static String _string(String text) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n');
    if (escaped.contains("'") && !escaped.contains('"')) return '"$escaped"';
    return "'${escaped.replaceAll("'", r"\'")}'";
  }
}
