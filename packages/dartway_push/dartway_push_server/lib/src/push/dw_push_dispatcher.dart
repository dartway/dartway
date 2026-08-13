import 'dart:math';

import 'package:serverpod/serverpod.dart';

import 'dw_device_push_token_store.dart';
import 'dw_push.dart';
import 'dw_push_contracts.dart';

/// Narrows a candidate audience to the recipients that should actually be
/// enqueued — consent, muted categories, blocked users, quiet hours.
///
/// Batched rather than per recipient because it is the query an app already
/// knows how to write once for a thousand ids. It is an optimisation, not a
/// guarantee: the resolver checks again at send time, when the answer is
/// current. This one only keeps the queue from filling with work that will be
/// thrown away.
typedef DwPushAudienceFilter =
    Future<Set<int>> Function(
      Session session, {
      required Set<int> recipientIds,
      required String category,
      required Transaction transaction,
    });

/// One page of recipients for a send to everybody, as ids after [afterId].
///
/// A callback rather than a query the module writes: the module has no user
/// table, and an app that keys its audience on something else — a segment, a
/// subscription, a tenant — pages through it the same way.
typedef DwPushRecipientPage =
    Future<List<int>> Function(
      Session session, {
      required int? afterId,
      required int limit,
      required Transaction transaction,
    });

