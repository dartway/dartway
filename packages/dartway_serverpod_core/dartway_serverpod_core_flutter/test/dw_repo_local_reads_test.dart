import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_client/src/protocol/protocol.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingLocalReads localReads;
  final queryKey = DwRepoQueryKey<Object>.getAll(
    modelClassName: 'Lesson',
    apiGroup: 'learning',
  );
  final authQueryKey = DwRepoQueryKey<DwAuthKey>.getAll(
    modelClassName: 'DwAuthKey',
    apiGroup: 'auth',
  );

  late _TestLocalStore store;

  setUpAll(() {
    store = _TestLocalStore();
    DwCore<_ReadsClient, DwAuthKey>(
      config: const DwConfig(),
      client: _ReadsClient(),
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
      plugins: [store],
    );
    DwRepository.setupRepository(
      defaultModel: DwAuthKey(id: 0, userId: 0, hash: '', key: ''),
    );
  });

  setUp(() {
    localReads = _RecordingLocalReads();
    store.reads = localReads;
  });

  tearDown(() {
    store.reads = null;
  });

  test(
    'persists a successfully processed online response as a versioned snapshot',
    () async {
      final result = await DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );

      expect(result.value, 42);
      expect(result.origin, DwRepoReadOrigin.network);
      expect(localReads.storedSnapshots, hasLength(1));
      expect(
        localReads.storedSnapshots.single.scope,
        localReads.currentScope,
      );
      expect(
        localReads.storedSnapshots.single.schemaVersion,
        DwRepoReadSnapshot.currentSchemaVersion,
      );
      expect(localReads.storedSnapshots.single.responseJson, {
        'isOk': true,
        'value': 42,
      });
    },
  );

  test('allows a store to ignore an unselected online query', () async {
    localReads.storeResult = DwRepoReadSnapshotStoreResult.ignored;

    final result = await DwRepository.executeRead<Object, int>(
      queryKey: queryKey,
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      onlineRequest: () async =>
          const DwApiResponse<int>(isOk: true, value: 42),
    );

    expect(result.value, 42);
    expect(result.origin, DwRepoReadOrigin.network);
    expect(localReads.storedSnapshots, isEmpty);
  });

  test(
    'uses an in-scope snapshot when the online request has a connection error',
    () async {
      localReads.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: localReads.currentScope,
        responseJson: const <String, dynamic>{'isOk': true, 'value': null},
      );

      final result = await DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw TimeoutException('offline'),
      );

      expect(result.value, isNull);
      expect(result.origin, DwRepoReadOrigin.localSnapshot);
      expect(localReads.loadedQueryKeys, [queryKey]);
    },
  );

  test('repo scope rejects empty and whitespace-bearing values', () {
    expect(() => DwRepoScope(''), throwsA(isA<StateError>()));
    expect(() => DwRepoScope('   '), throwsA(isA<StateError>()));
    expect(() => DwRepoScope(' user-1 '), throwsA(isA<StateError>()));
  });

  test(
    'invalid read scopes never reach snapshot store or load boundaries',
    () async {
      final invalidStoreReads = _InvalidScopeReadDelegate('');
      store.reads = invalidStoreReads;

      await expectLater(
        DwRepository.executeRead<Object, int>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () async =>
              const DwApiResponse<int>(isOk: true, value: 42),
        ),
        throwsA(isA<StateError>()),
      );
      expect(invalidStoreReads.storeCalls, 0);
      expect(invalidStoreReads.loadCalls, 0);

      final invalidLoadReads = _InvalidScopeReadDelegate('   ');
      store.reads = invalidLoadReads;

      await expectLater(
        DwRepository.executeRead<Object, Object?>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () async => throw TimeoutException('offline'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(invalidLoadReads.storeCalls, 0);
      expect(invalidLoadReads.loadCalls, 0);
    },
  );

  test(
    'rethrows the original connection error when no snapshot exists',
    () async {
      final failure = TimeoutException('offline');

      await expectLater(
        DwRepository.executeRead<Object, Object?>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () async => throw failure,
        ),
        throwsA(same(failure)),
      );

      expect(localReads.loadedQueryKeys, [queryKey]);
    },
  );

  test('does not read a snapshot after a non-connection error', () async {
    final failure = StateError('server rejected the request');

    await expectLater(
      DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      ),
      throwsA(same(failure)),
    );

    expect(localReads.loadedQueryKeys, isEmpty);
  });

  test('does not persist an unsuccessful API response', () async {
    await expectLater(
      DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: false, value: 42),
      ),
      throwsA(isA<StateError>()),
    );

    expect(localReads.storedSnapshots, isEmpty);
  });

  test('rejects a snapshot returned for another scope', () async {
    localReads.availableSnapshot = DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: DwRepoScope('second-user'),
      responseJson: <String, dynamic>{'isOk': true, 'value': null},
    );

    await expectLater(
      DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw TimeoutException('offline'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects an incompatible snapshot schema', () async {
    localReads.availableSnapshot = DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion + 1,
      scope: localReads.currentScope,
      responseJson: const <String, dynamic>{'isOk': true, 'value': null},
    );

    await expectLater(
      DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw TimeoutException('offline'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('dw.repo reads the local reads declared on the core', () {
    const repo = DwRepo();

    expect(repo.localReads, same(localReads));
  });

  test('rejects an online response after the store changes', () async {
    final onlineResponse = Completer<DwApiResponse<int>>();
    final requestStarted = Completer<void>();
    final originalDelegate = localReads;
    final replacementReads = _RecordingLocalReads();

    final read = DwRepository.executeRead<Object, int>(
      queryKey: queryKey,
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      onlineRequest: () {
        requestStarted.complete();
        return onlineResponse.future;
      },
    );
    await requestStarted.future;
    store.reads = replacementReads;
    onlineResponse.complete(const DwApiResponse<int>(isOk: true, value: 42));

    await expectLater(read, throwsA(isA<StateError>()));
    expect(originalDelegate.storedSnapshots, isEmpty);
    expect(replacementReads.storedSnapshots, isEmpty);
  });

  test('rejects an online response after the scope changes', () async {
    final onlineResponse = Completer<DwApiResponse<int>>();
    final requestStarted = Completer<void>();

    final read = DwRepository.executeRead<Object, int>(
      queryKey: queryKey,
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      onlineRequest: () {
        requestStarted.complete();
        return onlineResponse.future;
      },
    );
    await requestStarted.future;
    localReads.currentScope = DwRepoScope('second-user');
    onlineResponse.complete(const DwApiResponse<int>(isOk: true, value: 42));

    await expectLater(read, throwsA(isA<StateError>()));
    expect(localReads.storedSnapshots, isEmpty);
  });

  test(
    'rethrows the original connection error after a scope changes mid-fallback',
    () async {
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      localReads.snapshotRequested = snapshotRequested;
      localReads.snapshotResponse = snapshotResponse;

      final read = DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      localReads.currentScope = DwRepoScope('second-user');
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoScope('first-user'),
          responseJson: <String, dynamic>{'isOk': true, 'value': null},
        ),
      );

      await expectLater(read, throwsA(same(failure)));
    },
  );

  test(
    'rethrows the original connection error after a store changes mid-fallback',
    () async {
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      localReads.snapshotRequested = snapshotRequested;
      localReads.snapshotResponse = snapshotResponse;

      final read = DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      store.reads = _RecordingLocalReads();
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoScope('first-user'),
          responseJson: <String, dynamic>{'isOk': true, 'value': null},
        ),
      );

      await expectLater(read, throwsA(same(failure)));
    },
  );

  test(
    'rejects a stale online scope response before notifying repository listeners',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final onlineResponse = Completer<DwApiResponse<List<DwModelWrapper>>>();
      final requestStarted = Completer<void>();
      final update = DwModelWrapper.wrap(
        model: DwAuthKey(id: 101, userId: 201, hash: 'hash', key: 'key'),
      );
      DwRepository.addUpdatesListener<DwAuthKey>(receivedUpdates.add);
      addTearDown(
        () =>
            DwRepository.removeUpdatesListener<DwAuthKey>(receivedUpdates.add),
      );

      final read = DwRepository.executeRead<DwAuthKey, List<DwModelWrapper>>(
        queryKey: authQueryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () {
          requestStarted.complete();
          return onlineResponse.future;
        },
      );
      await requestStarted.future;
      localReads.currentScope = DwRepoScope('second-user');
      onlineResponse.complete(
        DwApiResponse<List<DwModelWrapper>>(
          isOk: true,
          value: const <DwModelWrapper>[],
          updatedModels: <DwModelWrapper>[update],
        ),
      );

      Object? error;
      try {
        await read;
      } catch (caught) {
        error = caught;
      }

      expect(receivedUpdates, isEmpty);
      expect(
        error,
        isA<StateError>().having(
          (failure) => failure.message,
          'message',
          'Repository read binding changed before processing response.',
        ),
      );
    },
  );

  test(
    'rejects a stale online response before notifying repository listeners',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final onlineResponse = Completer<DwApiResponse<List<DwModelWrapper>>>();
      final requestStarted = Completer<void>();
      final update = DwModelWrapper.wrap(
        model: DwAuthKey(id: 102, userId: 202, hash: 'hash', key: 'key'),
      );
      DwRepository.addUpdatesListener<DwAuthKey>(receivedUpdates.add);
      addTearDown(
        () =>
            DwRepository.removeUpdatesListener<DwAuthKey>(receivedUpdates.add),
      );

      final read = DwRepository.executeRead<DwAuthKey, List<DwModelWrapper>>(
        queryKey: authQueryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () {
          requestStarted.complete();
          return onlineResponse.future;
        },
      );
      await requestStarted.future;
      store.reads = _RecordingLocalReads();
      onlineResponse.complete(
        DwApiResponse<List<DwModelWrapper>>(
          isOk: true,
          value: const <DwModelWrapper>[],
          updatedModels: <DwModelWrapper>[update],
        ),
      );

      Object? error;
      try {
        await read;
      } catch (caught) {
        error = caught;
      }

      expect(receivedUpdates, isEmpty);
      expect(
        error,
        isA<StateError>().having(
          (failure) => failure.message,
          'message',
          'Repository read binding changed before processing response.',
        ),
      );
    },
  );

  test(
    'rejects a stale offline scope snapshot before notifying repository listeners',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      final update = DwModelWrapper.wrap(
        model: DwAuthKey(id: 103, userId: 203, hash: 'hash', key: 'key'),
      );
      localReads.snapshotRequested = snapshotRequested;
      localReads.snapshotResponse = snapshotResponse;
      DwRepository.addUpdatesListener<DwAuthKey>(receivedUpdates.add);
      addTearDown(
        () =>
            DwRepository.removeUpdatesListener<DwAuthKey>(receivedUpdates.add),
      );

      final read = DwRepository.executeRead<DwAuthKey, List<DwModelWrapper>>(
        queryKey: authQueryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      localReads.currentScope = DwRepoScope('second-user');
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoScope('first-user'),
          responseJson: DwApiResponse<List<DwModelWrapper>>(
            isOk: true,
            value: const <DwModelWrapper>[],
            updatedModels: <DwModelWrapper>[update],
          ).toJson(),
        ),
      );

      Object? error;
      try {
        await read;
      } catch (caught) {
        error = caught;
      }

      expect(receivedUpdates, isEmpty);
      expect(error, same(failure));
    },
  );

  test(
    'rejects a stale local snapshot before notifying repository listeners',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      final update = DwModelWrapper.wrap(
        model: DwAuthKey(id: 104, userId: 204, hash: 'hash', key: 'key'),
      );
      localReads.snapshotRequested = snapshotRequested;
      localReads.snapshotResponse = snapshotResponse;
      DwRepository.addUpdatesListener<DwAuthKey>(receivedUpdates.add);
      addTearDown(
        () =>
            DwRepository.removeUpdatesListener<DwAuthKey>(receivedUpdates.add),
      );

      final read = DwRepository.executeRead<DwAuthKey, List<DwModelWrapper>>(
        queryKey: authQueryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      store.reads = _RecordingLocalReads();
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoScope('first-user'),
          responseJson: DwApiResponse<List<DwModelWrapper>>(
            isOk: true,
            value: const <DwModelWrapper>[],
            updatedModels: <DwModelWrapper>[update],
          ).toJson(),
        ),
      );

      Object? error;
      try {
        await read;
      } catch (caught) {
        error = caught;
      }

      expect(receivedUpdates, isEmpty);
      expect(error, same(failure));
    },
  );

  test(
    'does not commit an online snapshot after its scope changes in store',
    () async {
      final storeReached = Completer<void>();
      final allowStoreCommit = Completer<void>();
      localReads.storeReached = storeReached;
      localReads.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      localReads.currentScope = DwRepoScope('second-user');
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      expect(localReads.storedSnapshots, isEmpty);
    },
  );

  test(
    'does not commit an online snapshot after its store changes',
    () async {
      final storeReached = Completer<void>();
      final allowStoreCommit = Completer<void>();
      final originalDelegate = localReads;
      final replacementReads = _RecordingLocalReads();
      localReads.storeReached = storeReached;
      localReads.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      store.reads = replacementReads;
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      // The core refuses the response and never hands the value to the caller.
      // Whether the outgoing store physically wrote the row is the store's own
      // commit-time condition to hold, not something the core can undo from
      // here — the store's own transaction exists for exactly that, and the
      // conformance suite is where an implementation is held to it.
      expect(replacementReads.storedSnapshots, isEmpty);
      expect(originalDelegate.loadedQueryKeys, isEmpty);
    },
  );

  test(
    'does not commit an online snapshot after same-scope logout-login ABA in store',
    () async {
      final storeReached = Completer<void>();
      final allowStoreCommit = Completer<void>();
      localReads.storeReached = storeReached;
      localReads.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      localReads.invalidateBinding();
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      expect(localReads.storedSnapshots, isEmpty);
    },
  );

  test(
    'preserves the original stack trace when a snapshot is missing',
    () async {
      final failure = TimeoutException('offline');
      final originalStackTrace = StackTrace.current;

      try {
        await DwRepository.executeRead<Object, Object?>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () =>
              Future<DwApiResponse<Object?>>.error(failure, originalStackTrace),
        );
        fail('Expected the original transport failure.');
      } catch (error, stackTrace) {
        expect(error, same(failure));
        expect(stackTrace.toString(), originalStackTrace.toString());
      }
    },
  );

  test('does not fallback for a not-authenticated API response', () async {
    await expectLater(
      DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<Object?>.notAuthenticated(),
      ),
      throwsA(isA<Exception>()),
    );

    expect(localReads.loadedQueryKeys, isEmpty);
  });

  test('does not fallback for a forbidden API response', () async {
    await expectLater(
      DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => const DwApiResponse<Object?>.forbidden(),
      ),
      throwsA(isA<Exception>()),
    );

    expect(localReads.loadedQueryKeys, isEmpty);
  });

  test(
    'round trips a nonempty single snapshot through the generated protocol',
    () async {
      final wrapper = DwModelWrapper.wrap(
        model: DwAuthKey(id: 7, userId: 42, hash: 'hash', key: 'key'),
      );
      localReads.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: localReads.currentScope,
        responseJson: DwApiResponse<DwModelWrapper>(
          isOk: true,
          value: wrapper,
        ).toJson(),
      );

      final result = await DwRepository.executeRead<Object, DwModelWrapper>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw TimeoutException('offline'),
      );

      expect(result.value!.model, isA<DwAuthKey>());
      expect((result.value!.model as DwAuthKey).userId, 42);
    },
  );

  test(
    'round trips a nonempty list snapshot through the generated protocol',
    () async {
      final wrapper = DwModelWrapper.wrap(
        model: DwAuthKey(id: 8, userId: 43, hash: 'hash', key: 'key'),
      );
      localReads.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: localReads.currentScope,
        responseJson: DwApiResponse<List<DwModelWrapper>>(
          isOk: true,
          value: <DwModelWrapper>[wrapper],
        ).toJson(),
      );

      final result =
          await DwRepository.executeRead<Object, List<DwModelWrapper>>(
            queryKey: queryKey,
            readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
            onlineRequest: () async => throw TimeoutException('offline'),
          );

      expect(result.value, hasLength(1));
      expect((result.value!.single.model as DwAuthKey).userId, 43);
    },
  );
}

