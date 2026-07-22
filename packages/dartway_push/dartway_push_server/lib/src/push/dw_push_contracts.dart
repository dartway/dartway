import 'dart:collection';

import 'package:serverpod/serverpod.dart';

import 'dw_push_retry_policy.dart';
import 'dw_push_transport.dart';

typedef DwPushClock = DateTime Function();

/// Fair-claim lane assigned to a stable, low-cardinality message category.
enum DwPushPriority { high, normal, bulk }

/// Validated, provider-independent content of one logical push message.
final class DwPushMessageInput {
  DwPushMessageInput({
    required String deduplicationKey,
    required String category,
    required String title,
    String? body,
    String? imageUrl,
    Map<String, String> data = const {},
    required DateTime scheduledAt,
    required DateTime expiresAt,
  }) : deduplicationKey = deduplicationKey.trim(),
       category = category.trim(),
       title = title.trim(),
       body = _trimToNull(body),
       imageUrl = _trimToNull(imageUrl),
       data = UnmodifiableMapView(Map.of(data)),
       scheduledAt = scheduledAt.toUtc(),
       expiresAt = expiresAt.toUtc() {
    _requireLength(this.deduplicationKey, 'deduplicationKey', 200);
    _requireLength(this.category, 'category', 100);
    _requireLength(this.title, 'title', 200);
    _requireOptionalLength(this.body, 'body', 4096);
    _requireOptionalLength(this.imageUrl, 'imageUrl', 2048);
    if (!expiresAt.isAfter(scheduledAt)) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'Must be after scheduledAt',
      );
    }
    if (this.data.length > 50) {
      throw ArgumentError.value(
        data,
        'data',
        'Must contain at most 50 entries',
      );
    }
    var dataCharacters = 0;
    for (final entry in this.data.entries) {
      _requireLength(entry.key, 'data key', 128);
      if (entry.value.length > 4096) {
        throw ArgumentError.value(
          entry.value,
          'data value',
          'Must contain at most 4096 characters',
        );
      }
      dataCharacters += entry.key.length + entry.value.length;
    }
    if (dataCharacters > 16384) {
      throw ArgumentError.value(
        data,
        'data',
        'Keys and values must contain at most 16384 characters in total',
      );
    }
  }

  final String deduplicationKey;
  final String category;
  final String title;
  final String? body;
  final String? imageUrl;
  final Map<String, String> data;
  final DateTime scheduledAt;
  final DateTime expiresAt;

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static void _requireLength(String value, String name, int maximum) {
    if (value.isEmpty || value.length > maximum) {
      throw ArgumentError.value(
        value,
        name,
        'Must contain between 1 and $maximum characters',
      );
    }
  }

  static void _requireOptionalLength(String? value, String name, int maximum) {
    if (value != null && value.length > maximum) {
      throw ArgumentError.value(
        value,
        name,
        'Must contain at most $maximum characters',
      );
    }
  }
}

/// Provider-independent payload passed to application adapters.
final class DwPushPayload {
  const DwPushPayload({
    required this.messageId,
    required this.category,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.data,
    required this.expiresAt,
  });

  final int messageId;
  final String category;
  final String title;
  final String? body;
  final String? imageUrl;
  final Map<String, String> data;
  final DateTime expiresAt;
}

/// Active provider targets resolved by the host application for one user.
final class DwPushRecipient {
  DwPushRecipient(Iterable<String> targets)
    : targets = List.unmodifiable(
        LinkedHashSet.of(targets.map((target) => target.trim()))
          ..removeWhere((target) => target.isEmpty),
      );

  final List<String> targets;
}

/// Context supplied to the transport for a single recipient attempt.
final class DwPushDeliveryAttempt {
  const DwPushDeliveryAttempt({
    required this.deliveryId,
    required this.recipientId,
    required this.attemptNumber,
    required this.payload,
    required this.targets,
  });

  final int deliveryId;
  final int recipientId;
  final int attemptNumber;
  final DwPushPayload payload;
  final List<String> targets;

  /// Stable across retries and suitable for transports with idempotency keys.
  String get idempotencyKey => 'dw-push-delivery:$deliveryId';
}

/// Resolves app-owned tokens and recipient preferences under a recipient lock.
abstract class DwPushRecipientResolver {
  const DwPushRecipientResolver();

  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  });

  /// Removes or disables provider targets reported as invalid.
  Future<void> invalidateTargets(
    Session session, {
    required int recipientId,
    required List<String> targets,
    required Transaction transaction,
  }) async {}
}

/// Sends resolved targets through FCM, RuStore or another host-owned provider.
abstract interface class DwPushTransport {
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  );
}

