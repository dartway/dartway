import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';

/// Enqueues background jobs.
abstract interface class DwJobQueue {
  /// Schedules [job] with [payload] at [runAt] (now when omitted). The row is
  /// written through the caller's database — inside a transaction it appears
  /// only if the transaction commits.
  ///
  /// The payload is encoded here, by the kind's codec, so a payload that is
  /// not JSON fails at the call site; the server must declare a job of this
  /// kind (`DwAppServer(jobs: …)` or a module's), or this throws.
  ///
  /// A [key] deduplicates: while a job with the same key is pending, another
  /// enqueue with it does nothing and returns `false`.
  Future<bool> enqueue<P>(
    DwJobKind<P> job,
    P payload, {
    DateTime? runAt,
    String? key,
  });
}

/// Delay before the next attempt of a failed job: 10 s, 20 s, 40 s … capped at
/// one hour.
Duration dwDefaultJobBackoff(int attempt) {
  final seconds = 10 * (1 << (attempt - 1).clamp(0, 20));
  return Duration(seconds: seconds.clamp(10, 3600));
}

/// Which run of a job a context belongs to: `ctx.job` in a job's handler.
final class DwJobAttempt {
  const DwJobAttempt({
    required this.name,
    required this.attempt,
    required this.maxAttempts,
  });

  final String name;

  /// This run's number, from 1. A recurring job runs once per occurrence, so
  /// it is always 1 of 1.
  final int attempt;

  final int maxAttempts;

  /// Whether a failure of this run marks the job failed instead of retrying
  /// it — where a handler records "gave up" for the people waiting on it.
  bool get isLastAttempt => attempt >= maxAttempts;

  @override
  String toString() => 'DwJobAttempt($name, $attempt of $maxAttempts)';
}

/// A background job the server knows how to run: [DwQueuedJob], run once per
/// enqueue, or [DwRecurringJob]; both go into `DwAppServer(jobs: …)`. Names
/// starting with `dw.` belong to the framework.
sealed class DwJobDefinition {
  const DwJobDefinition._(this.name);

  final String name;
}

/// What a job is: its name and how its payload of type [P] travels as JSON.
///
/// Enqueued by this constant (`ctx.jobs.enqueue(kind, payload)`) and run by
/// the [DwQueuedJob] declared for it — the two are apart because the handler
/// is often built from a service instance, while the places that enqueue are
/// not. The one place a payload is spelled as a map is here: [encode] runs at
/// the enqueue, [decode] before the handler, and both sides see [P]. A record
/// works as well as a class:
///
/// ```dart
/// static const reply = DwJobKind<({int messageId})>(
///   'coach.reply',
///   encode: _encodeReply,
///   decode: _decodeReply,
/// );
/// static Map<String, Object?> _encodeReply(({int messageId}) p) =>
///     {'messageId': p.messageId};
/// static ({int messageId}) _decodeReply(Map<String, Object?> json) =>
///     (messageId: json['messageId']! as int);
///
/// await ctx.jobs.enqueue(CoachReplies.reply, (messageId: message.id!));
/// ```
final class DwJobKind<P> {
  const DwJobKind(this.name, {required this.encode, required this.decode});

  /// A job that needs nothing but to run: enqueued with `null`.
  static DwJobKind<void> withoutPayload(String name) =>
      DwJobKind<void>(name, encode: (_) => const {}, decode: (_) {});

  final String name;
  final Map<String, Object?> Function(P payload) encode;
  final P Function(Map<String, Object?> json) decode;

  @override
  String toString() => 'DwJobKind($name)';
}

/// A job run once per enqueue of its [kind].
///
/// [transactional] (the default) runs the handler in the transaction that
/// claimed the row, so the job disappears exactly when its work commits and a
/// crash leaves it pending. Set it to `false` for handlers that call external
/// services; they are then claimed with a [lease] instead and may run again if
/// the process dies mid-job.
final class DwQueuedJob<P> extends DwJobDefinition {
  DwQueuedJob(
    this.kind, {
    required Future<void> Function(DwCallContext ctx, P payload) handle,
    this.transactional = true,
    this.maxAttempts = 5,
    this.backoff = dwDefaultJobBackoff,
    this.lease = const Duration(minutes: 5),
  }) : _handle = handle,
       super._(kind.name);

  final DwJobKind<P> kind;
  final Future<void> Function(DwCallContext ctx, P payload) _handle;

  final bool transactional;

  /// Attempts before the job is marked failed (kept for the operator, alerted).
  final int maxAttempts;
  final Duration Function(int attempt) backoff;

  /// How long a non-transactional job is reserved for its runner.
  final Duration lease;

  /// Decodes the stored [json] and runs the handler on it.
  @internal
  Future<void> run(DwCallContext ctx, Map<String, Object?> json) =>
      _handle(ctx, kind.decode(json));
}

/// A job that runs every [every], across restarts: its next run time lives in
/// the database, so a restart neither skips nor repeats a run. It runs in the
/// transaction that claimed it; a failure alerts and waits for the next run.
final class DwRecurringJob extends DwJobDefinition {
  const DwRecurringJob(super.name, {required this.every, required this.handle})
    : super._();

  final Duration every;
  final Future<void> Function(DwCallContext ctx) handle;
}

@internal
const String dwJobNotifyChannel = 'dw_jobs';
