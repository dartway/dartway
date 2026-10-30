import 'dart:async';

import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import 'dw_alert_sink.dart';
import 'dw_server_logger.dart';

/// Durable, leased delivery of incidents, with database-backed coalescing.
@internal
final class DwAlertOutbox {
  DwAlertOutbox({
    required this.db,
    required this.sink,
    required this.logger,
    required this.window,
    required this.pollInterval,
    this.maxClientDeliveriesPerMinute = 5,
    this.project,
    this.environment,
    this.version,
    DateTime Function()? clock,
  }) : _clock = clock ?? _systemClock;

  final DwDatabaseHandle db;
  final DwAlertSink sink;
  final DwServerLogger logger;
  final Duration window;
  final Duration pollInterval;
  final int maxClientDeliveriesPerMinute;
  final String? project;
  final String? environment;
  final String? version;
  final DateTime Function() _clock;

  static DateTime _systemClock() => DateTime.now().toUtc();
  final List<DwServerIncident> _buffer = [];
  final Set<Future<void>> _inFlight = {};
  bool _running = false;
  Future<void>? _loop;
  static const _bufferLimit = 1000;
  final List<DateTime> _clientDeliveries = [];

  void start() {
    _running = true;
    _loop = _work();
  }

  Future<void> enqueue(DwServerIncident incident) {
    late final Future<void> pending;
    pending = _persist(incident).whenComplete(() => _inFlight.remove(pending));
    _inFlight.add(pending);
    return pending;
  }

  Future<void> _persist(DwServerIncident incident) async {
    try {
      await _write(incident);
    } catch (error) {
      if (_buffer.length == _bufferLimit) _buffer.removeAt(0);
      _buffer.add(incident);
      logger.warning(
        'alert ${incident.id} waits for the database',
        error: error,
      );
    }
  }

  Future<void> stop() async {
    _running = false;
    await Future.wait(_inFlight.toList());
    // Persist memory before allowing the database to close.
    await _flush();
    await _loop;
  }

  Future<void> _write(DwServerIncident i) => db.transaction((tx) async {
    await _writeIn(tx, i);
  });

  Future<({String id, DateTime windowEndsAt})> _writeIn(
    DwDatabaseHandle tx,
    DwServerIncident i,
  ) async {
    await tx.query(
      'SELECT pg_advisory_xact_lock(hashtext(@signature))',
      params: {'signature': i.signature},
    );
    final updated = await tx.query(
      '''
UPDATE dw_alert_outbox SET repeat_count = repeat_count + 1
WHERE signature = @signature AND repeat_delivered_at IS NULL
  AND window_ends_at > @at::timestamptz RETURNING id, window_ends_at
''',
      params: {'signature': i.signature, 'at': i.at},
    );
    if (updated.isNotEmpty) {
      return (
        id: updated.single.get<String>('id'),
        windowEndsAt: updated.single.get<DateTime>('window_ends_at'),
      );
    }
    await tx.execute(
      '''
INSERT INTO dw_alert_outbox
 (id, signature, where_text, error_text, stack_trace, account_id, happened_at,
  window_started_at, window_ends_at, project, environment, version)
VALUES (@id, @signature, @where, @error, @stack, @account, @at,
        @at, @at::timestamptz + @window::int8 * interval '1 microsecond',
        @project, @environment, @version)
''',
      params: {
        'id': i.id,
        'signature': i.signature,
        'where': i.where,
        'error': '${i.error}',
        'stack': '${i.stackTrace}',
        'account': i.accountId,
        'at': i.at,
        'window': window.inMicroseconds,
        'project': project,
        'environment': environment,
        'version': version,
      },
    );
    return (id: i.id, windowEndsAt: i.at.add(window));
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final pending = List<DwServerIncident>.of(_buffer);
    final flushed = Set<DwServerIncident>.identity()..addAll(pending);
    try {
      // One transaction is important here: after an outage, committing every
      // incident separately can take minutes for the bounded 1000-item buffer.
      await db.transaction((tx) async {
        while (pending.isNotEmpty) {
          final incident = pending.removeAt(0);
          final target = await _writeIn(tx, incident);
          var repeats = 0;
          pending.removeWhere((candidate) {
            final coalesces =
                candidate.signature == incident.signature &&
                candidate.at.isBefore(target.windowEndsAt);
            if (coalesces) repeats++;
            return coalesces;
          });
          if (repeats > 0) {
            await tx.execute(
              'UPDATE dw_alert_outbox SET repeat_count = repeat_count + @repeats WHERE id = @id',
              params: {'repeats': repeats, 'id': target.id},
            );
          }
        }
      });
      _buffer.removeWhere(flushed.contains);
    } catch (_) {
      return;
    }
  }