class _RecordingLocalReads implements DwRepoLocalReads {
  DwRepoScope _currentScope = DwRepoScope('first-user');
  late DwRepoBinding _currentBinding = DwRepoBinding(
    scope: _currentScope,
  );
  final storedSnapshots = <DwRepoReadSnapshot>[];
  final loadedQueryKeys = <DwRepoQueryKey<Object>>[];
  DwRepoReadSnapshot? availableSnapshot;
  Completer<void>? snapshotRequested;
  Completer<DwRepoReadSnapshot?>? snapshotResponse;
  Completer<void>? storeReached;
  Completer<void>? allowStoreCommit;
  DwRepoReadSnapshotStoreResult storeResult =
      DwRepoReadSnapshotStoreResult.stored;
  DwRepoScope get currentScope => _currentScope;

  set currentScope(DwRepoScope value) {
    _currentScope = value;
    invalidateBinding();
  }

  void invalidateBinding() {
    _currentBinding.invalidate();
    _currentBinding = DwRepoBinding(scope: _currentScope);
  }

  @override
  Future<DwRepoBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      binding.isActive && identical(binding, _currentBinding);

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async {
    loadedQueryKeys.add(queryKey as DwRepoQueryKey<Object>);
    snapshotRequested?.complete();
    if (snapshotResponse != null) return snapshotResponse!.future;
    return availableSnapshot;
  }