/// Optional push delivery component configuration for [DwCore].
final class DwPushConfig {
  DwPushConfig({
    required this.recipientResolver,
    required this.transport,
    Map<String, DwPushPriority> categoryPriorities = const {},
    DwPushFineTuning? fineTuning,
  }) : categoryPriorities = _normalizePriorities(categoryPriorities),
       fineTuning = fineTuning ?? DwPushFineTuning();

  final DwPushRecipientResolver recipientResolver;
  final DwPushTransport transport;
  final Map<String, DwPushPriority> categoryPriorities;

  /// Advanced delivery tuning. Leave unset for safe defaults — most apps never
  /// touch it. See [DwPushFineTuning] for what each knob affects.
  final DwPushFineTuning fineTuning;

  // Delegating getters keep the engine's `config.<knob>` call sites unchanged
  // while the public constructor stays down to domain seams + one tuning object.
  DwPushRetryPolicy get retryPolicy => fineTuning.retryPolicy;
  int get batchSize => fineTuning.batchSize;
  int get maxConcurrentDeliveries => fineTuning.maxConcurrentDeliveries;
  int get enqueueChunkSize => fineTuning.enqueueChunkSize;
  Duration get leaseDuration => fineTuning.leaseDuration;
  Duration get idempotencyRetention => fineTuning.idempotencyRetention;
  Duration get metricsRetention => fineTuning.metricsRetention;
  Duration get recipientStateRetention => fineTuning.recipientStateRetention;
  DwPushClock get clock => fineTuning.clock;

  static Map<String, DwPushPriority> _normalizePriorities(
    Map<String, DwPushPriority> priorities,
  ) {
    final normalized = <String, DwPushPriority>{};
    for (final entry in priorities.entries) {
      final category = entry.key.trim();
      if (category.isEmpty || category.length > 100) {
        throw ArgumentError.value(
          entry.key,
          'categoryPriorities',
          'Category keys must contain between 1 and 100 characters',
        );
      }
      if (normalized.containsKey(category)) {
        throw ArgumentError.value(
          entry.key,
          'categoryPriorities',
          'Category keys must remain unique after trimming',
        );
      }
      normalized[category] = entry.value;
    }
    return UnmodifiableMapView(normalized);
  }
}

/// Advanced delivery tuning for [DwPushConfig].
///
/// Every value here has a safe default — an app that just wants push working
/// passes no `fineTuning` at all. Reach for it only to trade throughput,
/// latency or storage against your own database and load profile. Each field
/// documents what it actually affects so you are never guessing.
final class DwPushFineTuning {
  DwPushFineTuning({
    DwPushRetryPolicy? retryPolicy,
    this.batchSize = 100,
    this.maxConcurrentDeliveries = 4,
    this.enqueueChunkSize = 1000,
    this.leaseDuration = const Duration(minutes: 2),
    this.idempotencyRetention = const Duration(days: 7),
    this.metricsRetention = const Duration(days: 90),
    this.recipientStateRetention = const Duration(days: 90),
    DwPushClock? clock,
  }) : retryPolicy = retryPolicy ?? DwPushRetryPolicy(),
       clock = _normalizeClock(clock) {
    if (batchSize < 1 || batchSize > 1000) {
      throw ArgumentError.value(
        batchSize,
        'batchSize',
        'Must be between 1 and 1000',
      );
    }
    if (maxConcurrentDeliveries < 1 || maxConcurrentDeliveries > batchSize) {
      throw ArgumentError.value(
        maxConcurrentDeliveries,
        'maxConcurrentDeliveries',
        'Must be between 1 and batchSize',
      );
    }
    if (enqueueChunkSize < 1 || enqueueChunkSize > 5000) {
      throw ArgumentError.value(
        enqueueChunkSize,
        'enqueueChunkSize',
        'Must be between 1 and 5000',
      );
    }
    if (leaseDuration <= Duration.zero) {
      throw ArgumentError.value(
        leaseDuration,
        'leaseDuration',
        'Must be positive',
      );
    }
    if (idempotencyRetention <= Duration.zero) {
      throw ArgumentError.value(
        idempotencyRetention,
        'idempotencyRetention',
        'Must be positive',
      );
    }
    if (metricsRetention <= Duration.zero) {
      throw ArgumentError.value(
        metricsRetention,
        'metricsRetention',
        'Must be positive',
      );
    }
    if (recipientStateRetention <= Duration.zero) {
      throw ArgumentError.value(
        recipientStateRetention,
        'recipientStateRetention',
        'Must be positive',
      );
    }
  }

  /// How failed sends are retried (attempt cap, backoff, jitter). Wider backoff
  /// spares a struggling provider; a lower attempt cap drops undeliverable
  /// pushes sooner. Affects delivery latency and load on the provider.
  final DwPushRetryPolicy retryPolicy;