  Future<void> _work() async {
    while (_running) {
      try {
        await _flush();
        final now = _clock();
        _clientDeliveries.removeWhere(
          (sent) => now.difference(sent) >= const Duration(minutes: 1),
        );
        final allowClient =
            _clientDeliveries.length < maxClientDeliveriesPerMinute;
        final claimed = await db.transaction((tx) async {
          final rows = await tx.query(
            '''
SELECT * FROM dw_alert_outbox
WHERE created_at >= @expiry::timestamptz
  AND next_attempt_at <= @now::timestamptz
  AND (locked_until IS NULL OR locked_until < @now::timestamptz)
  AND (@allow_client::boolean OR signature NOT LIKE 'client|%')
  AND ((initial_delivered_at IS NULL AND next_attempt_at <= @now::timestamptz)
    OR (initial_delivered_at IS NOT NULL AND repeat_count > 0
      AND repeat_delivered_at IS NULL AND window_ends_at <= @now::timestamptz
      AND next_attempt_at <= @now::timestamptz))
ORDER BY (signature LIKE 'client|%'), created_at LIMIT 1 FOR UPDATE SKIP LOCKED
''',
            params: {
              'now': _clock(),
              'expiry': _clock().subtract(const Duration(days: 7)),
              'allow_client': allowClient,
            },
          );
          if (rows.isEmpty) return null;
          final row = rows.single;
          await tx.execute(
            "UPDATE dw_alert_outbox SET locked_until = @lease WHERE id = @id",
            params: {
              'lease': _clock().add(const Duration(minutes: 2)),
              'id': row['id'],
            },
          );
          return row;
        });
        if (claimed != null) {
          if (claimed.get<String>('signature').startsWith('client|')) {
            _clientDeliveries.add(now);
          }
          await _deliver(claimed);
        }
        final expired = await db.query(
          '''
WITH expired AS (
  DELETE FROM dw_alert_outbox WHERE created_at < @expiry::timestamptz
  RETURNING initial_delivered_at, repeat_count, repeat_delivered_at
)
SELECT count(*)::int AS undelivered FROM expired
WHERE initial_delivered_at IS NULL
   OR (repeat_count > 0 AND repeat_delivered_at IS NULL)
''',
          params: {'expiry': _clock().subtract(const Duration(days: 7))},
        );
        final undelivered = expired.single.get<int>('undelivered');
        if (undelivered > 0) {
          logger.warning(
            '$undelivered undelivered alert outbox row(s) expired after seven days',
          );
        }
      } catch (error) {
        logger.warning('alert outbox worker failed', error: error);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _deliver(DwResultRow row) async {
    final repeats = row.get<int>('repeat_count');
    final followUp = row['initial_delivered_at'] != null;
    final incident = DwServerIncident(
      id: row.get<String>('id'),
      where: row.get<String>('where_text'),
      error: followUp
          ? 'repeated $repeats times since ${row.get<DateTime>('window_started_at').toUtc().toIso8601String()}'
          : row.get<String>('error_text'),
      stackTrace: StackTrace.fromString(row.get<String>('stack_trace')),
      accountId: row['account_id'] as int?,
      at: row.get<DateTime>('happened_at'),
      repeatCount: followUp ? repeats : 0,
      project: row['project'] as String?,
      environment: row['environment'] as String?,
      version: row['version'] as String?,
      signature: row.get<String>('signature'),
    );
    try {
      await sink.send(incident).timeout(const Duration(seconds: 60));
      await db.execute(
        followUp
            ? 'UPDATE dw_alert_outbox SET repeat_delivered_at = @now, locked_until = NULL WHERE id = @id'
            : 'UPDATE dw_alert_outbox SET initial_delivered_at = @now, attempts = 0, locked_until = NULL WHERE id = @id',
        params: {'now': _clock(), 'id': incident.id},
      );
    } catch (error) {
      final attempts = row.get<int>('attempts') + 1;
      final seconds = (1 << attempts.clamp(0, 12)).clamp(1, 3600);
      final retryDelay = error is DwTelegramAlertException
          ? error.retryAfter
          : null;
      final delay = retryDelay != null && retryDelay.inSeconds > seconds
          ? retryDelay
          : Duration(seconds: seconds);
      await db.execute(
        '''
UPDATE dw_alert_outbox SET attempts = @attempts,
 next_attempt_at = @next, locked_until = NULL, last_error = @error WHERE id = @id
''',
        params: {
          'attempts': attempts,
          'next': _clock().add(delay),
          'error': '$error',
          'id': incident.id,
        },
      );
    }
  }
}
