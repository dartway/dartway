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
    DwPushRetryPolicy? retryPolicy,
    this.batchSize = 100,
    this.maxConcurrentDeliveries = 4,
    this.enqueueChunkSize = 1000,
    this.leaseDuration = const Duration(minutes: 2),
    this.idempotencyRetention = const Duration(days: 7),
    this.metricsRetention = const Duration(days: 90),
    this.recipientStateRetention = const Duration(days: 90),
    Map<String, DwPushPriority> categoryPriorities = const {},
    DwPushClock? clock,
  }) : retryPolicy = retryPolicy ?? DwPushRetryPolicy(),
       categoryPriorities = _normalizePriorities(categoryPriorities),
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

  final DwPushRecipientResolver recipientResolver;
  final DwPushTransport transport;
  final DwPushRetryPolicy retryPolicy;
  final int batchSize;
  final int maxConcurrentDeliveries;
  final int enqueueChunkSize;
  final Duration leaseDuration;
  final Duration idempotencyRetention;
  final Duration metricsRetention;
  final Duration recipientStateRetention;
  final Map<String, DwPushPriority> categoryPriorities;
  final DwPushClock clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  static DwPushClock _normalizeClock(DwPushClock? clock) =>
      clock == null ? _utcNow : () => clock().toUtc();

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
