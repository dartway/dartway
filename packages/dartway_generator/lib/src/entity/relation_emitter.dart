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
  final byTable = {for (final e in entities) e.tableName: e};
  for (final source in entities) {
    for (final field in source.fields) {
      final column = field.column;
      if (column?.foreignTable == null) continue;
      if (!column!.unique &&
          !source.indexes.any((i) => i.columns.first == column.sqlName)) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            source.element,
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
        (f) => const {'include', 'includeSpec'}.contains(f.name),
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
          (column.relation == null || column.reverse == null)) {
        diagnostics.add(
          DwGenerationDiagnostic.at(
            source.element,
            'ambiguous relations ${siblings.map((f) => '${source.name}.${f.name}').join(', ')} '
            'to ${target.name}; name each with relation: and reverse: on @DwForeignKey',
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
          '${conflicts.map((r) => '${r.field.name} (${r.target.name})').join(', ')}; '
          'set relation: / reverse: on @DwForeignKey',
        ),
      );
    }
  }
  return relations.where((r) => !invalid.contains(r)).toList();
}

String emitRelations(
  List<EntityClass> entities,
  List<EntityRelation> relations,
) {
  final out = StringBuffer();
  for (final entity in entities) {
    final own = relations.where((r) => r.source == entity).toList();
    if (own.isNotEmpty) {
      out.writeln(
        'extension ${entity.entityName}Relations on ${entity.tableClass} {',
      );
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
          final nullable = r.field.type.nullable ? '?' : '';
          out.writeln(
            '${r.target.entityName}Relation<${r.target.name}$nullable> get ${r.name} => '
            '${r.target.entityName}Relation($path);',
          );
        }
      }
      out.writeln('}');
    }
    if (!relations.any((r) => r.target == entity && !r.many)) continue;
    out.writeln(
      'final class ${entity.entityName}Relation<R extends ${entity.name}?> '
      'extends ${entity.tableClass} implements DwToOneRelation<R> {\n'
      'const ${entity.entityName}Relation(DwRelationPath path) : super(tablePath: path);\n'
      '@override DwIncludeSpec get includeSpec => DwIncludeSpec(this, tablePath!);\n'
      'DwRelationInclude include(List<DwRelationInclude> Function(${entity.tableClass} t) select) => '
      'DwIncludeSpec(this, tablePath!, nested: select(const ${entity.tableClass}()));\n'
      '}',
    );
  }
  return out.toString();
}
