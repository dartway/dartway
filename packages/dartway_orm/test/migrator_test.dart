import 'dart:async';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'support/test_database.dart';
import 'support/test_migration.dart';

TestMigration createTable(
  String id,
  String table, {
  List<DwColumnSchema> extra = const [],
  List<DwMigrationRef> dependsOn = const [],
  String checksum = 'sealed',
}) => TestMigration(
  id,
  checksum: checksum,
  dependsOn: dependsOn,
  onUp: (m) => m.createTable(
    DwTableSchema(table, columns: [DwColumnSchema.primaryKey(), ...extra]),
  ),
  onDown: (m) => m.dropTable(table),
);

void main() {
  late TestDatabase database;
  DwDatabaseHandle db() => database.db;

  setUp(() async {
    database = await TestDatabase.create(withFixtureSchema: false);
  });
  tearDown(() => database.dispose());

  Future<Set<String>> tables() async => {
    for (final row in await db().query(
      "SELECT tablename::text AS name FROM pg_tables WHERE schemaname = 'public'",
    ))
      row.get<String>('name'),
  };

  Future<List<String>> ledger() async => [
    for (final row in await db().query(
      "SELECT namespace || '/' || id || ':' || batch || ':' || state AS entry "
      'FROM dw_migrations ORDER BY seq',
    ))
      row.get<String>('entry'),
  ];

  group('apply', () {
    test('applies pending migrations as one batch and is idempotent', () async {
      final migrations = {
        'app': [
          createTable('20260101_000000_a', 'a'),
          createTable('20260102_000000_b', 'b'),
        ],
      };
      final run = await DwMigrationRunner(db(), migrations: migrations).apply();
      expect(run.batch, 1);
      expect(run.migrations, const [
        DwMigrationRef('app', '20260101_000000_a'),
        DwMigrationRef('app', '20260102_000000_b'),
      ]);
      expect(await tables(), containsAll(['a', 'b', 'dw_migrations']));

      final again = await DwMigrationRunner(
        db(),
        migrations: migrations,
      ).apply();
      expect(again.isEmpty, isTrue);
      expect(again.batch, isNull);

      migrations['app']!.add(createTable('20260103_000000_c', 'c'));
      final next = await DwMigrationRunner(
        db(),
        migrations: migrations,
      ).apply();
      expect(next.batch, 2);
      expect(await ledger(), [
        'app/20260101_000000_a:1:applied',
        'app/20260102_000000_b:1:applied',
        'app/20260103_000000_c:2:applied',
      ]);
    });

    test('orders by dependsOn first, then by id, across namespaces', () async {
      final run = await DwMigrationRunner(
        db(),
        migrations: {
          'app': [
            // Sorts first by id, yet references a table of a later one.
            createTable(
              '20200101_000000_early',
              'early',
              extra: [
                DwColumnSchema(
                  'late_id',
                  'bigint',
                  references: const DwForeignKey('late'),
                ),
              ],
              dependsOn: const [DwMigrationRef('app', '20260101_000000_late')],
            ),
            createTable(
              '20260101_000000_late',
              'late',
              extra: [
                DwColumnSchema(
                  'account_id',
                  'bigint',
                  references: const DwForeignKey('dw_account'),
                ),
              ],
              dependsOn: const [
                DwMigrationRef('dw', '20300101_000000_account'),
              ],
            ),
          ],
          'dw': [createTable('20300101_000000_account', 'dw_account')],
        },
      ).apply();
      expect(run.migrations.map((ref) => ref.toString()), [
        'dw/20300101_000000_account',
        'app/20260101_000000_late',
        'app/20200101_000000_early',
      ]);
    });

    test(
      'a dependency applied earlier by another migrator is satisfied',
      () async {
        await DwMigrationRunner(
          db(),
          migrations: {
            'dw': [createTable('1_account', 'dw_account')],
          },
        ).apply();
        final run = await DwMigrationRunner(
          db(),
          migrations: {
            'app': [
              createTable(
                '2_profile',
                'profile',
                dependsOn: const [DwMigrationRef('dw', '1_account')],
              ),
            ],
          },
        ).apply();
        expect(run.migrations.single.id, '2_profile');
      },
    );

    test('namespaces are owned separately', () async {
      await DwMigrationRunner(
        db(),
        migrations: {
          'dw': [createTable('1_framework', 'framework')],
          'app': [createTable('1_app', 'app_table')],
        },
      ).apply();
      // A migrator given only `app` neither validates nor touches `dw` rows,
      // and the same id in two namespaces is two migrations.
      final run = await DwMigrationRunner(
        db(),
        migrations: {
          'app': [
            createTable('1_app', 'app_table'),
            createTable('1_framework', 'app_framework'),
          ],
        },
      ).apply();
      expect(run.migrations.single, const DwMigrationRef('app', '1_framework'));
      expect(await ledger(), [
        'app/1_app:1:applied',
        'dw/1_framework:1:applied',
        'app/1_framework:2:applied',
      ]);
    });

    test('a failing transactional migration leaves no trace', () async {
      final migrations = {
        'app': [
          createTable('1_ok', 'ok'),
          TestMigration(
            '2_broken',
            onUp: (m) async {
              await m.createTable(
                DwTableSchema('half', columns: [DwColumnSchema.primaryKey()]),
              );
              await m.sql('SELECT * FROM no_such_table');
            },
          ),
          createTable('3_never', 'never'),
        ],
      };
      await expectLater(
        DwMigrationRunner(db(), migrations: migrations).apply(),
        throwsA(
          isA<DwMigrationFailed>()
              .having((e) => e.ref.id, 'ref', '2_broken')
              .having((e) => e.direction, 'direction', 'up')
              .having((e) => e.cause, 'cause', isA<DwDatabaseException>()),
        ),
      );
      expect(await tables(), isNot(contains('half')));
      expect(await tables(), isNot(contains('never')));
      expect(await ledger(), ['app/1_ok:1:applied']);
    });

    test('a non-transactional migration runs outside a transaction', () async {
      final run = await DwMigrationRunner(
        db(),
        migrations: {
          'app': [
            createTable('1_table', 't', extra: [DwColumnSchema('n', 'bigint')]),
            TestMigration(
              '2_concurrent_index',
              transactional: false,
              onUp: (m) => m.sql('CREATE INDEX CONCURRENTLY t_n_idx ON t (n)'),
              onDown: (m) => m.sql('DROP INDEX CONCURRENTLY t_n_idx'),
            ),
          ],
        },
      ).apply();
      expect(run.migrations, hasLength(2));
      expect(await ledger(), [
        'app/1_table:1:applied',
        'app/2_concurrent_index:1:applied',
      ]);
    });

    test(
      'a failed non-transactional migration stays dirty and blocks',
      () async {
        final migrations = {
          'app': [
            TestMigration(
              '1_dirty',
              transactional: false,
              onUp: (m) async {
                await m.sql('CREATE TABLE partial (id bigint)');
                throw StateError('crashed halfway');
              },
            ),
          ],
        };
        await expectLater(
          DwMigrationRunner(db(), migrations: migrations).apply(),
          throwsA(isA<DwMigrationFailed>()),
        );
        expect(await ledger(), ['app/1_dirty:1:dirty']);
        await expectLater(
          DwMigrationRunner(db(), migrations: migrations).apply(),
          throwsA(
            isA<DwMigrationRefused>().having(
              (e) => e.problems.single,
              'problem',
              isA<DwDirtyMigration>(),
            ),
          ),
        );
      },
    );
  });

  group('refusals', () {
    test('an applied migration missing from the code', () async {
      await DwMigrationRunner(
        db(),
        migrations: {
          'app': [createTable('1_a', 'a'), createTable('2_b', 'b')],
        },
      ).apply();
      await expectLater(
        DwMigrationRunner(
          db(),
          migrations: {
            'app': [createTable('2_b', 'b'), createTable('3_c', 'c')],
          },
        ).apply(),
        throwsA(
          isA<DwMigrationRefused>().having(
            (e) => e.problems.single,
            'problem',
            isA<DwMissingMigration>().having((p) => p.ref.id, 'id', '1_a'),
          ),
        ),
      );
      expect(await tables(), isNot(contains('c')));
    });

    test('an applied migration whose checksum changed', () async {
      await DwMigrationRunner(
        db(),
        migrations: {
          'app': [createTable('1_a', 'a', checksum: 'v1')],
        },
      ).apply();
      await expectLater(
        DwMigrationRunner(
          db(),
          migrations: {
            'app': [
              createTable('1_a', 'a', checksum: 'v2'),
              createTable('2_b', 'b'),
            ],
          },
        ).apply(),
        throwsA(
          isA<DwMigrationRefused>().having(
            (e) => e.problems.single,
            'problem',
            isA<DwChangedMigration>()
                .having((p) => p.applied, 'applied', 'v1')
                .having((p) => p.current, 'current', 'v2'),
          ),
        ),
      );
    });

    test('every problem is reported at once', () async {
      final refused = DwMigrationRunner(
        db(),
        migrations: {
          'app': [
            createTable('1_a', 'a'),
            createTable('1_a', 'a'),
            createTable(
              '2_b',
              'b',
              dependsOn: const [DwMigrationRef('app', '9_nowhere')],
            ),
            createTable(
              '3_c',
              'c',
              dependsOn: const [DwMigrationRef('app', '4_d')],
            ),
            createTable(
              '4_d',
              'd',
              dependsOn: const [DwMigrationRef('app', '3_c')],
            ),
          ],
        },
      ).apply();
      await expectLater(
        refused,
        throwsA(
          isA<DwMigrationRefused>().having(
            (e) => e.problems.map((p) => p.runtimeType).toSet(),
            'problems',
            {DwDuplicateMigration, DwUnknownDependency, DwDependencyCycle},
          ),
        ),
      );
      expect(await tables(), {'dw_migrations'});
    });
  });

  group('rollback', () {
    Map<String, List<DwDatabaseMigration>> threeBatches() => {
      'app': [
        createTable('1_a', 'a'),
        createTable('2_b', 'b'),
        createTable('3_c', 'c'),
      ],
    };

    Future<void> applyInBatches() async {
      final all = threeBatches()['app']!;
      for (var i = 1; i <= all.length; i++) {
        await DwMigrationRunner(
          db(),
          migrations: {'app': all.take(i).toList()},
        ).apply();
      }
    }

    test('rolls back the last batch by default, in reverse order', () async {
      await DwMigrationRunner(
        db(),
        migrations: {
          'app': [createTable('1_a', 'a')],
        },
      ).apply();
      await DwMigrationRunner(db(), migrations: threeBatches()).apply();
      final run = await DwMigrationRunner(
        db(),
        migrations: threeBatches(),
      ).rollback();
      expect(run.batch, 2);
      expect(run.migrations.map((ref) => ref.id), ['3_c', '2_b']);
      expect(await tables(), {'a', 'dw_migrations'});
      expect(await ledger(), ['app/1_a:1:applied']);
    });

    test('rolls back a named batch or a single migration', () async {
      await applyInBatches();
      final byId = await DwMigrationRunner(
        db(),
        migrations: threeBatches(),
      ).rollback(id: const DwMigrationRef('app', '3_c'));
      expect(byId.migrations.single.id, '3_c');
      final byBatch = await DwMigrationRunner(
        db(),
        migrations: threeBatches(),
      ).rollback(batch: 1);
      expect(byBatch.migrations.single.id, '1_a');
      expect(await ledger(), ['app/2_b:2:applied']);
      // What was rolled back is pending again.
      final reapplied = await DwMigrationRunner(
        db(),
        migrations: threeBatches(),
      ).apply();
      expect(reapplied.migrations.map((ref) => ref.id), ['1_a', '3_c']);
    });

    test('refuses to roll back what an applied migration depends on', () async {
      final migrations = {
        'app': [
          createTable('1_a', 'a'),
          createTable(
            '2_b',
            'b',
            dependsOn: const [DwMigrationRef('app', '1_a')],
          ),
        ],
      };
      await DwMigrationRunner(db(), migrations: migrations).apply();
      await expectLater(
        DwMigrationRunner(
          db(),
          migrations: migrations,
        ).rollback(id: const DwMigrationRef('app', '1_a')),
        throwsA(
          isA<DwMigrationRefused>().having(
            (e) => e.problems.single,
            'problem',
            isA<DwDependentApplied>().having(
              (p) => p.dependent.id,
              'dependent',
              '2_b',
            ),
          ),
        ),
      );
      // Both in one batch: rolling back the batch takes the dependent too.
      final run = await DwMigrationRunner(
        db(),
        migrations: migrations,
      ).rollback();
      expect(run.migrations.map((ref) => ref.id), ['2_b', '1_a']);
    });

    test('refuses unknown targets and foreign namespaces', () async {
      await DwMigrationRunner(
        db(),
        migrations: {
          'dw': [createTable('1_f', 'f')],
        },
      ).apply();
      final app = DwMigrationRunner(db(), migrations: {'app': const []});
      await expectLater(
        app.rollback(id: const DwMigrationRef('app', 'nope')),
        throwsA(isA<DwMigrationRefused>()),
      );
      await expectLater(
        app.rollback(batch: 7),
        throwsA(isA<DwMigrationRefused>()),
      );
      await expectLater(
        app.rollback(batch: 1),
        throwsA(
          isA<DwMigrationRefused>().having(
            (e) => e.problems.single,
            'problem',
            isA<DwRollbackTargetInvalid>(),
          ),
        ),
      );
      expect(
        () => app.rollback(batch: 1, id: const DwMigrationRef('a', 'b')),
        throwsArgumentError,
      );
    });

    test(
      'an irreversible migration aborts a transactional batch whole',
      () async {
        final migrations = {
          'app': [
            TestMigration(
              '1_irreversible',
              onUp: (m) => m.sql('CREATE TABLE kept (id bigint)'),
            ),
            createTable('2_reversible', 'reversible'),
          ],
        };
        await DwMigrationRunner(db(), migrations: migrations).apply();
        await expectLater(
          DwMigrationRunner(db(), migrations: migrations).rollback(),
          throwsA(
            isA<DwMigrationFailed>()
                .having((e) => e.ref.id, 'ref', '1_irreversible')
                .having(
                  (e) => e.cause,
                  'cause',
                  isA<DwIrreversibleMigration>(),
                ),
          ),
        );
        // 2_reversible was rolled back inside the same transaction, and
        // restored.
        expect(await tables(), containsAll(['kept', 'reversible']));
        expect(await ledger(), hasLength(2));
      },
    );

    test('an empty ledger has nothing to roll back', () async {
      final run = await DwMigrationRunner(
        db(),
        migrations: {'app': const []},
      ).rollback();
      expect(run.isEmpty, isTrue);
    });
  });

  test('status reports every state', () async {
    await DwMigrationRunner(
      db(),
      migrations: {
        'app': [
          createTable('1_applied', 'a'),
          createTable('2_changed', 'b', checksum: 'old'),
          createTable('3_missing', 'c'),
          TestMigration(
            '4_dirty',
            transactional: false,
            onUp: (m) => throw StateError('x'),
          ),
        ],
      },
    ).apply().then((_) {}, onError: (Object _) {});
    final status = await DwMigrationRunner(
      db(),
      migrations: {
        'app': [
          createTable('1_applied', 'a'),
          createTable('2_changed', 'b', checksum: 'new'),
          TestMigration('4_dirty', onUp: (m) async {}),
          createTable('5_pending', 'e'),
        ],
      },
    ).status();
    expect(
      {for (final s in status) s.ref.id: s.state},
      {
        '1_applied': DwMigrationState.applied,
        '2_changed': DwMigrationState.changed,
        '3_missing': DwMigrationState.missing,
        '4_dirty': DwMigrationState.dirty,
        '5_pending': DwMigrationState.pending,
      },
    );
  });

  test('status of a database never migrated is all pending', () async {
    final status = await DwMigrationRunner(
      db(),
      migrations: {
        'app': [createTable('1_a', 'a')],
      },
    ).status();
    expect(status.single.state, DwMigrationState.pending);
    expect(await tables(), isEmpty);
  });

  test(
    'a module added to a live database applies only its own migrations',
    () async {
      final app = [createTable('20260101_000000_profile', 'profile')];
      await DwMigrationRunner(db(), migrations: {'app': app}).apply();
      final run = await DwMigrationRunner(
        db(),
        migrations: {
          'app': app,
          'push': [
            // Written long before the app's migrations, applied long after.
            createTable('20200101_000000_push_token', 'push_token'),
          ],
        },
      ).apply();
      expect(run.batch, 2);
      expect(
        run.migrations.single,
        const DwMigrationRef('push', '20200101_000000_push_token'),
      );
      expect(await tables(), containsAll(['profile', 'push_token']));
    },
  );

  test(
    'concurrent migrators: one applies, the other waits and finds nothing',
    () async {
      final other = await database.openAnother();
      addTearDown(other.close);
      final started = <String>[];
      Map<String, List<DwDatabaseMigration>> slow(String who) => {
        'app': [
          TestMigration(
            '1_slow',
            onUp: (m) async {
              started.add(who);
              await m.sql('SELECT pg_sleep(0.3)');
              await m.sql('CREATE TABLE slow (id bigint)');
            },
            onDown: (m) => m.dropTable('slow'),
          ),
        ],
      };
      final runs = await Future.wait([
        DwMigrationRunner(db(), migrations: slow('first')).apply(),
        DwMigrationRunner(other.db, migrations: slow('second')).apply(),
      ]);
      expect(runs.where((run) => run.isEmpty), hasLength(1));
      expect(runs.where((run) => !run.isEmpty), hasLength(1));
      expect(started, hasLength(1));
      expect(await ledger(), ['app/1_slow:1:applied']);
    },
  );
}
