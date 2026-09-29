/// Where a server reads the current instant: `ctx.now` in every context, and
/// the job queue's due times.
///
/// The one clock of a server, passed as `DwAppServer(clock: …)`: the system's
/// by default, a `DwTestClock` (from `testing.dart`) in a test that pins or
/// moves time. Project code never reads `DateTime.now()` on the server —
/// `dartway check` refuses it in `lib/src/` (`forbiddenDateTimeNow`) — so a
/// test that sets this clock sets it for everything the project decides by
/// time.
abstract interface class DwServerClock {
  /// The system's clock: `DateTime.now()`, in UTC.
  static const DwServerClock system = _DwSystemClock();

  /// The current instant, in UTC.
  DateTime now();
}

final class _DwSystemClock implements DwServerClock {
  const _DwSystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
