import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _OfflineWriteClient client;
  late _TestLocalStore store;
  late _RecordingLocalWrites localWrites;

  // The store is declared with the core and stays for as long as it — there is
  // no setter to swap it with, which is the point of declaring it here. Each
  // test gets a fresh recorder inside the same plugin instead.
  setUpAll(() {
    client = _OfflineWriteClient();
    store = _TestLocalStore();
    DwCore<_OfflineWriteClient, _OfflineWriteModel>(
      config: const DwConfig(),
      client: client,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
      plugins: [store],
    );
    DwRepository.setupRepository(
      defaultModel: const _OfflineWriteModel(id: 0, title: ''),
    );
  });

  setUp(() {
    client.reset();
    localWrites = _RecordingLocalWrites();
    store.writes = localWrites;
  });

  tearDown(() {
    store.writes = null;
  });

  test('dw.repo reads the local writes declared on the core', () {
    expect(const DwRepo().localWrites, same(localWrites));
  });

  test(
    'online save success returns the server model, publishes once, and does not enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      localWrites.optInSaves = false;
      final savedModel = const _OfflineWriteModel(id: 91, title: 'server');
      final savedWrapper = DwModelWrapper.wrap(model: savedModel);
      client.saveHandler = (_) async => DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: savedWrapper,
        updatedModels: <DwModelWrapper>[savedWrapper],
      );
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
        apiGroupOverride: 'learning',
      );

      expect(result.id, 91);
      expect(result.title, 'server');
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(receivedUpdates, hasLength(1));
      expect(client.saveApiGroups, ['learning']);
    },
  );

  test(
    'save response keeps updated models while publishing them once',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      localWrites.optInSaves = false;
      final savedWrapper = DwModelWrapper.wrap(
        model: const _OfflineWriteModel(id: 92, title: 'server response'),
      );
      final relatedWrapper = DwModelWrapper.wrap(
        model: const _OfflineWriteModel(id: 93, title: 'related response'),
      );
      client.saveHandler = (_) async => DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: savedWrapper,
        updatedModels: <DwModelWrapper>[relatedWrapper],
      );
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      final response = await const DwRepo().saveModelResponse(
        const _OfflineWriteModel(title: 'draft'),
        apiGroupOverride: 'learning',
      );

      expect(response.value!.model.toJson()['id'], 92);
      expect(response.updatedModels, [relatedWrapper]);
      expect(receivedUpdates, [
        <DwModelWrapper>[relatedWrapper],
      ]);
      expect(client.saveApiGroups, ['learning']);
    },
  );

  test('online delete success returns true and does not enqueue', () async {
    localWrites.optInDeletes = false;
    client.deleteHandler = (_) async =>
        const DwApiResponse<bool>(isOk: true, value: true);

    final result = await const DwRepo().deleteModel(
      const _OfflineWriteModel(id: 17, title: 'server'),
      apiGroupOverride: 'learning',
    );

    expect(result, isTrue);
    expect(localWrites.enqueuedMutations, isEmpty);
    expect(client.deletedModelIds, [17]);
    expect(client.deleteApiGroups, ['learning']);
  });

  test(
    'does not enqueue not-authenticated, forbidden, business, or corrupt save responses',
    () async {
      localWrites.optInSaves = false;
      final failingResponses = <Future<DwApiResponse<DwModelWrapper>>>[
        Future<DwApiResponse<DwModelWrapper>>.value(
          const DwApiResponse<DwModelWrapper>.notAuthenticated(),
        ),
        Future<DwApiResponse<DwModelWrapper>>.value(
          const DwApiResponse<DwModelWrapper>.forbidden(),
        ),
        Future<DwApiResponse<DwModelWrapper>>.value(
          const DwApiResponse<DwModelWrapper>(
            isOk: false,
            value: null,
            error: 'Validation failed',
          ),
        ),
        Future<DwApiResponse<DwModelWrapper>>.value(
          const DwApiResponse<DwModelWrapper>(isOk: true, value: null),
        ),
      ];

      for (final failingResponse in failingResponses) {
        client.saveHandler = (_) => failingResponse;

        await expectLater(
          const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
          throwsA(anything),
        );
        expect(localWrites.enqueuedMutations, isEmpty);
      }
    },
  );

  test(
    'rethrows the original transport error and stack when save is not opted in',
    () async {
      final failure = TimeoutException('offline');
      final originalStackTrace = StackTrace.current;
      localWrites.optInSaves = false;
      client.saveHandler = (_) => Future<DwApiResponse<DwModelWrapper>>.error(
        failure,
        originalStackTrace,
      );

      try {
        await const DwRepo().saveModel(
          const _OfflineWriteModel(title: 'draft'),
        );
        fail('Expected the original transport failure.');
      } catch (error, stackTrace) {
        expect(error, same(failure));
        expect(stackTrace.toString(), originalStackTrace.toString());
      }

      expect(localWrites.enqueuedMutations, isEmpty);
    },
  );

  test(
    'rethrows the original transport error when delete has no local store',
    () async {
      final failure = TimeoutException('offline');
      store.writes = null;
      client.deleteHandler = (_) async => throw failure;

      await expectLater(
        const DwRepo().deleteModel(const _OfflineWriteModel(id: 31)),
        throwsA(same(failure)),
      );
    },
  );

  test(
    'connection failure queues an opted-in save once and returns the optimistic model',
    () async {
      localWrites.saveMetadata = <String, dynamic>{'source': 'draft'};
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 501, title: 'offline'),
        ),
      );
      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
        apiGroupOverride: 'learning',
      );

      expect(result.id, 501);
      expect(result.title, 'offline');
      expect(localWrites.enqueuedMutations, hasLength(1));
    },
  );

  test(
    'an opted-in save leaves by the same one path as any other, and is queued once',
    () async {
      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 801, title: 'offline'),
        ),
      );
      client.saveHandler = (_) async => throw TimeoutException('lost response');

      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );

      expect(result.id, 801);
      expect(
        client.saveCallCount,
        1,
        reason:
            'Opting a write into local storage must not reroute how it is '
            'sent. The store keeps writes; the core sends them.',
      );
      expect(localWrites.enqueuedMutations, hasLength(1));
    },
  );

  test(
    'an opted-in save that succeeds online is never queued',
    () async {
      client.saveHandler = (_) async => DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 802, title: 'server'),
        ),
      );

      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );

      expect(result.id, 802);
      expect(result.title, 'server');
      expect(client.saveCallCount, 1);
      expect(localWrites.enqueuedMutations, isEmpty);
    },
  );

  test(
    'connection failure queues an opted-in delete once and returns true',
    () async {
      localWrites.deleteMetadata = <String, dynamic>{'reason': 'archive'};
      client.deleteHandler = (_) async =>
          throw TimeoutException('offline');

      final result = await const DwRepo().deleteModel(
        const _OfflineWriteModel(id: 33, title: 'server'),
        apiGroupOverride: 'learning',
      );

      expect(result, isTrue);
      expect(localWrites.enqueuedMutations, hasLength(1));
      expect(
        localWrites.enqueuedMutations.single.operation,
        DwRepoMutationOperation.delete,
      );
    },
  );

  test('queued save preserves the exact mutation envelope fields', () async {
    localWrites.saveMetadata = <String, dynamic>{
      'reason': 'offline-sync',
      'nested': <String, dynamic>{'attempt': 1},
    };
    client.saveHandler = (_) async =>
        throw TimeoutException('offline');
    localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
      isOk: true,
      value: DwModelWrapper.wrap(
        model: const _OfflineWriteModel(id: 601, title: 'offline'),
      ),
    );
    await const DwRepo().saveModel(
      const _OfflineWriteModel(title: 'draft'),
      apiGroupOverride: 'learning',
    );

    final mutation = localWrites.enqueuedMutations.single;
    expect(mutation.schemaVersion, DwRepoMutation.currentSchemaVersion);
    expect(mutation.scope.storageKey, 'first-user');
    expect(mutation.className, 'OfflineWriteModel');
    expect(mutation.entityType, 'OfflineWriteModel');
    expect(mutation.apiGroup, 'learning');
    expect(mutation.operation, DwRepoMutationOperation.save);
    expect(mutation.entityId, isNull);
    expect(mutation.mutationId, isNotEmpty);
    expect(mutation.idempotencyKey, mutation.mutationId);
    expect(mutation.opaqueMetadata, <String, dynamic>{
      'reason': 'offline-sync',
      'nested': <String, dynamic>{'attempt': 1},
    });
    expect(mutation.createdAtUtc.isUtc, isTrue);
    expect(mutation.protocolPayload, <String, dynamic>{
      'className': 'OfflineWriteModel',
      'data': <String, dynamic>{'id': null, 'title': 'draft'},
      'isDeleted': false,
    });
  });

  test('null-id delete stays a no-op without network or enqueue', () async {
    final result = await const DwRepo().deleteModel(
      const _OfflineWriteModel(title: 'draft'),
    );

    expect(result, isTrue);
    expect(client.deletedModelIds, isEmpty);
    expect(localWrites.enqueuedMutations, isEmpty);
  });

  test(
    'does not enqueue or publish after the scope changes before fallback handling',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final requestStarted = Completer<void>();
      client.saveHandler = (_) async {
        requestStarted.complete();
        throw TimeoutException('offline');
      };
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      final saveFuture = const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );
      await requestStarted.future;
      localWrites.currentScope = DwRepoScope('second-user');

      await expectLater(saveFuture, throwsA(isA<StateError>()));
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(receivedUpdates, isEmpty);
    },
  );

  test(
    'does not enqueue or publish after same-scope ABA during enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final enqueueReached = Completer<void>();
      final allowEnqueue = Completer<void>();
      localWrites.enqueueReached = enqueueReached;
      localWrites.allowEnqueue = allowEnqueue;
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      final saveFuture = const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );
      await enqueueReached.future;
      localWrites.rotateBinding();
      allowEnqueue.complete();

      await expectLater(saveFuture, throwsA(isA<StateError>()));
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(receivedUpdates, isEmpty);
    },
  );

  test(
    'surfaces enqueue failure instead of reporting offline success',
    () async {
      localWrites.enqueueFailure = StateError('disk full');
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');

      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(
          isA<StateError>().having(
            (failure) => failure.message,
            'message',
            'disk full',
          ),
        ),
      );
    },
  );

  test(
    'healthy online success ignores a malformed fallback save plan',
    () async {
      client.saveHandler = (_) async =>
          DwApiResponse<DwModelWrapper>(
            isOk: true,
            value: DwModelWrapper.wrap(
              model: const _OfflineWriteModel(id: 902, title: 'server'),
            ),
          );
      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 901, title: 'offline'),
        ),
        updatedModels: <DwModelWrapper>[
          DwModelWrapper.wrap(
            model: const _OfflineWriteModel(title: 'unstable'),
          ),
        ],
      );
      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );

      expect(result.id, 902);
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(client.saveCallCount, 1);
    },
  );

  test(
    'rejects a malformed fallback save plan after transport failure and before enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 701, title: 'offline'),
        ),
        updatedModels: <DwModelWrapper>[
          DwModelWrapper.wrap(
            model: const _OfflineWriteModel(title: 'unstable'),
          ),
        ],
      );
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );

      expect(receivedUpdates, isEmpty);
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(client.saveCallCount, 1);
    },
  );

  test(
    'rejects malformed optimistic save and delete result shapes before enqueue',
    () async {
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      client.deleteHandler = (_) async =>
          throw TimeoutException('offline');

      localWrites.optimisticSaveResponse =
          const DwApiResponse<DwModelWrapper>(isOk: true, value: null);
      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );
      expect(localWrites.enqueuedMutations, isEmpty);

      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(model: const _OtherWriteModel(id: 55)),
      );
      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );
      expect(localWrites.enqueuedMutations, isEmpty);

      localWrites.optimisticDeleteResponse = const DwApiResponse<bool>(
        isOk: true,
        value: false,
      );
      await expectLater(
        const DwRepo().deleteModel(const _OfflineWriteModel(id: 44)),
        throwsA(isA<StateError>()),
      );
      expect(localWrites.enqueuedMutations, isEmpty);

      localWrites.optimisticDeleteResponse = const DwApiResponse<bool>(
        isOk: true,
        value: null,
      );
      await expectLater(
        const DwRepo().deleteModel(const _OfflineWriteModel(id: 45)),
        throwsA(isA<StateError>()),
      );
      expect(localWrites.enqueuedMutations, isEmpty);
    },
  );

  test('mutation round trips as deeply immutable validated json', () {
    final mutation = DwRepoMutation.save(
      scope: DwRepoScope('user-1'),
      className: 'OfflineWriteModel',
      entityType: 'OfflineWriteModel',
      mutationId: '0123456789abcdef0123456789abcdef',
      apiGroup: 'learning',
      protocolPayload: <String, dynamic>{
        'className': 'OfflineWriteModel',
        'data': <String, dynamic>{'id': 7, 'title': 'draft', 'ratio': 1.5},
        'items': <Object?>[
          1,
          <String, dynamic>{'ok': true},
        ],
      },
      opaqueMetadata: <String, dynamic>{
        'nested': <String, dynamic>{'attempt': 1},
      },
      createdAtUtc: DateTime.utc(2026, 8, 11, 12),
    );

    final roundTrip = DwRepoMutation.fromJson(mutation.toJson());

    expect(roundTrip.toJson(), mutation.toJson());
    expect(
      () =>
          (mutation.protocolPayload['data'] as Map<String, dynamic>)['id'] = 99,
      throwsUnsupportedError,
    );
    expect(
      () =>
          (mutation.opaqueMetadata!['nested'] as Map<String, dynamic>)['x'] = 1,
      throwsUnsupportedError,
    );
  });

  test('mutation validation rejects corrupt values and unsupported json', () {
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('   '),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: '',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: '  ',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: ' OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: '',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.delete(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: ' OfflineWriteModel',
        entityId: 1,
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'modelId': 1},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.delete(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel ',
        entityType: '  ',
        entityId: 1,
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'modelId': 1},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.delete(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        entityId: 0,
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'modelId': 0},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: ' 0123456789abcdef0123456789abcdef',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        apiGroup: 'learning ',
        protocolPayload: const <String, dynamic>{'className': 'x'},
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        mutationId: '0123456789abcdef0123456789abcdef',
        protocolPayload: <String, dynamic>{'value': double.infinity},
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 2,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef ',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '   ',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef ',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '   ',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': ' OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': '   ',
        'entityType': 'OfflineWriteModel',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel ',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': '   ',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => DwRepoMutation.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'mutationId': '0123456789abcdef0123456789abcdef',
        'idempotencyKey': '0123456789abcdef0123456789abcdef',
        'scopeStorageKey': 'user-1',
        'className': 'OfflineWriteModel',
        'entityType': 'OfflineWriteModel',
        'apiGroup': ' learning ',
        'operation': 'save',
        'entityId': null,
        'protocolPayload': <String, dynamic>{'className': 'OfflineWriteModel'},
        'createdAtUtc': DateTime.utc(2026, 8, 11).toIso8601String(),
      }),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'mutations preserve negative ids reserved for optimistic local rows',
    () {
      final saveMutation = DwRepoMutation.save(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        entityId: -42,
        mutationId: 'local-save',
        protocolPayload: const <String, dynamic>{'id': -42},
      );
      final deleteMutation = DwRepoMutation.delete(
        scope: DwRepoScope('user-1'),
        className: 'OfflineWriteModel',
        entityType: 'OfflineWriteModel',
        entityId: -42,
        mutationId: 'local-delete',
        protocolPayload: const <String, dynamic>{'modelId': -42},
      );

      expect(saveMutation.entityId, -42);
      expect(deleteMutation.entityId, -42);
    },
  );

  test(
    'generated mutation ids are 128-bit hex tokens and stay unique across many writes',
    () async {
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      final mutationIds = <String>{};

      for (var index = 0; index < 40; index++) {
        localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
          isOk: true,
          value: DwModelWrapper.wrap(
            model: _OfflineWriteModel(id: 1000 + index, title: 'offline'),
          ),
        );
        await const DwRepo().saveModel(
          const _OfflineWriteModel(title: 'draft'),
        );
        mutationIds.add(localWrites.enqueuedMutations.last.mutationId);
      }

      expect(mutationIds, hasLength(40));
      for (final mutationId in mutationIds) {
        expect(mutationId, hasLength(32));
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(mutationId), isTrue);
      }
    },
  );

  test(
    'rejects listener-unsafe optimistic updatedModels instead of publishing them',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      client.saveHandler = (_) async =>
          throw TimeoutException('offline');
      localWrites.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 701, title: 'offline'),
        ),
        updatedModels: <DwModelWrapper>[
          DwModelWrapper.wrap(
            model: const _OfflineWriteModel(title: 'unstable'),
          ),
        ],
      );
      DwRepository.addUpdatesListener<_OfflineWriteModel>(receivedUpdates.add);
      addTearDown(
        () => DwRepository.removeUpdatesListener<_OfflineWriteModel>(
          receivedUpdates.add,
        ),
      );

      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );

      expect(receivedUpdates, isEmpty);
      expect(localWrites.enqueuedMutations, isEmpty);
      expect(client.saveApiGroups, [null]);
      expect(client.saveCallCount, 1);
    },
  );
}

