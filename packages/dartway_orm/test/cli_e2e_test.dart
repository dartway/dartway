@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/test_database.dart';

/// The whole authoring loop in a real process: `create` writes Dart that is
/// compiled and run by the next command, exactly as `bin/migrate.dart` in a
/// project would.
void main() {
  late TestDatabase database;
  late Directory project;

  setUpAll(() async {
    database = await TestDatabase.create(withFixtureSchema: false);
    project = await Directory(
      p.join('.dart_tool', 'dw_cli_sandbox'),
    ).create(recursive: true).then((dir) => dir.createTemp('e2e_'));
    final migrations = Directory(p.join(project.path, 'migrations'));
    await migrations.create();
    await File(p.join(migrations.path, 'migrations.dart')).writeAsString('''
import 'package:dartway_orm/dartway_orm.dart';

final List<DwMigration> appMigrations = [];
''');
    final fixtures = p.relative(
      p.join(
        Directory.current.path,
        'test',
        'fixtures',
        'generated',
        'dw_schema.dart',
      ),
      from: project.path,
    );
    // v2 of the entities: club_session loses its note, club_service gains a
    // required level. Both are decisions.
    await File(p.join(project.path, 'migrate.dart')).writeAsString('''
import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';

import '$fixtures';
import 'migrations/migrations.dart';

DwSchema get schema {
  if (Platform.environment['SCHEMA'] != 'v2') return fixtureSchema;
  return DwSchema.fromTables([
    for (final table in fixtureSchema.tables)
      switch (table.name) {
        'club_session' => DwTableSchema(
          table.name,
          columns: [for (final c in table.columns) if (c.name != 'note_text') c],
          indexes: table.indexes,
        ),
        'club_service' => DwTableSchema(
          table.name,
          columns: [...table.columns, DwColumnSchema('level', 'bigint')],
          indexes: table.indexes,
        ),
        _ => table,
      },
  ]);
}

Future<void> main(List<String> args) async {
  final code = await DwMigrationCli(
    schema: schema,
    migrations: appMigrations,
    directory: '${p.join(project.path, 'migrations')}',
    scratchDatabasePrefix: 'orm_test_scratch_',
    clock: () => DateTime.parse(Platform.environment['NOW']!),
  ).run(args);
  exit(code);
}
''');
  });

  tearDownAll(() async {
    await database.dispose();
    await project.delete(recursive: true);
  });

  Future<ProcessResult> migrate(
    List<String> args, {
    String schema = 'v1',
    String now = '2026-09-14T08:00:00Z',
  }) {
    final config = testServerConfig(name: database.name);
    return Process.run(
      Platform.resolvedExecutable,
      ['run', p.join(project.path, 'migrate.dart'), ...args],
      environment: {
        'DW_DATABASE_HOST': config.host,
        'DW_DATABASE_PORT': '${config.port}',
        'DW_DATABASE_NAME': config.name,
        'DW_DATABASE_USER': config.user,
        'DW_DATABASE_PASSWORD': config.password,
        'DW_DATABASE_SSL': 'false',
        'SCHEMA': schema,
        'NOW': now,
      },
    );
  }

  Future<ProcessResult> analyze() => Process.run(Platform.resolvedExecutable, [
    'analyze',
    '--no-fatal-warnings',
    project.path,
  ]);

  String describe(ProcessResult result) =>
      'exit ${result.exitCode}\n${result.stdout}\n${result.stderr}';

  test('create, check, apply; then a draft with decisions', () async {
    var result = await migrate(['create', 'initial']);
    expect(result.exitCode, 0, reason: describe(result));

    result = await analyze();
    expect(result.exitCode, 0, reason: describe(result));
    expect(result.stdout, contains('No issues found!'));

    result = await migrate(['check']);
    expect(result.exitCode, 0, reason: describe(result));
    expect(
      result.stdout,
      contains('ok   up/down/up of 1 reversible migration(s)'),
    );

    result = await migrate(['apply']);
    expect(result.exitCode, 0, reason: describe(result));
    expect(result.stdout, contains('app/20260914_080000_initial'));

    result = await migrate(
      ['create', 'level'],
      schema: 'v2',
      now: '2026-09-15T09:00:00Z',
    );
    expect(result.exitCode, 0, reason: describe(result));
    expect(result.stdout, contains('2 decisions required'));

    // The draft does not compile until the author decides.
    result = await analyze();
    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains("'decisionRequired' isn't defined"));
    result = await migrate(['status'], schema: 'v2');
    expect(result.exitCode, isNot(0));

    final draft = File(
      p.join(project.path, 'migrations', 'm20260915_090000_level.dart'),
    );
    final decided = draft
        .readAsStringSync()
        .replaceFirst(
          "decisionRequired('add NOT NULL column club_service.level');",
          "await m.addColumn('club_service', DwColumnSchema('level', 'bigint'), backfill: '1');",
        )
        .replaceFirst(
          "decisionRequired('drop column club_session.note_text');",
          "await m.dropColumn('club_session', 'note_text');",
        );
    expect(decided, isNot(contains("decisionRequired('")));
    draft.writeAsStringSync(decided);

    // Editing the draft changed its source: check says so until it is resealed.
    result = await migrate(['check'], schema: 'v2');
    expect(result.exitCode, 3, reason: describe(result));
    expect(result.stdout, contains('rehash 20260915_090000_level'));
    result = await migrate(['rehash'], schema: 'v2');
    expect(result.exitCode, 0, reason: describe(result));

    result = await migrate(['check'], schema: 'v2');
    expect(result.exitCode, 0, reason: describe(result));
    expect(
      result.stdout,
      contains('ok   up/down/up of 2 reversible migration(s)'),
    );

    result = await migrate(['apply'], schema: 'v2');
    expect(result.exitCode, 0, reason: describe(result));
    expect(
      result.stdout,
      contains('applied batch 2:\n  app/20260915_090000_level'),
    );

    result = await migrate(['rollback'], schema: 'v2');
    expect(result.exitCode, 0, reason: describe(result));
    result = await migrate(['status'], schema: 'v2');
    expect(result.exitCode, 0, reason: describe(result));
    expect(result.stdout, contains('app/20260915_090000_level pending'));
  });
}
