import 'package:collection/collection.dart';

import '../entity/dw_annotations.dart';
import 'dw_schema.dart';

/// One step from a schema towards another.
///
/// A change that loses data, or whose correct form depends on data the diff
/// cannot see, [requiresDecision]: a drop may really be a rename, a new
/// `NOT NULL` column needs a value for existing rows. Such changes are never
/// written as runnable code — the author decides.
sealed class DwSchemaChange {
  const DwSchemaChange(this.table);

  final String table;

  bool get requiresDecision => false;

  /// The change that undoes this one.
  DwSchemaChange get inverse;
}

final class DwCreateTable extends DwSchemaChange {
  DwCreateTable(this.schema) : super(schema.name);

  final DwTableSchema schema;

  @override
  DwSchemaChange get inverse => DwDropTable(schema, isInverse: true);

  @override
  String toString() => 'create table $table';
}

final class DwDropTable extends DwSchemaChange {
  DwDropTable(this.schema, {this.isInverse = false}) : super(schema.name);

  final DwTableSchema schema;

  /// Dropping a table this same migration created is no decision.
  final bool isInverse;

  @override
  bool get requiresDecision => !isInverse;

  @override
  DwSchemaChange get inverse => DwCreateTable(schema);

  @override
  String toString() => 'drop table $table';
}

final class DwAddColumn extends DwSchemaChange {
  const DwAddColumn(super.table, this.column);

  final DwColumnSchema column;

  /// Existing rows need a value the diff cannot invent.
  @override
  bool get requiresDecision =>
      column.primaryKey || (!column.nullable && column.defaultSql == null);

  @override
  DwSchemaChange get inverse => DwDropColumn(table, column, isInverse: true);

  @override
  String toString() => 'add column $table.${column.name}';
}

final class DwDropColumn extends DwSchemaChange {
  const DwDropColumn(super.table, this.column, {this.isInverse = false});

  final DwColumnSchema column;
  final bool isInverse;

  @override
  bool get requiresDecision => !isInverse;

  @override
  DwSchemaChange get inverse => DwAddColumn(table, column);

  @override
  String toString() => 'drop column $table.${column.name}';
}

final class DwAlterColumnType extends DwSchemaChange {
  const DwAlterColumnType(
    super.table,
    this.column, {
    required this.from,
    required this.to,
  });

  final String column;
  final String from;
  final String to;

  @override
  bool get requiresDecision => true;

  @override
  DwSchemaChange get inverse =>
      DwAlterColumnType(table, column, from: to, to: from);

  @override
  String toString() => 'change type of $table.$column from $from to $to';
}

final class DwAlterColumnNullability extends DwSchemaChange {
  const DwAlterColumnNullability(
    super.table,
    this.column, {
    required this.nullable,
  });

  final String column;
  final bool nullable;

  /// Existing nulls must be filled before `SET NOT NULL`.
  @override
  bool get requiresDecision => !nullable;

  @override
  DwSchemaChange get inverse =>
      DwAlterColumnNullability(table, column, nullable: !nullable);

  @override
  String toString() =>
      'make $table.$column ${nullable ? 'nullable' : 'NOT NULL'}';
}

final class DwAlterColumnDefault extends DwSchemaChange {
  const DwAlterColumnDefault(
    super.table,
    this.column, {
    required this.from,
    required this.to,
  });

  final String column;
  final String? from;
  final String? to;

  @override
  DwSchemaChange get inverse =>
      DwAlterColumnDefault(table, column, from: to, to: from);

  @override
  String toString() => 'change default of $table.$column from $from to $to';
}

final class DwAddUnique extends DwSchemaChange {
  const DwAddUnique(super.table, this.column);

  final String column;

  @override
  DwSchemaChange get inverse => DwDropUnique(table, column);

  @override
  String toString() => 'add unique $table.$column';
}

final class DwDropUnique extends DwSchemaChange {
  const DwDropUnique(super.table, this.column);

  final String column;

  @override
  DwSchemaChange get inverse => DwAddUnique(table, column);

  @override
  String toString() => 'drop unique $table.$column';
}

final class DwAddForeignKey extends DwSchemaChange {
  const DwAddForeignKey(super.table, this.column, this.references);

  final String column;
  final DwReferences references;

  @override
  DwSchemaChange get inverse => DwDropForeignKey(table, column, references);

  @override
  String toString() =>
      'add foreign key $table.$column -> ${references.tableName}';
}

final class DwDropForeignKey extends DwSchemaChange {
  const DwDropForeignKey(super.table, this.column, this.references);

  final String column;
  final DwReferences references;

  @override
  DwSchemaChange get inverse => DwAddForeignKey(table, column, references);

  @override
  String toString() =>
      'drop foreign key $table.$column -> ${references.tableName}';
}

final class DwCreateIndex extends DwSchemaChange {
  const DwCreateIndex(super.table, this.index);

  final DwIndexSchema index;

  @override
  DwSchemaChange get inverse => DwDropIndex(table, index);

  @override
  String toString() => 'create $index on $table';
}

final class DwDropIndex extends DwSchemaChange {
  const DwDropIndex(super.table, this.index);

  final DwIndexSchema index;

  @override
  DwSchemaChange get inverse => DwCreateIndex(table, index);

