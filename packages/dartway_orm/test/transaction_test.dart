import 'dart:async';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:test/test.dart';

import 'fixtures/app_setting.dart';
import 'fixtures/generated/dw_schema.dart';
import 'support/test_database.dart';

void main() {
  final database = useTestDatabase(maxConnections: 6);
  DwDb db() => database().db;

  AppSettingRow setting(String key, [String value = 'v']) =>
      AppSettingRow(key: key, value: value, updatedAt: DateTime.utc(2026));

  Future<List<String>> keys() async => [
    for (final s in await db().appSettings.find(orderBy: (t) => [t.key.asc()]))
      s.key,
  ];

  setUp(() => db().execute('TRUNCATE app_setting RESTART IDENTITY CASCADE'));

  group('transaction', () {
    test('commits when the body completes', () async {
      final result = await db().transaction((tx) async {
        expect(tx.inTransaction, isTrue);
        await tx.appSettings.insert(setting('a'));
        return 7;
      });
      expect(result, 7);
      expect(db().inTransaction, isFalse);
      expect(await keys(), ['a']);
    });

    test('rolls back and rethrows when the body throws', () async {
      await expectLater(
        db().transaction((tx) async {
          await tx.appSettings.insert(setting('a'));
          throw const FormatException('boom');
        }),
        throwsFormatException,
      );
      expect(await keys(), isEmpty);
    });

    test('a statement error swallowed by the body still rolls back', () async {
      await db().appSettings.insert(setting('taken'));
      await expectLater(
        db().transaction((tx) async {
          await tx.appSettings.insert(setting('a'));
          try {
            await tx.appSettings.insert(setting('taken'));
          } on DwUniqueViolation {
            // Swallowed on purpose: Postgres would turn COMMIT into ROLLBACK.
          }
          return 'looks fine';
        }),
        throwsA(isA<DwUniqueViolation>()),
      );
      expect(await keys(), ['taken']);
    });

    test('a nested transaction is a savepoint', () async {
      await db().transaction((tx) async {
        await tx.appSettings.insert(setting('outer'));
        await expectLater(
          tx.transaction((inner) async {
            await inner.appSettings.insert(setting('inner'));
            await inner.appSettings.insert(setting('outer'));
          }),
          throwsA(isA<DwUniqueViolation>()),
        );
        // The failure was confined to the savepoint: the outer transaction
        // goes on and commits.
        await tx.appSettings.insert(setting('after'));
        await tx.transaction((inner) async {
          await inner.appSettings.insert(setting('kept'));
          await inner.transaction((deeper) async {
            await deeper.appSettings.insert(setting('deeper'));
          });
        });
      });
      expect(await keys(), ['after', 'deeper', 'kept', 'outer']);
    });

    test('a swallowed error inside a savepoint rolls back only it', () async {
      await db().transaction((tx) async {
        await tx.appSettings.insert(setting('outer'));
        await expectLater(
          tx.transaction((inner) async {
            await inner.appSettings.insert(setting('lost'));
            try {
              await inner.appSettings.insert(setting('outer'));
            } on DwUniqueViolation {
              // swallowed
            }
          }),
          throwsA(isA<DwUniqueViolation>()),
        );
      });
      expect(await keys(), ['outer']);
    });

    test('an outer rollback discards committed savepoints', () async {
      await expectLater(
        db().transaction((tx) async {
          await tx.transaction(
            (inner) => inner.appSettings.insert(setting('a')),
          );
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect(await keys(), isEmpty);
    });

    test('the enclosing handle is refused while a savepoint is open', () async {
      await db().transaction((tx) async {
        await tx.transaction((inner) async {
          expect(() => tx.appSettings.count(), throwsStateError);
        });
        expect(await tx.appSettings.count(), 0);
      });
    });

    test('a handle escaping its transaction is refused', () async {
      late DwDb escaped;
      await db().transaction((tx) async => escaped = tx);
      expect(() => escaped.appSettings.count(), throwsStateError);
    });

    test('an unawaited statement fails the transaction loudly', () async {
      await expectLater(
        db().transaction((tx) async {
          await tx.appSettings.insert(setting('a'));
          // ignore: unawaited_futures
          tx.appSettings.insert(setting('b'));
        }),
        throwsStateError,
      );
      expect(await keys(), isEmpty);
      // The connection that carried it was discarded, not reused.
      expect(await db().appSettings.count(), 0);
    });

    test('isolation is chosen by the outermost transaction only', () async {
      await db().transaction(isolation: DwIsolation.repeatableRead, (tx) async {
        final level = await tx.query('SHOW transaction_isolation');
        expect(
          level.single.get<String>('transaction_isolation'),
          'repeatable read',
        );
        expect(
          () => tx.transaction(
            isolation: DwIsolation.serializable,
            (inner) async {},
          ),
          throwsArgumentError,
        );
      });
    });

    test(
      'a serialization conflict surfaces as DwSerializationFailure',
      () async {
        await db().appSettings.insertAll([
          setting('x', '0'),
          setting('y', '0'),
        ]);
        final bothRead = Completer<void>();
        var reads = 0;
        Future<void> writeSkew(String read, String write) =>
            db().transaction(isolation: DwIsolation.serializable, (tx) async {
              await tx.appSettings.findFirst(where: (t) => t.key.equals(read));
              if (++reads == 2) bothRead.complete();
              await bothRead.future;
              await tx.appSettings.updateWhere(
                where: (t) => t.key.equals(write),
                set: (t) => [t.value.set('1')],
              );
            });
        final results = await Future.wait([
          writeSkew(
            'x',
            'y',
          ).then<Object?>((_) => null, onError: (Object e) => e),
          writeSkew(
            'y',
            'x',
          ).then<Object?>((_) => null, onError: (Object e) => e),
        ]);
        expect(results.whereType<DwSerializationFailure>(), hasLength(1));
      },
    );
  });

  group('row locks', () {
    test('FOR UPDATE waits for the transaction holding the row', () async {
      final row = await db().appSettings.insert(setting('locked'));
      final events = <String>[];
      final held = Completer<void>();
      final release = Completer<void>();

      final first = db().transaction((tx) async {
        await tx.appSettings.findById(row.id!, lock: DwLock.forUpdate);
        events.add('first locked');
        held.complete();
        await release.future;
        await tx.appSettings.update(row.copyWith(value: 'first'));
        events.add('first commits');
      });
      await held.future;
      final second = db().transaction((tx) async {
        final seen = await tx.appSettings.findById(
          row.id!,
          lock: DwLock.forUpdate,
        );
        events.add('second locked');
        return seen!.value;
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(events, ['first locked']);
      release.complete();
      await first;
      expect(await second, 'first');
      expect(events, ['first locked', 'first commits', 'second locked']);
    });

    test(
      'FOR UPDATE SKIP LOCKED hands concurrent workers distinct rows',
      () async {
        await db().appSettings.insertAll([
          for (var i = 0; i < 4; i++) setting('job$i'),
        ]);
        final claimed = Completer<void>();
        final done = Completer<void>();
        final first = db().transaction((tx) async {
          final rows = await tx.appSettings.find(
            orderBy: (t) => [t.id.asc()],
            limit: 2,
            lock: DwLock.forUpdateSkipLocked,
          );
          claimed.complete();
          await done.future;
          return rows.map((r) => r.key).toList();
        });
        await claimed.future;
        final second = await db().transaction(
          (tx) async => [
            for (final r in await tx.appSettings.find(
              orderBy: (t) => [t.id.asc()],
              limit: 2,
              lock: DwLock.forUpdateSkipLocked,
            ))
              r.key,
          ],
        );
        done.complete();
        expect(await first, ['job0', 'job1']);
        expect(second, ['job2', 'job3']);
      },
    );
  });

  group('advisory locks', () {
    test('are transaction-scoped and exclusive', () async {
      final held = Completer<void>();
      final release = Completer<void>();
      final holder = db().transaction((tx) async {
        await tx.advisoryLock(7, 42);
        held.complete();
        await release.future;
      });
      await held.future;
      expect(
        await db().transaction((tx) => tx.tryAdvisoryLock(7, 42)),
        isFalse,
      );
      expect(await db().transaction((tx) => tx.tryAdvisoryLock(7, 43)), isTrue);
      release.complete();
      await holder;
      expect(await db().transaction((tx) => tx.tryAdvisoryLock(7, 42)), isTrue);
    });

    test('advisoryLock waits for the holder', () async {
      final order = <String>[];
      final held = Completer<void>();
      final holder = db().transaction((tx) async {
        await tx.advisoryLock(1, 1);
        held.complete();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        order.add('holder done');
      });
      await held.future;
      await db().transaction((tx) async {
        await tx.advisoryLock(1, 1);
        order.add('waiter locked');
      });
      await holder;
      expect(order, ['holder done', 'waiter locked']);
    });

    test('need a transaction and 32-bit keys', () async {
      expect(() => db().advisoryLock(1, 1), throwsStateError);
      expect(() => db().tryAdvisoryLock(1, 1), throwsStateError);
      await db().transaction((tx) async {
        expect(() => tx.advisoryLock(0x80000000, 1), throwsArgumentError);
      });
    });
  });

  group('pool', () {
    test(
      'an expected constraint error keeps the connection and its cache',
      () async {
        final pool = await DwDatabase.open(
          testServerConfig(name: database().name, maxConnections: 1),
        );
        addTearDown(pool.close);
        Future<int> pid() async => (await pool.db.query(
          'SELECT pg_backend_pid() AS pid',
        )).single.get<int>('pid');
        final before = await pid();
        await pool.db.appSettings.insert(setting('once'));
        await expectLater(
          pool.db.appSettings.insert(setting('once')),
          throwsA(isA<DwUniqueViolation>()),
        );
        expect(await pid(), before);
      },
    );

    test('never exceeds maxConnections', () async {
      final pool = await DwDatabase.open(
        testServerConfig(name: database().name, maxConnections: 2),
      );
      addTearDown(pool.close);
      final started = DateTime.now();
      await Future.wait([
        for (var i = 0; i < 4; i++) pool.db.query('SELECT pg_sleep(0.2)'),
      ]);
      final elapsed = DateTime.now().difference(started);
      // Four 200 ms statements over two connections take two rounds.
      expect(elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 390)));
      expect(elapsed, lessThan(const Duration(milliseconds: 780)));
    });

    test('a closed database refuses statements', () async {
      final pool = await DwDatabase.open(
        testServerConfig(name: database().name),
      );
      await pool.close();
      expect(() => pool.db.query('SELECT 1'), throwsStateError);
    });

    test('a wrong password fails at open', () async {
      final config = testServerConfig(name: database().name);
      await expectLater(
        DwDatabase.open(
          DwDatabaseConfig(
            host: config.host,
            port: config.port,
            name: config.name,
            user: config.user,
            password: 'wrong',
            ssl: false,
          ),
        ),
        throwsA(isA<DwDatabaseException>()),
      );
    });
  });

  group('listen', () {
    test('delivers notifications sent after it completes', () async {
      final stream = await database().database.listen('orm_events');
      final received = <String>[];
      final subscription = stream.listen(received.add);
      await db().notify('orm_events', 'outside');
      await db().transaction((tx) => tx.notify('orm_events', 'committed'));
      await expectLater(
        db().transaction((tx) async {
          await tx.notify('orm_events', 'rolled back');
          throw StateError('abort');
        }),
        throwsStateError,
      );
      await db().notify('orm_events', 'last');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await subscription.cancel();
      expect(received, ['outside', 'committed', 'last']);
    });
  });
}
