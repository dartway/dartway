import 'dart:async';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('DwPush compact delivery queue', (sessionBuilder, endpoints) {
    late DateTime now;
    late _TestRecipientResolver resolver;
    late _RecordingTransport transport;
    late DwPush push;

    setUp(() async {
      await _clearPushTables(sessionBuilder.build());
      now = DateTime.utc(2026, 7, 20, 10);
      resolver = _TestRecipientResolver();
      transport = _RecordingTransport();
      push = DwPush(
        config: DwPushConfig(
          recipientResolver: resolver,
          transport: transport,
          batchSize: 10,
          maxConcurrentDeliveries: 2,
          retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
          clock: () => now,
        ),
      );
    });

    tearDown(() => _clearPushTables(sessionBuilder.build()));

    test(
      'duplicate enqueue stores one message and missing deliveries only',
      () async {
        final session = sessionBuilder.build();
        final input = _message(now);

        final first = await push.queue.enqueue(
          session,
          message: input,
          recipientIds: [101, 102, 102],
        );
        final second = await push.queue.enqueue(
          session,
          message: input,
          recipientIds: [101, 102],
        );

        expect(first.insertedDeliveries, 2);
        expect(second.insertedDeliveries, 0);
        expect(second.existingDeliveries, 2);
        expect(await DwPushMessage.db.count(session), 1);
        expect(await DwPushDelivery.db.count(session), 2);
      },
    );

    test(
      'concurrent duplicate enqueue stores one message and the union of deliveries',
      () async {
        final results = await Future.wait([
          push.queue.enqueue(
            sessionBuilder.build(),
            message: _message(now, key: 'concurrent-enqueue'),
            recipientIds: [105, 106],
          ),
          push.queue.enqueue(
            sessionBuilder.build(),
            message: _message(now, key: 'concurrent-enqueue'),
            recipientIds: [106, 107],
          ),
        ]).timeout(const Duration(seconds: 5));
        final session = sessionBuilder.build();
        final deliveries = await DwPushDelivery.db.find(
          session,
          orderBy: (table) => table.recipientId,
        );

        expect(await DwPushMessage.db.count(session), 1);
        expect(await DwPushMessageRecipient.db.count(session), 3);
        expect(deliveries.map((delivery) => delivery.recipientId), [
          105,
          106,
          107,
        ]);
        expect(
          results.fold<int>(
            0,
            (sum, result) => sum + result.insertedDeliveries,
          ),
          3,
        );
      },
    );

    test('duplicate enqueue keeps the first delivery window', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [103],
      );

      final later = now.add(const Duration(seconds: 1));
      await push.queue.enqueue(
        session,
        message: _message(later),
        recipientIds: [103],
      );
      final stored = await DwPushMessage.db.findFirstRow(session);

      expect(stored!.scheduledAt, now);
      expect(stored.expiresAt, now.add(const Duration(days: 1)));
    });

    test('duplicate key with different content is rejected', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [104],
      );

      expect(
        () => push.queue.enqueue(
          session,
          message: DwPushMessageInput(
            deduplicationKey: 'integration-message-v1',
            category: 'integration',
            title: 'Different content',
            scheduledAt: now,
            expiresAt: now.add(const Duration(days: 1)),
          ),
          recipientIds: [104],
        ),
        throwsStateError,
      );
    });

    test('cancels queued deliveries by deduplication key', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now, key: 'cancel-by-key'),
        recipientIds: [111, 112],
      );

      final removed = await push.queue.cancelByDeduplicationKey(
        session,
        'cancel-by-key',
      );

      expect(removed, 2);
      expect(await DwPushDelivery.db.count(session), 0);
      expect(
        await push.queue.cancelByDeduplicationKey(session, 'unknown-key'),
        0,
      );
    });

    test('cancelled message rejects existing and new recipients', () async {
      final session = sessionBuilder.build();
      final message = _message(now, key: 'cancelled-idempotency');
      final enqueued = await push.queue.enqueue(
        session,
        message: message,
        recipientIds: [113],
      );
      await push.queue.cancelMessage(session, enqueued.messageId);

      final duplicate = await push.queue.enqueue(
        session,
        message: message,
        recipientIds: [113, 114],
      );

      expect(duplicate.insertedDeliveries, 0);
      expect(duplicate.existingDeliveries, 2);
      expect(await DwPushDelivery.db.count(session), 0);
      expect(await DwPushMessageRecipient.db.count(session), 1);
      expect(
        (await DwPushMessage.db.findById(
          session,
          enqueued.messageId,
        ))!.audienceClosedAt,
        isNotNull,
      );
    });

    test(
      'successful processing deletes delivery but keeps message tombstone',
      () async {
        final session = sessionBuilder.build();
        await push.queue.enqueue(
          session,
          message: _message(now),
          recipientIds: [201],
        );

        final result = await push.processBatch(session);

        expect(result.claimed, 1);
        expect(result.delivered, 1);
        expect(await DwPushDelivery.db.count(session), 0);
        expect(await DwPushMessageRecipient.db.count(session), 1);
        expect(await DwPushMessage.db.count(session), 1);
        expect(transport.attempts, hasLength(1));
      },
    );

    test(
      'enqueue after successful delivery does not recreate recipient work',
      () async {
        final session = sessionBuilder.build();
        final message = _message(now, key: 'completed-idempotency');
        await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [202],
        );
        await push.processBatch(session);

        final duplicate = await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [202],
        );
        final secondBatch = await push.processBatch(session);

        expect(duplicate.insertedDeliveries, 0);
        expect(duplicate.existingDeliveries, 1);
        expect(secondBatch.claimed, 0);
        expect(await DwPushDelivery.db.count(session), 0);
        expect(transport.attempts, hasLength(1));
      },
    );

    test(
      'new recipient can join after an earlier recipient succeeds',
      () async {
        final session = sessionBuilder.build();
        final message = _message(now, key: 'late-recipient-after-success');
        await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [205],
        );
        await push.processBatch(session);

        final lateAudience = await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [205, 206],
        );
        final secondBatch = await push.processBatch(session);

        expect(lateAudience.insertedDeliveries, 1);
        expect(lateAudience.existingDeliveries, 1);
        expect(secondBatch.delivered, 1);
        expect(await DwPushMessageRecipient.db.count(session), 2);
        expect(transport.attempts.map((attempt) => attempt.recipientId), [
          205,
          206,
        ]);
      },
    );

    test(
      'new recipient can join while the first recipient is being sent',
      () async {
        final blockingTransport = _BlockingTransport();
        push = _push(
          now: () => now,
          resolver: resolver,
          transport: blockingTransport,
        );
        final message = _message(now, key: 'late-audience');
        await push.queue.enqueue(
          sessionBuilder.build(),
          message: message,
          recipientIds: [203],
        );

        final firstBatch = push.processBatch(sessionBuilder.build());
        await blockingTransport.started.future;
        try {
          final lateAudience = await push.queue.enqueue(
            sessionBuilder.build(),
            message: message,
            recipientIds: [203, 204],
          );

          expect(lateAudience.insertedDeliveries, 1);
          expect(lateAudience.existingDeliveries, 1);
        } finally {
          blockingTransport.release.complete();
        }
        await firstBatch;
        final secondBatch = await push.processBatch(sessionBuilder.build());

        expect(secondBatch.delivered, 1);
        expect(await DwPushDelivery.db.count(sessionBuilder.build()), 0);
        expect(
          await DwPushMessageRecipient.db.count(sessionBuilder.build()),
          2,
        );
        expect(blockingTransport.attempts, 2);
      },
    );

    test('parallel workers claim a delivery once', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [301],
      );

      final results = await Future.wait([
        push.processBatch(sessionBuilder.build(), workerName: 'worker-a'),
        push.processBatch(sessionBuilder.build(), workerName: 'worker-b'),
      ]);

      expect(results.fold<int>(0, (sum, result) => sum + result.claimed), 1);
      expect(transport.attempts, hasLength(1));
      expect(await DwPushDelivery.db.count(session), 0);
    });

    test(
      'one batch claims at most one delivery per recipient without starving others',
      () async {
        final session = sessionBuilder.build();
        push = DwPush(
          config: DwPushConfig(
            recipientResolver: resolver,
            transport: transport,
            batchSize: 2,
            maxConcurrentDeliveries: 2,
            retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
            clock: () => now,
          ),
        );
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'same-recipient-first'),
          recipientIds: [302],
        );
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'same-recipient-second'),
          recipientIds: [302],
        );
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'different-recipient'),
          recipientIds: [303],
        );

        final result = await push.processBatch(session);
        final remaining = await DwPushDelivery.db.find(session);

        expect(result.claimed, 2);
        expect(
          transport.attempts.map((attempt) => attempt.recipientId).toSet(),
          {302, 303},
        );
        expect(remaining, hasLength(1));
        expect(remaining.single.recipientId, 302);
        expect(remaining.single.attemptCount, 0);
      },
    );

    test(
      'parallel workers do not lease a recipient whose send lock is busy',
      () async {
        final session = sessionBuilder.build();
        push = DwPush(
          config: DwPushConfig(
            recipientResolver: resolver,
            transport: transport,
            batchSize: 2,
            maxConcurrentDeliveries: 2,
            categoryPriorities: const {'urgent': DwPushPriority.high},
            retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
            clock: () => now,
          ),
        );
        await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'parallel-recipient-high',
            category: 'urgent',
          ),
          recipientIds: [304],
        );
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'parallel-recipient-normal'),
          recipientIds: [304],
        );
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'parallel-unrelated-recipient'),
          recipientIds: [305],
        );

        final heldLock = await _holdRecipientLock(
          sessionBuilder.build(),
          recipientId: 304,
        );
        try {
          final results = await Future.wait([
            push.processBatch(sessionBuilder.build(), workerName: 'worker-a'),
            push.processBatch(sessionBuilder.build(), workerName: 'worker-b'),
          ]);
          final deliveries = await DwPushDelivery.db.find(session);

          expect(
            results.fold<int>(0, (sum, result) => sum + result.claimed),
            1,
          );
          expect(transport.attempts.map((attempt) => attempt.recipientId), [
            305,
          ]);
          expect(deliveries, hasLength(2));
          expect(
            deliveries.every((delivery) => delivery.recipientId == 304),
            true,
          );
          expect(
            deliveries.every((delivery) => delivery.leaseId == null),
            true,
          );
          expect(
            deliveries.every((delivery) => delivery.attemptCount == 0),
            true,
          );
        } finally {
          heldLock.release();
          await heldLock.completion;
        }
      },
    );

    test(
      'claim backfill keeps scanning past more than four full batches of busy recipients',
      () async {
        final session = sessionBuilder.build();
        push = DwPush(
          config: DwPushConfig(
            recipientResolver: resolver,
            transport: transport,
            batchSize: 2,
            maxConcurrentDeliveries: 2,
            retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
            clock: () => now,
          ),
        );

        final busyRecipientIds = List.generate(9, (index) => 310 + index);
        for (final recipientId in busyRecipientIds) {
          await push.queue.enqueue(
            session,
            message: _message(now, key: 'busy-recipient-$recipientId'),
            recipientIds: [recipientId],
          );
        }
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'backfill-available-recipient'),
          recipientIds: [399],
        );

        final heldLocks = <_HeldRecipientLock>[];
        try {
          for (final recipientId in busyRecipientIds) {
            heldLocks.add(
              await _holdRecipientLock(
                sessionBuilder.build(),
                recipientId: recipientId,
              ),
            );
          }

          final result = await push.processBatch(sessionBuilder.build());
          final remaining = await DwPushDelivery.db.find(
            session,
            orderBy: (table) => table.recipientId,
          );

          expect(result.claimed, 1);
          expect(result.delivered, 1);
          expect(transport.attempts, hasLength(1));
          expect(transport.attempts.single.recipientId, 399);
          expect(
            await DwPushDelivery.db.count(session),
            busyRecipientIds.length,
          );
          expect(
            remaining.map((delivery) => delivery.recipientId).toSet(),
            busyRecipientIds.toSet(),
          );
          expect(
            remaining.every((delivery) => delivery.attemptCount == 0),
            isTrue,
          );
        } finally {
          for (final heldLock in heldLocks) {
            heldLock.release();
          }
          for (final heldLock in heldLocks) {
            await heldLock.completion.timeout(const Duration(seconds: 5));
          }
        }
      },
    );

    test('claims a fair batch across configured category priorities', () async {
      final session = sessionBuilder.build();
      push = DwPush(
        config: DwPushConfig(
          recipientResolver: resolver,
          transport: transport,
          batchSize: 10,
          maxConcurrentDeliveries: 2,
          categoryPriorities: const {
            'urgent': DwPushPriority.high,
            'campaign': DwPushPriority.bulk,
          },
          retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
          clock: () => now,
        ),
      );
      for (final category in ['urgent', 'normal', 'campaign']) {
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'priority-$category', category: category),
          recipientIds: List.generate(10, (index) => 700 + index),
        );
      }

      final result = await push.processBatch(session);
      final categories = transport.attempts
          .map((attempt) => attempt.payload.category)
          .toList();

      expect(result.claimed, 10);
      expect(categories.where((value) => value == 'urgent'), hasLength(5));
      expect(categories.where((value) => value == 'normal'), hasLength(3));
      expect(categories.where((value) => value == 'campaign'), hasLength(2));
    });

    test('retryable delivery is rescheduled and later removed', () async {
      final session = sessionBuilder.build();
      transport = _RecordingTransport(
        outcomes: [
          DwPushTargetStatus.retryableFailure,
          DwPushTargetStatus.sent,
        ],
      );
      push = _push(now: () => now, resolver: resolver, transport: transport);
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [401],
      );

      final first = await push.processBatch(session);
      final scheduled = await DwPushDelivery.db.findFirstRow(session);

      expect(first.retried, 1);
      expect(scheduled, isNotNull);
      expect(scheduled!.attemptCount, 1);
      expect(scheduled.leaseId, isNull);
      expect(scheduled.availableAt.isAfter(now), isTrue);

      now = scheduled.availableAt;
      final second = await push.processBatch(session);

      expect(second.delivered, 1);
      expect(await DwPushDelivery.db.count(session), 0);
      expect(transport.attempts, hasLength(2));
    });

    test('provider retry-after wins over the retry policy delay', () async {
      final session = sessionBuilder.build();
      transport = _RecordingTransport(
        outcomes: [DwPushTargetStatus.retryableFailure],
        retryAfter: const Duration(minutes: 3),
      );
      push = _push(now: () => now, resolver: resolver, transport: transport);
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [402],
      );

      await push.processBatch(session);
      final scheduled = await DwPushDelivery.db.findFirstRow(session);

      expect(scheduled!.availableAt, now.add(const Duration(minutes: 3)));
    });

    test('invalid provider target is terminal and invalidated', () async {
      final session = sessionBuilder.build();
      transport = _RecordingTransport(outcomes: [DwPushTargetStatus.invalid]);
      push = _push(now: () => now, resolver: resolver, transport: transport);
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [501],
      );

      final result = await push.processBatch(session);

      expect(result.removed, 1);
      expect(result.delivered, 0);
      expect(resolver.invalidatedTargets, ['token-501']);
      expect(await DwPushDelivery.db.count(session), 0);
    });

    test('pause preserves work and resume enables delivery', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [601],
      );

      await push.pause(session);
      final paused = await push.processBatch(session);

      expect(paused.paused, isTrue);
      expect(await DwPushDelivery.db.count(session), 1);
      expect(transport.attempts, isEmpty);

      await push.resume(session);
      final resumed = await push.processBatch(session);

      expect(resumed.delivered, 1);
      expect(await DwPushDelivery.db.count(session), 0);
    });

    test('pause serializes with a racing claim', () async {
      final session = sessionBuilder.build();
      await push.queue.enqueue(
        session,
        message: _message(now, key: 'pause-claim-race'),
        recipientIds: [603],
      );
      // Ensure the runtime row exists before taking a deterministic row lock.
      await push.pause(session);
      await push.resume(session);

      final heldState = await _holdRuntimeStateRow(
        sessionBuilder.build(),
        workerName: 'default',
      );
      Future<void>? pauseFuture;
      Future<DwPushBatchResult>? batchFuture;
      var sentWhilePauseWasWaiting = false;
      try {
        pauseFuture = push.pause(sessionBuilder.build());
        await _waitForRuntimeStateUpdateWaiter(sessionBuilder.build());
        batchFuture = push.processBatch(sessionBuilder.build());
        sentWhilePauseWasWaiting = await _waitForCondition(
          () => transport.attempts.isNotEmpty,
          timeout: const Duration(milliseconds: 300),
        );
      } finally {
        heldState.release();
        await heldState.completion;
      }

      await pauseFuture;
      final result = await batchFuture;
      expect(sentWhilePauseWasWaiting, isFalse);
      expect(result.paused, isTrue);
      expect(transport.attempts, isEmpty);
      expect(await DwPushDelivery.db.count(session), 1);
    });

    test(
      'resume can extend queued schedules and expiration by pause time',
      () async {
        final session = sessionBuilder.build();
        final originalNow = now;
        await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'pause-with-ttl-freeze',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          recipientIds: [602],
        );
        await push.pause(session);
        now = now.add(const Duration(hours: 2));

        final pausedFor = await push.resume(
          session,
          extendQueuedMessageLifetime: true,
        );
        final message = await DwPushMessage.db.findFirstRow(session);
        final delivery = await DwPushDelivery.db.findFirstRow(session);

        expect(pausedFor, const Duration(hours: 2));
        expect(message!.scheduledAt, originalNow.add(const Duration(hours: 2)));
        expect(message.expiresAt, originalNow.add(const Duration(hours: 3)));
        expect(
          delivery!.availableAt,
          originalNow.add(const Duration(hours: 2)),
        );
      },
    );

    test(
      'resume extends work created during pause only by its blocked time',
      () async {
        final session = sessionBuilder.build();
        final pauseStartedAt = now;
        await push.pause(session);
        now = pauseStartedAt.add(const Duration(hours: 1));
        final enqueuedAt = now;
        await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'created-during-pause',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          recipientIds: [604],
        );
        now = pauseStartedAt.add(const Duration(hours: 2));

        final pausedFor = await push.resume(
          session,
          extendQueuedMessageLifetime: true,
        );
        final message = await DwPushMessage.db.findFirstRow(session);
        final delivery = await DwPushDelivery.db.findFirstRow(session);

        expect(pausedFor, const Duration(hours: 2));
        expect(message!.scheduledAt, enqueuedAt.add(const Duration(hours: 1)));
        expect(message.expiresAt, enqueuedAt.add(const Duration(hours: 2)));
        expect(delivery!.availableAt, enqueuedAt.add(const Duration(hours: 1)));
      },
    );

    test('resume does not delay work scheduled after the pause', () async {
      final session = sessionBuilder.build();
      final scheduledAt = now.add(const Duration(hours: 3));
      final expiresAt = scheduledAt.add(const Duration(hours: 1));
      await push.queue.enqueue(
        session,
        message: _message(
          now,
          key: 'scheduled-after-pause',
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
        ),
        recipientIds: [605],
      );
      await push.pause(session);
      now = now.add(const Duration(hours: 2));

      await push.resume(session, extendQueuedMessageLifetime: true);
      final message = await DwPushMessage.db.findFirstRow(session);
      final delivery = await DwPushDelivery.db.findFirstRow(session);

      expect(message!.scheduledAt, scheduledAt);
      expect(message.expiresAt, expiresAt);
      expect(delivery!.availableAt, scheduledAt);
    });

    test('an expired timed pause does not leak into a later pause', () async {
      final session = sessionBuilder.build();
      await push.pause(session, until: now.add(const Duration(hours: 1)));

      now = now.add(const Duration(hours: 2));
      final automaticallyResumed = await push.processBatch(session);
      expect(automaticallyResumed.paused, isFalse);

      await push.pause(session);
      now = now.add(const Duration(minutes: 30));
      expect(
        await push.resume(session, extendQueuedMessageLifetime: true),
        const Duration(minutes: 30),
      );
    });

    test(
      'expired lease is reclaimed without consuming a provider attempt',
      () async {
        final session = sessionBuilder.build();
        await push.queue.enqueue(
          session,
          message: _message(now),
          recipientIds: [701],
        );
        final delivery = await DwPushDelivery.db.findFirstRow(session);
        await DwPushDelivery.db.updateById(
          session,
          delivery!.id!,
          columnValues: (table) => [
            table.leaseId('crashed-worker'),
            table.leaseExpiresAt(now.add(const Duration(minutes: 2))),
          ],
        );

        final whileLeased = await push.processBatch(session);
        expect(whileLeased.claimed, 0);

        now = now.add(const Duration(minutes: 3));
        final recovered = await push.processBatch(session);

        expect(recovered.delivered, 1);
        expect(transport.attempts, hasLength(1));
        expect(transport.attempts.single.attemptNumber, 1);
        expect(await DwPushDelivery.db.count(session), 0);
      },
    );

    test(
      'expired message suppresses recipients until tombstone cleanup',
      () async {
        final session = sessionBuilder.build();
        final message = _message(
          now,
          key: 'expired-idempotency',
          expiresAt: now.add(const Duration(hours: 1)),
        );
        await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [702],
        );
        now = now.add(const Duration(hours: 2));
        await push.cleanup(session);

        final duplicate = await push.queue.enqueue(
          session,
          message: message,
          recipientIds: [702],
        );

        expect(duplicate.insertedDeliveries, 0);
        expect(duplicate.existingDeliveries, 1);
        expect(await DwPushMessage.db.count(session), 1);
        expect(await DwPushMessageRecipient.db.count(session), 0);
        expect(await DwPushDelivery.db.count(session), 0);

        now = now.add(const Duration(days: 8));
        final retainedCleanup = await push.cleanup(session);
        expect(retainedCleanup.orphanedMessages, 1);

        final reused = await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'expired-idempotency',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          recipientIds: [702],
        );
        expect(reused.insertedDeliveries, 1);
        expect(await DwPushMessage.db.count(session), 1);
        expect(await DwPushMessageRecipient.db.count(session), 1);
        expect(await DwPushDelivery.db.count(session), 1);
      },
    );

    test(
      'cleanup expires queue rows, records metrics and keeps active work',
      () async {
        final session = sessionBuilder.build();
        push = DwPush(
          config: DwPushConfig(
            recipientResolver: resolver,
            transport: transport,
            idempotencyRetention: const Duration(days: 1),
            metricsRetention: const Duration(days: 30),
            clock: () => now,
          ),
        );
        await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'expired-message',
            category: 'expired',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          recipientIds: [801],
        );
        await push.queue.enqueue(
          session,
          message: _message(
            now,
            key: 'active-message',
            category: 'active',
            expiresAt: now.add(const Duration(days: 10)),
          ),
          recipientIds: [802],
        );

        now = now.add(const Duration(days: 3));
        final result = await push.cleanup(session);
        final expiredMetric = await DwPushMetricBucket.db.findFirstRow(
          session,
          where: (table) =>
              table.category.equals('expired') &
              table.outcome.equals(DwPushMetricOutcome.expired.name),
        );

        expect(result.expiredDeliveries, 1);
        expect(result.messageRecipients, 1);
        expect(result.orphanedMessages, 1);
        expect(await DwPushDelivery.db.count(session), 1);
        expect(await DwPushMessageRecipient.db.count(session), 1);
        expect(await DwPushMessage.db.count(session), 1);
        expect(expiredMetric?.eventCount, 1);
      },
    );

    test('cleanup drains message recipients in bounded batches', () async {
      final session = sessionBuilder.build();
      final enqueued = await push.queue.enqueue(
        session,
        message: _message(now, key: 'bounded-membership-cleanup'),
        recipientIds: List.generate(10001, (index) => 20000 + index),
      );
      await push.queue.cancelMessage(session, enqueued.messageId);

      final first = await push.cleanup(session);
      expect(first.messageRecipients, 10000);
      expect(await DwPushMessageRecipient.db.count(session), 1);

      final second = await push.cleanup(session);
      expect(second.messageRecipients, 1);
      expect(await DwPushMessageRecipient.db.count(session), 0);
      expect(await DwPushMessage.db.count(session), 1);
    });

    test(
      'cancelled future message keeps its tombstone for the retention window',
      () async {
        final session = sessionBuilder.build();
        final futureMessage = _message(
          now,
          key: 'future-message',
          scheduledAt: now.add(const Duration(days: 30)),
          expiresAt: now.add(const Duration(days: 31)),
        );
        final enqueued = await push.queue.enqueue(
          session,
          message: futureMessage,
          recipientIds: [901],
        );
        await push.queue.cancelMessage(session, enqueued.messageId);

        now = now.add(const Duration(days: 6));
        final earlyCleanup = await push.cleanup(session);

        expect(earlyCleanup.orphanedMessages, 0);
        expect(earlyCleanup.messageRecipients, 1);
        expect(await DwPushMessageRecipient.db.count(session), 0);
        expect(await DwPushMessage.db.count(session), 1);

        now = now.add(const Duration(days: 2));
        final finalCleanup = await push.cleanup(session);

        expect(finalCleanup.orphanedMessages, 1);
        expect(await DwPushMessage.db.count(session), 0);
      },
    );

    test(
      'account deletion waits for an active recipient send without blocking the database connection',
      () async {
        final session = sessionBuilder.build();
        final blockingTransport = _BlockingTransport();
        push = _push(
          now: () => now,
          resolver: resolver,
          transport: blockingTransport,
        );
        await push.queue.enqueue(
          session,
          message: _message(now),
          recipientIds: [1001],
        );

        final worker = push.processBatch(sessionBuilder.build());
        await blockingTransport.started.future;

        final deletionEntered = Completer<void>();
        final deletionSession = sessionBuilder.build();
        final deletion = push.withRecipientLock(
          deletionSession,
          recipientId: 1001,
          action: (transaction) async {
            deletionEntered.complete();
            await push.queue.cancelRecipient(
              deletionSession,
              1001,
              transaction: transaction,
            );
            await push.recipientState.clearRecipient(
              deletionSession,
              1001,
              transaction: transaction,
            );
          },
        );
        await _waitForDeletionToStayPendingWithoutAdvisoryWaiter(
          sessionBuilder.build(),
          actionEntered: deletionEntered,
          recipientId: 1001,
        );
        expect(deletionEntered.isCompleted, isFalse);

        blockingTransport.release.complete();
        await worker;
        await deletion;

        expect(deletionEntered.isCompleted, isTrue);
        expect(blockingTransport.attempts, 1);
        expect(await DwPushDelivery.db.count(session), 0);
        expect(await DwPushMessageRecipient.db.count(session), 0);
      },
    );

    test(
      'recipient lock contention returns promptly and leaves the delivery unattempted',
      () async {
        final session = sessionBuilder.build();
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'recipient-lock-contention'),
          recipientIds: [1002],
        );

        final heldLock = await _holdRecipientLock(
          sessionBuilder.build(),
          recipientId: 1002,
        );
        Future<DwPushBatchResult>? batchFuture;
        try {
          batchFuture = push.processBatch(sessionBuilder.build());
          final result = await batchFuture.timeout(
            const Duration(milliseconds: 500),
          );
          final delivery = await DwPushDelivery.db.findFirstRow(session);

          expect(result.claimed, 0);
          expect(result.delivered, 0);
          expect(result.retried, 0);
          expect(result.removed, 0);
          expect(transport.attempts, isEmpty);
          expect(delivery, isNotNull);
          expect(delivery!.attemptCount, 0);
          expect(delivery.leaseId, isNull);
          expect(delivery.leaseExpiresAt, isNull);
        } finally {
          heldLock.release();
          await heldLock.completion.timeout(const Duration(seconds: 5));
          if (batchFuture != null) {
            try {
              await batchFuture.timeout(const Duration(seconds: 5));
            } on TimeoutException {
              // Cleanup path for a RED timeout should not leave a blocked worker behind.
            }
          }
        }
      },
    );

    test(
      'first provider send uses attempt number one after recipient lock contention clears',
      () async {
        final session = sessionBuilder.build();
        await push.queue.enqueue(
          session,
          message: _message(now, key: 'recipient-lock-contention-attempt'),
          recipientIds: [1003],
        );

        final heldLock = await _holdRecipientLock(
          sessionBuilder.build(),
          recipientId: 1003,
        );
        try {
          final skipped = await push
              .processBatch(sessionBuilder.build())
              .timeout(const Duration(milliseconds: 500));
          final queued = await DwPushDelivery.db.findFirstRow(session);

          expect(skipped.claimed, 0);
          expect(queued, isNotNull);
          expect(queued!.attemptCount, 0);

          heldLock.release();
          await heldLock.completion.timeout(const Duration(seconds: 5));

          final delivered = await push.processBatch(sessionBuilder.build());

          expect(delivered.delivered, 1);
          expect(transport.attempts, hasLength(1));
          expect(transport.attempts.single.attemptNumber, 1);
          expect(await DwPushDelivery.db.count(session), 0);
        } finally {
          heldLock.release();
          await heldLock.completion.timeout(const Duration(seconds: 5));
        }
      },
    );

    test(
      'recipient throttle state opens, blocks, reopens and clears',
      () async {
        final session = sessionBuilder.build();

        final first = await push.recipientState.tryAcquire(
          session,
          recipientId: 1101,
          stateKey: 'digest',
          interval: const Duration(hours: 1),
          metadata: const {'source': 'integration'},
        );
        final blocked = await push.recipientState.tryAcquire(
          session,
          recipientId: 1101,
          stateKey: 'digest',
          interval: const Duration(hours: 1),
        );

        expect(first, isTrue);
        expect(blocked, isFalse);

        now = now.add(const Duration(hours: 1));
        final reopened = await push.recipientState.tryAcquire(
          session,
          recipientId: 1101,
          stateKey: 'digest',
          interval: const Duration(hours: 1),
        );
        final cleared = await push.recipientState.clearRecipient(session, 1101);

        expect(reopened, isTrue);
        expect(cleared, 1);
        expect(await DwPushRecipientState.db.count(session), 0);
      },
    );

    test(
      'concurrent recipient throttle acquisition has one winner and one row',
      () async {
        final acquired = await Future.wait([
          push.recipientState.tryAcquire(
            sessionBuilder.build(),
            recipientId: 1102,
            stateKey: 'digest',
            interval: const Duration(hours: 1),
          ),
          push.recipientState.tryAcquire(
            sessionBuilder.build(),
            recipientId: 1102,
            stateKey: 'digest',
            interval: const Duration(hours: 1),
          ),
        ]).timeout(const Duration(seconds: 5));
        final session = sessionBuilder.build();

        expect(acquired.where((value) => value), hasLength(1));
        expect(
          await DwPushRecipientState.db.count(
            session,
            where: (table) =>
                table.recipientId.equals(1102) &
                table.stateKey.equals('digest'),
          ),
          1,
        );
      },
    );

    test('malformed transport result is recovered as a retry', () async {
      final session = sessionBuilder.build();
      push = _push(
        now: () => now,
        resolver: resolver,
        transport: const _MalformedTransport(),
      );
      await push.queue.enqueue(
        session,
        message: _message(now),
        recipientIds: [1201],
      );

      final result = await push.processBatch(session);
      final delivery = await DwPushDelivery.db.findFirstRow(session);

      expect(result.retried, 1);
      expect(delivery, isNotNull);
      expect(delivery!.attemptCount, 1);
      expect(delivery.leaseId, isNull);
      expect(delivery.lastError, 'exception_StateError');
    });

    test(
      'repeated transport exceptions exhaust retries and remove work',
      () async {
        final session = sessionBuilder.build();
        push = DwPush(
          config: DwPushConfig(
            recipientResolver: resolver,
            transport: const _ThrowingTransport(),
            retryPolicy: DwPushRetryPolicy(maxAttempts: 2, jitterFactor: 0),
            clock: () => now,
          ),
        );
        await push.queue.enqueue(
          session,
          message: _message(now),
          recipientIds: [1301],
        );

        final first = await push.processBatch(session);
        final scheduled = await DwPushDelivery.db.findFirstRow(session);
        expect(first.retried, 1);

        now = scheduled!.availableAt;
        final second = await push.processBatch(session);

        expect(second.removed, 1);
        expect(await DwPushDelivery.db.count(session), 0);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}

Future<void> _clearPushTables(Session session) async {
  await session.db.unsafeExecute('DELETE FROM "dw_push_delivery"');
  await session.db.unsafeExecute('DELETE FROM "dw_push_message_recipient"');
  await session.db.unsafeExecute('DELETE FROM "dw_push_recipient_state"');
  await session.db.unsafeExecute('DELETE FROM "dw_push_runtime_state"');
  await session.db.unsafeExecute('DELETE FROM "dw_push_metric_bucket"');
  await session.db.unsafeExecute('DELETE FROM "dw_push_message"');
}

Future<_HeldRecipientLock> _holdRuntimeStateRow(
  Session session, {
  required String workerName,
}) async {
  final held = Completer<void>();
  final release = Completer<void>();
  final completion = session.db.transaction((transaction) async {
    await session.db.unsafeQuery(
      '''
SELECT "id"
FROM "dw_push_runtime_state"
WHERE "workerName" = @workerName
FOR UPDATE
''',
      transaction: transaction,
      parameters: QueryParameters.named({'workerName': workerName}),
    );
    held.complete();
    await release.future;
  });
  await held.future;
  return _HeldRecipientLock(release, completion);
}

Future<void> _waitForRuntimeStateUpdateWaiter(Session session) async {
  final found = await _waitForCondition(() async {
    final result = await session.db.unsafeQuery('''
SELECT EXISTS (
  SELECT 1
  FROM pg_stat_activity
  WHERE datname = current_database()
    AND wait_event_type = 'Lock'
    AND query LIKE '%UPDATE "dw_push_runtime_state"%'
)
''');
    return result.single.single == true;
  });
  if (!found) {
    throw StateError('Timed out waiting for the pause update to block');
  }
}

Future<bool> _waitForCondition(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return false;
}

Future<void> _waitForDeletionToStayPendingWithoutAdvisoryWaiter(
  Session session, {
  required Completer<void> actionEntered,
  required int recipientId,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (actionEntered.isCompleted) {
      throw StateError(
        'Deletion entered while recipient send still held the lock',
      );
    }
    if (!await _hasAdvisoryLockWaiter(session, recipientId: recipientId)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (actionEntered.isCompleted) {
        throw StateError(
          'Deletion entered while verifying recipient send still held the lock',
        );
      }
      if (!await _hasAdvisoryLockWaiter(session, recipientId: recipientId)) {
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('Timed out waiting for deletion to remain pending');
}

Future<bool> _hasAdvisoryLockWaiter(
  Session session, {
  required int recipientId,
}) async {
  const lockNamespace = 0x44575053; // "DWPS"
  final expectedLockKey = recipientId ^ (lockNamespace << 32);
  final result = await session.db.unsafeQuery('''
SELECT EXISTS (
  SELECT 1
  FROM pg_locks
  WHERE locktype = 'advisory'
    AND NOT granted
    AND database = (
      SELECT oid
      FROM pg_database
      WHERE datname = current_database()
    )
    AND objsubid = 1
    AND ((classid::bigint << 32) | objid::bigint) = @expectedLockKey
)
''', parameters: QueryParameters.named({'expectedLockKey': expectedLockKey}));
  return result.first.first == true;
}

Future<_HeldRecipientLock> _holdRecipientLock(
  Session session, {
  required int recipientId,
}) async {
  const lockNamespace = 0x44575053; // "DWPS"
  final held = Completer<void>();
  final release = Completer<void>();
  final completion = session.db.transaction((transaction) async {
    await session.db.unsafeQuery(
      '''
SELECT pg_advisory_xact_lock(
  @recipientId::bigint # (@namespace::bigint << 32)
)
''',
      transaction: transaction,
      parameters: QueryParameters.named({
        'namespace': lockNamespace,
        'recipientId': recipientId,
      }),
    );
    held.complete();
    await release.future;
  });
  await held.future;
  return _HeldRecipientLock(release, completion);
}

DwPush _push({
  required DateTime Function() now,
  required DwPushRecipientResolver resolver,
  required DwPushTransport transport,
}) => DwPush(
  config: DwPushConfig(
    recipientResolver: resolver,
    transport: transport,
    batchSize: 10,
    maxConcurrentDeliveries: 2,
    retryPolicy: DwPushRetryPolicy(jitterFactor: 0),
    clock: now,
  ),
);

DwPushMessageInput _message(
  DateTime now, {
  String key = 'integration-message-v1',
  String category = 'integration',
  DateTime? scheduledAt,
  DateTime? expiresAt,
}) => DwPushMessageInput(
  deduplicationKey: key,
  category: category,
  title: 'Integration push',
  data: const {'path': '/integration'},
  scheduledAt: scheduledAt ?? now,
  expiresAt: expiresAt ?? now.add(const Duration(days: 1)),
);

final class _TestRecipientResolver extends DwPushRecipientResolver {
  final List<String> invalidatedTargets = [];

  @override
  Future<DwPushRecipient> resolve(
    Session session, {
    required int recipientId,
    required DwPushPayload payload,
    required Transaction transaction,
  }) async => DwPushRecipient(['token-$recipientId']);

  @override
  Future<void> invalidateTargets(
    Session session, {
    required int recipientId,
    required List<String> targets,
    required Transaction transaction,
  }) async {
    invalidatedTargets.addAll(targets);
  }
}

final class _RecordingTransport implements DwPushTransport {
  _RecordingTransport({
    Iterable<DwPushTargetStatus> outcomes = const [],
    this.retryAfter,
  }) : _outcomes = List.of(outcomes);

  final List<DwPushTargetStatus> _outcomes;
  final Duration? retryAfter;
  final List<DwPushDeliveryAttempt> attempts = [];

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) async {
    attempts.add(attempt);
    final status = _outcomes.isEmpty
        ? DwPushTargetStatus.sent
        : _outcomes.removeAt(0);
    return DwPushTransportResult([
      for (final target in attempt.targets)
        DwPushTargetResult(
          target: target,
          status: status,
          errorCode: status == DwPushTargetStatus.retryableFailure
              ? 'temporary'
              : null,
          retryAfter: status == DwPushTargetStatus.retryableFailure
              ? retryAfter
              : null,
        ),
    ]);
  }
}

final class _BlockingTransport implements DwPushTransport {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  int attempts = 0;

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) async {
    attempts++;
    if (!started.isCompleted) started.complete();
    await release.future;
    return DwPushTransportResult([
      for (final target in attempt.targets)
        DwPushTargetResult(target: target, status: DwPushTargetStatus.sent),
    ]);
  }
}

final class _HeldRecipientLock {
  _HeldRecipientLock(this._release, this.completion);

  final Completer<void> _release;
  final Future<void> completion;

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }
}

final class _MalformedTransport implements DwPushTransport {
  const _MalformedTransport();

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) async => DwPushTransportResult(const []);
}

final class _ThrowingTransport implements DwPushTransport {
  const _ThrowingTransport();

  @override
  Future<DwPushTransportResult> send(
    Session session,
    DwPushDeliveryAttempt attempt,
  ) => throw StateError('provider unavailable');
}
