import '../emit/source_text.dart';
import '../emit/value_class_writer.dart';
import 'entity_model.dart';

/// Writes the generated code of one row class: the value mixin, `copyWith`,
/// the draft (`New<Name>Row`) and the table definition (the shape of
/// `packages/dartway_orm/test/fixtures`).
abstract final class EntityEmitter {
  static String emit(EntityClass entity) {
    final values = _values(entity);
    return [
      _mixin(entity),
      // A copy of a stored row is the same row: its id is kept.
      ?ValueClassWriter.copyWith(entity.name, values, kept: const ['id']),
      _draft(entity, values),
      ?ValueClassWriter.copyWith(entity.draftClass, values),
      _withId(entity, values),
      _table(entity),
    ].join('\n\n');
  }

  /// Every field but `id`: the columns a draft holds.
  static List<EntityField> _values(EntityClass entity) => [
    for (final field in entity.fields)
      if (field.column != null) field,
  ];

  static String _draft(EntityClass entity, List<EntityField> values) {
    final parameters = [
      for (final field in values)
        switch (field.constructor) {
          EntityParameter(isRequired: true) => 'required this.${field.name}',
          EntityParameter(:final defaultValue?) =>
            'this.${field.name} = $defaultValue',
          _ => 'this.${field.name}',
        },
    ];
    final fields = [
      for (final field in values) 'final ${field.spelling} ${field.name};',
    ];
    final draft = entity.draftClass;
    final base = 'DwRowDraft<${entity.name}>';
    // A value like the row: compared, hashed and printed by its columns, with
    // the members the row's mixin has, written by the same writer.
    final members = [
      ?ValueClassWriter.self(draft, values),
      ValueClassWriter.equalsMember(draft, values),
      ValueClassWriter.hashCodeMember(draft, values, seedWithType: false),
      ValueClassWriter.toStringMember(draft, values),
    ];
    return 'mixin _\$$draft on $base {\n'
        '${members.join('\n\n')}\n'
        '}\n\n'
        '/// A [${entity.name}] before insert: every column but the id.\n'
        'final class $draft extends $base with _\$$draft {\n'
        'const $draft('
        '${parameters.isEmpty ? '' : '{${parameters.join(', ')}}'});\n\n'
        '${fields.join('\n')}\n'
        '}';
  }

  static String _withId(EntityClass entity, List<EntityField> values) {
    final arguments = [
      'id: id',
      for (final field in values) '${field.name}: ${field.name}',
    ];
    return 'extension ${entity.draftClass}WithId on ${entity.draftClass} {\n'
        '/// The row stored under [id], for `update`.\n'
        '${entity.name} withId(int id) => '
        '${entity.name}(${arguments.join(', ')});\n'
        '}';
  }

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
    final columns = _values(entity);
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
      '@override\nMap<String, Object?> toRow($name row) => '
          '${_valueMap(columns, 'row')};',
      '@override\nMap<String, Object?> toDraftRow(${entity.draftClass} draft) => '
          '${_valueMap(columns, 'draft')};',
    ];
    return 'final class ${entity.tableClass} extends DwTableDef<$name> {\n'
        '${members.join('\n\n')}\n'
        '}';
  }

  static String _valueMap(List<EntityField> columns, String of) =>
      '{${[for (final field in columns) '${dartString(field.column!.sqlName)}: $of.${field.name}'].join(', ')}}';

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