  @override
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body) async {
    storeReached?.complete();
    if (allowStoreCommit != null) await allowStoreCommit!.future;
    final transaction = _RecordingReadTx(this);
    final result = await body(transaction);
    // Committed only once the body returned, the way a rolled-back transaction
    // leaves nothing behind.
    storedSnapshots.addAll(transaction.staged);
    return result;
  }
}

class _RecordingReadTx implements DwRepoLocalReadTx {
  _RecordingReadTx(this._store);

  final _RecordingLocalReads _store;
  final staged = <DwRepoReadSnapshot>[];

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) =>
      _store.isBindingCurrent(binding);

  @override
  Future<bool> storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    if (_store.storeResult != DwRepoReadSnapshotStoreResult.stored) return false;
    staged.add(snapshot);
    return true;
  }
}

class _InvalidScopeReadDelegate implements DwRepoLocalReads {
  _InvalidScopeReadDelegate(this.storageKey);

  final String storageKey;
  var storeCalls = 0;
  var loadCalls = 0;

  @override
  Future<DwRepoBinding?> resolveBinding() async =>
      DwRepoBinding(scope: DwRepoScope(storageKey));

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async => true;

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async {
    loadCalls++;
    return null;
  }

  @override
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body) =>
      body(_InvalidScopeReadTx(this));
}

