import 'dart:math';

/// Limits and timings of push delivery. The defaults suit an app sending to
/// thousands of devices from one process; every value exists because
/// something unbounded would otherwise grow — a run, a table, a retry loop.
final class DwPushSettings {
  const DwPushSettings({
    this.batchSize = 100,
    this.concurrentSends = 16,
    this.runBudget = const Duration(seconds: 10),
    this.sendTimeout = const Duration(seconds: 15),
    this.maxAttempts = 6,
    this.backoff = dwDefaultPushBackoff,
    this.messageLifetime = const Duration(days: 1),
    this.retention = const Duration(days: 7),
    this.maxDevicesPerAccount = 10,
    this.cleanupInterval = const Duration(minutes: 10),
  });

  /// Deliveries claimed per transaction. A batch costs a fixed handful of
  /// statements whatever its size — the claim, the devices, the leases, the
  /// record — and the project's eligibility hook once per message.
  final int batchSize;

  /// Provider requests in flight at once. They hold no database connection:
  /// a batch is claimed and committed before the first request and recorded
  /// after the last.
  final int concurrentSends;

  /// How long one run of the delivery job starts new sends. A run ends by
  /// queueing its continuation, so a large audience is sent in runs of this
  /// length and other jobs get the executor between them. Sends already in
  /// flight finish within [sendTimeout], so a run lasts at most
  /// `runBudget + sendTimeout` plus two short transactions.
  final Duration runBudget;

  /// The longest one provider request may take, its OAuth token fetch
  /// included; past it the send counts as a retryable failure.
  final Duration sendTimeout;

  /// Attempts at a device that keeps failing retryably before its delivery
  /// is recorded as failed. An attempt is counted once, when its failure is
  /// recorded — never at the claim.
  final int maxAttempts;

  /// The delay before attempt `n + 1` after `n` failed ones; a provider's
  /// `Retry-After` wins when it is longer.
  final Duration Function(int failedAttempts) backoff;

  /// How long after its scheduled time a message may still go out; a
  /// delivery due later is recorded as expired. A notification that arrives a
  /// day late is usually worse than none.
  final Duration messageLifetime;

  /// How long finished deliveries are kept — for operators, and as the
  /// window in which a dedup key holds.
  final Duration retention;

  /// Devices kept per account; registering one more drops the least
  /// recently registered.
  final int maxDevicesPerAccount;

  /// How often finished deliveries past [retention] are removed and overdue
  /// work is looked for.
  final Duration cleanupInterval;

  /// How long a claim is reserved for its run: a run's sends and records
  /// finish well inside it, so another run never takes over a delivery that
  /// is still being sent.
  Duration get lease =>
      runBudget + sendTimeout * 2 + const Duration(minutes: 1);

  /// Problems with these values; empty when they are usable.
  List<String> get problems => [
    if (batchSize < 1) 'push batchSize must be positive',
    if (concurrentSends < 1) 'push concurrentSends must be positive',
    if (runBudget <= Duration.zero) 'push runBudget must be positive',
    if (sendTimeout <= Duration.zero) 'push sendTimeout must be positive',
    if (maxAttempts < 1) 'push maxAttempts must be at least 1',
    if (messageLifetime <= Duration.zero)
      'push messageLifetime must be positive',
    if (retention <= Duration.zero) 'push retention must be positive',
    if (maxDevicesPerAccount < 1) 'push maxDevicesPerAccount must be positive',
    if (cleanupInterval <= Duration.zero)
      'push cleanupInterval must be positive',
  ];
}

final Random _jitter = Random();

/// 15 s, 30 s, 1 min … capped at one hour, each within ±20 %: devices that
/// failed together do not all come back in the same second.
Duration dwDefaultPushBackoff(int failedAttempts) {
  final base = 15 * pow(2, (failedAttempts - 1).clamp(0, 12));
  final seconds = min(base, 3600) * (0.8 + _jitter.nextDouble() * 0.4);
  return Duration(milliseconds: (seconds * 1000).round());
}
