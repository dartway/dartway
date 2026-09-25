# Jobs: how does work run after the call, or on a schedule?

A job is work that should not happen inside the call that caused it — sending a message, calling a
slow provider, rebuilding a report — or that happens on a schedule. Jobs live in the database
(`dw_job`, `dw_recurring_job`), so they survive restarts, join the transaction that enqueues them,
and are claimed by exactly one worker even when several processes run.

## Declaring jobs

A job has two halves. **What it is** — its name and how its payload travels as JSON — is a
`DwJobKind<P>`, a constant the places that enqueue it import. **How it runs** is a `DwQueuedJob<P>`
in the server's job list, often built from a service instance the enqueuing code never sees:

```dart
abstract final class InvoiceJobs {
  static const send = DwJobKind<({int invoiceId})>(
    'invoice.send',
    encode: _encode,
    decode: _decode,
  );

  static Map<String, Object?> _encode(({int invoiceId}) p) => {'invoiceId': p.invoiceId};
  static ({int invoiceId}) _decode(Map<String, Object?> json) =>
      (invoiceId: json['invoiceId']! as int);
}

final invoiceJobs = <DwJobDefinition>[
  DwQueuedJob(
    InvoiceJobs.send,
    handle: (ctx, p) async => ctx.log.info('sending invoice ${p.invoiceId}'),
  ),
  DwRecurringJob(
    'invoice.markOverdue',
    every: const Duration(hours: 1),
    handle: (ctx) => ctx.db.execute(
      'UPDATE invoice SET overdue = true '
      'WHERE due_at < now() AND paid_at IS NULL AND NOT overdue',
    ),
  ),
];
```

passed as `DwAppServer(jobs: invoiceJobs)`.

**`DwJobKind<P>(name, {encode, decode})`** — the one place a payload is spelled as a map: `encode`
runs at the enqueue, `decode` before the handler, and both sides see `P` (a record, a class, `int`).
`DwJobKind.withoutPayload(name)` is a `DwJobKind<void>`, enqueued with `null`.

**`DwQueuedJob<P>(kind, {handle, transactional, maxAttempts, backoff, lease})`** — a job that runs
once per enqueue:

| Parameter | Default | Meaning |
|---|---|---|
| `handle` | required | `Future<void> Function(DwCallContext ctx, P payload)` |
| `transactional` | `true` | run the handler in the transaction that claimed the row (below) |
| `maxAttempts` | `5` | attempts before the job is marked failed |
| `backoff` | `dwDefaultJobBackoff` | the delay before the next attempt, by attempt number: 10 s, 20 s, 40 s … capped at one hour |
| `lease` | 5 min | how long a non-transactional job is reserved for its worker |

**`DwRecurringJob(name, {every, handle})`** — a job that runs every `every`, with
`handle: Future<void> Function(DwCallContext ctx)`.

