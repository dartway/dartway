import 'package:meta/meta.dart';

import '../context/dw_context.dart';

/// Enqueues background jobs.
abstract interface class DwJobs {
  /// Schedules the job named [name] with [payload] (a JSON object) at [runAt]
  /// (now when omitted). The row is written through the caller's database —
  /// inside a transaction it appears only if the transaction commits.
  ///
  /// A [key] deduplicates: while a job with the same key is pending, another
  /// enqueue with it does nothing and returns `false`.
  Future<bool> enqueue(
    String name,
    Map<String, Object?> payload, {
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

/// A background job the server knows how to run.
///
/// Enqueued jobs are declared with the unnamed constructor, recurring ones
/// with [DwRecurringJob]; both go into `DwServer(jobs: …)`. Names starting
/// with `dw.` belong to the framework.
sealed class DwJobDefinition {
  const DwJobDefinition._(this.name);

  /// A job run once per enqueue.
  ///
  /// [transactional] (the default) runs the handler in the transaction that
  /// claimed the row, so the job disappears exactly when its work commits and
  /// a crash leaves it pending. Set it to `false` for handlers that call
  /// external services; they are then claimed with a [lease] instead and may
  /// run again if the process dies mid-job.
  factory DwJobDefinition(
    String name, {
    required Future<void> Function(DwContext ctx, Map<String, Object?> payload)
    handle,
    bool transactional,
    int maxAttempts,
    Duration Function(int attempt) backoff,
    Duration lease,
  }) = DwQueuedJob;

  final String name;
}

final class DwQueuedJob extends DwJobDefinition {
  const DwQueuedJob(
    super.name, {
    required this.handle,
    this.transactional = true,
    this.maxAttempts = 5,
    this.backoff = dwDefaultJobBackoff,
    this.lease = const Duration(minutes: 5),
  }) : super._();

  final Future<void> Function(DwContext ctx, Map<String, Object?> payload)
  handle;
  final bool transactional;

  /// Attempts before the job is marked failed (kept for the operator, alerted).
  final int maxAttempts;
  final Duration Function(int attempt) backoff;

  /// How long a non-transactional job is reserved for its runner.
  final Duration lease;
}

/// A job that runs every [every], across restarts: its next run time lives in
/// the database, so a restart neither skips nor repeats a run. It runs in the
/// transaction that claimed it; a failure alerts and waits for the next run.
final class DwRecurringJob extends DwJobDefinition {
  const DwRecurringJob(super.name, {required this.every, required this.handle})
    : super._();

  final Duration every;
  final Future<void> Function(DwContext ctx) handle;
}

@internal
const String dwJobNotifyChannel = 'dw_jobs';
