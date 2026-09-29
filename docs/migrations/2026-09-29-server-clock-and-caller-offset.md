---
title: "The server's time is ctx.now, and the caller's UTC offset arrives with every call"
affects:
  dartway_core_server: "0.21.0-dev.9"
  dartway_cli: "0.13.0"
---

## Who is affected

Every project whose server reads `DateTime.now()` (or `DateTime.timestamp()`, or `clock.now()` of
`package:clock`) anywhere in `lib/` — the factory file beside `src/` included:
`dart run dartway_cli:dartway check` fails on it now (`forbiddenDateTimeNow`). And every
project whose commands carry the caller's UTC offset as a field of their own.

## What to change

**Read the time from the context.** In every handler, job, route, channel rule and startup step:

    - final paidAt = DateTime.now().toUtc();
    + final paidAt = ctx.now;

`ctx.now` is already UTC. Code outside a handler that needs the time takes the context, or the
instant, as a parameter — a publication that counts "upcoming" rows, a profile factory called from
`onAccountCreated`:

    - static Future<Counters> countCounters(DwDatabaseHandle db) async => …
    -     where: (t) => t.startsAt.gte(DateTime.now()),
    + static Future<Counters> countCounters(DwCallContext ctx) async => …
    +     where: (t) => t.startsAt.gte(ctx.now),

`bin/` (a dev seed) and `test/` are not checked and may keep the system clock.

**Give the server factory a clock, and the test harness a `DwTestClock`.** The function
`bin/server.dart` and the tests share takes it and passes it on:

    static DwAppServer build({
      …
    + DwServerClock clock = DwServerClock.system,
    }) => DwAppServer(
      …
    + clock: clock,
    );

and `test/support/app_harness.dart` builds the server with `clock: DwTestClock(DateTime.now())`,
keeping the clock on the harness. A test that rewrote `dw_job.run_at` or a row's time to make a job
due moves the clock instead: `harness.clock.moveTo(…)` wakes the job executor, and the job's handler
sees the moved time. Times a test sets up (a session "tomorrow") read `harness.clock.now()`.

**What a clock that stands still changes in a suite.** `ctx.now` answers the same instant until the
test moves it, and the job queue runs by it. So a job's retry after its backoff, a push retry, a
non-transactional job's expired lease and a recurring job's next run no longer happen by waiting:
a test that waited for one (`eventually(…)` over a failed attempt) moves the clock past it —
`harness.clock.advance(const Duration(minutes: 1))`. What the database stamps itself keeps real
time: `created_at` columns, session keys, sign-in codes and their expiry. A test comparing one of
those with `ctx.now` compares two clocks — assert on what the server's clock stamped instead.

**The caller's offset in tests is pinned to zero.** The test server's callers and clients report
`DwTestServer.utcOffset`, `Duration.zero` unless the test sets it (`server.utcOffset = …`, or
`connectClient(utcOffset: …)`), not the zone of the machine the suite runs on. A test that relied
on the machine's zone sets the offset it means.

**Drop the hand-carried offset.** The app now sends the device's UTC offset with every call; the
handler reads it:

    - final class LogWorkout extends DwActionCommand<void> {
    -   const LogWorkout({required this.workoutId, required this.utcOffsetMinutes});
    + final class LogWorkout extends DwActionCommand<void> {
    +   const LogWorkout({required this.workoutId});

    - final offset = Duration(minutes: command.utcOffsetMinutes);
    + final offset = ctx.callerUtcOffset;           // Duration?, null when the app sent none
    + final local = ctx.callerLocalTime;            // DwCallerLocalTime?: year/month/day/hour/weekday
    + final dayStart = local?.startOfDayUtc;        // the instant the caller's day began

A helper that shifted `DateTime.now()` by the offset to read the local date is replaced by
`ctx.callerLocalTime`, which is a reading, not a `DateTime`: take its fields, and `startOfDayUtc`
when a query needs the instant.

Remove the field from the DTO and from the widget that filled it (a helper that stamped the device
offset on each command goes with it), then `dart run dartway_cli:dartway generate`. Decide what a
`null` offset means for your command — an app too old to send it — rather than assuming one.

**A stored offset stays yours.** Work that runs later for a person (a job, a reminder at their 8
a.m.) has no caller, so `ctx.callerUtcOffset` is `null` there. A project that stores the last known
offset on a profile keeps doing so — now from `ctx.callerUtcOffset` of their calls instead of a
command field; the framework stores none.

**A test double of `DwCallContext`** implements `now` and `callerUtcOffset`.

## How to check

`dart run dartway_cli:dartway check` reports no `forbiddenDateTimeNow`, and
`dart run dartway_cli:dartway test` is green with the harness on a `DwTestClock`.
