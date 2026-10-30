import 'dart:io';
import 'dart:convert';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_server_contract.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The server's contract with its sources: generated code up to date and
/// migrations producing the schema. The generator and the migration runner do
/// the detecting; what these checks must get right is the verdict — a finding
/// only for a difference, and a note, never a pass, when nothing ran.
void main() {
  late Directory sandbox;
  late Directory server;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_server_contract');
    server = Directory(p.join(sandbox.path, 'shop_server'))
      ..createSync(recursive: true);
    File(p.join(server.path, 'bin', 'migrate.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('');
    File(p.join(server.path, '.dart_tool/package_config.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {
              'name': 'dartway_generator',
              'rootUri': p.toUri(p.absolute('../dartway_generator')).toString(),
            },
          ],
        }),
      );
  });

  tearDown(() => sandbox.deleteSync(recursive: true));

  DwDartProbe answering(int exitCode, String stdout, [String stderr = '']) =>
      (arguments, workingDirectory) =>
          ProcessResult(0, exitCode, stdout, stderr);

  group('generatedCodeStale', () {
    test('runs the generator the server resolved, over the project', () {
      late List<String> ran;
      late String where;
      final inspector = DwGeneratedCodeInspector(
        serverPackageDir: server,
        probe: (arguments, workingDirectory) {
          ran = arguments;
          where = workingDirectory;
          return ProcessResult(
            0,
            0,
            'dartway generate --check: 7 up to date',
            '',
          );
        },
      );
      expect(inspector.run(), 0);
      expect(ran, [
        '--packages=${p.join(server.path, '.dart_tool/package_config.json')}',
        p.normalize(
          p.absolute('../dartway_generator/bin/dartway_generator.dart'),
        ),
        '--project',
        sandbox.path,
        '--check',
      ]);
      expect(where, server.path);
      expect(inspector.findings, isEmpty);
      expect(inspector.notes, isEmpty);
    });

    test('every out-of-date and stale file is an error', () {
      final inspector = DwGeneratedCodeInspector(
        serverPackageDir: server,
        probe: answering(
          1,
          '  out of date shop_shared/lib/src/cart.dw.dart\n'
              '  stale shop_server/lib/src/entities/old.dw.dart\n',
          'dartway generate --check: 1 out of date, 1 stale',
        ),
      );
      expect(inspector.run(), 2);
      expect(inspector.findings, [
        'out of date shop_shared/lib/src/cart.dw.dart',
        'stale shop_server/lib/src/entities/old.dw.dart',
      ]);
    });

    test('an unverified project contract is an error', () {
      final inspector = DwGeneratedCodeInspector(
        serverPackageDir: server,
        probe: answering(
          1,
          '',
          'shop_server has no resolved package config; run `dart pub get`',
        ),
      );
      expect(inspector.run(), 1);
      expect(inspector.findings, isEmpty);
      expect(inspector.notes, isEmpty);
    });

    test('filtered to another check, it runs nothing', () {
      var ran = false;
      DwGeneratedCodeInspector(
        serverPackageDir: server,
        filterType: DwCheckType.migrationsDrift,
        probe: (arguments, workingDirectory) {
          ran = true;
          return null;
        },
      ).run();
      expect(ran, isFalse);
    });
  });

  group('migrationsDrift', () {
    test('judges only migrations after dataChecksAfter', () {
      final migrations = Directory(p.join(server.path, 'lib/src/migrations'))
        ..createSync(recursive: true);
      for (final name in [
        'm20260901_100000_old.dart',
        'm20260930_100000_new.dart',
      ]) {
        File(p.join(migrations.path, name)).writeAsStringSync(
          "void up(m) { m.execute('ALTER TABLE orders ADD COLUMN label text NOT NULL'); }",
        );
      }
      File(p.join(sandbox.path, 'deploy/config.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'migrations:\n  dataChecksAfter: 20260901_100000_old\n',
        );

      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {},
      );

      expect(inspector.run(), 1);
      expect(inspector.findings.single, contains('m20260930_100000_new.dart'));
    });

    for (final boundary in ['latest', '20260101_000000_gone']) {
      test('reports invalid dataChecksAfter boundary $boundary', () {
        final migration = File(
          p.join(server.path, 'lib/src/migrations/m20260930_100000_new.dart'),
        );
        migration.parent.createSync(recursive: true);
        migration.writeAsStringSync('void up(m) {}');
        File(p.join(sandbox.path, 'deploy/config.yaml'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('migrations:\n  dataChecksAfter: $boundary\n');

        final inspector = DwMigrationsInspector(
          serverPackageDir: server,
          environment: const {},
        );

        expect(inspector.run(), 1);
        expect(
          inspector.findings.single,
          contains(
            boundary == 'latest'
                ? 'must be a migration id'
                : 'names no migration',
          ),
        );
      });
    }

    test('refuses a required addColumn with only a backfill', () {
      final file = File(p.join(server.path, 'lib/src/migrations/m_added.dart'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        "void up(m) { m.addColumn('orders', DwColumnSchema('label', 'text'), backfill: 'old'); }",
      );
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {},
      );
      expect(inspector.run(), 1);
    });
    for (final body in [
      "m.addColumn('orders', DwColumnSchema('label', 'text', nullable: true));",
      "m.addColumn('orders', DwColumnSchema('label', 'text', defaultSql: 'current_user'));",
      "m.createTable(DwTableSchema('orders', columns: [])); m.addColumn('orders', DwColumnSchema('label', 'text'));",
      "} void down(m) { m.addColumn('orders', DwColumnSchema('label', 'text'));",
    ]) {
      test('accepts safe migration builder: $body', () {
        final file = File(
          p.join(server.path, 'lib/src/migrations/m_safe.dart'),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('void up(m) { $body }');
        final inspector = DwMigrationsInspector(
          serverPackageDir: server,
          environment: const {},
        );
        expect(inspector.run(), 0);
      });
    }
    test('refuses a new required column without a default even offline', () {
      final migration = File(
        p.join(server.path, 'lib/src/migrations/m_new.dart'),
      );
      migration.parent.createSync(recursive: true);
      migration.writeAsStringSync(
        "void up(m) { m.execute('ALTER TABLE orders ADD COLUMN label text NOT NULL'); }",
      );
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {},
      );
      expect(inspector.run(), 1);
      expect(inspector.findings.single, contains('nullable'));
      expect(inspector.findings.single, contains('DEFAULT'));
    });

    for (final sql in [
      'ALTER TABLE orders ADD COLUMN label text NOT NULL DEFAULT \"new\"',
      'ALTER TABLE orders ADD COLUMN label text',
      'CREATE TABLE orders (id int); ALTER TABLE orders ADD label text NOT NULL',
      'ALTER TABLE orders ADD COLUMN id int GENERATED ALWAYS AS IDENTITY NOT NULL',
    ]) {
      test('accepts safe addition: $sql', () {
        final file = File(
          p.join(server.path, 'lib/src/migrations/m_safe.dart'),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync("void up(m) { m.execute('$sql'); }");
        final inspector = DwMigrationsInspector(
          serverPackageDir: server,
          environment: const {},
        );
        expect(inspector.run(), 0);
        expect(inspector.findings, isEmpty);
      });
    }
    test(
      'refuses the required column in a multi-action ALTER with a default on another column',
      () {
        final file = File(p.join(server.path, 'lib/src/migrations/m_bad.dart'));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          "void up(m) { m.execute('ALTER TABLE orders ADD amount numeric(10,2) DEFAULT 0, ADD label text NOT NULL'); }",
        );
        final inspector = DwMigrationsInspector(
          serverPackageDir: server,
          environment: const {},
        );
        expect(inspector.run(), 1);
      },
    );
    test('without a database it says it did not run, and passes nothing', () {
      var ran = false;
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {},
        probe: (arguments, workingDirectory) {
          ran = true;
          return null;
        },
      );
      expect(inspector.run(), 0);
      expect(ran, isFalse);
      expect(inspector.notes.single, contains('DW_DATABASE_*'));
    });

    test('with a database it runs the check and passes on success', () {
      late List<String> ran;
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {'DW_DATABASE_HOST': '127.0.0.1'},
        probe: (arguments, workingDirectory) {
          ran = arguments;
          return ProcessResult(0, 0, 'ok   migrations produce the schema', '');
        },
      );
      expect(inspector.run(), 0);
      expect(ran, ['run', 'bin/migrate.dart', 'check']);
      expect(inspector.notes, isEmpty);
    });

    test('each FAIL with its details is an error', () {
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {'DW_DATABASE_HOST': '127.0.0.1'},
        probe: answering(
          3,
          "FAIL migrations do not produce the row classes' schema; missing changes:\n"
          '       add column cart.note\n'
          'FAIL 20260914_000000_initial has a file but is not registered in migrations.dart\n',
        ),
      );
      expect(inspector.run(), 2);
      expect(inspector.findings.first, contains('add column cart.note'));
      expect(inspector.findings.last, contains('not registered'));
    });

    test('a database that cannot be reached is a note, not a finding', () {
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {'DW_DATABASE_HOST': '127.0.0.1'},
        probe: answering(1, 'failed: SocketException: Connection refused'),
      );
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
      expect(inspector.notes.single, contains('Connection refused'));
    });

    test('a server package without bin/migrate.dart has nothing to check', () {
      File(p.join(server.path, 'bin', 'migrate.dart')).deleteSync();
      final inspector = DwMigrationsInspector(
        serverPackageDir: server,
        environment: const {},
      );
      expect(inspector.run(), 0);
      expect(inspector.notes, isEmpty);
    });
  });
}
