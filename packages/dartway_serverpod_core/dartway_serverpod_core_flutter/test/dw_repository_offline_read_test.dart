import 'dart:async';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/repository/dw_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _OfflineReadClient client;
  late _TestLocalStore store;
  late _OfflineLocalReads localReads;

  setUpAll(() {
    client = _OfflineReadClient();
    store = _TestLocalStore();
    DwCore<_OfflineReadClient, _OfflineReadModel>(
      config: const DwConfig(),
      client: client,
      dwAlerts: DwAlerts.init(logErrors: false, logFunction: (_) {}),
      getUserId: (_) => null,
      plugins: [store],
    );
    DwRepository.setupRepository(defaultModel: _OfflineReadModel());
  });

  setUp(() {
    client.listResponse = null;
    localReads = _OfflineLocalReads();
    store.reads = localReads;
  });

  tearDown(() {
    store.reads = null;
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
    expect(localReads.snapshotLoadCount, 0);
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
        DwRepoReadOrigin.localSnapshot,
      );

      expect(
        await container.read(provider.notifier).read(forceFetch: true),
        isNull,
      );
      expect(
        container.read(provider.notifier).lastReadOrigin,
        DwRepoReadOrigin.localSnapshot,
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
      DwRepoReadOrigin.localSnapshot,
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
    client.listResponse = DwApiResponse<List<DwModelWrapper>>(
      isOk: true,
      value: const <DwModelWrapper>[],
      updatedModels: <DwModelWrapper>[update],
    );
    DwRepository.addUpdatesListener<_OfflineReadModel>(receivedUpdates.add);
    addTearDown(() {
      DwRepository.removeUpdatesListener<_OfflineReadModel>(
        receivedUpdates.add,
      );
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

  /// What the backend answers a list read with. `null` — the default — is a
  /// connection that is simply down, which is what most cases here need.
  DwApiResponse<List<DwModelWrapper>>? listResponse;

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    final response = listResponse;
    if (response != null && method == 'getAll') return response as T;
    throw TimeoutException('offline');
  }
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

class _OfflineLocalReads implements DwRepoLocalReads {
  late final _scope = DwRepoScope('offline-read-test');
  late final _binding = DwRepoBinding(scope: _scope);
  int snapshotLoadCount = 0;

  @override
  Future<DwRepoBinding?> resolveBinding() async => _binding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      identical(binding, _binding);

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
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
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body) =>
      body(_OfflineReadTx(this));
}

class _OfflineReadTx implements DwRepoLocalReadTx {
  _OfflineReadTx(this._store);

  final _OfflineLocalReads _store;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) =>
      _store.isBindingCurrent(binding);

  @override
  Future<bool> storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async => true;
}

/// The application's own plugin, standing in for a real store.
class _TestLocalStore extends DwRepoLocalStorePlugin {
  _OfflineLocalReads? reads;

  @override
  DwRepoLocalReads? get localReads => reads;

  @override
  DwRepoLocalWrites? get localWrites => null;

  @override
  Future<void> init(DwFlutter core) async {}
}
