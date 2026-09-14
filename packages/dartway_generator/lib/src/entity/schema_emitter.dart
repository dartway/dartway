import '../emit/source_text.dart';
import 'entity_model.dart';

/// Writes `lib/generated/dw_schema.dart` of the server package: the schema and
/// the `DwDatabaseHandle` extension with one repository getter per row class.
abstract final class SchemaEmitter {
  static String emit({
    required String baseName,
    required List<EntityClass> entities,
    required List<String> imports,
  }) {
    final sorted = [...entities]..sort((a, b) => a.name.compareTo(b.name));
    final out = StringBuffer()
      ..writeln(generatedHeader)
      ..writeln("import 'package:dartway_orm/dartway_orm.dart';");
    if (imports.isNotEmpty) out.writeln();
    for (final uri in imports) {
      out.writeln('import ${dartString(uri)};');
    }
    out
      ..writeln()
      ..writeln(
        'final DwDatabaseSchema ${camelCase(baseName)}Schema = DwDatabaseSchema(['
        '${sorted.map((entity) => '${entity.name}.table').join(', ')}]);',
      )
      ..writeln()
      ..write('extension ${pascalCase(baseName)}Db on DwDatabaseHandle {');
    out.write(
      sorted
          .map(
            (entity) =>
                '\nDwTableRepository<${entity.name}, ${entity.tableClass}> get '
                '${entity.repositoryGetter} => repository(${entity.name}.table);\n',
          )
          .join(),
    );
    out.writeln('}');
    return out.toString();
  }
}
