import 'dart:async';
import 'dart:convert';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../context/dw_call_context.dart';
import '../server/dw_runtime.dart';
import 'dw_job_queue.dart';

/// Enqueues through the context's current database (its transaction, when
/// there is one).
@internal
final class DwContextJobQueue implements DwJobQueue {
  DwContextJobQueue(this._ctx, this._known);

  final DwRuntimeContext _ctx;
  final Map<String, Object> _known;

  @override
  Future<bool> enqueue(
    String name,
    Map<String, Object?> payload, {
    DateTime? runAt,
    String? key,
  }) async {
    if (!_known.containsKey(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'No enqueueable job has this name',
      );
    }
    // Encoded here so a payload that is not JSON fails at the call site.
    final encoded = jsonEncode(payload);
    // Insert and wake the executors in one statement; NOTIFY inside a
    // transaction is delivered at its commit, and not at all on rollback.
    final rows = await _ctx.db.query(
      "WITH inserted AS (INSERT INTO dw_job (name, payload, key, run_at) "
      "VALUES (@name, @payload::jsonb, @key::text, "
      "COALESCE(@run_at::timestamptz, now())) "
      "ON CONFLICT (key) WHERE failed_at IS NULL DO NOTHING RETURNING id) "
      "SELECT id, pg_notify('$dwJobNotifyChannel', '') FROM inserted",
      params: {
        'name': name,
        'payload': encoded,
        'key': key,
        'run_at': runAt?.toUtc(),
      },
    );
    return rows.isNotEmpty;
  }
}

/// Wakes workers: a notification, the next due time, or the slow poll.
///
/// A worker notes the generation before its pass and waits against it, so a
/// wake that arrives while it is busy is not lost, and every worker — waiting
/// or busy — sees every wake.
final class _Signal {
  int generation = 0;
  Completer<void> _completer = Completer<void>();

  void fire() {
    generation++;
    final completer = _completer;
    _completer = Completer<void>();
    completer.complete();
  }

  Future<void> wait(int seen, Duration timeout) {
    if (generation != seen || timeout <= Duration.zero) return Future.value();
    return _completer.future.timeout(timeout, onTimeout: () {});
  }
}

/// Runs `dw_job` and `dw_recurring_job` rows.
@internal
final class DwJobRunner {
  DwJobRunner({
    required this.runtime,
    required List<DwJobDefinition> definitions,
    required this.listen,
    required this.workers,
    required this.pollInterval,
  }) : queued = {
         for (final d in definitions.whereType<DwQueuedJob>()) d.name: d,
       },
       recurring = {
         for (final d in definitions.whereType<DwRecurringJob>()) d.name: d,
       };

  final DwRuntime runtime;
  final Map<String, DwQueuedJob> queued;
  final Map<String, DwRecurringJob> recurring;

  /// Opens a notification stream on a dedicated connection (the database's
  /// `listen`); reconnects are its business.
  final Future<Stream<String>> Function(String channel) listen;
  final int workers;
  final Duration pollInterval;

  DwServerLogger get _log => runtime.log;
  DwDatabaseHandle get _db => runtime.db;

  static const _contendedRetry = Duration(milliseconds: 250);

  final _Signal _signal = _Signal();
  final List<Future<void>> _loops = [];
  bool _running = false;
  StreamSubscription<String>? _listener;

  DwJobQueue jobsFor(DwRuntimeContext ctx) => DwContextJobQueue(ctx, queued);

  Future<void> start() async {
    await _syncRecurring();
    // A process that only serves keeps the schedule declared but opens no
    // listening connection.
    if (workers == 0) return;
    // Listening starts before the first pass, so nothing enqueued between the
    // pass and the wait goes unnoticed.
    _listener = (await listen(dwJobNotifyChannel)).listen(
      (_) => _signal.fire(),
      onError: (Object error) {
        // The stream reports failed reconnects; the poll covers the gap.
        _log.warning('job notifications interrupted', error: error);
        _signal.fire();
      },
    );
    _running = true;
    for (var i = 0; i < workers; i++) {
      _loops.add(_work(i));
    }
  }

  /// Stops taking jobs and waits for the running ones to finish.
  Future<void> stop() async {
    _running = false;
    _signal.fire();
    await Future.wait(_loops);
    _loops.clear();
    await _listener?.cancel();
    _listener = null;
  }

