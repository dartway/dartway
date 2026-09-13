import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

import '../analysis/fields.dart';
import '../analysis/framework.dart';
import '../analysis/library_names.dart';
import '../analysis/wire_type.dart';
import '../diagnostic.dart';
import '../emit/source_text.dart';
import 'entity_model.dart';

/// Reads one concrete entity class (CONTRACTS §2.2) into an [EntityClass].
final class EntityReader {
  EntityReader(this.names, this.diagnostics)
    : types = WireTypeReader(names, forEntity: true);

  final LibraryNames names;
  final WireTypeReader types;
  final List<DwDiagnostic> diagnostics;

  /// Postgres truncates longer identifiers silently.
  static const _maxIdentifierBytes = 63;

  EntityClass? read(ClassElement element, ClassDeclaration declaration) {
    final name = element.name!;
    final extendsClause = declaration.extendsClause;
    if (extendsClause == null ||
        !_reachesEntityBySuperclass(element) ||
        element.typeParameters.isNotEmpty) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          element.typeParameters.isNotEmpty
              ? '`$name` is generic; an entity class cannot have type '
                    'parameters'
              : '`$name` must extend DwEntity; implementing or mixing it in '
                    'is not supported',
        ),
      );
      return null;
    }

    final table = _annotation(element.metadata.annotations, 'DwTable');
    final tableName = table?.getField('name')?.toStringValue();
    if (table == null || tableName == null) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          'entity `$name` needs its table: annotate it with '
          "`@DwTable('${snakeCase(name)}')`",
        ),
      );
      return null;
    }

    var valid = _checkIdentifier(element, tableName, 'table name');
    if (!_declaresTable(element)) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          'entity `$name` must declare its table: add '
          '`static const table = ${name}Table();`',
        ),
      );
      valid = false;
    }

    final constructorFields = readConstructorFields(element, diagnostics);
    if (constructorFields == null) return null;

    final reserved = _reservedTableMembers();
    final fields = <EntityField>[];
    // `id` is a column of every table, and indexes may name it.
    final columnsByField = <String, String>{'id': 'id'};
    final fieldsByColumn = <String, String>{'id': 'id'};
    var hasId = false;
    for (final field in constructorFields) {
      final fieldElement = field.field;
      final fieldName = field.name;
      final location = fieldElement.enclosingElement == element
          ? fieldElement
          : element;

      if (fieldName == 'id') {
        hasId = true;
        final type = fieldElement.type;
        if (!type.isDartCoreInt ||
            type.nullabilitySuffix != NullabilitySuffix.question) {
          diagnostics.add(
            DwDiagnostic.at(
              location,
              'the id of entity `$name` must be `int?` (a bigserial key, '
              'null before insert), not `${type.getDisplayString()}`',
            ),
          );
          valid = false;
          continue;
        }
        fields.add(
          EntityField(
            name: 'id',
            type: const ScalarWire('int', nullable: true),
            spelling: 'int?',
            column: null,
          ),
        );
        continue;
      }

      if (reserved.contains(fieldName)) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'field `$fieldName` of entity `$name` would shadow '
            '`DwTableDef.$fieldName` in the generated table class; rename the '
            "field (the column can keep its name with `@DwColumnName('...')`)",
          ),
        );
        valid = false;
        continue;
      }

      final WireType type;
      try {
        type = types.read(fieldElement.type);
      } on UnsupportedType catch (problem) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'field `$fieldName` of entity `$name` cannot be a column: '
            '${problem.reason}',
          ),
        );
        valid = false;
        continue;
      }
      final spelling = names.spell(fieldElement.type);
      if (spelling == null) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'field `$fieldName` of entity `$name` has a type this library does '
            'not import, and the generated part can only use the library\'s '
            'imports',
          ),
        );
        valid = false;
        continue;
      }

      final annotations = fieldElement.metadata.annotations;
      final sqlName =
          _annotation(
            annotations,
            'DwColumnName',
          )?.getField('name')?.toStringValue() ??
          snakeCase(fieldName);
      final previous = fieldsByColumn[sqlName];
      if (previous != null) {
        diagnostics.add(
          DwDiagnostic.at(
            location,
            'fields `$previous` and `$fieldName` of entity `$name` both map to '
            'column `$sqlName`',
          ),
        );
        valid = false;
        continue;
      }
      fieldsByColumn[sqlName] = fieldName;
      columnsByField[fieldName] = sqlName;
      valid &= _checkIdentifier(location, sqlName, 'column name');

      final unique = _annotation(annotations, 'DwUnique') != null;
      if (unique) {
        valid &= _checkIdentifier(
          location,
          '${tableName}_${sqlName}_key',
          'unique constraint name',
        );
      }

      final referencesValue = _annotation(annotations, 'DwReferences');
      String? references;
      if (referencesValue != null) {
        if (type is! ScalarWire || type.dartName != 'int') {
          diagnostics.add(
            DwDiagnostic.at(
              location,
              'field `$fieldName` of entity `$name` references another table, '
              'so it holds that row\'s id and must be `int` or `int?`',
            ),
          );
          valid = false;
          continue;
        }
        valid &= _checkIdentifier(
          location,
          '${tableName}_${sqlName}_fkey',
          'foreign key name',
        );
        final target = referencesValue.getField('tableName')!.toStringValue()!;
        final onDelete = _enumName(referencesValue.getField('onDelete'));
        references =
            'DwReferences(${dartString(target)}'
            '${onDelete == null || onDelete == 'noAction' ? '' : ', onDelete: DwOnDelete.$onDelete'})';
      }

      final defaultValue = _annotation(annotations, 'DwDefault');
      final defaultSql = defaultValue?.getField('sql')?.toStringValue();

      fields.add(
        EntityField(
          name: fieldName,
          type: type,
          spelling: spelling,
          column: EntityColumn(
            sqlName: sqlName,
            dwType: _dwType(type),
            unique: unique,
            defaultValue: defaultSql == null
                ? null
                : defaultSql == 'now()'
                ? 'DwDefault.now()'
                : 'DwDefault(${dartString(defaultSql)})',
            references: references,
          ),
        ),
      );
    }

    if (!hasId && valid) {
      diagnostics.add(
        DwDiagnostic.at(
          element,
          'entity `$name` must declare `@override final int? id;` with a '
          'named constructor parameter `this.id`',
        ),
      );
      valid = false;
    }

    final indexes = <EntityIndex>[];
    final indexNames = <String>{};
    for (final index in table.getField('indexes')?.toListValue() ?? const []) {
      final fieldNames = [
        for (final field in index.getField('fields')?.toListValue() ?? const [])
          field.toStringValue()!,
      ];
      final unknown = fieldNames.where((f) => !columnsByField.containsKey(f));
      if (fieldNames.isEmpty || unknown.isNotEmpty) {
        diagnostics.add(
          DwDiagnostic.at(
            element,
            fieldNames.isEmpty
                ? 'an index of entity `$name` names no fields'
                : 'an index of entity `$name` names `${unknown.first}`, which '
                      'is not a column field of `$name` (indexes name Dart '
                      'fields, not SQL columns)',
          ),
        );
        valid = false;
        continue;
      }
      final columns = [for (final field in fieldNames) columnsByField[field]!];
      final unique = index.getField('unique')?.toBoolValue() ?? false;
      final indexName =
          index.getField('name')?.toStringValue() ??
          '${tableName}_${columns.join('_')}_${unique ? 'key' : 'idx'}';
      if (!indexNames.add(indexName)) {
        diagnostics.add(
          DwDiagnostic.at(
            element,
            'entity `$name` declares index `$indexName` twice',
          ),
        );
        valid = false;
        continue;
      }
      valid &= _checkIdentifier(element, indexName, 'index name');
      indexes.add(EntityIndex(indexName, columns, unique: unique));
    }
    indexes.sort((a, b) => a.name.compareTo(b.name));

    if (!valid) return null;
    return EntityClass(
      name: name,
      superclass: extendsClause.superclass.toSource(),
      tableName: tableName,
      fields: fields,
      indexes: indexes,
      element: element,
    );
  }

  bool _checkIdentifier(Element location, String identifier, String what) {
    if (utf8.encode(identifier).length <= _maxIdentifierBytes) return true;
    diagnostics.add(
      DwDiagnostic.at(
        location,
        'the $what `$identifier` is longer than $_maxIdentifierBytes bytes, '
        'and Postgres would silently truncate it',
      ),
    );
    return false;
  }

  static String _dwType(WireType type) => switch (type) {
    ScalarWire(dartName: 'int') => 'DwType.bigint',
    ScalarWire(dartName: 'String') => 'DwType.text',
    ScalarWire() => 'DwType.boolean',
    DoubleWire() => 'DwType.doublePrecision',
    DateTimeWire() => 'DwType.timestamptz',
    DurationWire() => 'DwType.duration',
    BytesWire() => 'DwType.bytea',
    EnumWire(:final spelling) => 'DwEnumType($spelling.values)',
    ListWire(:final element) => 'DwJsonListType<${_jsonSpelling(element)}>()',
    MapWire(:final value) => 'DwJsonMapType<${_jsonSpelling(value)}>()',
    DtoWire() || PatchWire() => throw StateError('not a column type: $type'),
  };

  static String _jsonSpelling(WireType type) {
    final base = switch (type) {
      ScalarWire(:final dartName) => dartName,
      DoubleWire() => 'double',
      _ => throw StateError('not a jsonb element: $type'),
    };
    return type.nullable ? '$base?' : base;
  }

  /// The constant value of the first annotation that is the dartway_orm
  /// class [className] (or one of its constructors).
  static DartObject? _annotation(
    List<ElementAnnotation> annotations,
    String className,
  ) {
    for (final annotation in annotations) {
      final annotationElement = annotation.element;
      final classElement = annotationElement is ConstructorElement
          ? annotationElement.enclosingElement
          : annotationElement;
      if (classElement != null &&
          DwFramework.isOrmClass(classElement, className)) {
        return annotation.computeConstantValue();
      }
    }
    return null;
  }

  static String? _enumName(DartObject? value) =>
      value?.variable?.name ?? value?.getField('_name')?.toStringValue();

  static bool _reachesEntityBySuperclass(ClassElement element) {
    for (
      var type = element.supertype;
      type != null;
      type = type.element.supertype
    ) {
      if (DwFramework.isOrmClass(type.element, 'DwEntity')) return true;
    }
    return false;
  }

  static bool _declaresTable(ClassElement element) {
    final field = element.getField('table');
    return field != null && field.isStatic && field.isConst;
  }

  /// Names a column getter of the table class cannot take: the members of
  /// `DwTableDef` and `Object`, read from the ORM itself so the list follows
  /// it.
  Set<String> _reservedTableMembers() {
    final tableDef = names.library.firstFragment.scope
        .lookup('DwTableDef')
        .getter;
    final reserved = <String>{
      'hashCode',
      'runtimeType',
      'toString',
      'noSuchMethod',
    };
    if (tableDef is InterfaceElement) {
      for (final type in [tableDef.thisType, ...tableDef.allSupertypes]) {
        final member = type.element;
        for (final field in member.fields) {
          reserved.add(field.name!);
        }
        for (final method in member.methods) {
          reserved.add(method.name!);
        }
      }
    } else {
      reserved.addAll(const [
        'name',
        'columns',
        'indexSchemas',
        'schema',
        'fromRow',
        'toRow',
      ]);
    }
    reserved.remove('id');
    return reserved;
  }
}
