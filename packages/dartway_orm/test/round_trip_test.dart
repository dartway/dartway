import 'package:dartway_orm/dartway_orm.dart';
// ignore: implementation_imports
import 'package:dartway_orm/src/db/dw_connection.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:test/test.dart';

import 'fixtures/app_setting.dart';
import 'fixtures/generated/dw_schema.dart';
import 'support/test_database.dart';

/// Prepared-statement caching, measured in server round trips
/// (`ReadyForQuery` messages).
///
/// Baseline — the driver's parameterised `execute`: Parse, then
/// Bind/Execute, then Close — 3 round trips per statement, every time; 4
/// inside a transaction (the portal close). Through the cache: the first run
/// of a statement shape costs Parse + run = 2, every later run 1 (2 inside a
/// transaction).
void main() {
  final database = useTestDatabase(countRoundTrips: true, maxConnections: 1);
  DwDatabase dw() => database().database;

  Future<int> cost(Future<void> Function() action) async {
    final before = dw().roundTrips;
    await action();
    return dw().roundTrips - before;
  }

  test(
    'the driver baseline: 3 round trips per parameterised statement',
    () async {
      final counter = DwRoundTripCounter();
      final config = testServerConfig(name: database().name);
      final connection = await pg.Connection.open(
        pg.Endpoint(
          host: config.host,
          port: config.port,
          database: config.name,
          username: config.user,
          password: config.password,
        ),
        settings: pg.ConnectionSettings(
          sslMode: pg.SslMode.disable,
          transformer: dwWireTap(counter),
        ),
      );
      addTearDown(connection.close);
      for (var i = 0; i < 3; i++) {
        final before = counter.count;
        await connection.execute(
          pg.Sql.named('SELECT id FROM app_setting WHERE id = @id:int8'),
          parameters: {'id': i},
        );
        expect(counter.count - before, 3);
      }
      final before = counter.count;
      await connection.runTx((tx) async {
        final inner = counter.count;
        await tx.execute(
          pg.Sql.named('SELECT id FROM app_setting WHERE id = @id:int8'),
          parameters: {'id': 1},
        );
        expect(counter.count - inner, 4);
      });
      expect(counter.count - before, 6); // BEGIN + 4 + COMMIT
    },
  );

  test('a cached statement costs one round trip after the first', () async {
    expect(await cost(() => dw().db.appSettings.findById(1)), 2);
    for (var i = 2; i < 10; i++) {
      expect(await cost(() => dw().db.appSettings.findById(i)), 1);
    }
    // Same shape, different values: still the cached statement.
    expect(
      await cost(
        () => dw().db.appSettings.find(
          where: (t) => t.key.inList(['a']),
          limit: 5,
        ),
      ),
      2,
    );
    expect(
      await cost(
        () => dw().db.appSettings.find(
          where: (t) => t.key.inList(['b', 'c', 'd']),
          limit: 50,
        ),
      ),
      1,
    );
    final setting = AppSetting(
      key: 'rt',
      value: 'v',
      updatedAt: DateTime.utc(2026),
    );
    expect(await cost(() => dw().db.appSettings.insert(setting)), 2);
    expect(
      await cost(
        () => dw().db.appSettings.insert(setting.copyWith(key: 'rt2')),
      ),
      1,
    );
    expect(
      await cost(
        () => dw().db.appSettings.insertAll([
          setting.copyWith(key: 'rt3'),
          setting.copyWith(key: 'rt4'),
        ]),
      ),
      2,
    );
  });

  test('inside a transaction: BEGIN, 2 per cached statement, COMMIT', () async {
    await dw().db.appSettings.count();
    final spent = await cost(
      () => dw().db.transaction((tx) async {
        await tx.appSettings.count();
        await tx.appSettings.count();
      }),
    );
    expect(spent, 1 + 2 + 2 + 1);
  });

  test('a script without parameters is one round trip', () async {
    // Two row-returning statements: the driver alone fails on this script.
    expect(await cost(() => dw().db.execute('SELECT 1; SELECT 2')), 1);
    expect(await dw().db.query('SELECT 3 AS x'), [
      {'x': 3},
    ]);
  });

  test('nothing is sent for empty findByIds or insertAll', () async {
    expect(await cost(() => dw().db.appSettings.findByIds(const [])), 0);
    expect(await cost(() => dw().db.appSettings.insertAll(const [])), 0);
  });

  test('the cache is bounded per connection', () async {
    final small = await DwDatabase.open(
      DwDatabaseConfig(
        host: testServerConfig().host,
        port: testServerConfig().port,
        name: database().name,
        user: testServerConfig().user,
        password: testServerConfig().password,
        ssl: false,
        maxConnections: 1,
        statementCacheSize: 2,
      ),
      countRoundTrips: true,
    );
    addTearDown(small.close);
    Future<int> costOn(Future<void> Function() action) async {
      final before = small.roundTrips;
      await action();
      return small.roundTrips - before;
    }

    Future<void> shape(int n) =>
        small.db.query('SELECT @v::int8 + $n AS x', params: {'v': 1});
    expect(await costOn(() => shape(1)), 2);
    expect(await costOn(() => shape(2)), 2);
    expect(await costOn(() => shape(1)), 1);
    // A third shape evicts the least recently used (2): Parse, Close of the
    // evicted statement, run.
    expect(await costOn(() => shape(3)), 3);
    expect(await costOn(() => shape(1)), 1);
    expect(await costOn(() => shape(2)), 3);
  });
}