class _OfflineWriteModel implements SerializableModel {
  const _OfflineWriteModel({this.id, this.title = 'draft'});

  final int? id;
  final String title;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'title': title};
}

class _OtherWriteModel implements SerializableModel {
  const _OtherWriteModel({required this.id});

  final int id;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}

class _OfflineWriteProtocol extends SerializationManager {
  @override
  String? getClassNameForObject(Object? value) => switch (value) {
    _OfflineWriteModel() => 'OfflineWriteModel',
    _OtherWriteModel() => 'OtherWriteModel',
    _ => super.getClassNameForObject(value),
  };
}

class _OfflineWriteClient extends ServerpodClientShared {
  _OfflineWriteClient()
    : super(
        'http://localhost:8080',
        _OfflineWriteProtocol(),
        streamingConnectionTimeout: null,
        connectionTimeout: null,
      ) {
    _caller = Caller(this);
  }

  late final Caller _caller;
  Future<Object?> Function(Map<String, dynamic> args)? saveHandler;
  Future<Object?> Function(Map<String, dynamic> args)? deleteHandler;
  final saveApiGroups = <String?>[];
  final deleteApiGroups = <String?>[];
  final deletedModelIds = <int>[];
  var saveCallCount = 0;
  var deleteCallCount = 0;

  void reset() {
    saveHandler = null;
    deleteHandler = null;
    saveApiGroups.clear();
    deleteApiGroups.clear();
    deletedModelIds.clear();
    saveCallCount = 0;
    deleteCallCount = 0;
  }

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
  }) async {
    if (endpoint != 'dartway_serverpod_core.dwCrud') {
      throw StateError('Unexpected endpoint request: $endpoint.$method');
    }
    if (method == 'saveModel') {
      saveCallCount++;
      saveApiGroups.add(args['apiGroup'] as String?);
      return await (saveHandler?.call(args) ??
              Future<Object?>.error(
                StateError('Missing save test handler for $method'),
              ))
          as T;
    }
    if (method == 'delete') {
      deleteCallCount++;
      deleteApiGroups.add(args['apiGroup'] as String?);
      deletedModelIds.add(args['modelId'] as int);
      return await (deleteHandler?.call(args) ??
              Future<Object?>.error(
                StateError('Missing delete test handler for $method'),
              ))
          as T;
    }
    throw StateError('Unexpected endpoint request: $endpoint.$method');
  }
}

