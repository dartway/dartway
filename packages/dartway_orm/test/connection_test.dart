import 'dart:async';
import 'dart:typed_data';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:test/test.dart';

import 'support/test_database.dart';

void main() {
  final database = useTestDatabase(withFixtureSchema: false);

  Future<DwPostgresDatabase> open({
    int maxConnections = 1,
    Duration connectTimeout = const Duration(seconds: 15),
  }) async {
    final base = testServerConfig(name: database().name);
    final opened = await DwPostgresDatabase.open(
      DwDatabaseConfig(
        host: base.host,
        port: base.port,
        name: base.name,
        user: base.user,
        password: base.password,
        ssl: false,
        maxConnections: maxConnections,
        connectTimeout: connectTimeout,
        applicationName: 'orm_test_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    addTearDown(opened.close);
    return opened;
  }

  Future<void> terminate(String applicationName) => database().db.query(
    'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
    'WHERE application_name = @name',
    params: {'name': applicationName},
  );

  test('SSL required of a server without it is refused at once, naming the '
      'setting', () async {
    // The suites' Postgres runs without SSL, as a development database does.
    // The driver alone threw here and left its socket open, so a CLI printed
    // the error and never exited.
    final config = testServerConfig(name: database().name);
    final stopwatch = Stopwatch()..start();
    await expectLater(
      DwPostgresDatabase.open(
        DwDatabaseConfig(
          host: config.host,
          port: config.port,
          name: config.name,
          user: config.user,
          password: config.password,
          ssl: true,
        ),
      ),
      throwsA(
        isA<DwDatabaseException>().having(
          (e) => e.message,
          'message',
          contains('DW_DATABASE_SSL=false'),
        ),
      ),
    );
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('a caller waiting for a free connection times out loudly', () async {
    final pool = await open(connectTimeout: const Duration(milliseconds: 300));
    final release = Completer<void>();
    final holder = pool.db.transaction((tx) => release.future);
    await expectLater(
      pool.db.query('SELECT 1'),
      throwsA(
        isA<DwDatabaseException>().having(
          (e) => e.message,
          'message',
          contains('no database connection became free'),
        ),
      ),
    );
    release.complete();
    await holder;
    expect(await pool.db.query('SELECT 1 AS one'), [
      {'one': 1},
    ]);
  });

  test('a connection killed by the server is replaced', () async {
    final pool = await open();
    final before = (await pool.db.query(
      'SELECT pg_backend_pid() AS pid',
    )).single;
    await terminate(pool.config.applicationName);
    // The dead connection surfaces as it is used, then is dropped.
    await pool.db.query('SELECT 1').then((_) {}, onError: (Object _) {});
    final after = (await pool.db.query(
      'SELECT pg_backend_pid() AS pid',
    )).single;
    expect(after['pid'], isNot(before['pid']));
  });

  test(
    'a statement made stale by DDL is re-prepared outside a transaction',
    () async {
      final pool = await open();
      await pool.db.execute(
        'CREATE TABLE stale (a bigint); INSERT INTO stale VALUES (1)',
      );
      expect(await pool.db.query('SELECT * FROM stale'), [
        {'a': 1},
      ]);
      await pool.db.execute('ALTER TABLE stale ADD COLUMN b text');
      expect(await pool.db.query('SELECT * FROM stale'), [
        {'a': 1, 'b': null},
      ]);

      // Inside a transaction the same failure has aborted it and must surface.
      await pool.db.execute('ALTER TABLE stale ADD COLUMN c text');
      await expectLater(
        pool.db.transaction((tx) => tx.query('SELECT * FROM stale')),
        throwsA(
          isA<DwDatabaseException>().having((e) => e.code, 'code', '0A000'),
        ),
      );
      expect(await pool.db.query('SELECT * FROM stale'), hasLength(1));
    },
  );

  test('listen survives its connection being killed', () async {
    final pool = await open();
    final stream = await pool.listen('orm_reconnect');
    final received = StreamController<String>();
    final subscription = stream.listen(
      received.add,
      onError: received.addError,
    );
    addTearDown(subscription.cancel);
    final events = StreamQueue(received.stream);

    await pool.db.notify('orm_reconnect', 'before');
    expect(await events.next, 'before');

    await terminate('${pool.config.applicationName}-listen');
    // Until the listener is back, notifications are lost by design; keep
    // sending until one arrives.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    String? after;
    while (after == null && DateTime.now().isBefore(deadline)) {
      await pool.db.notify('orm_reconnect', 'after');
      after = await events.nextOrNull(const Duration(milliseconds: 300));
    }
    expect(after, 'after');
  });

  group('DwDatabaseConfig.fromEnvironment', () {
    test('reads every key under the prefix', () {
      final config = DwDatabaseConfig.fromEnvironment({
        'APP_DB_HOST': 'db',
        'APP_DB_PORT': '6543',
        'APP_DB_NAME': 'app',
        'APP_DB_USER': 'u',
        'APP_DB_PASSWORD': 'secret',
        'APP_DB_SSL': 'FALSE',
        'APP_DB_MAX_CONNECTIONS': '3',
      }, prefix: 'APP_DB_');
      expect(config.host, 'db');
      expect(config.port, 6543);
      expect(config.ssl, isFalse);
      expect(config.maxConnections, 3);
      expect(config.toString(), isNot(contains('secret')));
    });

    test('defaults port, SSL and pool size', () {
      final config = DwDatabaseConfig.fromEnvironment({
        'DW_DATABASE_HOST': 'db',
        'DW_DATABASE_NAME': 'app',
        'DW_DATABASE_USER': 'u',
        'DW_DATABASE_PASSWORD': 'p',
      });
      expect(config.port, 5432);
      expect(config.ssl, isTrue);
      expect(config.maxConnections, 10);
    });

    test('reports every problem at once', () {
      expect(
        () => DwDatabaseConfig.fromEnvironment({
          'DW_DATABASE_HOST': 'db',
          'DW_DATABASE_PORT': 'x',
          'DW_DATABASE_SSL': 'yes',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('DW_DATABASE_NAME is not set'),
              contains('DW_DATABASE_USER is not set'),
              contains('DW_DATABASE_PASSWORD is not set'),
              contains('DW_DATABASE_PORT must be a positive integer'),
              contains('DW_DATABASE_SSL must be "true" or "false"'),
            ),
          ),
        ),
      );
    });
  });

  test('raw query binds untyped values of every common type', () async {
    final local = DateTime(2026, 9, 13, 23, 30, 0, 0, 7);
    final rows = await database().db.query(
      'SELECT @at::timestamptz AS at, @flag::boolean AS flag, @ratio::float8 AS ratio, '
      '@nothing::text AS nothing, 2 = ANY(@ids::int8[]) AS has_two, '
      "@doc::jsonb ->> 'k' AS k, @bytes::bytea AS bytes",
      params: {
        'at': local,
        'flag': true,
        'ratio': 0.25,
        'nothing': null,
        'ids': [1, 2, 3],
        'doc': {'k': 'v'},
        'bytes': Uint8List.fromList([1, 2]),
      },
    );
    expect(rows.single, {
      'at': local.toUtc(),
      'flag': true,
      'ratio': 0.25,
      'nothing': null,
      'has_two': true,
      'k': 'v',
      'bytes': [1, 2],
    });
  });

  // Pins the driver defect the JSON types work around: if this starts
  // failing, JSON arrays can travel as jsonb[] again.
  test('the driver encodes a null jsonb[] element as JSON null', () async {
    final rows = await database().db.run(
      r'SELECT (a)[1] IS NULL AS sql_null, (a)[1] AS value FROM (SELECT $1::jsonb[] AS a) s',
      const [pg.Type.jsonbArray],
      [
        [null],
      ],
    );
    expect(rows.single[0], isFalse);
  });
}

/// A minimal pull-based reader over a stream, for tests that wait for the
/// next event with a deadline.
final class StreamQueue<T> {
  StreamQueue(Stream<T> stream) {
    stream.listen((event) {
      if (_waiting != null) {
        final waiting = _waiting!;
        _waiting = null;
        waiting.complete(event);
      } else {
        _buffer.add(event);
      }
    });
  }

  final List<T> _buffer = [];
  Completer<T>? _waiting;

  Future<T> get next {
    if (_buffer.isNotEmpty) return Future.value(_buffer.removeAt(0));
    return (_waiting = Completer<T>()).future;
  }

  Future<T?> nextOrNull(Duration timeout) => next
      .then<T?>((value) => value)
      .timeout(
        timeout,
        onTimeout: () {
          _waiting = null;
          return null;
        },
      );
}