class _InvalidScopeReadTx implements DwRepoLocalReadTx {
  _InvalidScopeReadTx(this._store);

  final _InvalidScopeReadDelegate _store;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async => true;

  @override
  Future<bool> storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    _store.storeCalls++;
    return true;
  }
}

/// The application's own plugin, standing in for a real store.
class _TestLocalStore extends DwRepoLocalStorePlugin {
  DwRepoLocalReads? reads;

  @override
  DwRepoLocalReads? get localReads => reads;

  @override
  DwRepoLocalWrites? get localWrites => null;

  @override
  Future<void> init(DwFlutter core) async {}
}

/// The reads here supply their own online request, so the client only has to
/// exist for the core to be constructible.
class _ReadsClient extends ServerpodClientShared {
  _ReadsClient()
    : super(
        'http://localhost:8080',
        generated.Protocol(),
        streamingConnectionTimeout: null,
        connectionTimeout: null,
      ) {
    _caller = Caller(this);
  }

  late final Caller _caller;

  @override
  Map<String, ModuleEndpointCaller> get moduleLookup =>
      <String, ModuleEndpointCaller>{'dartway_serverpod_core': _caller};

  @override
  Map<String, EndpointRef> get endpointRefLookup => <String, EndpointRef>{};

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async => throw StateError('No test here reaches the network.');
}
