# Recurring jobs

A Serverpod future call fires once. Making one recurring — surviving restarts
without stacking duplicates, reporting failures, and re-arming even after a
failed run — is the same fiddly boilerplate in every project, and it is easy to
get the last part wrong: forget to reschedule inside a `finally` and one bad run
silently kills the schedule forever.

`DwRecurringFutureCall` owns that whole lifecycle. A job declares only *what*
runs and *how often*:

```dart
class SessionClosureFutureCall extends DwRecurringFutureCall {
  @override
  String get name => 'sessionClosure';

  @override
  Duration get interval => const Duration(minutes: 1);

  @override
  Future<void> run(Session session) => closeTimedOutSessions(session);
}
```

Then, once at server startup (after `pod.start()`), hand the jobs over. This
registers each handler and arms its first run:

```dart
await DwRecurringJobs.startAll(pod, [
  SessionClosureFutureCall(),
  DatabaseRetentionFutureCall(),
]);
```

That is the entire contract. You never touch Serverpod's future-call plumbing —
`registerFutureCall`, `futureCallWithDelay`, `cancelFutureCall` are all handled
behind the base class.

## What the base class guarantees

- **Re-arms after every run**, including a failed one — the schedule survives a
  bad run instead of dying on it.
- **No duplicate schedules on restart** — the pending run is cancelled and
  re-queued under the job's `name`, so a redeploy doesn't stack a second copy.
- **Failures are reported**, not swallowed — a throw from `run` goes to
  `dw.alerts` (with the exception and stack trace) and is logged; the next run
  is still queued.

## First run timing

By default the first run happens one `interval` after startup. Override
`initialDelay` to change that — for example, run once immediately on boot:

```dart
@override
Duration get initialDelay => Duration.zero;
```
