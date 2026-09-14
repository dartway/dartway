import 'dart:io';

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
        'run',
        'dartway_generator',
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

    test('a generator that could not judge is a note, not a finding', () {
      final inspector = DwGeneratedCodeInspector(
        serverPackageDir: server,
        probe: answering(
          1,
          '',
          'shop_server has no resolved package config; run `dart pub get`',
        ),
      );
      expect(inspector.run(), 0);
      expect(inspector.findings, isEmpty);
      expect(inspector.notes.single, contains('dart pub get'));
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