The server refuses to start on a name starting with `dw.` (the framework's), a name declared twice,
a non-positive interval or fewer than one attempt. A payload is not a DTO of the protocol (D-016):
a job is server-to-server, and its type never reaches the app's registry (D-092).

## `ctx.jobs.enqueue`

```dart
Future<bool> enqueue<P>(
  DwJobKind<P> job,
  P payload, {
  DateTime? runAt,
  String? key,
});

await ctx.jobs.enqueue(InvoiceJobs.send, (invoiceId: invoice.id!));
```

- The row is written through `ctx.db`, so **an enqueue joins the enclosing transaction**: inside a
  transactional command the job exists only if the command commits, and a refusal or a failure
  leaves no job behind. Outside a transaction it is written at once.
- `runAt` schedules it; now when omitted.
- `key` deduplicates: while a job with the same key is pending or running, another enqueue with it
  does nothing and answers `false`. A job that ran out of attempts no longer blocks its key. Once a
  job has **succeeded** its row is gone, so the key is free again — idempotence for work that must
  happen once ever belongs in the project's own rows.
- A kind the server declares no job for throws `ArgumentError`, and a payload that is not JSON fails `jsonEncode`, both
  at the call site rather than in a worker later. Recurring jobs cannot be enqueued.

## How jobs run

Each server process runs `DwServerSettings.jobWorkers` workers (2 by default). A worker takes the
next due recurring job, else the next due queued job, claiming its row with
`FOR UPDATE SKIP LOCKED` — so any number of workers in any number of processes never run one row
twice. It wakes on a `LISTEN`/`NOTIFY` signal sent when a job is enqueued (delivered at commit), at
the next due time, and at least every `jobPollInterval` in case a notification was lost.
`jobWorkers: 0` runs no jobs in that process.

The context of a job has no caller: `accountId` and `sessionKey` are `null`. It may publish; a
transactional job's publications are delivered after it commits.

### Transactional jobs (the default)

The handler runs in a savepoint of the transaction that claimed the row, and the row is deleted in
that same transaction. So the job disappears exactly when its work commits: a crash mid-job rolls
everything back and leaves the job pending, as if it never started.

On a throw, the savepoint rolls back, and the attempt, the error's text (`last_error`) and the next
run time — `backoff(attempt)` from now — are written under the same row lock. Intermediate failures
are logged as warnings. The last attempt sets `failed_at` and **alerts** ([alerts](alerts.md)). A
failed row stays in `dw_job` for the operator — nothing retries it — until `dw.cleanup` removes it
`DwServerSettings.failedJobRetention` (30 days) after it failed.

### Non-transactional jobs

`transactional: false` is for handlers that call external services, which must not hold a
transaction open for seconds or be undone by a rollback. The claim commits first, with the attempt
counted and the row leased for `lease`; the handler then runs on the pool, and the row is deleted
when it returns. A crash mid-job leaves the lease to expire, and the job runs again.

So a non-transactional job may run twice, and **a handler running longer than its lease can run
twice at once** — another worker claims the row when the lease expires. Make such handlers
idempotent, and give them a lease longer than they take.

What such a handler publishes inside a `ctx.transaction` goes out **when that transaction commits**,
not when the job ends — a status ("analysing") reaches subscribers before the slow call it announces.
Publications outside any transaction go when the handler returns.

### Which attempt

`ctx.job` is the run a handler belongs to: `attempt` (from 1), `maxAttempts` and `isLastAttempt`. A
handler that must tell the people waiting on it that it gave up does so when `isLastAttempt` is true
and it is about to fail. The delay before the next attempt is `DwQueuedJob(backoff: (attempt) =>
…)`; outside a job, `ctx.job` is `null`.

### Recurring jobs

A recurring job's next run time lives in `dw_recurring_job`, so a restart neither skips nor repeats
a run. At start the server syncs the table with the declared jobs: a shortened interval pulls the
next run in, a lengthened one keeps the run already due, and a job no longer declared is removed.

A run executes in the transaction that claimed it. After a long outage the job runs once, not once
per missed slot, and its next run is the first slot of its schedule after now. A failure alerts, stores its text in `last_error`,
and waits for the next slot: a recurring job has no retries — its next run is the retry.

### Two versions at once

During a deployment the new server starts beside the old one on the same tables. **A process claims
only the jobs it declares**: a recurring job the new version added — inserted already due — and a
job of a kind only the new code enqueues wait for a process that declares them, instead of stopping
the old worker or being marked failed by it. If the new version never takes over (its health check
failed and the deployment stopped), such rows simply wait; the old server logs a warning at start
for queued jobs no job of it declares.

## The framework's jobs

| Job | Kind | What it does |
|---|---|---|
| `dw.cleanup` | recurring, hourly | deletes command outcomes older than `DwServerSettings.commandOutcomeRetention`, code tickets past their use, session keys revoked more than a day ago, and jobs that failed longer ago than `DwServerSettings.failedJobRetention` |
| `dw.files.cleanup` | recurring, every `DwFileStorage.cleanupInterval` | removes unfinished uploads past their ticket and grace, object first ([uploads](uploads.md#cleanup)) |
| `dw.files.deleteObject` | queued, non-transactional, 10 attempts | deletes a file's object after `ctx.files.delete` commits |

The file jobs exist only when the server has `files`.

## Related

- [Handlers and the call context](handlers-and-context.md) — `ctx.jobs` and transactions.
- [Routes](routes.md) — a webhook that acknowledges at once and enqueues the work.
- [Testing](../5-tooling/testing.md) — servers, databases and jobs in tests.
