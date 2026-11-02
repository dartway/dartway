import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/metrics/dw_server_counters.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  test('read token rejects wrong, missing and revoked values', () {
    expect(DwServerCounters.acceptsToken('new-secret', 'new-secret'), isTrue);
    expect(DwServerCounters.acceptsToken('new-secret', 'old-secret'), isFalse);
    expect(DwServerCounters.acceptsToken('new-secret', null), isFalse);
    expect(DwServerCounters.acceptsToken(null, 'old-secret'), isFalse);
  });

  test('keeps closed endpoint minutes, errors and response percentiles', () {
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12));
    final counters = DwServerCounters(clock: clock);

    for (var i = 1; i <= 100; i++) {
      counters.record(
        'CreateOrder',
        i <= 3 ? 500 : 200,
        Duration(milliseconds: i),
      );
    }
    expect(counters.read(null), isEmpty, reason: 'the current minute is open');

    clock.advance(const Duration(minutes: 1));
    expect(counters.read(null), [
      {
        'minute': '2026-10-31T12:00:00.000Z',
        'endpoints': {
          'CreateOrder': {
            'calls': 100,
            'errors': 3,
            'responseTimeMs': {'p50': 50.0, 'p95': 95.0, 'max': 100.0},
          },
        },
      },
    ]);
  });

  test('returns every retained closed minute after a cursor', () {
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12));
    final counters = DwServerCounters(clock: clock);
    for (var i = 0; i < 11; i++) {
      counters.record('Heartbeat', 200, const Duration(milliseconds: 1));
      clock.advance(const Duration(minutes: 1));
    }

    final minutes = counters.read(DateTime.utc(2026, 10, 31, 12));
    expect(minutes, hasLength(10));
    expect(minutes.first['minute'], '2026-10-31T12:01:00.000Z');
    expect(minutes.last['minute'], '2026-10-31T12:10:00.000Z');
  });

  test('coverage starts after the partial startup minute', () {
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12, 0, 30));
    final counters = DwServerCounters(clock: clock);

    clock.advance(const Duration(minutes: 7));

    expect(
      counters.coveredSince(clock.now()),
      DateTime.utc(2026, 10, 31, 12, 1),
    );
    expect(
      counters
          .coveredSince(clock.now())
          .isAfter(DateTime.utc(2026, 10, 31, 12)),
      isTrue,
      reason: 'the partial minute in which counting started is not covered',
    );
  });

  group('GET /dw/server-counters', () {
    final app = TestApp();
    final clock = DwTestClock(DateTime.utc(2026, 10, 31, 12));
    late DwTestDatabase database;
    late DwTestServer server;

    setUpAll(() async {
      database = await DwTestDatabase.create(admin: adminConfig());
      server = await DwTestServer.start(
        app.server(
          database.config,
          clock: clock,
          settings: const DwServerSettings(
            jobWorkers: 0,
            studioReadToken: 'studio-secret',
            keyActions: {GetMyNote},
          ),
        ),
      );
      await server.db.execute(
        "INSERT INTO dw_job (name, payload, run_at) VALUES "
        "('waiting', '{}'::jsonb, '2026-10-31 11:00Z'), "
        "('failed', '{}'::jsonb, '2026-10-31 11:00Z'), "
        "('scheduled', '{}'::jsonb, '2026-10-31 13:00Z'), "
        "('taken', '{}'::jsonb, '2026-10-31 11:00Z')",
      );
      await server.db.execute(
        "UPDATE dw_job SET failed_at = now(), last_error = 'failed' "
        "WHERE name = 'failed'",
      );
      await server.db.execute(
        "UPDATE dw_job SET locked_until = '2026-10-31 13:00Z' "
        "WHERE name = 'taken'",
      );
    });

    tearDownAll(() async {
      await server.stop();
      await database.drop();
    });

    test('enforces method, cursor and exact Bearer authentication', () async {
      final caller = server.caller();
      addTearDown(caller.close);
      for (final headers in <Map<String, String?>>[
        {},
        {'Authorization': 'Bearer wrong'},
        {'Authorization': 'bearer studio-secret'},
        {'Authorization': 'Basic studio-secret'},
      ]) {
        expect(
          (await caller.raw(
            'GET',
            DwHttpContract.serverCountersPath,
            headers: headers,
          )).status,
          401,
        );
      }
      expect(
        (await caller.raw(
          'POST',
          DwHttpContract.serverCountersPath,
          headers: {'Authorization': 'Bearer studio-secret'},
        )).status,
        405,
      );
      expect(
        (await caller.raw(
          'GET',
          DwHttpContract.serverCountersPath,
          query: {'cursor': 'not-a-minute'},
          headers: {'Authorization': 'Bearer studio-secret'},
        )).status,
        400,
      );
    });

    test(
      'reports jobs and registered key actions and bounds unknown names',
      () async {
        final caller = server.caller();
        addTearDown(caller.close);
        for (var i = 0; i < 30; i++) {
          await caller.raw('POST', '/dw/random-$i');
        }
        await caller.raw('POST', '/dw/GetMyNote');
        clock.advance(const Duration(minutes: 1));
        final answer = await caller.raw(
          'GET',
          DwHttpContract.serverCountersPath,
          headers: {'Authorization': 'Bearer studio-secret'},
        );
        expect(answer.status, 200);
        final json = jsonDecode(answer.text) as Map<String, Object?>;
        expect(json['jobQueue'], {'waiting': 1, 'failed': 1});
        expect(json['keyActions'], ['GetMyNote']);
        expect(json['coveredSince'], '2026-10-31T12:01:00.000Z');
        final minutes = json['minutes']! as List<Object?>;
        final endpoints =
            (minutes.single as Map<String, Object?>)['endpoints']!
                as Map<String, Object?>;
        expect(endpoints.keys, containsAll(<String>['unknown', 'GetMyNote']));
        expect(endpoints.keys, hasLength(2));
        expect((endpoints['unknown']! as Map<String, Object?>)['calls'], 30);
      },
    );

    test(
      'answers 503 when the queue snapshot cannot query the database',
      () async {
        final caller = server.caller();
        addTearDown(caller.close);
        await server.db.execute(
          'ALTER TABLE dw_job RENAME TO dw_job_unavailable',
        );
        try {
          expect(
            (await caller.raw(
              'GET',
              DwHttpContract.serverCountersPath,
              headers: {'Authorization': 'Bearer studio-secret'},
            )).status,
            503,
          );
        } finally {
          await server.db.execute(
            'ALTER TABLE dw_job_unavailable RENAME TO dw_job',
          );
        }
      },
    );

    test(
      'counts handler failures but not refusals or 429 answers as errors',
      () async {
        final caller = server.caller();
        addTearDown(caller.close);
        expect(
          (await caller.call(const ExplodingRequest('counter-test'))).status,
          500,
        );
        expect(
          (await caller.call(
            const Count('counter-refusal', mode: 'refuse'),
          )).status,
          409,
        );
        const limited = DwRequestCode(
          kind: DwIdentifierKind.email,
          identifier: 'counter-limit@example.com',
        );
        expect((await caller.call(limited)).status, 200);
        expect((await caller.call(limited)).status, 429);

        clock.advance(const Duration(minutes: 1));
        final answer = await caller.raw(
          'GET',
          DwHttpContract.serverCountersPath,
          headers: {'Authorization': 'Bearer studio-secret'},
        );
        final json = jsonDecode(answer.text) as Map<String, Object?>;
        final minutes = json['minutes']! as List<Object?>;
        final endpoints =
            (minutes.last as Map<String, Object?>)['endpoints']!
                as Map<String, Object?>;
        expect(endpoints['ExplodingRequest'], containsPair('errors', 1));
        expect(endpoints['Count'], containsPair('errors', 0));
        expect(endpoints['DwRequestCode'], containsPair('errors', 0));
      },
    );

    test(
      'refuses an unconfigured token and invalid startup settings',
      () async {
        final disabled = await DwTestServer.start(app.server(database.config));
        try {
          final caller = disabled.caller();
          try {
            expect(
              (await caller.raw(
                'GET',
                DwHttpContract.serverCountersPath,
                headers: {'Authorization': 'Bearer studio-secret'},
              )).status,
              401,
            );
          } finally {
            caller.close();
          }
        } finally {
          await disabled.stop();
        }
        for (final settings in <DwServerSettings>[
          const DwServerSettings(studioReadToken: ''),
          const DwServerSettings(keyActions: {String}),
        ]) {
          await expectLater(
            DwTestServer.start(app.server(database.config, settings: settings)),
            throwsA(isA<DwStartupException>()),
          );
        }
      },
    );
  });
}
