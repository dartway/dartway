import 'package:flutter_test/flutter_test.dart';

import '../repository/domain/dw_repo_binding.dart';
import '../repository/domain/dw_repo_local_reads.dart';
import '../repository/domain/dw_repo_query_key.dart';

/// One store under test, plus the three things a test cannot reach through the
/// public contract: which queries the store agreed to keep, what it is holding,
/// and a sign-out landing mid-flight.
abstract class DwRepoLocalReadsFixture {
  /// The store being checked. One instance per test — `createFixture` is called
  /// again for each case.
  DwRepoLocalReads get store;

  /// A query this store will agree to keep, and the snapshot to offer under it.
  ///
  /// Whatever selection the store applies (a whitelist, a size budget, a rule
  /// about which models are worth keeping), this pair must pass it.
  ({DwRepoQueryKey<Object> queryKey, DwRepoReadSnapshot snapshot}) keptQueryFor(
    DwRepoBinding binding,
  );

  /// A query this store will decline to keep, or `null` when it keeps
  /// everything it is offered.
  ///
  /// Declining is an ordinary answer, and a store that never declines is a
  /// legitimate store — the case is skipped for it rather than failed.
  DwRepoQueryKey<Object>? ignoredQueryFor(DwRepoBinding binding);

  /// Ends the session the current binding belongs to, exactly as signing out
  /// does in the application.
  ///
  /// Called from inside an open transaction. Do not make it wait for that
  /// transaction on purpose — the store decides the order, and either order it
  /// picks must leave the device correct.
  Future<void> signOut();

  /// Every query key this store is currently holding a snapshot for, under
  /// [scope].
  Future<List<String>> keptStorageKeysFor(DwRepoScope scope);

  Future<void> dispose();
}

/// The tests every [DwRepoLocalReads] implementation must pass.
///
/// Call it from the implementation's own test suite:
///
/// ```dart
/// import 'package:dartway_serverpod_core_flutter/testing.dart';
///
/// void main() {
///   dwRepoLocalReadsConformance(
///     'MyLocalReads',
///     createFixture: () async => MyFixture(await openStore()),
///   );
/// }
/// ```
///
/// Keeping a read is a write, and it carries the same danger as any other: a
/// snapshot committed after the user signed out survives the purge that was
/// supposed to remove it. `keep` hands the store a transaction and lets the
/// core write the order of operations inside it, which is what stops an
/// implementation from checking the binding and committing the row separately —
/// but nothing in the type system says the transaction is real, that
/// `isBindingCurrent` reads inside it, or that a rolled-back body leaves
/// nothing behind. This runs instead.
void dwRepoLocalReadsConformance(
  String description, {
  required Future<DwRepoLocalReadsFixture> Function() createFixture,
}) {
  group('$description — DwRepoLocalReads conformance', () {
    late DwRepoLocalReadsFixture fixture;

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

    test('keep returns what the body returned', () async {
      final result = await fixture.store.keep<String>((_) async => 'returned');

      expect(result, 'returned');
    });

    test('a body that throws commits nothing', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final kept = fixture.keptQueryFor(binding);

      await expectLater(
        fixture.store.keep<void>((tx) async {
          await tx.storeSnapshot(
            queryKey: kept.queryKey,
            snapshot: kept.snapshot,
          );
          throw const _ConformanceFailure();
        }),
        throwsA(isA<_ConformanceFailure>()),
      );

      expect(
        await fixture.keptStorageKeysFor(binding.scope),
        isEmpty,
        reason:
            'A snapshot written inside a failed transaction must roll back '
            'with it. A store that commits the row before the body returns '
            'keeps a read nobody asked it to keep.',
      );
    });

    test('an accepted snapshot is durably kept and readable back', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final kept = fixture.keptQueryFor(binding);

      final accepted = await fixture.store.keep<bool>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return false;
        return tx.storeSnapshot(
          queryKey: kept.queryKey,
          snapshot: kept.snapshot,
        );
      });

      expect(accepted, isTrue);
      expect(await fixture.keptStorageKeysFor(binding.scope), [
        kept.queryKey.toStorageKey(),
      ]);
      final loaded = await fixture.store.loadSnapshot(
        binding: binding,
        queryKey: kept.queryKey,
      );
      expect(loaded, isNotNull);
      expect(loaded!.scope, binding.scope);
      expect(loaded.schemaVersion, kept.snapshot.schemaVersion);
    });

    test('declining a query keeps nothing and is not a failure', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final ignoredQuery = fixture.ignoredQueryFor(binding);
      if (ignoredQuery == null) {
        markTestSkipped('This store keeps every query it is offered.');
        return;
      }
      final kept = fixture.keptQueryFor(binding);

      final accepted = await fixture.store.keep<bool>(
        (tx) => tx.storeSnapshot(
          queryKey: ignoredQuery,
          snapshot: kept.snapshot,
        ),
      );

      expect(accepted, isFalse);
      expect(await fixture.keptStorageKeysFor(binding.scope), isEmpty);
    });

    test('a snapshot offered under a revoked binding is refused', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final kept = fixture.keptQueryFor(binding);
      await fixture.signOut();

      final refused = await fixture.store.keep<bool>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return false;
        await tx.storeSnapshot(
          queryKey: kept.queryKey,
          snapshot: kept.snapshot,
        );
        return true;
      });

      expect(refused, isFalse);
      expect(await fixture.keptStorageKeysFor(binding.scope), isEmpty);
    });

    // The case the inversion exists for. A store that reads the binding outside
    // the transaction says "current", the sign-out commits, the row commits
    // after it, and the device is left holding a snapshot of a session that
    // ended — past the purge that was supposed to take it.
    //
    // The interleaving is the store's to order and both orders are correct.
    // What this pins is that whichever it picks, the answer and the disk say
    // the same thing afterwards.
    test('a sign-out landing mid-transaction leaves no torn state', () async {
      final binding = (await fixture.store.resolveBinding())!;
      final kept = fixture.keptQueryFor(binding);
      late Future<void> signOut;

      final accepted = await fixture.store.keep<bool>((tx) async {
        if (!await tx.isBindingCurrent(binding)) return false;
        signOut = fixture.signOut();
        return tx.storeSnapshot(
          queryKey: kept.queryKey,
          snapshot: kept.snapshot,
        );
      });
      await signOut;

      final held = await fixture.keptStorageKeysFor(binding.scope);
      expect(
        held,
        accepted ? [kept.queryKey.toStorageKey()] : isEmpty,
        reason:
            'The answer and the disk disagree: keep returned $accepted while '
            'the store holds $held. The binding check has to read inside the '
            'same transaction that commits the row — a check taken before '
            'opening it is exactly this bug.',
      );
    });
  });
}

class _ConformanceFailure implements Exception {
  const _ConformanceFailure();
}
