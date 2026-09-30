import 'dart:async';

import '../server/dw_server_clock.dart';

/// A server clock a test sets and moves: `DwAppServer(clock: DwTestClock(…))`.
///
/// It stands still — `ctx.now` answers the same instant until the test moves
/// it — so what a handler or a job decides by time is decided at the instant
/// the test chose. Moving it wakes the server's job executor
/// ([DwServerClock.jumps]): a job whose `runAt` the clock has passed runs
/// without waiting for the next poll.
///
/// ```dart
/// final clock = DwTestClock(DateTime.utc(2026, 9, 29, 8));
/// final server = await DwTestServer.start(buildServer(clock: clock));
/// …
/// clock.advance(const Duration(days: 1)); // tomorrow's reminders are due
/// ```
///
/// Standing still is the point, and it has a consequence: a retry scheduled
/// after its backoff, or a recurring job's next run, waits until the test
/// moves the clock past it. What the framework stamps in the database itself
/// — `created_at` columns, session keys and sign-in codes, their expiry —
/// is the database's clock, not this one, and keeps real time.
final class DwTestClock extends DwServerClock {
  DwTestClock(DateTime at) : _now = at.toUtc();

  DateTime _now;
  final StreamController<void> _jumps = StreamController.broadcast(
    sync: true,
  );

  @override
  DateTime now() => _now;

  @override
  Stream<void> get jumps => _jumps.stream;

  /// Moves the clock by [by], forward or back.
  void advance(Duration by) => moveTo(_now.add(by));

  /// Sets the clock to [at].
  void moveTo(DateTime at) {
    _now = at.toUtc();
    _jumps.add(null);
  }
}