  /// How many deliveries one worker pass claims at once. Higher drains a backlog
  /// faster but does more work per pass; lower spreads load. Throughput knob.
  final int batchSize;

  /// How many of a claimed batch are sent in parallel. **This is the one to
  /// respect:** each in-flight send holds a database connection for the whole
  /// provider round-trip, so a value near your Postgres pool size can starve the
  /// rest of the app. Keep it a small fraction of the pool. Throughput vs. pool
  /// safety.
  final int maxConcurrentDeliveries;

  /// Row-insert chunk size when enqueuing a large audience. Purely an internal
  /// batching detail for big fan-outs; rarely worth changing.
  final int enqueueChunkSize;

  /// How long a claimed delivery stays "leased" before another worker may
  /// re-claim it. Shorter recovers faster after a crashed worker but risks
  /// re-sending a delivery whose provider call is merely slow; longer is safer
  /// against duplicates but leaves crashed work stuck longer. Recovery vs.
  /// duplicate risk.
  final Duration leaseDuration;

  /// How long a completed message's dedup record is kept so the same
  /// deduplication key cannot resend. Longer protects against late duplicates at
  /// the cost of table size.
  final Duration idempotencyRetention;

  /// How long hourly delivery metric buckets are kept before cleanup. Longer
  /// history costs storage; it does not affect delivery.
  final Duration metricsRetention;

  /// How long per-recipient coordination state (cooldowns, rate-limit windows)
  /// is kept. Longer holds more rows; it does not affect delivery correctness.
  final Duration recipientStateRetention;

  /// Time source. Injected only by tests to make delivery timing deterministic;
  /// production leaves it unset and the engine uses the wall clock in UTC.
  final DwPushClock clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  static DwPushClock _normalizeClock(DwPushClock? clock) =>
      clock == null ? _utcNow : () => clock().toUtc();
}

/// Bounded outcomes stored as hourly counters instead of delivery history.
enum DwPushMetricOutcome {
  queued,
  delivered,
  skipped,
  retryScheduled,
  failed,
  expired,
  cancelled,
}

/// Summary returned after one worker batch.
final class DwPushBatchResult {
  const DwPushBatchResult({
    required this.claimed,
    required this.delivered,
    required this.retried,
    required this.removed,
    required this.paused,
  });

  const DwPushBatchResult.paused()
    : claimed = 0,
      delivered = 0,
      retried = 0,
      removed = 0,
      paused = true;

  final int claimed;
  final int delivered;
  final int retried;
  final int removed;
  final bool paused;
}

/// Query-computed delivery progress for one message.
///
/// Cheap to read — two `COUNT(*)`s, no per-message counter maintained on a hot
/// row — so reading it never contends with delivery. It is a snapshot, not a
/// live millisecond gauge: fine for a dashboard that polls every few seconds.
/// Because terminal deliveries are deleted, [remaining] trends to zero and the
/// campaign is [isComplete] once it reaches it.
final class DwPushCampaignProgress {
  const DwPushCampaignProgress({required this.total, required this.remaining});

  /// Unique recipients the message was ever enqueued to (durable membership).
  final int total;

  /// Deliveries still pending; terminal ones are deleted, so this trends to 0.
  final int remaining;

  /// Recipients whose delivery has reached a terminal outcome.
  int get done => total - remaining;

  /// Whether every enqueued recipient has reached a terminal outcome.
  bool get isComplete => remaining == 0;
}

/// Idempotent enqueue result.
final class DwPushEnqueueResult {
  const DwPushEnqueueResult({
    required this.messageId,
    required this.insertedDeliveries,
    required this.existingDeliveries,
  });

  final int messageId;

  /// Requested recipients for which this call created new delivery work.
  final int insertedDeliveries;

  /// Requested recipients for which this call did not create delivery work.
  ///
  /// This includes recipients with an existing message membership and all
  /// recipients suppressed because the message is expired or its whole
  /// audience was cancelled. It is therefore not a count of physical rows in
  /// `dw_push_delivery`.
  final int existingDeliveries;
}

/// Counts removed by a retention cleanup pass.
final class DwPushCleanupResult {
  const DwPushCleanupResult({
    required this.expiredDeliveries,
    this.messageRecipients = 0,
    required this.orphanedMessages,
    required this.metricBuckets,
    required this.recipientStates,
  });

  final int expiredDeliveries;

  /// Compact recipient memberships removed during this cleanup pass.
  final int messageRecipients;
  final int orphanedMessages;
  final int metricBuckets;
  final int recipientStates;
}

/// Lightweight queue snapshot for health checks and alerts.
final class DwPushQueueHealth {
  const DwPushQueueHealth({
    required this.pendingDeliveries,
    required this.oldestAvailableAt,
  });

  final int pendingDeliveries;
  final DateTime? oldestAvailableAt;
}
