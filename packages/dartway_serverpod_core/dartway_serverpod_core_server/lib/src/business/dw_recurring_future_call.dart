import 'package:serverpod/serverpod.dart';

import '../private/dw_singleton.dart';

/// Base class for a future call that runs on a fixed [interval] and manages its
/// own whole lifecycle — registration, first run, and re-arming — so the app
/// never touches Serverpod's future-call plumbing.
///
/// A [FutureCall] fires once; making it recurring, surviving restarts without
/// stacking duplicates, reporting failures, and re-arming even after a failed
/// run is the same fiddly boilerplate in every project. This base owns all of
/// it. A subclass declares only *what* runs and *how often*:
///
/// ```dart
/// class SessionClosureFutureCall extends DwRecurringFutureCall {
///   @override
///   String get name => 'sessionClosure';
///   @override
///   Duration get interval => const Duration(minutes: 1);
///   @override
///   Future<void> run(Session session) => closeTimedOutSessions(session);
/// }
/// ```
///
/// Then, once at server startup (after `pod.start()`), hand the jobs over — this
/// registers each handler and arms its first run:
///
/// ```dart
/// await DwRecurringFutureCall.startAll(pod, [
///   SessionClosureFutureCall(),
///   DatabaseRetentionFutureCall(),
/// ]);
/// ```
///
/// That is the entire contract. Re-arming after each run (including a failed
/// one) and cancelling a stale schedule on restart happen automatically.
abstract class DwRecurringFutureCall extends FutureCall {
  /// Unique name — used to register the handler and as the reschedule
  /// identifier, so a restart replaces the pending run instead of stacking a
  /// second one.
  String get name;

  /// Delay between runs, queued again after every run.
  Duration get interval;

  /// Delay before the first run after startup. Defaults to [interval]; override
  /// with `Duration.zero` to run once immediately on boot.
  Duration get initialDelay => interval;

  /// The work to do each run. Throwing is safe: the error is reported via
  /// [dw].alerts and the next run is still queued.
  Future<void> run(Session session);

  /// Registers each call's handler on [pod] and arms its first run. Call once at
  /// server startup, after `pod.start()`.
  static Future<void> startAll(
    Serverpod pod,
    List<DwRecurringFutureCall> calls,
  ) async {
    for (final call in calls) {
      pod.registerFutureCall(call, call.name);
      await call._reschedule(pod, call.initialDelay);
    }
  }

  @override
  Future<void> invoke(Session session, SerializableModel? object) async {
    try {
      await run(session);
    } catch (exception, stackTrace) {
      dw.alerts.reportError(
        'Recurring future call "$name" failed',
        exception: exception,
        stackTrace: stackTrace,
      );
      session.log('$name failed: $exception', level: LogLevel.error);
    } finally {
      await _reschedule(session.serverpod, interval);
    }
  }

  /// Cancels any pending run and queues the next one [delay] from now.
  ///
  // The imperative scheduler is `@Deprecated` in Serverpod 3 in favour of
  // per-call *generated* methods, which only exist in the application. Owning the
  // recurring lifecycle generically here means driving it imperatively — so the
  // deprecated calls are isolated to this one method (the app never sees them).
  // TODO(dartway): revisit if Serverpod exposes a public, non-deprecated
  // imperative scheduler, or adopt the generated methods behind this seam.
  Future<void> _reschedule(Serverpod pod, Duration delay) async {
    // ignore: deprecated_member_use
    await pod.cancelFutureCall(name);
    // ignore: deprecated_member_use
    await pod.futureCallWithDelay(name, null, delay, identifier: name);
  }
}
