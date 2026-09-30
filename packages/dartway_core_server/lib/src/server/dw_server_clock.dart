/// Where a server reads the current instant: `ctx.now` in every context, and
/// the job queue's due times.
///
/// The one clock of a server, passed as `DwAppServer(clock: …)`: the system's
/// by default, a `DwTestClock` (from `testing.dart`) in a test that pins or
/// moves time. Project code never reads `DateTime.now()` on the server —
/// `dartway check` refuses it (`forbiddenDateTimeNow`) — so a test that sets
/// this clock sets it for everything the project decides by time.
abstract class DwServerClock {
  const DwServerClock();

  /// The system's clock: `DateTime.now()`, in UTC.
  static const DwServerClock system = _DwSystemClock();

  /// The current instant, in UTC.
  DateTime now();

  /// An event each time the clock is set to another time rather than ticking
  /// on — a test moving it. A running server wakes its job executor on each,
  /// so a job the move made due runs at once. Never fires for the system's
  /// clock.
  Stream<void> get jumps => const Stream.empty();
}

final class _DwSystemClock extends DwServerClock {
  const _DwSystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
