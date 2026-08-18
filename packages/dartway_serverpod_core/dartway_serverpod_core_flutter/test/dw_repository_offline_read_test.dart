import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/domain/dw_repository_read_executor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    final client = _OfflineReadClient();
    DwCore<_OfflineReadClient, _OfflineReadModel>(
      config: const DwConfig(),
      client: client,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
    );
    DwRepository.setupRepository(defaultModel: _OfflineReadModel());
  });

  late _OfflineReadDelegate readDelegate;

  setUp(() {
    readDelegate = _OfflineReadDelegate();
    DwRepository.readDelegate = readDelegate;
  });

  tearDown(() {
    DwRepository.readDelegate = null;
  });

  test('default list config remains network-only', () async {
    final queryKey = DwRepoQueryKey<_OfflineReadModel>.getAll(
      modelClassName: 'OfflineReadModel',
    );

    await expectLater(
      DwRepository.executeRead<_OfflineReadModel, List<DwModelWrapper>>(
        queryKey: queryKey,
        readStrategy: DwRepoReadStrategy.networkOnly,
        onlineRequest: () async => throw TimeoutException('offline'),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(readDelegate.snapshotLoadCount, 0);
  });

  test(
    'single initial and forced reads retain their offline snapshot origin',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = DwRepository.singleModelProvider<_OfflineReadModel>()(
        DwSingleModelStateConfig<_OfflineReadModel>(
          id: 42,
          readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
        ),
      );

      expect(await container.read(provider.future), isNull);
      expect(
        container.read(provider.notifier).lastReadOrigin,
        DwRepoReadOrigin.offlineSnapshot,
      );

      expect(
        await container.read(provider.notifier).read(forceFetch: true),
        isNull,
      );
      expect(
        container.read(provider.notifier).lastReadOrigin,
        DwRepoReadOrigin.offlineSnapshot,
      );
    },
  );

  test('list reads retain the offline snapshot origin', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = DwRepository.modelListStateProvider<_OfflineReadModel>()(
      DwModelListStateConfig<_OfflineReadModel>(
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      ),
    );

    expect(await container.read(provider.future), isEmpty);
    expect(
      container.read(provider.notifier).lastReadOrigin,
      DwRepoReadOrigin.offlineSnapshot,
    );
  });

  test('imperative list reads use the same offline snapshot path', () async {
    expect(
      await const DwRepo().fetchList<_OfflineReadModel>(
        readStrategy: DwRepoReadStrategy.networkFirstWithSnapshot,
      ),
      isEmpty,
    );
  });

  test('imperative list reads do not publish updated models', () async {
    final receivedUpdates = <List<DwModelWrapper>>[];
    final update = DwModelWrapper.wrap(model: _OfflineReadModel());
    DwRepository.readExecutor = _UpdatedModelsReadExecutor(
      DwApiResponse<List<DwModelWrapper>>(
        isOk: true,
        value: const <DwModelWrapper>[],
        updatedModels: <DwModelWrapper>[update],
      ),
    );
    DwRepository.addUpdatesListener<_OfflineReadModel>(receivedUpdates.add);
    addTearDown(() {
      DwRepository.removeUpdatesListener<_OfflineReadModel>(
        receivedUpdates.add,
      );
      DwRepository.readExecutor = const DwOnlineRepositoryReadExecutor();
    });

    expect(await const DwRepo().fetchList<_OfflineReadModel>(), isEmpty);
    expect(receivedUpdates, isEmpty);
  });
}

class _OfflineReadModel implements SerializableModel {
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{};
}

class _OfflineReadClient extends ServerpodClientShared {
  _OfflineReadClient()
    : super(
        'http://localhost:8080',
        _OfflineReadProtocol(),
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
  }) async => throw TimeoutException('offline');
}

class _OfflineReadProtocol extends SerializationManager {
  @override
  T deserialize<T>(dynamic value, [Type? type]) {
    if (T == List<DwModelWrapper>) {
      return <DwModelWrapper>[] as T;
    }
    return super.deserialize(value, type);
  }

  @override
  String? getClassNameForObject(Object? value) => switch (value) {
    _OfflineReadModel() => 'OfflineReadModel',
    _ => super.getClassNameForObject(value),
  };
}

class _OfflineReadDelegate implements DwRepoReadDelegate {
  late final _scope = DwRepoReadScope('offline-read-test');
  late final _binding = DwRepoReadBinding(scope: _scope);
  int snapshotLoadCount = 0;

  @override
  Future<DwRepoReadBinding?> resolveBinding() async => _binding;

  @override
  Future<bool> isBindingCurrent(DwRepoReadBinding binding) async =>
      identical(binding, _binding);

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) async {
    snapshotLoadCount += 1;
    return DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: _scope,
      responseJson: queryKey.operation == 'getAll'
          ? const <String, dynamic>{'isOk': true, 'value': <dynamic>[]}
          : const <String, dynamic>{'isOk': true, 'value': null},
    );
  }

  @override
  Future<DwRepoReadSnapshotStoreResult> storeSnapshotIfCurrent<Model>({
    required DwRepoReadBinding binding,
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async => DwRepoReadSnapshotStoreResult.stored;
}

class _UpdatedModelsReadExecutor implements DwRepositoryReadExecutor {
  const _UpdatedModelsReadExecutor(this.response);

  final DwApiResponse<List<DwModelWrapper>> response;

  @override
  Future<Response> execute<Model, Response>({
    required DwRepoQueryKey<Model> queryKey,
    required Future<Response> Function() onlineRequest,
  }) async => response as Response;
}