  @override
  String toString() => 'drop $index on $table';
}

/// The changes that turn one schema into another, in an order that runs.
abstract final class DwSchemaDiff {
  /// Changes from [from] to [to], ordered so each can run after the previous:
  /// constraints that stand in the way are dropped first, new tables are
  /// created before columns reference them, and drops of columns and tables
  /// come last.
  static List<DwSchemaChange> compare({
    required DwSchema from,
    required DwSchema to,
  }) {
    final dropConstraints = <DwSchemaChange>[];
    final createTables = <DwSchemaChange>[];
    final addColumns = <DwSchemaChange>[];
    final alterColumns = <DwSchemaChange>[];
    final addConstraints = <DwSchemaChange>[];
    final dropColumns = <DwSchemaChange>[];
    final dropTables = <DwTableSchema>[];

    final newTables = <DwTableSchema>[];
    for (final target in to.tables) {
      final current = from.table(target.name);
      if (current == null) {
        newTables.add(target);
        continue;
      }
      final table = target.name;

      for (final index in current.indexes) {
        if (target.index(index.name) != index) {
          dropConstraints.add(DwDropIndex(table, index));
        }
      }
      for (final index in target.indexes) {
        if (current.index(index.name) != index) {
          addConstraints.add(DwCreateIndex(table, index));
        }
      }

      for (final column in current.columns) {
        final wanted = target.column(column.name);
        if (wanted == null) {
          // Its own constraints go with it, and come back with it on undo.
          dropColumns.add(DwDropColumn(table, column));
          continue;
        }
        if (column.references != null &&
            column.references != wanted.references) {
          dropConstraints.add(
            DwDropForeignKey(table, column.name, column.references!),
          );
        }
        if (column.unique && !wanted.unique) {
          dropConstraints.add(DwDropUnique(table, column.name));
        }
        if (column.sqlType != wanted.sqlType) {
          alterColumns.add(
            DwAlterColumnType(
              table,
              column.name,
              from: column.sqlType,
              to: wanted.sqlType,
            ),
          );
        }
        if (column.defaultSql != wanted.defaultSql) {
          alterColumns.add(
            DwAlterColumnDefault(
              table,
              column.name,
              from: column.defaultSql,
              to: wanted.defaultSql,
            ),
          );
        }
        if (column.nullable != wanted.nullable) {
          alterColumns.add(
            DwAlterColumnNullability(
              table,
              column.name,
              nullable: wanted.nullable,
            ),
          );
        }
        if (wanted.unique && !column.unique) {
          addConstraints.add(DwAddUnique(table, column.name));
        }
        if (wanted.references != null &&
            column.references != wanted.references) {
          addConstraints.add(
            DwAddForeignKey(table, column.name, wanted.references!),
          );
        }
      }
      for (final column in target.columns) {
        if (current.column(column.name) == null) {
          addColumns.add(DwAddColumn(table, column));
        }
      }
    }

    for (final current in from.tables) {
      if (to.table(current.name) == null) dropTables.add(current);
    }

    // New tables referencing each other in a cycle cannot be created with
    // their foreign keys inline; those keys are added once all exist.
    final (ordered, deferred) = _orderByReferences(newTables);
    for (final table in ordered) {
      final late = deferred[table.name] ?? const <String>{};
      createTables.add(
        DwCreateTable(
          late.isEmpty
              ? table
              : DwTableSchema(
                  table.name,
                  columns: [
                    for (final column in table.columns)
                      late.contains(column.name)
                          ? column.copyWith(references: () => null)
                          : column,
                  ],
                  indexes: table.indexes,
                ),
        ),
      );
      for (final column in table.columns) {
        if (late.contains(column.name)) {
          addConstraints.add(
            DwAddForeignKey(table.name, column.name, column.references!),
          );
        }
      }
    }

    // Tables are dropped referencing ones first.
    final (dropOrder, _) = _orderByReferences(dropTables);
    return [
      ...dropConstraints,
      ...createTables,
      ...addColumns,
      ...alterColumns,
      ...addConstraints,
      ...dropColumns,
      for (final table in dropOrder.reversed) DwDropTable(table),
    ];
  }

  /// Orders [tables] so a table comes after the tables it references, and
  /// names, per table, the columns whose references close a cycle.
  static (List<DwTableSchema>, Map<String, Set<String>>) _orderByReferences(
    List<DwTableSchema> tables,
  ) {
    final byName = {for (final table in tables) table.name: table};
    final ordered = <DwTableSchema>[];
    final deferred = <String, Set<String>>{};
    final state = <String, bool>{}; // false: visiting, true: done

    void visit(DwTableSchema table) {
      state[table.name] = false;
      for (final column in table.columns) {
        final target = column.references?.tableName;
        if (target == null || target == table.name) continue;
        final next = byName[target];
        if (next == null) continue;
        switch (state[target]) {
          case null:
            visit(next);
          case false:
            deferred.putIfAbsent(table.name, () => {}).add(column.name);
          case true:
            break;
        }
      }
      state[table.name] = true;
      ordered.add(table);
    }

    for (final table in tables.sortedBy((table) => table.name)) {
      if (state[table.name] == null) visit(table);
    }
    return (ordered, deferred);
  }
}
