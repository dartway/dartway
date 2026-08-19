import 'package:flutter_test/flutter_test.dart';

import '../repository/domain/dw_repo_binding.dart';
import '../repository/domain/dw_repo_local_writes.dart';
import '../repository/domain/dw_repo_mutation.dart';

/// One store under test, plus the two things a test cannot reach through the
/// public contract: what the queue holds, and a sign-out landing mid-flight.
abstract class DwRepoLocalWritesFixture {
  /// The store being checked. One instance per test — [createFixture] is called
  /// again for each case.
  DwRepoLocalWrites get store;

  /// A mutation this store would accept for [binding].
  DwRepoMutation mutationFor(DwRepoBinding binding);

  /// Ends the session the current binding belongs to, exactly as signing out
  /// does in the application.
  ///
  /// Called from inside an open transaction. Do not make it wait for that
  /// transaction on purpose — the point of the case is that the store decides
  /// the order, and either order it picks must leave the queue correct.
  Future<void> signOut();

  /// Every mutation the store currently holds for [scope], queue order.
  Future<List<DwRepoMutation>> queuedFor(DwRepoScope scope);

  Future<void> dispose();
}

/// The tests every [DwRepoLocalWrites] implementation must pass.
///
/// Call it from the implementation's own test suite:
///
/// ```dart
/// import 'package:dartway_serverpod_core_flutter/testing.dart';
///
/// void main() {
///   dwRepoLocalWritesConformance(
///     'DwOfflineLocalWrites',
///     createFixture: () async => MyFixture(await openStore()),
///   );
/// }
/// ```
///
/// It exists because the dangerous part of this contract cannot be held by the
/// shape of the API. `write` hands the store a transaction and lets the core
/// write what happens inside it, which is what stops an implementation from
/// checking the binding and enqueueing in two separate commits — but nothing in
/// the type system says the transaction is real, that `isBindingCurrent` reads
/// inside it, or that a rolled-back body leaves nothing behind. Prose asking
/// for it compiles just as well when ignored. This runs instead.
void dwRepoLocalWritesConformance(
  String description, {
  required Future<DwRepoLocalWritesFixture> Function() createFixture,
}) {
  group('$description — DwRepoLocalWrites conformance', () {
    late DwRepoLocalWritesFixture fixture;

    setUp(() async => fixture = await createFixture());
    tearDown(() => fixture.dispose());

    test('an active binding resolves and reports itself current', () async {
      final binding = await fixture.store.resolveBinding();

      expect(
        binding,
        isNotNull,
        reason: 'The fixture must start with a usable session.',
      );
      expect(await fixture.store.isBindingCurrent(binding!), isTrue);
    });

    test('a revoked binding is never current again', () async {
      final binding = (await fixture.store.resolveBinding())!;

      binding.invalidate();

      expect(await fixture.store.isBindingCurrent(binding), isFalse);
    });

    test('write returns what the body returned', () async {
      final result = await fixture.store.write<String>((_) async => 'returned');

      expect(result, 'returned');
    });

    test('a body that throws commits nothing', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final mutation = fixture.mutationFor(binding);

      await expectLater(
        fixture.store.write<void>((tx) async {
          await tx.enqueue(mutation);
          throw const _ConformanceFailure();
        }),
        throwsA(isA<_ConformanceFailure>()),
      );

      expect(
        await fixture.queuedFor(binding.scope),
        isEmpty,
        reason:
            'An enqueue inside a failed transaction must roll back with it. '
            'A store that writes the row before the body returns keeps a '
            'mutation nobody asked to keep.',
      );
    });

    test('an accepted enqueue is durably queued', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final mutation = fixture.mutationFor(binding);

      final outcome = await fixture.store.write<DwRepoEnqueue>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return DwRepoEnqueue.stale;
        await tx.enqueue(mutation);
        return DwRepoEnqueue.accepted;
      });

      expect(outcome, DwRepoEnqueue.accepted);
      expect(
        (await fixture.queuedFor(binding.scope)).map((m) => m.mutationId),
        [mutation.mutationId],
      );
    });

    test('a mutation enqueued under a revoked binding is refused', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final mutation = fixture.mutationFor(binding);
      await fixture.signOut();

      final outcome = await fixture.store.write<DwRepoEnqueue>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return DwRepoEnqueue.stale;
        await tx.enqueue(mutation);
        return DwRepoEnqueue.accepted;
      });

      expect(outcome, DwRepoEnqueue.stale);
      expect(await fixture.queuedFor(binding.scope), isEmpty);
    });

    // The case the whole inversion exists for. The network drops, the write
    // goes to the queue, and the user signs out in that exact window. A store
    // that reads the binding outside the transaction says "current", the
    // sign-out commits, and the enqueue commits after it — leaving the queue
    // and the answer disagreeing about whether anything was written.
    //
    // The interleaving itself is the store's to order, and both orders are
    // correct. What this pins is that whichever it picks, the outcome and the
    // queue say the same thing afterwards.
    test('a sign-out landing mid-transaction leaves no torn state', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final mutation = fixture.mutationFor(binding);
      late Future<void> signOut;

      final outcome = await fixture.store.write<DwRepoEnqueue>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return DwRepoEnqueue.stale;
        signOut = fixture.signOut();
        await tx.enqueue(mutation);
        return DwRepoEnqueue.accepted;
      });
      await signOut;

      final queued = (await fixture.queuedFor(
        binding.scope,
      )).map((queuedMutation) => queuedMutation.mutationId).toList();
      expect(
        queued,
        outcome == DwRepoEnqueue.accepted ? [mutation.mutationId] : isEmpty,
        reason:
            'The answer and the queue disagree: write returned $outcome while '
            'the queue holds $queued. The binding check has to read inside the '
            'same transaction that commits the row — a check taken before '
            'opening it is exactly this bug.',
      );
    });
  });
}

class _ConformanceFailure implements Exception {
  const _ConformanceFailure();
}