/// Turns "notify these people about this" into queued work.
///
/// [DwPushQueue.enqueue] is the primitive: it takes a validated message and a
/// list of ids and writes rows. Everything between a domain event and that
/// call is the same in every app — drop the actor, drop the muted, drop the
/// recipients who have no device at all, invent a deduplication key when the
/// caller has no natural one, pick a lifetime that suits the category, and cut
/// a large audience into chunks. This is that part, and none of it knows what
/// the app's users are.
final class DwPushDispatcher {
  DwPushDispatcher({
    required this.push,
    this.audienceFilter,
    this.isEnabled,
    Map<String, Duration> categoryLifetimes = const {},
    this.defaultLifetime = const Duration(hours: 24),
    this.chunkSize = 1000,
  }) : categoryLifetimes = Map.unmodifiable(categoryLifetimes) {
    if (chunkSize < 1 || chunkSize > 5000) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'Must be between 1 and 5000',
      );
    }
    if (defaultLifetime <= Duration.zero) {
      throw ArgumentError.value(
        defaultLifetime,
        'defaultLifetime',
        'Must be positive',
      );
    }
    for (final entry in categoryLifetimes.entries) {
      if (entry.value <= Duration.zero) {
        throw ArgumentError.value(
          entry.value,
          'categoryLifetimes',
          'Lifetime of "${entry.key}" must be positive',
        );
      }
    }
  }

  final DwPush push;

  final DwPushAudienceFilter? audienceFilter;

  /// A global kill switch, checked before anything is written. Operators want
  /// one place to stop an app from generating notifications at all — after a
  /// bad deploy, during a migration — without redeploying it.
  final Future<bool> Function(Session session, Transaction transaction)?
  isEnabled;

  /// How long a message of a given category stays worth delivering. A chat
  /// reply is stale in an hour; an announcement is not. Past it the queue drops
  /// the delivery instead of waking a phone with old news.
  final Map<String, Duration> categoryLifetimes;

  final Duration defaultLifetime;

  /// How many recipients are handed to one enqueue call.
  final int chunkSize;

  static final Random _random = Random.secure();

  /// Enqueues one message for [recipientIds].
  ///
  /// Returns null when nothing was written: the switch is off, or nobody was
  /// left after filtering. That is an ordinary outcome, not a failure.
  Future<DwPushEnqueueResult?> send(
    Session session, {
    required Iterable<int> recipientIds,
    required String category,
    required String title,
    String? body,
    String? imageUrl,
    Map<String, String> data = const {},
    String? deduplicationKey,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? excludeRecipientId,
    Transaction? transaction,
  }) async {
    if (transaction == null) {
      return session.db.transaction(
        (openedTransaction) => send(
          session,
          recipientIds: recipientIds,
          category: category,
          title: title,
          body: body,
          imageUrl: imageUrl,
          data: data,
          deduplicationKey: deduplicationKey,
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
          excludeRecipientId: excludeRecipientId,
          transaction: openedTransaction,
        ),
      );
    }

    if (!await _isEnabled(session, transaction)) return null;

    final audience = await _audience(
      session,
      recipientIds: recipientIds,
      category: category,
      excludeRecipientId: excludeRecipientId,
      transaction: transaction,
    );
    if (audience.isEmpty) return null;

    return _enqueue(
      session,
      recipientIds: audience,
      category: category,
      title: title,
      body: body,
      imageUrl: imageUrl,
      data: data,
      deduplicationKey: deduplicationKey,
      scheduledAt: scheduledAt,
      expiresAt: expiresAt,
      transaction: transaction,
    );
  }

  /// Enqueues one message for everybody [page] hands out, a chunk at a time.
  ///
  /// The whole audience shares one message and one deduplication key, so the
  /// campaign stays a single message with one progress figure — and running it
  /// twice does not double-send.
  Future<DwPushEnqueueResult?> sendToEveryone(
    Session session, {
    required DwPushRecipientPage page,
    required String category,
    required String title,
    String? body,
    String? imageUrl,
    Map<String, String> data = const {},
    String? deduplicationKey,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? excludeRecipientId,
    Transaction? transaction,
  }) async {
    if (transaction == null) {
      return session.db.transaction(
        (openedTransaction) => sendToEveryone(
          session,
          page: page,
          category: category,
          title: title,
          body: body,
          imageUrl: imageUrl,
          data: data,
          deduplicationKey: deduplicationKey,
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
          excludeRecipientId: excludeRecipientId,
          transaction: openedTransaction,
        ),
      );
    }

    if (!await _isEnabled(session, transaction)) return null;

    final sharedDeduplicationKey =
        deduplicationKey ?? _automaticDeduplicationKey(category);
    DwPushEnqueueResult? lastResult;
    var insertedDeliveries = 0;
    var existingDeliveries = 0;
    int? cursor;

    while (true) {
      final pageIds = await page(
        session,
        afterId: cursor,
        limit: chunkSize,
        transaction: transaction,
      );
      if (pageIds.isEmpty) break;
      cursor = pageIds.reduce(max);

      final audience = await _audience(
        session,
        recipientIds: pageIds,
        category: category,
        excludeRecipientId: excludeRecipientId,
        transaction: transaction,
      );
      if (audience.isNotEmpty) {
        final result = await _enqueue(
          session,
          recipientIds: audience,
          category: category,
          title: title,
          body: body,
          imageUrl: imageUrl,
          data: data,
          deduplicationKey: sharedDeduplicationKey,
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
          transaction: transaction,
        );
        lastResult = result;
        insertedDeliveries += result.insertedDeliveries;
        existingDeliveries += result.existingDeliveries;
      }

      if (pageIds.length < chunkSize) break;
    }

    if (lastResult == null) return null;
    return DwPushEnqueueResult(
      messageId: lastResult.messageId,
      insertedDeliveries: insertedDeliveries,
      existingDeliveries: existingDeliveries,
    );
  }

  Future<DwPushEnqueueResult> _enqueue(
    Session session, {
    required Set<int> recipientIds,
    required String category,
    required String title,
    required String? body,
    required String? imageUrl,
    required Map<String, String> data,
    required String? deduplicationKey,
    required DateTime? scheduledAt,
    required DateTime? expiresAt,
    required Transaction transaction,
  }) {
    final now = push.config.clock();
    final effectiveScheduledAt = (scheduledAt ?? now).toUtc();
    return push.queue.enqueue(
      session,
      message: DwPushMessageInput(
        deduplicationKey:
            deduplicationKey ?? _automaticDeduplicationKey(category),
        category: category,
        title: title,
        body: body,
        imageUrl: imageUrl,
        data: data,
        scheduledAt: effectiveScheduledAt,
        expiresAt:
            expiresAt?.toUtc() ??
            effectiveScheduledAt.add(
              categoryLifetimes[category.trim()] ?? defaultLifetime,
            ),
      ),
      recipientIds: recipientIds.toList(growable: false),
      transaction: transaction,
    );
  }

  Future<Set<int>> _audience(
    Session session, {
    required Iterable<int> recipientIds,
    required String category,
    required int? excludeRecipientId,
    required Transaction transaction,
  }) async {
    final candidates = recipientIds
        .where((recipientId) => recipientId != excludeRecipientId)
        .toSet();
    if (candidates.isEmpty) return const {};

    // Cheapest filter first: a recipient with no device is dropped before the
    // app is asked anything about them.
    var audience = await DwDevicePushTokenStore.filterRecipientsWithTokens(
      session,
      candidates,
      transaction: transaction,
    );
    if (audience.isEmpty) return const {};

    final filter = audienceFilter;
    if (filter != null) {
      audience = (await filter(
        session,
        recipientIds: audience,
        category: category,
        transaction: transaction,
      )).intersection(audience);
    }
    return audience;
  }

  Future<bool> _isEnabled(Session session, Transaction transaction) async {
    final enabled = isEnabled;
    return enabled == null || await enabled(session, transaction);
  }

  /// A key nothing else will produce, for a send with no natural identity.
  ///
  /// Deliberately unique rather than derived from the content: two identical
  /// announcements a week apart are two announcements, and a content hash would
  /// silently swallow the second.
  static String _automaticDeduplicationKey(String category) {
    final randomSuffix = List.generate(
      4,
      (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    final trimmedCategory = category.trim();
    final shortCategory = trimmedCategory.length > 40
        ? trimmedCategory.substring(0, 40)
        : trimmedCategory;
    return 'auto:$shortCategory:'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}:$randomSuffix';
  }
}