  /// Wakes the workers now (tests; an enqueue outside this process).
  void wake() => _signal.fire();

  Future<void> _syncRecurring() async {
    for (final job in recurring.values) {
      // A shortened interval pulls the next run in; a lengthened one keeps the
      // run already due.
      await _db.execute(
        'INSERT INTO dw_recurring_job (name, every_micros, next_run_at) '
        'VALUES (@name, @every::int8, now()) '
        'ON CONFLICT (name) DO UPDATE SET every_micros = EXCLUDED.every_micros, '
        'next_run_at = LEAST(dw_recurring_job.next_run_at, '
        'now() + EXCLUDED.every_micros * interval \'1 microsecond\')',
        params: {'name': job.name, 'every': job.every.inMicroseconds},
      );
    }
    final removed = await _db.query(
      'DELETE FROM dw_recurring_job WHERE NOT (name = ANY(@names::text[])) '
      'RETURNING name',
      params: {'names': recurring.keys.toList()},
    );
    for (final row in removed) {
      _log.info('recurring job ${row['name']} is no longer declared; removed');
    }
  }

  Future<void> _work(int worker) async {
    while (_running) {
      final seen = _signal.generation;
      try {
        if (await _runRecurring() || await _runQueued()) continue;
        await _signal.wait(seen, await _untilNextDue());
      } catch (error, stackTrace) {
        runtime.alerts.report(
          where: 'job executor',
          error: error,
          stackTrace: stackTrace,
        );
        await _signal.wait(seen, const Duration(seconds: 1));
      }
    }
  }

  Future<Duration> _untilNextDue() async {
    final row = (await _db.query(
      'SELECT EXTRACT(EPOCH FROM (LEAST('
      '(SELECT min(GREATEST(run_at, COALESCE(locked_until, run_at))) '
      'FROM dw_job WHERE failed_at IS NULL), '
      '(SELECT min(next_run_at) FROM dw_recurring_job)) - now()))::float8 '
      'AS seconds',
    )).single;
    final seconds = row['seconds'] as double?;
    if (seconds == null) return pollInterval;
    final due = Duration(microseconds: (seconds * 1e6).ceil());
    // Due yet not claimed means another worker holds it: look again shortly
    // instead of spinning.
    if (due <= _contendedRetry) return _contendedRetry;
    return due < pollInterval ? due : pollInterval;
  }

  Future<bool> _runRecurring() async {
    late DwRuntimeContext ctx;
    final ran = await _db.transaction((tx) async {
      final rows = await tx.query(
        'SELECT name, every_micros, next_run_at, now() AS now '
        'FROM dw_recurring_job WHERE next_run_at <= now() '
        'ORDER BY next_run_at LIMIT 1 FOR UPDATE SKIP LOCKED',
      );
      if (rows.isEmpty) return false;
      final row = rows.single;
      final name = row.get<String>('name');
      final job = recurring[name]!;
      final every = Duration(microseconds: row.get<int>('every_micros'));
      final due = row.get<DateTime>('next_run_at');
      final now = row.get<DateTime>('now');
      // The first slot of the schedule after now: a long outage runs the job
      // once, not once per missed slot.
      final missed = now.difference(due).inMicroseconds ~/ every.inMicroseconds;
      final next = due.add(every * (missed + 1));
      ctx = runtime.context(
        scope: 'job ${job.name}',
        kind: DwContextKind.background,
        db: tx,
      );
      try {
        await ctx.transaction((_) => job.handle(ctx));
        await tx.execute(
          'UPDATE dw_recurring_job SET next_run_at = @next, '
          'last_run_at = now(), last_error = NULL WHERE name = @name',
          params: {'name': name, 'next': next},
        );
      } catch (error, stackTrace) {
        runtime.alerts.report(
          where: 'recurring job $name',
          error: error,
          stackTrace: stackTrace,
        );
        await tx.execute(
          'UPDATE dw_recurring_job SET next_run_at = @next, last_error = @error '
          'WHERE name = @name',
          params: {'name': name, 'next': next, 'error': '$error'},
        );
      }
      return true;
    });
    if (ran) runtime.deliver(ctx);
    return ran;
  }

