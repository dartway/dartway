import 'dart:io';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:dartway_orm/src/migrations/dw_migration_checksum.dart';
import 'package:dartway_orm/src/migrations/dw_draft_writer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fixtures/generated/dw_schema.dart';
import 'support/test_database.dart';
import 'support/test_migration.dart';

DwTableSchema noteTable({bool withTitle = true}) => DwTableSchema(
  'note',
  columns: [
    DwColumnSchema.primaryKey(),
    DwColumnSchema('body', 'text'),
    if (withTitle) DwColumnSchema('title', 'text', nullable: true),
  ],
);

void main() {
  late TestDatabase database;
  late Directory sandbox;
  late StringBuffer out;

  setUp(() async {
    database = await TestDatabase.create(withFixtureSchema: false);
    sandbox = await Directory(
      p.join('.dart_tool', 'dw_cli_sandbox'),
    ).create(recursive: true).then((dir) => dir.createTemp('cli_'));
    out = StringBuffer();
  });
  tearDown(() async {
    await database.dispose();
    await sandbox.delete(recursive: true);
  });

  String migrationsDir() => p.join(sandbox.path, 'migrations');

  DwMigrationCli cli({
    DwDatabaseSchema? schema,
    List<DwDatabaseMigration> migrations = const [],
    Map<String, List<DwDatabaseMigration>> modules = const {},
  }) => DwMigrationCli(
    schema: schema ?? DwDatabaseSchema.fromTables(const []),
    migrations: migrations,
    directory: migrationsDir(),
    modules: modules,
    database: testServerConfig(name: database.name),
    scratchDatabasePrefix: 'orm_test_scratch_',
    clock: () => DateTime.utc(2026, 9, 14, 8, 30, 5),
    out: out,
  );

  /// A migration whose source file exists and is sealed, so `check` sees a
  /// consistent directory.
  Future<TestMigration> fileBacked(
    String id,
    Future<void> Function(DwMigrationContext m) up, {
    Future<void> Function(DwMigrationContext m)? down,
  }) async {
    final source = DwMigrationChecksum.seal('''
import 'package:dartway_orm/dartway_orm.dart';

final class M$id extends DwDatabaseMigration {
  @override
  String get id => '$id';

  @override
  String get checksum => '';

  // The test runs the same steps from a closure.
}
''');
    await Directory(migrationsDir()).create(recursive: true);
    await File(
      p.join(migrationsDir(), DwDraftWriter.fileName(id)),
    ).writeAsString(source);
    return TestMigration(
      id,
      checksum: DwMigrationChecksum.declared(source)!,
      onUp: up,
      onDown: down,
    );
  }

  group('usage', () {
    test('unknown commands and arguments exit 64', () async {
      expect(await cli().run(const []), DwMigrationCli.exitUsage);
      expect(await cli().run(['migrate']), DwMigrationCli.exitUsage);
      expect(await cli().run(['apply', 'now']), DwMigrationCli.exitUsage);
      expect(
        await cli().run(['rollback', '--batch', 'x']),
        DwMigrationCli.exitUsage,
      );
      expect(await cli().run(['create', 'Bad-Name']), DwMigrationCli.exitUsage);
      expect(out.toString(), contains('usage: migrate'));
      exitCode = 0;
    });
  });

  group('apply, status, rollback', () {
    test('map outcomes to exit codes', () async {
      final first = TestMigration(
        '20260101_000000_note',
        onUp: (m) => m.createTable(noteTable()),
        onDown: (m) => m.dropTable('note'),
      );
      expect(
        await cli(migrations: [first]).run(['apply']),
        DwMigrationCli.exitOk,
      );
      expect(
        out.toString(),
        contains('applied batch 1:\n  app/20260101_000000_note'),
      );
      expect(
        await cli(migrations: [first]).run(['status']),
        DwMigrationCli.exitOk,
      );
      expect(
        out.toString(),
        contains('app/20260101_000000_note applied (batch 1'),
      );

      final edited = TestMigration(
        first.id,
        checksum: 'edited',
        onUp: first.onUp,
        onDown: first.onDown,
      );
      expect(
        await cli(migrations: [edited]).run(['apply']),
        DwMigrationCli.exitRefused,
      );
      expect(out.toString(), contains('was edited after it was applied'));
      expect(
        await cli(migrations: [edited]).run(['status']),
        DwMigrationCli.exitRefused,
      );

      final failing = TestMigration(
        '20260102_000000_fails',
        onUp: (m) => m.sql('SELECT * FROM nowhere'),
      );
      expect(
        await cli(migrations: [first, failing]).run(['apply']),
        DwMigrationCli.exitFailed,
      );
      expect(
        out.toString(),
        contains('up of app/20260102_000000_fails failed'),
      );

      expect(
        await cli(
          migrations: [first],
        ).run(['rollback', '--id', 'app/${first.id}']),
        DwMigrationCli.exitOk,
      );
      expect(out.toString(), contains('rolled back:\n  app/${first.id}'));
      expect(
        await cli(migrations: [first]).run(['rollback']),
        DwMigrationCli.exitOk,
      );
      expect(out.toString(), contains('nothing to roll back'));
      exitCode = 0;
    });

    test('an unreachable database exits 1', () async {
      final unreachable = DwMigrationCli(
        schema: DwDatabaseSchema.fromTables(const []),
        migrations: const [],
        directory: migrationsDir(),
        database: DwDatabaseConfig(
          host: '127.0.0.1',
          port: 1,
          name: 'x',
          user: 'x',
          password: 'x',
          ssl: false,
          connectTimeout: const Duration(seconds: 2),
        ),
        out: out,
      );
      expect(await unreachable.run(['status']), DwMigrationCli.exitFailed);
      exitCode = 0;
    });
  });

  group('create', () {
    test('writes a sealed draft and its registration', () async {
      expect(
        await cli(schema: fixtureSchema).run(['create', 'initial']),
        DwMigrationCli.exitOk,
      );
      final file = File(
        p.join(migrationsDir(), 'm20260914_083005_initial.dart'),
      );
      final source = file.readAsStringSync();
      expect(
        source,
        contains(
          'final class M20260914083005Initial extends DwDatabaseMigration',
        ),
      );
      expect(source, contains("String get id => '20260914_083005_initial';"));
      expect(
        DwMigrationChecksum.declared(source),
        DwMigrationChecksum.of(source),
      );
      expect(source, isNot(contains('decisionRequired')));
      // Referenced tables come first; the self-reference stays inline.
      final order = [
        for (final match in RegExp(
          r"createTable\(\s*DwTableSchema\(\s*'(\w+)'",
        ).allMatches(source))
          match[1],
      ];
      expect(order, ['club_service', 'app_setting', 'club_session']);
      expect(source, contains("await m.dropTable('club_session');"));
      expect(
        source,
        contains(
          "DwColumnSchema('featured_service_id', 'bigint', nullable: true, unique: true, "
          "references: DwForeignKey('club_service', onDelete: DwOnDelete.setNull))",
        ),
      );

      final registration = File(
        p.join(migrationsDir(), 'migrations.dart'),
      ).readAsStringSync();
      expect(registration, contains("import 'm20260914_083005_initial.dart';"));
      expect(
        registration,
        contains('final List<DwDatabaseMigration> appMigrations = ['),
      );
      expect(registration, contains('  const M20260914083005Initial(),'));
      expect(out.toString(), contains('create table club_session'));
    });

    test('marks decisions and offers the rename', () async {
      final applied = TestMigration(
        '20260101_000000_note',
        onUp: (m) => m.createTable(noteTable()),
      );
      final target = DwDatabaseSchema.fromTables([
        DwTableSchema(
          'note',
          columns: [
            DwColumnSchema.primaryKey(),
            DwColumnSchema('body', 'text'),
            DwColumnSchema('heading', 'text'),
          ],
        ),
      ]);
      expect(
        await cli(
          schema: target,
          migrations: [applied],
        ).run(['create', 'rename_title']),
        DwMigrationCli.exitOk,
      );
      final source = File(
        p.join(migrationsDir(), 'm20260914_083005_rename_title.dart'),
      ).readAsStringSync();
      expect(
        source,
        contains("decisionRequired('add NOT NULL column note.heading');"),
      );
      expect(source, contains("decisionRequired('drop column note.title');"));
      expect(
        source,
        contains("//   await m.renameColumn('note', 'title', 'heading');"),
      );
      expect(source, contains('// 2 decisions required'));
      expect(out.toString(), contains('2 decisions required'));
    });

    test(
      'with no schema changes writes an empty migration for data work',
      () async {
        expect(
          await cli().run(['create', 'backfill_prices']),
          DwMigrationCli.exitOk,
        );
        final source = File(
          p.join(migrationsDir(), 'm20260914_083005_backfill_prices.dart'),
        ).readAsStringSync();
        expect(source, contains('No schema changes'));
        expect(source, isNot(contains('Future<void> down')));
        expect(out.toString(), contains('no schema changes'));
      },
    );

    test('module tables are not the project\'s to create or drop', () async {
      final account = TestMigration(
        '20200101_000000_account',
        onUp: (m) => m.createTable(
          DwTableSchema('dw_account', columns: [DwColumnSchema.primaryKey()]),
        ),
      );
      final target = DwDatabaseSchema.fromTables([
        DwTableSchema(
          'profile',
          columns: [
            DwColumnSchema.primaryKey(),
            DwColumnSchema(
              'account_id',
              'bigint',
              references: const DwForeignKey('dw_account'),
            ),
          ],
        ),
      ]);
      expect(
        await cli(
          schema: target,
          modules: {
            'dw': [account],
          },
        ).run(['create', 'profile']),
        DwMigrationCli.exitOk,
      );
      expect(out.toString(), contains('create table profile'));
      expect(out.toString(), isNot(contains('dw_account')));
    });
  });

  group('check', () {
    test('passes when files, schema and up/down/up agree', () async {
      final create = await fileBacked(
        '20260101_000000_note',
        (m) => m.createTable(noteTable(withTitle: false)),
        down: (m) => m.dropTable('note'),
      );
      final addTitle = await fileBacked(
        '20260102_000000_title',
        (m) => m.addColumn(
          'note',
          DwColumnSchema('title', 'text', nullable: true),
        ),
        down: (m) => m.dropColumn('note', 'title'),
      );
      final code = await cli(
        schema: DwDatabaseSchema.fromTables([noteTable()]),
        migrations: [create, addTitle],
      ).run(['check']);
      expect(code, DwMigrationCli.exitOk, reason: out.toString());
      expect(
        out.toString(),
        contains("ok   migrations produce the row classes' schema"),
      );
      expect(
        out.toString(),
        contains('ok   up/down/up of 2 reversible migration(s)'),
      );
    });

    test('fails on schema drift', () async {
      final create = await fileBacked(
        '20260101_000000_note',
        (m) => m.createTable(noteTable(withTitle: false)),
        down: (m) => m.dropTable('note'),
      );
      final code = await cli(
        schema: DwDatabaseSchema.fromTables([noteTable()]),
        migrations: [create],
      ).run(['check']);
      expect(code, DwMigrationCli.exitCheckFailed);
      expect(out.toString(), contains('add column note.title'));
    });

    test('fails when a down does not undo its up', () async {
      final create = await fileBacked(
        '20260101_000000_note',
        (m) => m.createTable(noteTable()),
        down: (m) => m.dropTable('note'),
      );
      final sloppy = await fileBacked(
        '20260102_000000_index',
        (m) => m.createIndex('note', DwIndexSchema('note_body_idx', ['body'])),
        down: (m) => m.noop(),
      );
      final code = await cli(
        schema: DwDatabaseSchema.fromTables([
          DwTableSchema(
            'note',
            columns: noteTable().columns,
            indexes: [
              DwIndexSchema('note_body_idx', ['body']),
            ],
          ),
        ]),
        migrations: [create, sloppy],
      ).run(['check']);
      expect(code, DwMigrationCli.exitCheckFailed, reason: out.toString());
      expect(
        out.toString(),
        contains('down of 20260102_000000_index does not restore'),
      );
    });

    test('stops the round trip at an irreversible migration', () async {
      final create = await fileBacked(
        '20260101_000000_note',
        (m) => m.createTable(noteTable()),
      );
      final index = await fileBacked(
        '20260102_000000_index',
        (m) => m.createIndex('note', DwIndexSchema('note_body_idx', ['body'])),
        down: (m) => m.dropIndex('note_body_idx'),
      );
      final code = await cli(
        schema: DwDatabaseSchema.fromTables([
          DwTableSchema(
            'note',
            columns: noteTable().columns,
            indexes: [
              DwIndexSchema('note_body_idx', ['body']),
            ],
          ),
        ]),
        migrations: [create, index],
      ).run(['check']);
      expect(code, DwMigrationCli.exitOk, reason: out.toString());
      expect(out.toString(), contains('20260101_000000_note is irreversible'));
      expect(
        out.toString(),
        contains('up/down/up of 1 reversible migration(s)'),
      );
    });

    test(
      'fails on an edited file or a registration mismatch; rehash reseals',
      () async {
        final create = await fileBacked(
          '20260101_000000_note',
          (m) => m.createTable(noteTable()),
          down: (m) => m.dropTable('note'),
        );
        final path = p.join(migrationsDir(), DwDraftWriter.fileName(create.id));
        File(path).writeAsStringSync(
          File(path).readAsStringSync().replaceFirst(
            '// The test',
            '// Edited: the test',
          ),
        );
        final schema = DwDatabaseSchema.fromTables([noteTable()]);
        expect(
          await cli(schema: schema, migrations: [create]).run(['check']),
          DwMigrationCli.exitCheckFailed,
        );
        expect(out.toString(), contains('run `rehash 20260101_000000_note`'));

        // Formatting alone is not an edit.
        File(path).writeAsStringSync(
          File(path).readAsStringSync().replaceAll('\n\n', '\n\n\n'),
        );
        expect(
          await cli(schema: schema).run(['rehash']),
          DwMigrationCli.exitOk,
        );
        expect(out.toString(), contains('resealed 20260101_000000_note'));
        final resealed = File(path).readAsStringSync();
        final registered = TestMigration(
          create.id,
          checksum: DwMigrationChecksum.declared(resealed)!,
          onUp: create.onUp,
          onDown: create.onDown,
        );
        out.clear();
        expect(
          await cli(schema: schema, migrations: [registered]).run(['check']),
          DwMigrationCli.exitOk,
          reason: out.toString(),
        );

        out.clear();
        expect(
          await cli(schema: schema, migrations: const []).run(['check']),
          DwMigrationCli.exitCheckFailed,
        );
        expect(out.toString(), contains('has a file but is not registered'));
        expect(await cli().run(['rehash', 'nope']), DwMigrationCli.exitUsage);
        exitCode = 0;
      },
    );
  });

  test('checksums ignore whitespace and the checksum literal', () {
    const a =
        "class M extends DwDatabaseMigration { String get checksum => 'abc'; }";
    const b =
        "class M extends DwDatabaseMigration {\n  String get checksum =>\n      'zzz';\n}";
    expect(DwMigrationChecksum.of(a), DwMigrationChecksum.of(b));
    expect(
      DwMigrationChecksum.of(a),
      isNot(DwMigrationChecksum.of(a.replaceFirst('M', 'N'))),
    );
    expect(() => DwMigrationChecksum.seal('class X {}'), throwsFormatException);
    expect(
      DwDraftWriter.registration(
        variable: 'pushMigrations',
        classesById: const {},
      ),
      contains('final List<DwDatabaseMigration> pushMigrations = [\n];'),
    );
  });
}
