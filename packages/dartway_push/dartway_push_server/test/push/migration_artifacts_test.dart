import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// What a project inherits when it adds this module, and why only one file in
/// `migrations/` decides it.
///
/// Serverpod 3.4.11 never replays a module's migration chain against a
/// database. `ServerMigrationManager` is constructed with the *project*
/// directory, and `MigrationManager.migrateToLatest` migrates exactly one
/// module — the one `session.db.serializationManager.getModuleName()` names,
/// which is the project. A module's `migration.sql` and `definition.sql` are
/// read by nothing.
///
/// What *is* read is `definition_project.json` of the module's **last**
/// version, once, by `serverpod create-migration` running in the project
/// (`MigrationGenerator._loadModuleDatabaseDefinitions`). Its tables are merged
/// into the project's target definition, and the difference against the
/// project's previous definition becomes the project's own migration. So this
/// one file is the entire blast radius of the module on somebody's database: a
/// table that appears in it appears as a `CREATE TABLE` in every project that
/// runs `create-migration` next.
///
/// Which is why it is pinned here. The module's own `definition.sql` lists the
/// whole world — `serverpod_log`, `dw_auth_key` and the rest — because the
/// generator folds every dependency module into it and offers no way to ask it
/// not to. That file being a bootstrap is inert. This one quietly growing a
/// table the module does not own would not be.
void main() {
  const migrations = 'migrations';

  /// Exactly the tables this module owns. Adding a name here is a deliberate
  /// act: it becomes a `CREATE TABLE` in every project on the module.
  const ownedTables = {
    'dw_device_push_token',
    'dw_push_delivery',
    'dw_push_message',
    'dw_push_message_recipient',
    'dw_push_metric_bucket',
    'dw_push_recipient_state',
    'dw_push_runtime_state',
    'dw_push_source_link',
  };

  const moduleName = 'dartway_push';

  List<String> registeredVersions() =>
      File('$migrations/migration_registry.txt')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();

  List<String> versionDirectories() =>
      Directory(migrations)
          .listSync()
          .whereType<Directory>()
          .map(
            (directory) =>
                directory.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
          )
          .toList()
        ..sort();

  Map<String, dynamic> projectDefinition(String version) =>
      jsonDecode(
            File(
              '$migrations/$version/definition_project.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  List<Map<String, dynamic>> tablesOf(Map<String, dynamic> definition) =>
      (definition['tables'] as List).cast<Map<String, dynamic>>();

  group('what a project inherits from this module', () {
    test('is exactly the tables the module owns', () {
      final definition = projectDefinition(registeredVersions().last);

      expect(
        tablesOf(definition).map((table) => table['name']).toSet(),
        ownedTables,
        reason:
            'definition_project.json of the last migration is what '
            '"serverpod create-migration" merges into every project on this '
            'module. A name here that the module does not own becomes a '
            'CREATE TABLE against a database that already has that table.',
      );
    });

    test('and every one of them is attributed to this module', () {
      final definition = projectDefinition(registeredVersions().last);

      expect(definition['moduleName'], moduleName);
      for (final table in tablesOf(definition)) {
        expect(table['module'], moduleName, reason: '${table['name']}');
      }
    });
  });

  group('the migration registry', () {
    test('lists every version directory, and only those', () {
      // The registry warns in its own header that a merge can collide here. A
      // version in the registry with no directory makes `MigrationVersion.load`
      // throw in every project that generates a migration; a directory absent
      // from the registry is never read at all.
      expect(registeredVersions(), versionDirectories());
    });

    test('names the newest version last', () {
      // `_loadMigrationVersionsFromModules` takes `migrationVersions.last` and
      // nothing else. If that is not the newest, projects inherit an older
      // table set with nothing to say so.
      expect(registeredVersions().last, versionDirectories().last);
    });

    test('every version carries the files the loaders require', () {
      for (final version in registeredVersions()) {
        for (final artefact in const [
          'definition_project.json',
          'definition.json',
          'definition.sql',
          'migration.json',
          'migration.sql',
        ]) {
          expect(
            File('$migrations/$version/$artefact').existsSync(),
            isTrue,
            reason: '$version/$artefact',
          );
        }
      }
    });
  });
}
