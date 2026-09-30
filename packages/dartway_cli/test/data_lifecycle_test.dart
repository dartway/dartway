import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_tally.dart';
import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_data_lifecycle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Seeds, migrations, settings and patches each have one pattern (#388).
void main() {
  group('migrationChangesData', () {
    test('finds INSERT, UPDATE and DELETE, each on its line', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(r"""
Future<void> up(DwMigrationContext m) async {
  await m.sql('INSERT INTO "survey_question" ("title") VALUES (@title)');
  await m.query(
    'UPDATE "survey_question" SET "position" = @position, '
    '"kind" = @kind WHERE "id" = @id',
  );
  await m.sql('''
DELETE FROM issue_task WHERE issue_id IS NULL;
''');
  await m.sql("update project_issue as issue set merged_at = now()");
}
"""),
        [(2, 'INSERT'), (4, 'UPDATE'), (7, 'DELETE'), (10, 'UPDATE')],
      );
    });

    test('reads adjacent literals as one string', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn('''
Future<void> up(DwMigrationContext m) =>
    m.sql('UPDATE "user_profile" '
        'SET "trial_started_at" = "survey_completed_at"');
'''),
        [(2, 'UPDATE')],
      );
    });

    test('reads a raw literal beside a plain one as the same string', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(r"""
Future<void> up(DwMigrationContext m) =>
    m.sql('DELETE ' r'FROM "issue_event"');
"""),
        [(2, 'DELETE')],
      );
    });

    test('passes a statement given to backfill', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn(r"""
Future<void> up(DwMigrationContext m) async {
  await m.addColumn('t', DwColumnSchema('block', 'text'), backfill: "'a'");
  await m.backfill('''
UPDATE project_issue SET stage = 'development' WHERE stage = 'implementation';
DELETE FROM issue_event WHERE issue_id IS NULL;
''');
  await m.backfill(
    'UPDATE "user_profile" SET "trial_started_at" = @at',
    params: {'at': at},
  );
}
"""),
        isEmpty,
      );
    });

    test('a statement held in a variable is judged where it is written', () {
      expect(
        DwDataLifecycleInspector.dataChangesIn('''
const _rename = 'UPDATE t SET kind = 1';
Future<void> up(DwMigrationContext m) => m.backfill(_rename);
'''),
        [(1, 'UPDATE')],
      );
    });

    test(
      'schema statements, comments, routine bodies and identifiers pass',
      () {
        expect(
          DwDataLifecycleInspector.dataChangesIn(r"""
// INSERT INTO nothing — a comment
/// UPDATE t SET x = 1 in a doc comment
Future<void> up(DwMigrationContext m) async {
  await m.sql('CREATE TABLE t (id bigserial PRIMARY KEY, updated_at timestamptz)');
  await m.sql('ALTER TABLE t ADD COLUMN deleted_from text');
  await m.sql('CREATE INDEX t_update ON t (updated_at)');
  await m.sql('ALTER TABLE a ADD FOREIGN KEY (b) REFERENCES b (id) ON DELETE CASCADE');
  await m.sql('''
CREATE OR REPLACE FUNCTION touch() RETURNS trigger AS $$
BEGIN
  UPDATE t SET updated_at = now() WHERE id = NEW.id;
  RETURN NEW;
END $$ LANGUAGE plpgsql''');
  await m.sql('CREATE TRIGGER t_touch BEFORE INSERT OR UPDATE ON t '
      'FOR EACH ROW EXECUTE FUNCTION touch()');
}
"""),
          isEmpty,
        );
      },
    );
  });

  group('workAfterServerStart', () {
    test('finds what main does after start(), and only there', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn('''
Future<void> main() async {
  await provision();
  final server = AppServer.build();
  await server.start();
  await CatalogSeed.ensureSeeded(server.db);
  unawaited(server.runInContext(prompts));
  if (storage == null) {
    server.logger.warning('uploads are off');
  }
}

Future<void> helper() async {
  await other();
}
'''),
        [
          (5, 'await CatalogSeed.ensureSeeded(server.db);'),
          (6, 'unawaited(server.runInContext(prompts));'),
        ],
      );
    });

    test('logging and shutdown pass', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn('''
Future<void> main() async {
  final server = AppServer.build();
  await server.start();
  ProcessSignal.sigterm.watch().listen((_) async {
    await server.stop();
  });
  server.logger.info('await nothing: started');
  // await server.db — a comment
}
'''),
        isEmpty,
      );
    });

    test('a file that never starts a server passes', () {
      expect(
        DwDataLifecycleInspector.workAfterStartIn(
          'Future<void> main() async => await run();',
        ),
        isEmpty,
      );
    });
  });

  group('settingsKeyValueTable', () {
    test('finds a unique string key beside a string value', () {
      expect(
        DwDataLifecycleInspector.keyValueTablesIn('''
@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow with _\$AppSettingRow {
  const AppSettingRow({this.id, required this.key, required this.value});

  @override
  final int? id;

  @DwUniqueColumn()
  final String key;

  final String value;

  static const tableDef = AppSettingTable();
}

@DwSqlTable('exercise')
final class ExerciseRow extends DwTableRow with _\$ExerciseRow {
  @DwUniqueColumn()
  final String slug;
  final String title;
}
'''),
        [(1, 'app_setting')],
      );
    });

    test('a key that is not unique, or no value beside it, passes', () {
      expect(
        DwDataLifecycleInspector.keyValueTablesIn('''
@DwSqlTable('translation')
final class TranslationRow extends DwTableRow {
  final String key;
  final String locale;
  final String value;
}

@DwSqlTable('api_key')
final class ApiKeyRow extends DwTableRow {
  @DwUniqueColumn()
  final String key;
  final DateTime issuedAt;
}
'''),
        isEmpty,
      );
    });
  });

  group('fieldPatchMatched', () {
    test('finds each variant named in code', () {
      expect(
        DwDataLifecycleInspector.patchMatchesIn('''
String? text(DwFieldPatch<String> patch, String? current) => switch (patch) {
  DwSetField(:final value) when value.trim().isEmpty => null,
  DwClearField() => null,
  _ => current,
};
final kept = patch is DwKeepField;
'''),
        [(2, 'DwSetField'), (3, 'DwClearField'), (6, 'DwKeepField')],
      );
    });

    test('the helpers, constructors, comments and strings pass', () {
      expect(
        DwDataLifecycleInspector.patchMatchesIn(r'''
/// Never match `DwSetField` by hand.
final summary = command.summary.trimmedOrCleared.apply(row.summary);
final cover = command.coverFileId.newValue;
final cleared = command.domain.isCleared;
const keep = DwFieldPatch<int>.keep();
final text = 'DwSetField';
'''),
        isEmpty,
      );
    });
  });

  group('over a project', () {
    late Directory root;
    Directory package(String name) => Directory(p.join(root.path, name));

    setUp(() => root = Directory.systemTemp.createTempSync('dw_lifecycle'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String content) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    DwDataLifecycleInspector inspector({
      DwCheckType? filterType,
      DwCheckSeverity? filterSeverity,
    }) => DwDataLifecycleInspector(
      serverPackageDir: package('shop_server'),
      sharedPackageDir: package('shop_shared'),
      flutterPackageDir: package('shop_flutter'),
      filterType: filterType,
      filterSeverity: filterSeverity,
    );

    void writeAll() {
      write(
        'shop_server/lib/src/migrations/m20260930_100000_seed.dart',
        "Future<void> up(m) => m.sql('INSERT INTO item (slug) VALUES (1)');\n",
      );
      // Not a migration: `migrations.dart` lists them.
      write(
        'shop_server/lib/src/migrations/migrations.dart',
        "const note = 'INSERT INTO nothing';\n",
      );
      write('shop_server/bin/server.dart', '''
Future<void> main() async {
  await server.start();
  await Seed.run(server.db);
}
''');
      write('shop_server/lib/src/settings/settings_rows.dart', '''
@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow {
  @DwUniqueColumn()
  final String key;
  final String value;
}
''');
      write(
        'shop_shared/lib/src/profile.dart',
        'final ok = lastName case DwSetField();\n',
      );
      write(
        'shop_flutter/test/support/fake.dart',
        'final ok = lastName is DwClearField;\n',
      );
      // Generated code is the generator's, which reads the variants by design.
      write(
        'shop_shared/lib/src/profile.dw.dart',
        'final ok = lastName is DwClearField;\n',
      );
    }

    test('reports each check, names the file and line, and fails', () {
      writeAll();
      final tally = DwCheckTally();
      final run = inspector();
      expect(run.run(tally: tally), 5);
      expect(tally.counts, {
        DwCheckType.migrationChangesData: 1,
        DwCheckType.workAfterServerStart: 1,
        DwCheckType.settingsKeyValueTable: 1,
        DwCheckType.fieldPatchMatched: 2,
      });
      final text = run.findings.map((finding) => finding.$2).join('\n');
      expect(
        text,
        contains(
          '${p.join('shop_server', 'lib', 'src', 'migrations', 'm20260930_100000_seed.dart')}:1',
        ),
      );
      expect(
        text,
        contains('${p.join('shop_server', 'bin', 'server.dart')}:3'),
      );
      expect(
        text,
        contains('${p.join('shop_shared', 'lib', 'src', 'profile.dart')}:1'),
      );
      expect(
        text,
        contains('${p.join('shop_flutter', 'test', 'support', 'fake.dart')}:1'),
      );
    });

    test('a clean project passes', () {
      write('shop_server/lib/src/migrations/m20260930_100000_t.dart', '''
Future<void> up(m) async {
  await m.sql('CREATE TABLE item (id bigserial PRIMARY KEY)');
  await m.backfill("UPDATE item SET kind = 'a' WHERE kind = 'b'");
}
''');
      write('shop_server/bin/server.dart', '''
Future<void> main() async {
  await server.start();
  server.logger.info('up');
}
''');
      expect(inspector().run(), 0);
    });

    test('every check is an error, and runs only when asked for', () {
      for (final check in DwDataLifecycleInspector.checks) {
        expect(check.severity, DwCheckSeverity.error, reason: check.name);
      }
      writeAll();
      expect(inspector(filterType: DwCheckType.fileLong).run(), 0);
      expect(inspector(filterSeverity: DwCheckSeverity.warning).run(), 0);
      final only = inspector(filterType: DwCheckType.fieldPatchMatched);
      expect(only.run(), 2);
      expect(only.findings.map((finding) => finding.$1).toSet(), {
        DwCheckType.fieldPatchMatched,
      });
    });
  });
}
