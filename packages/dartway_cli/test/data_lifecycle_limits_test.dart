import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_data_lifecycle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The edges of the data lifecycle checks (#388): what they read as code and
/// as SQL, and which migrations they judge.
void main() {
  group('migrationChangesData reads the statements', () {
    test('an SQL comment is not a statement; the statement after it is', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) async {\n"
          "  await m.sql('-- UPDATE nothing SET x = 1, a note\\n'\n"
          "      'ALTER TABLE t ADD COLUMN x int');\n"
          "  await m.sql('-- rows of the old shape:\\n'\n"
          "      'DELETE FROM t WHERE x IS NULL');\n"
          "}\n",
        ),
        [(4, 'DELETE')],
      );
    });

    test('only the body of a function being defined passes', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) => m.sql(r'''\n"
          r"CREATE FUNCTION touch() RETURNS trigger AS $body$"
          "\n"
          r"BEGIN UPDATE t SET at = now(); RETURN NEW; END $body$"
          "\n"
          "LANGUAGE plpgsql;\n"
          "UPDATE t SET at = now();\n"
          "''');\n",
        ),
        [(1, 'UPDATE')],
      );
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) => m.sql(r'''\n"
          r"CREATE FUNCTION touch() RETURNS trigger AS $$"
          "\n"
          r"BEGIN UPDATE t SET at = now(); RETURN NEW; END $$"
          "\n"
          "LANGUAGE plpgsql''');\n",
        ),
        isEmpty,
      );
    });

    test('a table named by interpolation is still a statement', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) =>\n"
          r"    m.sql('UPDATE ${table} SET kind = 1');"
          "\n",
        ),
        [(2, 'UPDATE')],
      );
    });
  });

  group('migrationChangesData, more edges', () {
    test('a braceless interpolated table is still a statement', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) =>\n"
          r"    m.sql('DELETE FROM $table WHERE x IS NULL');"
          "\n",
        ),
        [(2, 'DELETE')],
      );
    });

    test("a rule's action is a definition, not a statement", () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) => m.sql(\n"
          "  'CREATE RULE keep AS ON DELETE TO item DO INSTEAD '\n"
          "  'UPDATE item SET gone = true WHERE id = OLD.id');\n",
        ),
        isEmpty,
      );
    });

    test("a write into the framework's tables is refused, even through "
        'backfill; carrySettings reads', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(
          "Future<void> up(DwMigrationContext m) async {\n"
          "  await m.backfill(\"INSERT INTO dw_setting (area, value) \"\n"
          "      \"VALUES ('AppSettings', '{}')\");\n"
          "  await m.backfill('UPDATE \"dw_account\" SET created_at = now()');\n"
          "  await m.carrySettings('AppSettings', fromSql: \"SELECT '{}'::jsonb\");\n"
          "}\n",
        ),
        [(2, 'INSERT dw_setting'), (4, 'UPDATE dw_account')],
      );
    });
  });

  group('workAfterServerStart anchors on the server', () {
    test('not on a stopwatch; a signal awaited before stop() passes', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn(r'''
Future<void> main() async {
  final watch = Stopwatch()..start();
  await provision();
  final server = AcmeServer.build(port: 8080);
  await server.start();
  server.logger.info('started in ${watch.elapsed}');
  await ProcessSignal.sigterm.watch().first;
  await server.stop();
}
'''),
        isEmpty,
      );
    });

    test('only awaiting a ProcessSignal watch passes, not anything that '
        'mentions one', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn('''
Future<void> main() async {
  final server = AcmeServer.build(port: 8080);
  await server.start();
  await ProcessSignal.sigint.watch().first;
  await seed(server, ProcessSignal.sigterm);
}
'''),
        [(5, 'await seed(server, ProcessSignal.sigterm);')],
      );
    });

    test('a DwAppServer built in place is anchored too', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn('''
Future<void> main() async {
  final app = DwAppServer(port: 8080);
  await app.start();
  await Catalog.seed(app.db);
}
'''),
        [(4, 'await Catalog.seed(app.db);')],
      );
    });
  });

  test('settingsKeyValueTable judges one class body at a time', () {
    expect(
      DwDataLifecycleInspector.keyValueTablesIn('''
@DwSqlTable('api_key')
final class ApiKeyRow extends DwTableRow {
  @DwUniqueColumn()
  final String key;
}

final class Pair {
  final String value;
}
'''),
      isEmpty,
    );
  });

  group('dataChecksAfter', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dw_cutoff'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    DwDataLifecycleInspector inspector() => DwDataLifecycleInspector(
      serverPackageDir: Directory(p.join(root.path, 'shop_server')),
      sharedPackageDir: null,
      flutterPackageDir: null,
      filterType: DwCheckType.migrationChangesData,
    );

    test('migrations up to it are not judged, the ones after are', () {
      write(
        'shop_server/lib/src/migrations/m20260901_100000_old.dart',
        "Future<void> up(m) => m.sql('DELETE FROM item');\n",
      );
      write(
        'shop_server/lib/src/migrations/m20260930_100000_new.dart',
        "Future<void> up(m) => m.sql('DELETE FROM item');\n",
      );
      write(
        'deploy/config.yaml',
        'migrations:\n  dataChecksAfter: 20260901_100000_old\n'
            'local:\n  DW_DATABASE_HOST: 127.0.0.1\n',
      );
      final run = inspector();
      expect(run.run(), 1);
      expect(run.findings.single.$2, contains('m20260930_100000_new.dart'));
    });

    test('unset, every migration is judged', () {
      write(
        'shop_server/lib/src/migrations/m20260901_100000_old.dart',
        "Future<void> up(m) => m.sql('DELETE FROM item');\n",
      );
      expect(inspector().run(), 1);
    });

    test('a value that is not a migration id, or names none, is a finding', () {
      write(
        'shop_server/lib/src/migrations/m20260930_100000_new.dart',
        "Future<void> up(m) => m.sql('CREATE TABLE item (id bigint)');\n",
      );
      write('deploy/config.yaml', 'migrations:\n  dataChecksAfter: latest\n');
      final wrong = inspector();
      expect(wrong.run(), 1);
      expect(wrong.findings.single.$2, contains('must be a migration id'));

      write(
        'deploy/config.yaml',
        'migrations:\n  dataChecksAfter: 20260101_000000_gone\n',
      );
      final missing = inspector();
      expect(missing.run(), 1);
      expect(missing.findings.single.$2, contains('names no migration'));
    });
  });
}