  Future<bool> _runQueued() async {
    DwRuntimeContext? committed;
    _Lease? lease;
    final claimed = await _db.transaction((tx) async {
      final rows = await tx.query(
        'SELECT id, name, payload, attempts FROM dw_job '
        'WHERE failed_at IS NULL AND run_at <= now() '
        'AND (locked_until IS NULL OR locked_until <= now()) '
        'ORDER BY run_at, id LIMIT 1 FOR UPDATE SKIP LOCKED',
      );
      if (rows.isEmpty) return false;
      final row = rows.single;
      final id = row.get<int>('id');
      final name = row.get<String>('name');
      final payload = (row['payload']! as Map).cast<String, Object?>();
      final attempts = row.get<int>('attempts');
      final job = queued[name];
      if (job == null) {
        final error = StateError('No job definition named "$name"');
        runtime.alerts.report(
          where: 'job $name',
          error: error,
          stackTrace: StackTrace.current,
        );
        await _markFailed(tx, id, attempts, '$error');
        return true;
      }
      if (!job.transactional) {
        await tx.execute(
          'UPDATE dw_job SET attempts = attempts + 1, '
          'locked_until = now() + @lease::int8 * interval \'1 microsecond\' '
          'WHERE id = @id',
          params: {'id': id, 'lease': job.lease.inMicroseconds},
        );
        lease = _Lease(id, job, payload, attempts + 1);
        return true;
      }
      final ctx = runtime.context(
        scope: 'job $name #$id',
        kind: DwContextKind.background,
        db: tx,
      );
      try {
        // A savepoint: a failing handler leaves the claim transaction usable
        // for recording the failure under the same row lock.
        await ctx.transaction((_) => job.handle(ctx, payload));
        await tx.execute(
          'DELETE FROM dw_job WHERE id = @id',
          params: {'id': id},
        );
        committed = ctx;
      } catch (error, stackTrace) {
        await _recordFailure(tx, job, id, attempts + 1, error, stackTrace);
      }
      return true;
    });
    if (committed != null) runtime.deliver(committed!);
    final leased = lease;
    if (leased != null) await _runLeased(leased);
    return claimed;
  }

  Future<void> _runLeased(_Lease lease) async {
    final job = lease.job;
    final ctx = runtime.context(
      scope: 'job ${job.name} #${lease.id}',
      kind: DwContextKind.background,
    );
    try {
      await job.handle(ctx, lease.payload);
      await _db.execute(
        'DELETE FROM dw_job WHERE id = @id',
        params: {'id': lease.id},
      );
    } catch (error, stackTrace) {
      await _recordFailure(
        _db,
        job,
        lease.id,
        lease.attempt,
        error,
        stackTrace,
      );
    } finally {
      runtime.deliver(ctx);
    }
  }

  /// Schedules the next attempt, or marks the job failed after its last one.
  /// Intermediate failures are logged with their text stored on the row; the
  /// final one alerts.
  Future<void> _recordFailure(
    DwDatabaseHandle db,
    DwQueuedJob job,
    int id,
    int attempt,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (attempt >= job.maxAttempts) {
      runtime.alerts.report(
        where: 'job ${job.name} (attempt $attempt of ${job.maxAttempts})',
        error: error,
        stackTrace: stackTrace,
      );
      await _markFailed(db, id, attempt, '$error');
      return;
    }
    _log.warning(
      'job ${job.name} #$id failed (attempt $attempt of ${job.maxAttempts}); '
      'retrying',
      error: error,
    );
    await db.execute(
      'UPDATE dw_job SET attempts = @attempts, last_error = @error, '
      'locked_until = NULL, '
      'run_at = now() + @delay::int8 * interval \'1 microsecond\' WHERE id = @id',
      params: {
        'id': id,
        'attempts': attempt,
        'error': '$error',
        'delay': job.backoff(attempt).inMicroseconds,
      },
    );
  }

  Future<void> _markFailed(
    DwDatabaseHandle db,
    int id,
    int attempts,
    String error,
  ) => db.execute(
    'UPDATE dw_job SET attempts = @attempts, last_error = @error, '
    'locked_until = NULL, failed_at = now() WHERE id = @id',
    params: {'id': id, 'attempts': attempts, 'error': error},
  );
}

final class _Lease {
  _Lease(this.id, this.job, this.payload, this.attempt);

  final int id;
  final DwQueuedJob job;
  final Map<String, Object?> payload;
  final int attempt;
}
