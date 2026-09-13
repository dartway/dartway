import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/generated/dw_schema.dart';
import 'support/apply_changes.dart';
import 'support/test_database.dart';

DwColumnSchema text(String name, {bool nullable = false, String? defaultSql}) =>
    DwColumnSchema(name, 'text', nullable: nullable, defaultSql: defaultSql);

DwTableSchema table(
  String name,
  List<DwColumnSchema> columns, {
  List<DwIndexSchema> indexes = const [],
}) => DwTableSchema(
  name,
  columns: [DwColumnSchema.primaryKey(), ...columns],
  indexes: indexes,
);

void main() {
  late TestDatabase database;
  DwDb db() => database.db;

  setUp(() async {
    database = await TestDatabase.create(withFixtureSchema: false);
  });
  tearDown(() => database.dispose());

  Future<DwSchema> introspect() async =>
      (await DwIntrospector.read(db())).schema;

  Future<void> create(DwSchema schema) async {
    await applyChanges(
      DwMigrationContext(db()),
      DwSchemaDiff.compare(from: DwSchema.fromTables(const []), to: schema),
    );
  }

  /// Moves the live database from its schema to [to] through the diff and
  /// requires it to arrive exactly.
  Future<List<DwSchemaChange>> migrateTo(DwSchema to) async {
    final changes = DwSchemaDiff.compare(from: await introspect(), to: to);
    await applyChanges(DwMigrationContext(db()), changes);
    expect(await introspect(), to);
    return changes;
  }

  group('introspection', () {
    test('reads back exactly what the entities declare', () async {
      await create(fixtureSchema);
      final introspection = await DwIntrospector.read(db());
      expect(introspection.schema, fixtureSchema);
      expect(introspection.unmodelled, isEmpty);
      // Column order is part of the table, not of equality.
      expect(
        introspection.schema.table('club_service')!.columns.map((c) => c.name),
        fixtureSchema.table('club_service')!.columns.map((c) => c.name),
      );
    });

    test('lists what the model cannot express, and leaves it out', () async {
      await db().execute('''
        CREATE TABLE parent (id bigserial CONSTRAINT parent_pkey PRIMARY KEY, a bigint, b bigint);
        CREATE UNIQUE INDEX parent_a_b_uniq ON parent (a, b);
        ALTER TABLE parent ADD CONSTRAINT parent_ab UNIQUE (a, b);
        CREATE TABLE child (
          id bigserial CONSTRAINT child_pkey PRIMARY KEY,
          a bigint, b bigint,
          amount bigint CHECK (amount > 0),
          FOREIGN KEY (a, b) REFERENCES parent (a, b)
        );
        CREATE INDEX child_live_idx ON child (a) WHERE amount > 10;
        CREATE INDEX child_expr_idx ON child ((a + b));
        CREATE TABLE natural_key (code text PRIMARY KEY);
      ''');
      final introspection = await DwIntrospector.read(db());
      expect(introspection.unmodelled, hasLength(6));
      expect(
        introspection.unmodelled.join('\n'),
        allOf(
          contains('check constraint child_amount_check'),
          contains('foreign key child_a_b_fkey'),
          contains('unique constraint parent_ab'),
          contains('child_live_idx'),
          contains('child_expr_idx'),
          contains('primary key natural_key_pkey'),
        ),
      );
      expect(
        introspection.schema.table('parent')!.indexes.single,
        DwIndexSchema('parent_a_b_uniq', ['a', 'b'], unique: true),
      );
      expect(introspection.schema.table('child')!.indexes, isEmpty);
    });

    test('excludes tables and reads another schema', () async {
      await db().execute('''
        CREATE SCHEMA other;
        CREATE TABLE other.elsewhere (id bigserial CONSTRAINT elsewhere_pkey PRIMARY KEY);
        CREATE TABLE here (id bigserial CONSTRAINT here_pkey PRIMARY KEY);
        CREATE TABLE skipped (id bigint);
      ''');
      final public = await DwIntrospector.read(
        db(),
        excludeTables: {'skipped'},
      );
      expect(public.schema.tables.map((t) => t.name), ['here']);
      final other = await DwIntrospector.read(db(), schemaName: 'other');
      expect(other.schema, DwSchema.fromTables([table('elsewhere', const [])]));
    });
  });

  group('diff', () {
    test('identical schemas have no changes', () {
      expect(
        DwSchemaDiff.compare(from: fixtureSchema, to: fixtureSchema),
        isEmpty,
      );
    });

    test(
      'new tables are created referenced-first, cycles defer their keys',
      () async {
        final a = table('a', [
          DwColumnSchema(
            'b_id',
            'bigint',
            nullable: true,
            references: const DwReferences('b'),
          ),
        ]);
        final b = table('b', [
          DwColumnSchema(
            'a_id',
            'bigint',
            nullable: true,
            references: const DwReferences('a'),
          ),
          DwColumnSchema(
            'c_id',
            'bigint',
            references: const DwReferences('c', onDelete: DwOnDelete.cascade),
          ),
        ]);
        final c = table('c', [
          DwColumnSchema(
            'parent_id',
            'bigint',
            nullable: true,
            references: const DwReferences('c'),
          ),
        ]);
        final changes = await migrateTo(DwSchema.fromTables([a, b, c]));
        expect(changes.map((change) => change.toString()), [
          'create table c',
          'create table b',
          'create table a',
          'add foreign key b.a_id -> a',
        ]);
        expect(changes.any((change) => change.requiresDecision), isFalse);
      },
    );

    test('columns: add, drop, nullability, default, type', () async {
      await create(
        DwSchema.fromTables([
          table('t', [
            text('kept'),
            text('dropped'),
            text('becomes_required', nullable: true),
            text('becomes_optional'),
            text('gets_default'),
            DwColumnSchema('retyped', 'integer'),
          ]),
        ]),
      );
      final changes = await migrateTo(
        DwSchema.fromTables([
          table('t', [
            text('kept'),
            text('becomes_required'),
            text('becomes_optional', nullable: true),
            text('gets_default', defaultSql: "'x'::text"),
            DwColumnSchema('retyped', 'bigint'),
            text('added_optional', nullable: true),
            text('added_required'),
            text('added_with_default', defaultSql: "'d'::text"),
          ]),
        ]),
      );
      final decisions = {
        for (final change in changes)
          change.toString(): change.requiresDecision,
      };
      expect(decisions, {
        'add column t.added_optional': false,
        'add column t.added_required': true,
        'add column t.added_with_default': false,
        'change type of t.retyped from integer to bigint': true,
        "change default of t.gets_default from null to 'x'::text": false,
        'make t.becomes_required NOT NULL': true,
        'make t.becomes_optional nullable': false,
        'drop column t.dropped': true,
      });
      // Drops come last, after everything that might still need the column.
      expect(changes.last, isA<DwDropColumn>());
    });

    test('constraints and indexes: add, drop, change', () async {
      await create(
        DwSchema.fromTables([
          table('target', const []),
          table('other_target', const []),
          table(
            't',
            [
              DwColumnSchema(
                'ref',
                'bigint',
                references: const DwReferences('target'),
              ),
              DwColumnSchema(
                'ref_changed',
                'bigint',
                references: const DwReferences('target'),
              ),
              DwColumnSchema(
                'unref',
                'bigint',
                nullable: true,
                references: const DwReferences('target'),
              ),
              text('code', nullable: true),
              text('was_unique', nullable: true).copyWith(unique: true),
              text('name', nullable: true),
            ],
            indexes: [
              DwIndexSchema('t_name_idx', ['name']),
              DwIndexSchema('t_code_idx', ['code']),
            ],
          ),
        ]),
      );
      final changes = await migrateTo(
        DwSchema.fromTables([
          table('target', const []),
          table('other_target', const []),
          table(
            't',
            [
              DwColumnSchema(
                'ref',
                'bigint',
                references: const DwReferences('target'),
              ),
              DwColumnSchema(
                'ref_changed',
                'bigint',
                references: const DwReferences(
                  'other_target',
                  onDelete: DwOnDelete.cascade,
                ),
              ),
              DwColumnSchema('unref', 'bigint', nullable: true),
              text('code', nullable: true).copyWith(unique: true),
              text('was_unique', nullable: true),
              text('name', nullable: true),
            ],
            indexes: [
              DwIndexSchema('t_name_idx', ['name', 'code']),
              DwIndexSchema('t_code_name_key', ['code', 'name'], unique: true),
            ],
          ),
        ]),
      );
      expect(changes.map((change) => change.toString()).toSet(), {
        'drop index t_code_idx(code) on t',
        'drop index t_name_idx(name) on t',
        'drop foreign key t.ref_changed -> target',
        'drop foreign key t.unref -> target',
        'drop unique t.was_unique',
        'add unique t.code',
        'add foreign key t.ref_changed -> other_target',
        'create unique index t_code_name_key(code, name) on t',
        'create index t_name_idx(name, code) on t',
      });
      expect(changes.any((change) => change.requiresDecision), isFalse);
    });

    test(
      'a dropped table is a decision, dropped referencing tables first',
      () async {
        await create(
          DwSchema.fromTables([
            table('kept', const []),
            table('gone_parent', const []),
            table('gone_child', [
              DwColumnSchema(
                'parent_id',
                'bigint',
                references: const DwReferences('gone_parent'),
              ),
            ]),
          ]),
        );
        final changes = await migrateTo(
          DwSchema.fromTables([table('kept', const [])]),
        );
        expect(changes.map((change) => change.toString()), [
          'drop table gone_child',
          'drop table gone_parent',
        ]);
        expect(changes.every((change) => change.requiresDecision), isTrue);
      },
    );

    test(
      'a NOT NULL column added with a backfill fills existing rows',
      () async {
        await create(
          DwSchema.fromTables([
            table('t', [text('a', nullable: true)]),
          ]),
        );
        await db().execute("INSERT INTO t (a) VALUES ('x'), (NULL)");
        await migrateTo(
          DwSchema.fromTables([
            table('t', [text('a'), DwColumnSchema('n', 'bigint')]),
          ]),
        );
        final rows = await db().query('SELECT a, n FROM t ORDER BY id');
        expect(rows.map((row) => row['a']), ['x', '0']);
        expect(rows.map((row) => row['n']), [0, 0]);
      },
    );

    test('every change has an inverse that restores the schema', () async {
      final before = DwSchema.fromTables([
        table('target', const []),
        table(
          't',
          [
            text('a'),
            DwColumnSchema(
              'ref',
              'bigint',
              nullable: true,
              references: const DwReferences('target'),
            ),
          ],
          indexes: [
            DwIndexSchema('t_a_idx', ['a']),
          ],
        ),
      ]);
      await create(before);
      final changes = await migrateTo(
        DwSchema.fromTables([
          table('target', const []),
          table('t', [
            text(
              'a',
              nullable: true,
              defaultSql: "'z'::text",
            ).copyWith(unique: true),
            text('b', nullable: true),
          ]),
          table('fresh', [
            DwColumnSchema(
              't_id',
              'bigint',
              references: const DwReferences('t'),
            ),
          ]),
        ]),
      );
      await applyChanges(DwMigrationContext(db()), [
        for (final change in changes.reversed) change.inverse,
      ]);
      expect(await introspect(), before);
    });
  });

  group('schema values', () {
    test('identifiers longer than 63 bytes are refused', () {
      expect(() => DwColumnSchema('x' * 64, 'text'), throwsArgumentError);
      expect(
        () => DwTableSchema(
          't' * 40,
          columns: [text('c' * 20).copyWith(unique: true)],
        ),
        throwsArgumentError,
      );
    });

    test('duplicates and dangling index columns are refused', () {
      expect(
        () => DwTableSchema('t', columns: [text('a'), text('a')]),
        throwsArgumentError,
      );
      expect(
        () => DwTableSchema(
          't',
          columns: [text('a')],
          indexes: [
            DwIndexSchema('i', ['b']),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => DwSchema.fromTables([table('t', const []), table('t', const [])]),
        throwsArgumentError,
      );
    });
  });
}
