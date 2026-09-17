import 'dart:async';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      jobs: app.jobs(withTick: true),
      // A poll far longer than any test: a job that runs promptly was woken
      // by its notification.
      settings: const DwServerSettings(jobPollInterval: Duration(minutes: 5)),
    ),
  );

  Future<List<String?>> logged(String name) async => [
    for (final row in await harness().db.query(
      'SELECT tag FROM job_log WHERE name = @name ORDER BY id',
      params: {'name': name},
    ))
      row['tag'] as String?,
  ];

  Future<DwResultRow?> jobRow(String tag) async {
    final rows = await harness().db.query(
      "SELECT * FROM dw_job WHERE payload->>'tag' = @tag",
      params: {'tag': tag},
    );
    return rows.isEmpty ? null : rows.single;
  }

  late DwTestCaller caller;
  setUpAll(() => caller = harness().caller());

  test(
    'a job enqueued in a committed command runs, woken by its notification',
    () async {
      final watch = Stopwatch()..start();
      expect(
        (await caller.call(
          const EnqueueJob('record', 'committed'),
        )).value(const EnqueueJob('', '')),
        isTrue,
      );
      await eventually(
        () async => (await logged('record')).contains('committed'),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      await eventually(() async => await jobRow('committed') == null);
    },
  );

  test('a job enqueued in a rolled-back command does not exist', () async {
    final result = await caller.call(
      const EnqueueJob('record', 'rolled-back', refuse: true),
    );
    expect(result.status, 409);
    expect(await jobRow('rolled-back'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await logged('record'), isNot(contains('rolled-back')));
  });

  test('a dedup key holds while the job is pending', () async {
    final first = await caller.call(
      const EnqueueJob('record', 'dedup-1', key: 'dedup', delayMillis: 60000),
    );
    final second = await caller.call(
      const EnqueueJob('record', 'dedup-2', key: 'dedup', delayMillis: 60000),
    );
    expect(first.value(const EnqueueJob('', '')), isTrue);
    expect(second.value(const EnqueueJob('', '')), isFalse);
    final rows = await harness().db.query(
      "SELECT payload->>'tag' AS tag FROM dw_job WHERE key = 'dedup'",
    );
    expect(rows.map((r) => r['tag']), ['dedup-1']);
  });

  test('a delayed job waits for its time', () async {
    await caller.call(const EnqueueJob('record', 'delayed', delayMillis: 700));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(await logged('record'), isNot(contains('delayed')));
    await eventually(() async => (await logged('record')).contains('delayed'));
  });

  test('a failing job is retried with backoff, its error text stored, and '
      'its work of failed attempts rolled back', () async {
    harness().app.jobFailures['flaky:twice'] = 2;
    await caller.call(const EnqueueJob('flaky', 'twice'));
    await eventually(
      () =>
          harness().app.jobEvents.stream.isBroadcast &&
          harness().app.jobFailures['flaky:twice'] == 0,
    );
    await eventually(() async => await jobRow('twice') == null);
    // Two failed attempts wrote their log row inside the rolled-back savepoint.
    expect(await logged('flaky-attempt'), ['twice']);
  });

  test('a handler knows its attempt and whether it is the last', () async {
    harness().app.jobAttempts.clear();
    harness().app.jobFailures['flaky:attempts'] = 2;
    await caller.call(const EnqueueJob('flaky', 'attempts'));
    await eventually(() async => await jobRow('attempts') == null);
    expect(harness().app.jobAttempts, ['1/3:false', '2/3:false', '3/3:true']);
  });

  test('a non-transactional job publishes when its transaction commits, not '
      'when the job ends', () async {
    final app = harness().app;
    app.jobGate = Completer();
    final (_, session) = await harness().signedIn('job-announce@example.com');
    final socket = await harness().live(token: session.token);
    expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
    await caller.call(const EnqueueJob('announced', 'analysing'));
    // Heard while the job still waits on its long call.
    final update = await socket.expect<DwUpdateMessage>();
    expect((update.updates.objects.single as NoteView).text, 'analysing');
    expect(app.jobGate.isCompleted, isFalse);
    app.jobGate.complete();
    await eventually(() async => await jobRow('analysing') == null);
    await socket.expectSilence();
  });

  test('a job out of attempts is kept as failed and alerts', () async {
    harness().app.jobFailures['flaky:dead'] = 10;
    await caller.call(const EnqueueJob('flaky', 'dead'));
    await eventually(() async => (await jobRow('dead'))?['failed_at'] != null);
    final row = (await jobRow('dead'))!;
    expect(row['attempts'], 3);
    expect(row['last_error'], contains('flaky failure'));
    await eventually(
      () => harness().app.alerts.incidents.any(
        (i) => i.where == 'job flaky (attempt 3 of 3)',
      ),
    );
    // A failed job does not run again.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect((await jobRow('dead'))!['attempts'], 3);
  });

  test('a failed job does not hold its dedup key', () async {
    harness().app.jobFailures['flaky:keyed-dead'] = 10;
    await caller.call(const EnqueueJob('flaky', 'keyed-dead', key: 'keyed'));
    await eventually(
      () async => (await jobRow('keyed-dead'))?['failed_at'] != null,
    );
    final again = await caller.call(
      const EnqueueJob('record', 'keyed-again', key: 'keyed'),
    );
    expect(again.value(const EnqueueJob('', '')), isTrue);
    await eventually(
      () async => (await logged('record')).contains('keyed-again'),
    );
  });

  test(
    'a non-transactional job is leased, retried, and deleted when done',
    () async {
      harness().app.jobFailures['outside:leased'] = 1;
      await caller.call(const EnqueueJob('outside', 'leased'));
      await eventually(
        () async => (await logged('outside')).contains('leased'),
      );
      await eventually(() async => await jobRow('leased') == null);
    },
  );

  test(
    'jobs a newer version declared wait for it, and stop nothing here',
    () async {
      // During a deployment the new server shares the tables: it inserts its
      // recurring row already due and enqueues kinds this process does not
      // know. Neither may throw this worker out of its loop or be marked
      // failed by it.
      final incidentsBefore = harness().app.alerts.incidents.length;
      final db = harness().db;
      await db.execute(
        'INSERT INTO dw_recurring_job (name, every_micros, next_run_at) '
        "VALUES ('from_newer', 3600000000, now() - interval '1 second')",
      );
      await db.execute(
        "INSERT INTO dw_job (name, payload, run_at) "
        "VALUES ('from_newer_queued', '{\"tag\": \"newer\"}'::jsonb, now())",
      );

      await caller.call(const EnqueueJob('record', 'alongside'));
      await eventually(
        () async => (await logged('record')).contains('alongside'),
      );

      final queued = (await jobRow('newer'))!;
      expect(queued['failed_at'], isNull);
      expect(queued['attempts'], 0);
      final recurring = await db.query(
        "SELECT next_run_at <= now() AS due FROM dw_recurring_job "
        "WHERE name = 'from_newer'",
      );
      expect(
        recurring.single['due'],
        isTrue,
        reason: 'not run by this process',
      );
      // Let a worker that would trip over the foreign row come round again.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(
        harness().app.alerts.incidents.skip(incidentsBefore),
        isEmpty,
        reason: 'a foreign job must not fail this process',
      );

      await db.execute(
        "DELETE FROM dw_recurring_job WHERE name = 'from_newer'",
      );
      await db.execute("DELETE FROM dw_job WHERE name = 'from_newer_queued'");
    },
  );

  test('an unknown job name fails the enqueueing call', () async {
    final result = await caller.call(const EnqueueJob('nope', 'x'));
    expect(result.status, 500);
  });

  test('a recurring job runs on its schedule, and the schedule survives a '
      'restart', () async {
    await eventually(() async => (await logged('tick')).length >= 3);
    final before = (await harness().db.query(
      "SELECT next_run_at FROM dw_recurring_job WHERE name = 'tick'",
    )).single.get<DateTime>('next_run_at');

    final app = harness().app;
    final config = harness().database.config;
    await harness().server.stop();
    // Push the next run far out while stopped: a restart must keep it (the
    // interval did not change), not reset it to now.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    harness().server = await DwTestServer.start(
      app.server(
        config,
        jobs: [
          ...app.jobs(),
          DwRecurringJob(
            'tick',
            every: const Duration(hours: 1),
            handle: (ctx) async => app.jobEvents.add('slow tick'),
          ),
        ],
      ),
    );
    final rows = await harness().db.query(
      "SELECT every_micros, next_run_at FROM dw_recurring_job WHERE name = 'tick'",
    );
    expect(
      rows.single['every_micros'],
      const Duration(hours: 1).inMicroseconds,
    );
    final after = rows.single.get<DateTime>('next_run_at');
    // LEAST(previous next run, now + new interval): the run already due stays.
    expect(after.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    expect(
      after.isBefore(DateTime.now().add(const Duration(minutes: 59))),
      isTrue,
    );
    final framework = await harness().db.query(
      'SELECT name FROM dw_recurring_job ORDER BY name',
    );
    expect(framework.map((r) => r['name']), ['dw.cleanup', 'tick']);
  });

  test('a recurring job no longer declared is removed at start', () async {
    final app = harness().app;
    final config = harness().database.config;
    await harness().server.stop();
    harness().server = await DwTestServer.start(app.server(config));
    final names = await harness().db.query('SELECT name FROM dw_recurring_job');
    expect(names.map((r) => r['name']), ['dw.cleanup']);
    caller = harness().caller();
  });

  test('the framework cleanup removes old outcomes, tickets, revoked keys and '
      'long-failed jobs', () async {
    final db = harness().db;
    await db.execute(
      "INSERT INTO dw_command_outcome (key, type, status, created_at) VALUES "
      "('old', 'Ping', 'ok', now() - interval '8 days'), "
      "('new', 'Ping', 'ok', now())",
    );
    // Failed jobs are kept for the operator, but not forever: one failed
    // past the retention goes, one failed recently and one still pending
    // stay.
    await db.execute(
      "INSERT INTO dw_job (name, payload, key, run_at, failed_at, last_error) "
      "VALUES "
      "('gone', '{}', 'failed-old', now(), now() - interval '31 days', 'boom'), "
      "('gone', '{}', 'failed-new', now(), now() - interval '1 day', 'boom'), "
      // Not due, so no worker claims a job nobody declares.
      "('gone', '{}', 'pending', now() + interval '1 day', NULL, NULL)",
    );
    await db.execute(
      "UPDATE dw_recurring_job SET next_run_at = now() WHERE name = 'dw.cleanup'",
    );
    harness().server.wakeJobs();
    await eventually(() async {
      final rows = await db.query('SELECT key FROM dw_command_outcome');
      return !rows.any((r) => r['key'] == 'old');
    });
    final rows = await db.query(
      "SELECT key FROM dw_command_outcome WHERE key = 'new'",
    );
    expect(rows, hasLength(1));
    final jobs = await db.query(
      "SELECT key FROM dw_job WHERE name = 'gone' ORDER BY key",
    );
    expect(jobs.map((r) => r['key']), ['failed-new', 'pending']);
  });
}
