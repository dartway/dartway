import 'package:analyzer/dart/ast/token.dart';
import '../diagnostic.dart';
import '../emit/source_text.dart';
import 'entity_model.dart';

final class EntityRelation {
  const EntityRelation(
    this.source,
    this.target,
    this.field,
    this.name, {
    required this.many,
  });
  final EntityClass source;
  final EntityClass target;
  final EntityField field;
  final String name;
  final bool many;
}

List<EntityRelation> resolveRelations(
  List<EntityClass> entities,
  List<DwGenerationDiagnostic> diagnostics,
) {
  final relations = <EntityRelation>[];
  final ambiguousPairs = <String>{};
  final byTable = {for (final e in entities) e.tableName: e};
  for (final source in entities) {
    for (final field in source.fields) {
      final column = field.column;
      if (column?.foreignTable == null) continue;
      if (!column!.unique &&
          !source.indexes.any((i) => i.columns.first == column.sqlName)) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            source.element.getField(field.name) ?? source.element,
            'foreign key ${source.name}.${field.name} has no leading index; '
            "add DwTableIndex(['${field.name}']) and generate a migration",
            isWarning: true,
          ),
        );
      }
      final target = byTable[column.foreignTable];
      // External SQL/module/framework tables deliberately have no typed path.
      if (target == null) continue;
      final hidden = target.fields.where(
        (f) => const {'tablePath', 'include', 'includeSpec'}.contains(f.name),
      );
      if (hidden.isNotEmpty) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            target.element,
            'field `${hidden.first.name}` of ${target.name} conflicts with generated relation metadata; '
            'rename the Dart field and retain its SQL name with @DwColumnName',
          ),
        );
        continue;
      }
      final siblings = source.fields
          .where((f) => f.column?.foreignTable == column.foreignTable)
          .toList();
      if (siblings.length > 1 &&
          siblings.any(
            (f) => f.column!.relation == null || f.column!.reverse == null,
          )) {
        if (!ambiguousPairs.add('${source.tableName}/${target.tableName}')) {
          continue;
        }
        diagnostics.add(
          DwGenerationDiagnostic.at(
            source.element,
            'ambiguous relations ${siblings.map((f) => '${source.name}.${f.name}').join(', ')} '
            'to ${target.name}; name each with relation: and reverse: on @DwForeignKey; no relation emitted',
            isWarning: true,
          ),
        );
        continue;
      }
      final forward =
          column.relation ??
          (field.name.endsWith('Id')
              ? field.name.substring(0, field.name.length - 2)
              : field.name);
      relations.add(
        EntityRelation(source, target, field, forward, many: false),
      );
      relations.add(
        EntityRelation(
          target,
          source,
          field,
          column.reverse ?? source.repositoryGetter,
          many: true,
        ),
      );
    }
  }
  const reserved = {
    'id',
    'tableName',
    'tablePath',
    'tableColumns',
    'indexSchemas',
    'tableSchema',
    'fromRow',
    'toRow',
    'toDraftRow',
    'include',
    'includeSpec',
    'hashCode',
    'runtimeType',
    'toString',
    'noSuchMethod',
  };
  final invalid = <EntityRelation>{};
  for (final relation in relations) {
    final conflicts = relations
        .where((r) => r.source == relation.source && r.name == relation.name)
        .toList();
    if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(relation.name) ||
        reserved.contains(relation.name) ||
        (Keyword.keywords[relation.name]?.isReservedWord ?? false) ||
        relation.source.fields.any((f) => f.name == relation.name) ||
        conflicts.length > 1) {
      invalid.addAll(conflicts);
      diagnostics.add(
        DwGenerationDiagnostic.at(
          relation.source.element,
          'relation name `${relation.name}` collides or is invalid on ${relation.source.name}: '
          '${conflicts.map((r) => '${r.field.name} (${r.target.name})').join(', ')}'
          '${relation.source.fields.any((f) => f.name == relation.name) ? '; field ${relation.source.name}.${relation.name}' : ''}; '
          'set relation: / reverse: on @DwForeignKey; no relation emitted',
          isWarning: true,
        ),
      );
    }
  }
  final invalidFields = {for (final r in invalid) r.field};
  return relations.where((r) => !invalidFields.contains(r.field)).toList();
}

String emitRelations(
  List<EntityClass> entities,
  List<EntityRelation> relations,
) {
  final out = StringBuffer();
  for (final entity in entities) {
    final own = relations.where((r) => r.source == entity).toList();
    final referenced = relations.any((r) => r.target == entity && !r.many);
    final receivers = [
      (entity.tableClass, false),
      if (referenced) ...[
        ('${entity.entityName}Relation', false),
        ('${entity.entityName}NullableRelation', true),
      ],
    ];
    for (final (receiver, nullablePath) in receivers) {
      if (own.isEmpty) continue;
      out.writeln('extension ${receiver}Relations on $receiver {');
      for (final r in own) {
        final path =
            'DwRelationPath(${dartString(r.source.tableName)}, '
            '${dartString(r.target.tableName)}, ${dartString(r.field.column!.sqlName)}, '
            'parent: tablePath${r.many ? ', many: true' : ''})';
        if (r.many) {
          out.writeln(
            'DwToManyRelation<${r.target.name}, ${r.target.tableClass}> get ${r.name} => '
            'DwToManyRelation(const ${r.target.tableClass}(), $path);',
          );
        } else {
          final nullable = nullablePath || r.field.type.nullable;
          final type =
              '${r.target.entityName}${nullable ? 'Nullable' : ''}Relation';
          out.writeln('$type get ${r.name} => $type($path);');
        }
      }
      out.writeln('}');
    }
  }
  return out.toString();
}

String emitRelationViews(EntityClass entity) {
  final out = StringBuffer();
  for (final nullable in [false, true]) {
    final type = '${entity.entityName}${nullable ? 'Nullable' : ''}Relation';
    out.writeln(
      'final class $type implements DwToOneRelation<${entity.name}${nullable ? '?' : ''}> {\n'
      'const $type(this.tablePath);\n'
      'final DwRelationPath tablePath;\n',
    );
    for (final field in entity.fields) {
      final spelling = nullable && !field.type.nullable
          ? '${field.spelling}?'
          : field.spelling;
      out.writeln(
        'DwTableColumn<$spelling> get ${field.name} => '
        '(const ${entity.tableClass}()).${field.name}.${nullable ? 'atNullablePath' : 'atPath'}(tablePath);',
      );
    }
    out.writeln(
      '@override DwIncludeSpec get includeSpec => DwIncludeSpec(const ${entity.tableClass}(), tablePath);\n'
      'DwRelationInclude include(List<DwRelationInclude> Function(${entity.tableClass} t) select) => '
      'DwIncludeSpec(const ${entity.tableClass}(), tablePath, nested: select(const ${entity.tableClass}()));\n'
      '}',
    );
  }
  return out.toString();
}
