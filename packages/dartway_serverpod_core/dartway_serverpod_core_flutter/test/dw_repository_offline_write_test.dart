import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _OfflineWriteClient client;
  late _RecordingWriteDelegate writeDelegate;

  setUpAll(() {
    client = _OfflineWriteClient();
    DwCore<_OfflineWriteClient, _OfflineWriteModel>(
      config: const DwConfig(),
      client: client,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
    );
    DwRepository.setupRepository(
      defaultModel: const _OfflineWriteModel(id: 0, title: ''),
    );
  });

  setUp(() {
    client.reset();
    writeDelegate = _RecordingWriteDelegate();
    DwRepository.writeDelegate = writeDelegate;
  });

  tearDown(() {
    DwRepository.writeDelegate = null;
  });

  test('dw.repo registers an optional write delegate', () {
    const repo = DwRepo();

    repo.writeDelegate = writeDelegate;

    expect(repo.writeDelegate, same(writeDelegate));
  });

  test(
    'online save success returns the server model, publishes once, and does not enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      writeDelegate.optInSaves = false;
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
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(receivedUpdates, hasLength(1));
      expect(client.saveApiGroups, ['learning']);
    },
  );

  test(
    'save response keeps updated models while publishing them once',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      writeDelegate.optInSaves = false;
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
    writeDelegate.optInDeletes = false;
    client.deleteHandler = (_) async =>
        const DwApiResponse<bool>(isOk: true, value: true);

    final result = await const DwRepo().deleteModel(
      const _OfflineWriteModel(id: 17, title: 'server'),
      apiGroupOverride: 'learning',
    );

    expect(result, isTrue);
    expect(writeDelegate.enqueuedMutations, isEmpty);
    expect(client.deletedModelIds, [17]);
    expect(client.deleteApiGroups, ['learning']);
  });

  test(
    'does not enqueue not-authenticated, forbidden, business, or corrupt save responses',
    () async {
      writeDelegate.optInSaves = false;
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
        expect(writeDelegate.enqueuedMutations, isEmpty);
      }
    },
  );

  test(
    'rethrows the original transport error and stack when save is not opted in',
    () async {
      final failure = TimeoutException('offline');
      final originalStackTrace = StackTrace.current;
      writeDelegate.optInSaves = false;
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

      expect(writeDelegate.enqueuedMutations, isEmpty);
    },
  );

  test(
    'rethrows the original transport error when delete has no delegate',
    () async {
      final failure = TimeoutException('offline');
      DwRepository.writeDelegate = null;
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
      writeDelegate.saveMetadata = <String, dynamic>{'source': 'draft'};
      writeDelegate.onlineSaveTransport = (_) async =>
          throw TimeoutException('offline');
      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
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
      expect(writeDelegate.enqueuedMutations, hasLength(1));
    },
  );

  test(
    'opted-in save uses the delegate online transport and reuses the exact mutation after a lost response',
    () async {
      final failure = TimeoutException('lost response');
      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(
          model: const _OfflineWriteModel(id: 801, title: 'offline'),
        ),
      );
      writeDelegate.onlineSaveTransport = (mutation) async =>
          Future<DwApiResponse<DwModelWrapper>>.error(
            failure,
            StackTrace.current,
          );
      client.saveHandler = (_) async => throw StateError('generic save called');

      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );

      expect(result.id, 801);
      expect(writeDelegate.onlineTransportMutations, hasLength(1));
      expect(writeDelegate.enqueuedMutations, hasLength(1));
      expect(
        writeDelegate.onlineTransportMutations.single.mutationId,
        writeDelegate.enqueuedMutations.single.mutationId,
      );
      expect(
        writeDelegate.onlineTransportMutations.single.idempotencyKey,
        writeDelegate.enqueuedMutations.single.idempotencyKey,
      );
      expect(client.saveCallCount, 0);
    },
  );

  test(
    'opted-in save success goes through the delegate online transport and never enqueues',
    () async {
      writeDelegate.onlineSaveTransport = (mutation) async {
        return DwApiResponse<DwModelWrapper>(
          isOk: true,
          value: DwModelWrapper.wrap(
            model: const _OfflineWriteModel(id: 802, title: 'server'),
          ),
        );
      };
      client.saveHandler = (_) async => throw StateError('generic save called');

      final result = await const DwRepo().saveModel(
        const _OfflineWriteModel(title: 'draft'),
      );

      expect(result.id, 802);
      expect(writeDelegate.onlineTransportMutations, hasLength(1));
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(client.saveCallCount, 0);
    },
  );

  test(
    'connection failure queues an opted-in delete once and returns true',
    () async {
      writeDelegate.deleteMetadata = <String, dynamic>{'reason': 'archive'};
      writeDelegate.onlineDeleteTransport = (_) async =>
          throw TimeoutException('offline');

      final result = await const DwRepo().deleteModel(
        const _OfflineWriteModel(id: 33, title: 'server'),
        apiGroupOverride: 'learning',
      );

      expect(result, isTrue);
      expect(writeDelegate.enqueuedMutations, hasLength(1));
      expect(
        writeDelegate.enqueuedMutations.single.operation,
        DwRepoMutationOperation.delete,
      );
    },
  );

  test('queued save preserves the exact mutation envelope fields', () async {
    writeDelegate.saveMetadata = <String, dynamic>{
      'reason': 'offline-sync',
      'nested': <String, dynamic>{'attempt': 1},
    };
    writeDelegate.onlineSaveTransport = (_) async =>
        throw TimeoutException('offline');
    writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
      isOk: true,
      value: DwModelWrapper.wrap(
        model: const _OfflineWriteModel(id: 601, title: 'offline'),
      ),
    );
    await const DwRepo().saveModel(
      const _OfflineWriteModel(title: 'draft'),
      apiGroupOverride: 'learning',
    );

    final mutation = writeDelegate.enqueuedMutations.single;
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
    expect(writeDelegate.enqueuedMutations, isEmpty);
  });

  test(
    'does not enqueue or publish after the scope changes before fallback handling',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final requestStarted = Completer<void>();
      writeDelegate.onlineSaveTransport = (_) async {
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
      writeDelegate.currentScope = DwRepoWriteScope('second-user');

      await expectLater(saveFuture, throwsA(isA<StateError>()));
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(receivedUpdates, isEmpty);
    },
  );

  test(
    'does not enqueue or publish after same-scope ABA during enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      final enqueueReached = Completer<void>();
      final allowEnqueue = Completer<void>();
      writeDelegate.enqueueReached = enqueueReached;
      writeDelegate.allowEnqueue = allowEnqueue;
      writeDelegate.onlineSaveTransport = (_) async =>
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
      writeDelegate.rotateBinding();
      allowEnqueue.complete();

      await expectLater(saveFuture, throwsA(isA<StateError>()));
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(receivedUpdates, isEmpty);
    },
  );

  test(
    'surfaces enqueue failure instead of reporting offline success',
    () async {
      writeDelegate.enqueueFailure = StateError('disk full');
      writeDelegate.onlineSaveTransport = (_) async =>
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
      writeDelegate.onlineSaveTransport = (_) async =>
          DwApiResponse<DwModelWrapper>(
            isOk: true,
            value: DwModelWrapper.wrap(
              model: const _OfflineWriteModel(id: 902, title: 'server'),
            ),
          );
      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
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
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(client.saveCallCount, 0);
    },
  );

  test(
    'rejects a malformed fallback save plan after transport failure and before enqueue',
    () async {
      final receivedUpdates = <List<DwModelWrapper>>[];
      writeDelegate.onlineSaveTransport = (_) async =>
          throw TimeoutException('offline');
      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
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
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(client.saveCallCount, 0);
    },
  );

  test(
    'rejects malformed optimistic save and delete result shapes before enqueue',
    () async {
      writeDelegate.onlineSaveTransport = (_) async =>
          throw TimeoutException('offline');
      writeDelegate.onlineDeleteTransport = (_) async =>
          throw TimeoutException('offline');

      writeDelegate.optimisticSaveResponse =
          const DwApiResponse<DwModelWrapper>(isOk: true, value: null);
      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );
      expect(writeDelegate.enqueuedMutations, isEmpty);

      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
        isOk: true,
        value: DwModelWrapper.wrap(model: const _OtherWriteModel(id: 55)),
      );
      await expectLater(
        const DwRepo().saveModel(const _OfflineWriteModel(title: 'draft')),
        throwsA(isA<StateError>()),
      );
      expect(writeDelegate.enqueuedMutations, isEmpty);

      writeDelegate.optimisticDeleteResponse = const DwApiResponse<bool>(
        isOk: true,
        value: false,
      );
      await expectLater(
        const DwRepo().deleteModel(const _OfflineWriteModel(id: 44)),
        throwsA(isA<StateError>()),
      );
      expect(writeDelegate.enqueuedMutations, isEmpty);

      writeDelegate.optimisticDeleteResponse = const DwApiResponse<bool>(
        isOk: true,
        value: null,
      );
      await expectLater(
        const DwRepo().deleteModel(const _OfflineWriteModel(id: 45)),
        throwsA(isA<StateError>()),
      );
      expect(writeDelegate.enqueuedMutations, isEmpty);
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
      writeDelegate.onlineSaveTransport = (_) async =>
          throw TimeoutException('offline');
      final mutationIds = <String>{};

      for (var index = 0; index < 40; index++) {
        writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
          isOk: true,
          value: DwModelWrapper.wrap(
            model: _OfflineWriteModel(id: 1000 + index, title: 'offline'),
          ),
        );
        await const DwRepo().saveModel(
          const _OfflineWriteModel(title: 'draft'),
        );
        mutationIds.add(writeDelegate.enqueuedMutations.last.mutationId);
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
      writeDelegate.onlineSaveTransport = (_) async =>
          throw TimeoutException('offline');
      writeDelegate.optimisticSaveResponse = DwApiResponse<DwModelWrapper>(
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
      expect(writeDelegate.enqueuedMutations, isEmpty);
      expect(client.saveApiGroups, isEmpty);
      expect(client.saveCallCount, 0);
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

class _RecordingWriteDelegate implements DwRepoWriteDelegate {
  DwRepoWriteScope _currentScope = DwRepoWriteScope('first-user');
  late DwRepoWriteBinding _currentBinding = DwRepoWriteBinding(
    scope: _currentScope,
  );

  final enqueuedMutations = <DwRepoMutation>[];
  bool optInSaves = true;
  bool optInDeletes = true;
  Map<String, dynamic>? saveMetadata;
  Map<String, dynamic>? deleteMetadata;
  DwApiResponse<DwModelWrapper>? optimisticSaveResponse;
  DwApiResponse<bool>? optimisticDeleteResponse;
  Future<DwApiResponse<DwModelWrapper>> Function(DwRepoMutation mutation)?
  onlineSaveTransport;
  Future<DwApiResponse<bool>> Function(DwRepoMutation mutation)?
  onlineDeleteTransport;
  final onlineTransportMutations = <DwRepoMutation>[];
  Completer<void>? enqueueReached;
  Completer<void>? allowEnqueue;
  Object? enqueueFailure;

  DwRepoWriteScope get currentScope => _currentScope;

  set currentScope(DwRepoWriteScope value) {
    _currentScope = value;
    rotateBinding();
  }

  void rotateBinding() {
    _currentBinding.invalidate();
    _currentBinding = DwRepoWriteBinding(scope: _currentScope);
  }

  @override
  Future<DwRepoWriteBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoWriteBinding binding) async =>
      binding.isActive && identical(binding, _currentBinding);

  @override
  Future<DwRepoMutationEnqueueResult> enqueueMutationIfCurrent({
    required DwRepoWriteBinding binding,
    required DwRepoMutation mutation,
  }) async {
    enqueueReached?.complete();
    if (allowEnqueue != null) await allowEnqueue!.future;
    if (enqueueFailure != null) throw enqueueFailure!;
    if (!await isBindingCurrent(binding)) {
      return DwRepoMutationEnqueueResult.stale;
    }
    enqueuedMutations.add(mutation);
    return DwRepoMutationEnqueueResult.accepted;
  }

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
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
      onlineTransport: (mutation) {
        onlineTransportMutations.add(mutation);
        return (onlineSaveTransport ??
            ((_) => Future<DwApiResponse<DwModelWrapper>>.error(
              StateError('Missing online save transport for opted-in plan.'),
            )))(mutation);
      },
    );
  }

  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  }) async {
    if (!optInDeletes) return null;
    return DwRepoWritePlan<bool>(
      optimisticResponse:
          optimisticDeleteResponse ??
          const DwApiResponse<bool>(isOk: true, value: true),
      opaqueMetadata: deleteMetadata,
      onlineTransport: (mutation) {
        onlineTransportMutations.add(mutation);
        return (onlineDeleteTransport ??
            ((_) => Future<DwApiResponse<bool>>.error(
              StateError('Missing online delete transport for opted-in plan.'),
            )))(mutation);
      },
    );
  }
}