class _RecordingLocalWrites implements DwRepoLocalWrites {
  DwRepoScope _currentScope = DwRepoScope('first-user');
  late DwRepoBinding _currentBinding = DwRepoBinding(
    scope: _currentScope,
  );

  final enqueuedMutations = <DwRepoMutation>[];
  bool optInSaves = true;
  bool optInDeletes = true;
  Map<String, dynamic>? saveMetadata;
  Map<String, dynamic>? deleteMetadata;
  DwApiResponse<DwModelWrapper>? optimisticSaveResponse;
  DwApiResponse<bool>? optimisticDeleteResponse;
  Completer<void>? enqueueReached;
  Completer<void>? allowEnqueue;
  Object? enqueueFailure;

  DwRepoScope get currentScope => _currentScope;

  set currentScope(DwRepoScope value) {
    _currentScope = value;
    rotateBinding();
  }

  void rotateBinding() {
    _currentBinding.invalidate();
    _currentBinding = DwRepoBinding(scope: _currentScope);
  }

  @override
  Future<DwRepoBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      binding.isActive && identical(binding, _currentBinding);

  @override
  Future<R> write<R>(Future<R> Function(DwRepoLocalWriteTx tx) body) async {
    enqueueReached?.complete();
    if (allowEnqueue != null) await allowEnqueue!.future;
    if (enqueueFailure != null) throw enqueueFailure!;
    final transaction = _RecordingWriteTx(this);
    final result = await body(transaction);
    // Committed only once the body returned: a body that threw leaves the
    // staged rows behind, exactly as a rolled-back transaction would.
    enqueuedMutations.addAll(transaction.staged);
    return result;
  }

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async {
    if (!optInSaves) return null;
    return DwRepoWritePlan<DwModelWrapper>(
      optimisticResponse:
          optimisticSaveResponse ??
          DwApiResponse<DwModelWrapper>(
            isOk: true,
            value: DwModelWrapper.wrap(
              model: _OfflineWriteModel(id: 401, title: 'offline') as Model,
            ),
          ),
      opaqueMetadata: saveMetadata,
    );
  }

  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async {
    if (!optInDeletes) return null;
    return DwRepoWritePlan<bool>(
      optimisticResponse:
          optimisticDeleteResponse ??
          const DwApiResponse<bool>(isOk: true, value: true),
      opaqueMetadata: deleteMetadata,
    );
  }
}

class _RecordingWriteTx implements DwRepoLocalWriteTx {
  _RecordingWriteTx(this._store);

  final _RecordingLocalWrites _store;
  final staged = <DwRepoMutation>[];

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) =>
      _store.isBindingCurrent(binding);

  @override
  Future<void> enqueue(DwRepoMutation mutation) async => staged.add(mutation);
}

/// The application's own plugin, standing in for a real store.
class _TestLocalStore extends DwRepoLocalStorePlugin {
  _RecordingLocalWrites? writes;

  @override
  DwRepoLocalReads? get localReads => null;

  @override
  DwRepoLocalWrites? get localWrites => writes;

  @override
  Future<void> init(DwFlutter core) async {}
}
