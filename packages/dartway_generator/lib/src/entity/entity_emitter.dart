import '../emit/source_text.dart';
import '../emit/value_class_writer.dart';
import 'entity_model.dart';

/// Writes the generated code of one row class: the value mixin, `copyWith` and
/// the table definition (the shape of `packages/dartway_orm/test/fixtures`).
abstract final class EntityEmitter {
  static String emit(EntityClass entity) => [
    _mixin(entity),
    ?ValueClassWriter.copyWith(entity.name, entity.fields),
    _table(entity),
  ].join('\n\n');

  static String _mixin(EntityClass entity) {
    final name = entity.name;
    final members = [
      ?ValueClassWriter.self(name, entity.fields),
      ValueClassWriter.equalsMember(name, entity.fields),
      ValueClassWriter.hashCodeMember(name, entity.fields, seedWithType: false),
      ValueClassWriter.toStringMember(name, entity.fields),
    ];
    return 'mixin _\$$name on ${entity.superclass} {\n'
        '${members.join('\n\n')}\n'
        '}';
  }

  static String _table(EntityClass entity) {
    final name = entity.name;
    final columns = [
      for (final field in entity.fields)
        if (field.column != null) field,
    ];
    final members = <String>[
      'const ${entity.tableClass}() : super(${dartString(entity.tableName)});',
      for (final field in columns) _columnGetter(field),
      '@override\nList<DwTableColumn<Object?>> get tableColumns => '
          '[id, ${columns.map((field) => field.name).join(', ')}];',
      if (entity.indexes.isNotEmpty)
        '@override\nList<DwIndexSchema> get indexSchemas => ['
            '${entity.indexes.map(_index).join(', ')}];',
      '@override\n$name fromRow(DwResultRow row) => $name('
          '${entity.fields.map((field) => '${field.name}: row.decode(${_column(field)})').join(', ')});',
      '@override\nMap<String, Object?> toRow($name row) => {'
          '${[
            // Absent before insert: the database assigns it.
            "if (row.id != null) 'id': row.id",
            for (final field in columns) '${dartString(field.column!.sqlName)}: row.${field.name}',
          ].join(', ')}};',
    ];
    return 'final class ${entity.tableClass} extends DwTableDef<$name> {\n'
        '${members.join('\n\n')}\n'
        '}';
  }

  /// The column getter of [field] inside `fromRow`, whose parameter is `row`:
  /// a field named `row` reaches its getter through `this`.
  static String _column(EntityField field) =>
      field.name == 'row' ? 'this.row' : field.name;

  static String _columnGetter(EntityField field) {
    final column = field.column!;
    final arguments = [
      dartString(column.sqlName),
      column.dwType,
      // In the order DwTableColumn declares them.
      if (column.unique) 'unique: true',
      if (column.defaultValue != null) 'defaultValue: ${column.defaultValue}',
      if (column.references != null) 'references: ${column.references}',
    ];
    return 'DwTableColumn<${field.spelling}> get ${field.name} => '
        'const DwTableColumn(${arguments.join(', ')});';
  }

  static String _index(EntityIndex index) =>
      'DwIndexSchema(${dartString(index.name)}, '
      '[${index.columns.map(dartString).join(', ')}]'
      '${index.unique ? ', unique: true' : ''})';
}
