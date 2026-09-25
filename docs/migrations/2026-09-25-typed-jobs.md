---
title: "Jobs are typed: DwJobKind names a job and its payload, enqueue takes the kind"
affects:
  dartway_core_server: "0.21.0-dev.4"
---

## Who is affected

Every project that declares a queued job or enqueues one. `DwJobDefinition(name, handle: …)` and
`ctx.jobs.enqueue(String name, Map payload)` are gone; recurring jobs (`DwRecurringJob`) are
unchanged.

## What to change

For each queued job, declare its kind once — the name and how its payload travels — next to the code
that enqueues it:

    abstract final class ReplyJobs {
      static const reply = DwJobKind<({int messageId})>(
        'coach.reply',
        encode: _encode,
        decode: _decode,
      );
      static Map<String, Object?> _encode(({int messageId}) p) => {'messageId': p.messageId};
      static ({int messageId}) _decode(Map<String, Object?> json) =>
          (messageId: json['messageId']! as int);
    }

Keep the name string exactly as it was: jobs already waiting in `dw_job` are found by it.

The declaration takes the kind, and the handler receives the decoded payload:

    - DwJobDefinition(
    -   'coach.reply',
    -   handle: (ctx, payload) => answer(ctx, payload['messageId']! as int),
    - ),
    + DwQueuedJob(
    +   ReplyJobs.reply,
    +   handle: (ctx, p) => answer(ctx, p.messageId),
    + ),

And every enqueue passes the kind and a typed payload:

    - await ctx.jobs.enqueue('coach.reply', {'messageId': message.id});
    + await ctx.jobs.enqueue(ReplyJobs.reply, (messageId: message.id!));

A job with no payload is `DwJobKind.withoutPayload('name')`, a `DwJobKind<void>`, enqueued with
`null`. A test double of `DwJobQueue` changes its `enqueue` to
`Future<bool> enqueue<P>(DwJobKind<P> job, P payload, {DateTime? runAt, String? key})`.
