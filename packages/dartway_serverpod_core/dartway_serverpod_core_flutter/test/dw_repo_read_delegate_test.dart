import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_client/src/protocol/protocol.dart'
    as generated;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _RecordingReadDelegate readDelegate;
  final queryKey = DwRepoQueryKey<Object>.getAll(
    modelClassName: 'Lesson',
    apiGroup: 'learning',
  );
  final authQueryKey = DwRepoQueryKey<DwAuthKey>.getAll(
    modelClassName: 'DwAuthKey',
    apiGroup: 'auth',
  );

  setUpAll(() {
    DwCoreServerpodClient.protocol = generated.Protocol();
    DwRepository.setupRepository(
      defaultModel: DwAuthKey(id: 0, userId: 0, hash: '', key: ''),
    );
  });

  setUp(() {
    readDelegate = _RecordingReadDelegate();
    DwRepository.readDelegate = readDelegate;
  });

  tearDown(() {
    DwRepository.readDelegate = null;
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
      expect(readDelegate.storedSnapshots, hasLength(1));
      expect(
        readDelegate.storedSnapshots.single.scope,
        readDelegate.currentScope,
      );
      expect(
        readDelegate.storedSnapshots.single.schemaVersion,
        DwRepoReadSnapshot.currentSchemaVersion,
      );
      expect(readDelegate.storedSnapshots.single.responseJson, {
        'isOk': true,
        'value': 42,
      });
    },
  );

  test('allows a delegate to ignore an unselected online query', () async {
    readDelegate.storeResult = DwRepoReadSnapshotStoreResult.ignored;

    final result = await DwRepository.executeRead<Object, int>(
      queryKey: queryKey,
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      onlineRequest: () async =>
          const DwApiResponse<int>(isOk: true, value: 42),
    );

    expect(result.value, 42);
    expect(result.origin, DwRepoReadOrigin.network);
    expect(readDelegate.storedSnapshots, isEmpty);
  });

  test(
    'uses an in-scope snapshot when the online request has a connection error',
    () async {
      readDelegate.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: readDelegate.currentScope,
        responseJson: const <String, dynamic>{'isOk': true, 'value': null},
      );

      final result = await DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw TimeoutException('offline'),
      );

      expect(result.value, isNull);
      expect(result.origin, DwRepoReadOrigin.offlineSnapshot);
      expect(readDelegate.loadedQueryKeys, [queryKey]);
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
      final invalidStoreDelegate = _InvalidScopeReadDelegate('');
      DwRepository.readDelegate = invalidStoreDelegate;

      await expectLater(
        DwRepository.executeRead<Object, int>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () async =>
              const DwApiResponse<int>(isOk: true, value: 42),
        ),
        throwsA(isA<StateError>()),
      );
      expect(invalidStoreDelegate.storeCalls, 0);
      expect(invalidStoreDelegate.loadCalls, 0);

      final invalidLoadDelegate = _InvalidScopeReadDelegate('   ');
      DwRepository.readDelegate = invalidLoadDelegate;

      await expectLater(
        DwRepository.executeRead<Object, Object?>(
          queryKey: queryKey,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
          onlineRequest: () async => throw TimeoutException('offline'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(invalidLoadDelegate.storeCalls, 0);
      expect(invalidLoadDelegate.loadCalls, 0);
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

      expect(readDelegate.loadedQueryKeys, [queryKey]);
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

    expect(readDelegate.loadedQueryKeys, isEmpty);
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

    expect(readDelegate.storedSnapshots, isEmpty);
  });

  test('rejects a snapshot returned for another scope', () async {
    readDelegate.availableSnapshot = DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: DwRepoReadScope('second-user'),
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
    readDelegate.availableSnapshot = DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion + 1,
      scope: readDelegate.currentScope,
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

  test('dw.repo registers an optional read delegate', () {
    const repo = DwRepo();

    repo.readDelegate = readDelegate;

    expect(repo.readDelegate, same(readDelegate));
  });

  test('rejects an online response after the delegate changes', () async {
    final onlineResponse = Completer<DwApiResponse<int>>();
    final requestStarted = Completer<void>();
    final originalDelegate = readDelegate;
    final replacementDelegate = _RecordingReadDelegate();

    final read = DwRepository.executeRead<Object, int>(
      queryKey: queryKey,
      readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      onlineRequest: () {
        requestStarted.complete();
        return onlineResponse.future;
      },
    );
    await requestStarted.future;
    DwRepository.readDelegate = replacementDelegate;
    onlineResponse.complete(const DwApiResponse<int>(isOk: true, value: 42));

    await expectLater(read, throwsA(isA<StateError>()));
    expect(originalDelegate.storedSnapshots, isEmpty);
    expect(replacementDelegate.storedSnapshots, isEmpty);
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
    readDelegate.currentScope = DwRepoReadScope('second-user');
    onlineResponse.complete(const DwApiResponse<int>(isOk: true, value: 42));

    await expectLater(read, throwsA(isA<StateError>()));
    expect(readDelegate.storedSnapshots, isEmpty);
  });

  test(
    'rethrows the original connection error after a scope changes mid-fallback',
    () async {
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      readDelegate.snapshotRequested = snapshotRequested;
      readDelegate.snapshotResponse = snapshotResponse;

      final read = DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      readDelegate.currentScope = DwRepoReadScope('second-user');
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoReadScope('first-user'),
          responseJson: <String, dynamic>{'isOk': true, 'value': null},
        ),
      );

      await expectLater(read, throwsA(same(failure)));
    },
  );

  test(
    'rethrows the original connection error after a delegate changes mid-fallback',
    () async {
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      readDelegate.snapshotRequested = snapshotRequested;
      readDelegate.snapshotResponse = snapshotResponse;

      final read = DwRepository.executeRead<Object, Object?>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async => throw failure,
      );
      await snapshotRequested.future;
      DwRepository.readDelegate = _RecordingReadDelegate();
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoReadScope('first-user'),
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
      readDelegate.currentScope = DwRepoReadScope('second-user');
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
    'rejects a stale online delegate response before notifying repository listeners',
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
      DwRepository.readDelegate = _RecordingReadDelegate();
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
      readDelegate.snapshotRequested = snapshotRequested;
      readDelegate.snapshotResponse = snapshotResponse;
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
      readDelegate.currentScope = DwRepoReadScope('second-user');
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoReadScope('first-user'),
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
    'rejects a stale offline delegate snapshot before notifying repository listeners',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final failure = TimeoutException('offline');
      final snapshotRequested = Completer<void>();
      final snapshotResponse = Completer<DwRepoReadSnapshot?>();
      final update = DwModelWrapper.wrap(
        model: DwAuthKey(id: 104, userId: 204, hash: 'hash', key: 'key'),
      );
      readDelegate.snapshotRequested = snapshotRequested;
      readDelegate.snapshotResponse = snapshotResponse;
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
      DwRepository.readDelegate = _RecordingReadDelegate();
      snapshotResponse.complete(
        DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoReadScope('first-user'),
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
      readDelegate.storeReached = storeReached;
      readDelegate.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      readDelegate.currentScope = DwRepoReadScope('second-user');
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      expect(readDelegate.storedSnapshots, isEmpty);
    },
  );

  test(
    'does not commit an online snapshot after its delegate changes in store',
    () async {
      final storeReached = Completer<void>();
      final allowStoreCommit = Completer<void>();
      final originalDelegate = readDelegate;
      final replacementDelegate = _RecordingReadDelegate();
      readDelegate.storeReached = storeReached;
      readDelegate.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      DwRepository.readDelegate = replacementDelegate;
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      expect(originalDelegate.storedSnapshots, isEmpty);
      expect(replacementDelegate.storedSnapshots, isEmpty);
    },
  );

  test(
    'does not commit an online snapshot after same-scope logout-login ABA in store',
    () async {
      final storeReached = Completer<void>();
      final allowStoreCommit = Completer<void>();
      readDelegate.storeReached = storeReached;
      readDelegate.allowStoreCommit = allowStoreCommit;

      final read = DwRepository.executeRead<Object, int>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        onlineRequest: () async =>
            const DwApiResponse<int>(isOk: true, value: 42),
      );
      await storeReached.future;
      readDelegate.invalidateBinding();
      allowStoreCommit.complete();

      await expectLater(read, throwsA(isA<StateError>()));
      expect(readDelegate.storedSnapshots, isEmpty);
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

    expect(readDelegate.loadedQueryKeys, isEmpty);
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

    expect(readDelegate.loadedQueryKeys, isEmpty);
  });

  test(
    'round trips a nonempty single snapshot through the generated protocol',
    () async {
      final wrapper = DwModelWrapper.wrap(
        model: DwAuthKey(id: 7, userId: 42, hash: 'hash', key: 'key'),
      );
      readDelegate.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: readDelegate.currentScope,
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
      readDelegate.availableSnapshot = DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: readDelegate.currentScope,
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

class _RecordingReadDelegate implements DwRepoReadDelegate {
  DwRepoReadScope _currentScope = DwRepoReadScope('first-user');
  late DwRepoReadBinding _currentBinding = DwRepoReadBinding(
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
  DwRepoReadScope get currentScope => _currentScope;

  set currentScope(DwRepoReadScope value) {
    _currentScope = value;
    invalidateBinding();
  }

  void invalidateBinding() {
    _currentBinding.invalidate();
    _currentBinding = DwRepoReadBinding(scope: _currentScope);
  }

  @override
  Future<DwRepoReadBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoReadBinding binding) async =>
      binding.isActive && identical(binding, _currentBinding);

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async {
    loadedQueryKeys.add(queryKey as DwRepoQueryKey<Object>);
    snapshotRequested?.complete();
    if (snapshotResponse != null) return snapshotResponse!.future;
    return availableSnapshot;
  }

  @override
  Future<DwRepoReadSnapshotStoreResult> storeSnapshotIfCurrent<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    storeReached?.complete();
    if (allowStoreCommit != null) await allowStoreCommit!.future;
    if (!await isBindingCurrent(binding)) {
      return DwRepoReadSnapshotStoreResult.stale;
    }
    if (storeResult == DwRepoReadSnapshotStoreResult.stored) {
      storedSnapshots.add(snapshot);
    }
    return storeResult;
  }
}

class _InvalidScopeReadDelegate implements DwRepoReadDelegate {
  _InvalidScopeReadDelegate(this.storageKey);

  final String storageKey;
  var storeCalls = 0;
  var loadCalls = 0;

  @override
  Future<DwRepoReadBinding?> resolveBinding() async =>
      DwRepoReadBinding(scope: DwRepoReadScope(storageKey));

  @override
  Future<bool> isBindingCurrent(DwRepoReadBinding binding) async => true;

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async {
    loadCalls++;
    return null;
  }

  @override
  Future<DwRepoReadSnapshotStoreResult> storeSnapshotIfCurrent<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    storeCalls++;
    return DwRepoReadSnapshotStoreResult.stored;
  }
}
