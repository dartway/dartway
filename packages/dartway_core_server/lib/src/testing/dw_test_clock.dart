import 'package:meta/meta.dart';

import '../server/dw_server_clock.dart';

/// A server clock a test sets and moves: `DwAppServer(clock: DwTestClock(…))`.
///
/// It stands still — `ctx.now` answers the same instant until the test moves
/// it — so what a handler or a job decides by time is decided at the instant
/// the test chose. Moving it wakes the server's job executor: a job whose
/// `runAt` the clock has passed runs without waiting for the next poll.
///
/// ```dart
/// final clock = DwTestClock(DateTime.utc(2026, 9, 29, 8));
/// final server = await DwTestServer.start(buildServer(clock: clock));
/// …
/// clock.advance(const Duration(days: 1)); // tomorrow's reminders are due
/// ```
///
/// What the framework stamps in the database itself — `created_at` columns,
/// session keys and sign-in codes, their expiry — is the database's clock,
/// not this one.
final class DwTestClock implements DwServerClock {
  DwTestClock(DateTime at) : _now = at.toUtc();

  DateTime _now;
  final List<void Function()> _listeners = [];

  @override
  DateTime now() => _now;

  /// Moves the clock by [by], forward or back.
  void advance(Duration by) => moveTo(_now.add(by));

  /// Sets the clock to [at].
  void moveTo(DateTime at) {
    _now = at.toUtc();
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Called after every move — how a running server's job executor hears
  /// that jobs may have become due.
  @internal
  void addListener(void Function() listener) => _listeners.add(listener);

  @internal
  void removeListener(void Function() listener) => _listeners.remove(listener);
}
