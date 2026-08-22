// export 'descriptor/repository_descriptor.dart';
// export 'state/nit_repository_state.dart';

import 'dart:math';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../private/dw_singleton.dart';
import 'domain/dw_model_list_state_config.dart';
import 'domain/dw_repo_binding.dart';
import 'domain/dw_repo_local_reads.dart';
import 'domain/dw_repo_local_store.dart';
import 'domain/dw_repo_query_key.dart';
import 'domain/dw_repo_read_strategy.dart';
import 'domain/dw_repo_mutation.dart';
import 'domain/dw_repo_local_writes.dart';
import 'domain/dw_single_model_state_config.dart';
import '../app/socket/service/streaming_error_classifier.dart';
import 'states/dw_model_list_state.dart';
import 'states/dw_single_model_state.dart';

class DwRepository {
  static const int mockModelId = 0;

  static final _activeReadBindings = <DwRepoBinding, int>{};
  static final _activeWriteBindings = <DwRepoBinding, int>{};
  static final _mutationRandom = Random.secure();

  static DwRepoLocalReads? _lastSeenLocalReads;
  static DwRepoLocalWrites? _lastSeenLocalWrites;

  /// The local copy of reads declared on the core, or `null` when there is
  /// none. Registration alone caches nothing: a query is kept only when its
  /// config asks for [DwRepoReadStrategy.networkFirstWithSnapshot].
  ///
  /// Resolved on every use rather than held: the store belongs to the core, so
  /// a core that goes away takes its store with it. Watching it change is also
  /// how bindings issued by the previous store are revoked — they can no longer
  /// commit into a store nobody reaches any more.
  static DwRepoLocalReads? get localReads {
    final localReads = _localStore?.localReads;
    if (!identical(localReads, _lastSeenLocalReads)) {
      for (final binding in _activeReadBindings.keys) {
        binding.invalidate();
      }
      _lastSeenLocalReads = localReads;
    }
    return localReads;
  }

  /// The local copy of writes declared on the core, or `null` when there is
  /// none — in which case every `dw.repo` write stays network-only. Which
  /// writes are kept is decided inside the store, per operation and model.
  ///
  /// Resolved on every use, and a change revokes outstanding bindings, for the
  /// same reason as [localReads].
  static DwRepoLocalWrites? get localWrites {
    final localWrites = _localStore?.localWrites;
    if (!identical(localWrites, _lastSeenLocalWrites)) {
      for (final binding in _activeWriteBindings.keys) {
        binding.invalidate();
      }
      _lastSeenLocalWrites = localWrites;
    }
    return localWrites;
  }

  static DwRepoLocalStorePlugin? get _localStore =>
      dw.plugins.maybeOf<DwRepoLocalStorePlugin>();

  static final Map<Type, String> _typeNamesMapping = {};

  static final Map<String, List<Function(List<DwModelWrapper>)>>
  _updateListeners = <String, List<Function(List<DwModelWrapper>)>>{};

  static String typeName<T extends SerializableModel>() {
    final name = _typeNamesMapping[T];
    if (name == null) {
      throw Exception("Dw Repository was not initialized for type $T");
    }
    return name;
  }

  static String? maybeTypeName<T>() => _typeNamesMapping[T];

  static final defaultObjectsRepository = <String, dynamic>{};

  static setupRepository<T extends SerializableModel>({
    required T defaultModel,
  }) {
    _typeNamesMapping[T] = DwCoreServerpodClient.protocol
        .getClassNameForObject(defaultModel)!
        .split('.')
        .last;
    defaultObjectsRepository[typeName<T>()] = defaultModel;
  }

  static provideNonModelDefaultValue<T>({required T nonModelObject}) {
    assert(nonModelObject is! SerializableModel);
    return defaultObjectsRepository[T.toString()] = nonModelObject;
  }

  static T getDefault<T>() {
    final t = defaultObjectsRepository[maybeTypeName<T>() ?? T.toString()];
    if (t == null) {
      throw UnimplementedError(
        "Default Objects Repository doesn't contain a model of type $T",
      );
    }
    return t as T;
  }

  static addUpdatesListener<T extends SerializableModel>(
    Function(List<DwModelWrapper> wrappedModelUpdates) listener,
  ) {
    if (_updateListeners[DwRepository.typeName<T>()] == null) {
      _updateListeners[DwRepository.typeName<T>()] = [];
    }
    _updateListeners[DwRepository.typeName<T>()]!.add(listener);
  }

  static removeUpdatesListener<T extends SerializableModel>(
    Function(List<DwModelWrapper> wrappedModel) listener,
  ) {
    if (_updateListeners[DwRepository.typeName<T>()] != null) {
      _updateListeners[DwRepository.typeName<T>()]!.remove(listener);
    }
  }

  static updateListeningStates({
    required List<DwModelWrapper> wrappedModelUpdates,
  }) {
    final updateMap = <String, List<DwModelWrapper>>{};

    for (var wrappedModel in wrappedModelUpdates) {
      if (updateMap[wrappedModel.nitMappingClassname] == null) {
        updateMap[wrappedModel.nitMappingClassname] = [wrappedModel];
      } else {
        updateMap[wrappedModel.nitMappingClassname]!.add(wrappedModel);
      }
    }

    for (var className in updateMap.keys) {
      debugPrint(
        'Updating Listening States for $className with ${updateMap[className]!.length} objects, ids: ${updateMap[className]!.map((e) => e.modelId?.toString()).join(', ')}. Active listeners: ${_updateListeners.keys}.',

        // 'Updating Listening States for $className . Active listeners: ${_updateListeners.keys}.',
      );
      for (var listener in _updateListeners[className] ?? []) {
        listener(updateMap[className]);
      }
    }
  }

  // Providers are stored with erased types but cast back to proper generics
  // on retrieval in modelListStateProvider<T>(). This is safe because each
  // provider is created with correct generic parameters.
  static final Map<Type, Object> _modelListStateProviders = {};

  static AsyncNotifierProviderFamily<
    DwModelListState<T>,
    List<T>,
    DwModelListStateConfig<T>
  >
  modelListStateProvider<T extends SerializableModel>() {
    if (_modelListStateProviders[T] == null) {
      _modelListStateProviders[T] =
          AsyncNotifierProvider.family<
            DwModelListState<T>,
            List<T>,
            DwModelListStateConfig<T>
          >(DwModelListState<T>.new);
    }

    return _modelListStateProviders[T]
        as AsyncNotifierProviderFamily<
          DwModelListState<T>,
          List<T>,
          DwModelListStateConfig<T>
        >;
  }

  // Same pattern as _modelListStateProviders - erased for storage,
  // cast back on retrieval in singleModelProvider<T>().
  static final Map<Type, Object> _singleModelStateProviders = {};

  static AsyncNotifierProviderFamily<
    DwSingleModelState<T>,
    T?,
    DwSingleModelStateConfig<T>
  >
  singleModelProvider<T extends SerializableModel>() {
    if (_singleModelStateProviders[T] == null) {
      _singleModelStateProviders[T] =
          AsyncNotifierProvider.family<
            DwSingleModelState<T>,
            T?,
            DwSingleModelStateConfig<T>
          >(DwSingleModelState<T>.new);
    }

    return _singleModelStateProviders[T]
        as AsyncNotifierProviderFamily<
          DwSingleModelState<T>,
          T?,
          DwSingleModelStateConfig<T>
        >;
  }

  // A throwing view over [singleModelProvider]: same fetch and live updates,
  // but resolves to a non-null `T` and surfaces a `StateError` when the model
  // is absent. Derived (not its own fetch) so it always tracks the raw
  // provider; force a refetch by refreshing the raw `maybeModel`, not this.
  static final Map<Type, Object> _throwingSingleModelProviders = {};

  static FutureProviderFamily<T, DwSingleModelStateConfig<T>>
  throwingSingleModelProvider<T extends SerializableModel>() {
    if (_throwingSingleModelProviders[T] == null) {
      _throwingSingleModelProviders[T] =
          FutureProvider.family<T, DwSingleModelStateConfig<T>>((
            ref,
            cfg,
          ) async {
            final model = await ref.watch(singleModelProvider<T>()(cfg).future);
            if (model == null) {
              throw StateError('dw.repo.model<$T>: model not found ($cfg)');
            }
            return model;
          });
    }

    return _throwingSingleModelProviders[T]
        as FutureProviderFamily<T, DwSingleModelStateConfig<T>>;
  }

  static Future<Model> saveModel<Model extends SerializableModel>(
    Model model, {
    String? apiGroupOverride,
  }) => _executeWrite<DwModelWrapper, Model>(
    capturePreparedWrite: () =>
        _capturePreparedSaveWrite(model: model, apiGroup: apiGroupOverride),
    onlineRequest: () => dw.serverTransport.saveModel(
      wrappedModel: DwModelWrapper.wrap(model: model),
      apiGroup: apiGroupOverride,
    ),
    processResponse: (response) =>
        processApiResponse<DwModelWrapper>(response)!.model as Model,
  );

  static Future<DwApiResponse<DwModelWrapper>>
  saveModelResponse<Model extends SerializableModel>(
    Model model, {
    String? apiGroupOverride,
  }) => _executeWrite<DwModelWrapper, DwApiResponse<DwModelWrapper>>(
    capturePreparedWrite: () =>
        _capturePreparedSaveWrite(model: model, apiGroup: apiGroupOverride),
    onlineRequest: () => dw.serverTransport.saveModel(
      wrappedModel: DwModelWrapper.wrap(model: model),
      apiGroup: apiGroupOverride,
    ),
    processResponse: (response) {
      processApiResponse<DwModelWrapper>(response);
      return response;
    },
  );

  static Future<bool> deleteModel<T extends SerializableModel>(
    T model, {
    String? apiGroupOverride,
  }) async {
    final modelId = model.toJson()['id'];
    if (modelId == null) {
      // Never persisted, so there is nothing on the server to delete.
      return true;
    }
    return _executeWrite<bool, bool>(
      capturePreparedWrite: () => _capturePreparedDeleteWrite(
        model: model,
        modelId: modelId,
        apiGroup: apiGroupOverride,
      ),
      onlineRequest: () => dw.serverTransport.delete(
        className: DwModelWrapper.getClassNameForObject(model),
        modelId: modelId,
        apiGroup: apiGroupOverride,
      ),
      processResponse: (response) =>
          processApiResponse<bool>(response) ?? false,
    );
  }

  static Future<ReturnValue> _executeWrite<Value, ReturnValue>({
    required Future<_DwPreparedWrite<Value>?> Function() capturePreparedWrite,
    required Future<DwApiResponse<Value>> Function() onlineRequest,
    required ReturnValue Function(DwApiResponse<Value> response)
    processResponse,
  }) async {
    final preparedWrite = await capturePreparedWrite();
    try {
      DwApiResponse<Value> onlineResponse;
      try {
        // One path out, whether or not this write is kept locally. The store
        // decides what survives; how a write leaves the device is the core's
        // business and stays that way, so a later transport port has one owner
        // to move rather than two to reconcile.
        onlineResponse = await onlineRequest();
      } catch (error, stackTrace) {
        return _recoverOfflineWrite(
          preparedWrite: preparedWrite,
          originalError: error,
          originalStackTrace: stackTrace,
          processResponse: processResponse,
        );
      }

      if (preparedWrite != null &&
          !await _isCurrentWriteBinding(preparedWrite)) {
        throw _writeBindingChangedResponseError();
      }
      return processResponse(onlineResponse);
    } finally {
      if (preparedWrite != null) {
        _releaseWriteBinding(preparedWrite.binding);
      }
    }
  }

  static Future<ReturnValue> _recoverOfflineWrite<Value, ReturnValue>({
    required _DwPreparedWrite<Value>? preparedWrite,
    required Object originalError,
    required StackTrace originalStackTrace,
    required ReturnValue Function(DwApiResponse<Value> response)
    processResponse,
  }) async {
    if (preparedWrite == null || !isStreamingConnectionError(originalError)) {
      Error.throwWithStackTrace(originalError, originalStackTrace);
    }
    if (!await _isCurrentWriteBinding(preparedWrite)) {
      throw _writeBindingChangedEnqueueError();
    }
    preparedWrite.validateOptimisticResponse(preparedWrite.optimisticResponse!);

    // The check and the enqueue commit together or not at all. Between them
    // is where a sign-out would otherwise slip through and leave a mutation
    // queued under a session that no longer exists — replayed, on the next
    // sign-in, as somebody else.
    final enqueueResult = await preparedWrite.store.write<DwRepoEnqueue>((
      tx,
    ) async {
      if (!identical(localWrites, preparedWrite.store)) {
        return DwRepoEnqueue.stale;
      }
      if (!preparedWrite.binding.isActive) return DwRepoEnqueue.stale;
      if (!await tx.isBindingCurrent(preparedWrite.binding)) {
        return DwRepoEnqueue.stale;
      }
      await tx.enqueue(preparedWrite.mutation!);
      return DwRepoEnqueue.accepted;
    });
    if (enqueueResult != DwRepoEnqueue.accepted) {
      throw _writeBindingChangedEnqueueError();
    }
    if (!await _isCurrentWriteBinding(preparedWrite)) {
      throw _writeBindingChangedOptimisticResponseError();
    }
    return processResponse(preparedWrite.optimisticResponse!);
  }

  /// One-shot list fetch for imperative flows that own their own state (e.g.
  /// anchor/offset pagination that can't be expressed as a reactive provider).
  /// Handles class-name resolution and response unwrapping — the caller gets a
  /// plain `List<Model>`. Reactive reads should use the `dw.repo` providers.
  static Future<List<Model>> fetchList<Model extends SerializableModel>({
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroupOverride,
    DwRepoReadStrategy readStrategy = DwRepoReadStrategy.networkOnly,
  }) async {
    final className = typeName<Model>();
    final result = await executeRead<Model, List<DwModelWrapper>>(
      queryKey: DwRepoQueryKey<Model>.getAll(
        modelClassName: className,
        apiGroup: apiGroupOverride,
        filters: filter?.toJson(),
        ordering: orderByList?.map((orderBy) => orderBy.toJson()).toList(),
        pagination: <String, Object?>{
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
      ),
      readStrategy: readStrategy,
      onlineRequest: () => dw.serverTransport.getAll(
        className: className,
        filter: filter,
        orderByList: orderByList,
        limit: limit,
        offset: offset,
        apiGroup: apiGroupOverride,
      ),
      updateListeners: false,
    );
    final wrappers = result.value ?? const <DwModelWrapper>[];
    return wrappers.map((wrapper) => wrapper.model as Model).toList();
  }

  /// Executes a canonical read. The local store participates only when
  /// [readStrategy] opts in.
  /// Transport failures are the only failures eligible for fallback; API and
  /// response-processing failures always surface as-is.
  static Future<DwRepoReadResult<Value>> executeRead<Model, Value>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadStrategy readStrategy,
    required Future<DwApiResponse<Value>> Function() onlineRequest,
    bool updateListeners = true,
  }) async {
    final readBinding = readStrategy == DwRepoReadStrategy.networkOnly
        ? null
        : await _captureReadBinding();
    try {
      DwApiResponse<Value> onlineResponse;
      try {
        onlineResponse = await onlineRequest();
      } catch (error, stackTrace) {
        return _readOfflineSnapshot<Model, Value>(
          queryKey: queryKey,
          readBinding: readBinding,
          originalError: error,
          originalStackTrace: stackTrace,
          updateListeners: updateListeners,
        );
      }

      if (readBinding != null && !await _isCurrentReadBinding(readBinding)) {
        throw _readBindingChangedError();
      }
      final value = processApiResponse<Value>(
        onlineResponse,
        updateListeners: updateListeners,
      );
      final snapshotStored = await _storeOnlineSnapshot<Model, Value>(
        queryKey: queryKey,
        response: onlineResponse,
        readBinding: readBinding,
      );
      if (!snapshotStored) throw _readBindingChangedError();
      if (readBinding != null && !await _isCurrentReadBinding(readBinding)) {
        throw _readBindingChangedError();
      }
      return DwRepoReadResult<Value>(
        value: value,
        origin: DwRepoReadOrigin.network,
      );
    } finally {
      if (readBinding != null) _releaseReadBinding(readBinding.binding);
    }
  }

  static Future<bool> _storeOnlineSnapshot<Model, Value>({
    required DwRepoQueryKey<Model> queryKey,
    required DwApiResponse<Value> response,
    required _DwRepoReadCapture? readBinding,
  }) async {
    if (readBinding == null) return true;

    final snapshot = DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: readBinding.scope,
      responseJson: Map<String, dynamic>.from(response.toJson()),
    );

    // The check and the row commit together or not at all. Between them is
    // where a sign-out would otherwise slip through and leave a snapshot of a
    // session that has ended sitting on the device, past the purge that was
    // supposed to take it.
    final result = await readBinding.store.keep<DwRepoReadSnapshotStoreResult>((
      tx,
    ) async {
      if (!identical(localReads, readBinding.store)) {
        return DwRepoReadSnapshotStoreResult.stale;
      }
      if (!readBinding.binding.isActive) {
        return DwRepoReadSnapshotStoreResult.stale;
      }
      if (!await tx.isBindingCurrent(readBinding.binding)) {
        return DwRepoReadSnapshotStoreResult.stale;
      }
      final kept = await tx.storeSnapshot(
        queryKey: queryKey,
        snapshot: snapshot,
      );
      return kept
          ? DwRepoReadSnapshotStoreResult.stored
          : DwRepoReadSnapshotStoreResult.ignored;
    });
    return result != DwRepoReadSnapshotStoreResult.stale;
  }

  static Future<DwRepoReadResult<Value>> _readOfflineSnapshot<Model, Value>({
    required DwRepoQueryKey<Model> queryKey,
    required _DwRepoReadCapture? readBinding,
    required Object originalError,
    required StackTrace originalStackTrace,
    required bool updateListeners,
  }) async {
    if (readBinding == null || !isStreamingConnectionError(originalError)) {
      Error.throwWithStackTrace(originalError, originalStackTrace);
    }

    final snapshot = await readBinding.store.loadSnapshot(
      binding: readBinding.binding,
      queryKey: queryKey,
    );
    if (snapshot == null) {
      Error.throwWithStackTrace(originalError, originalStackTrace);
    }
    if (!await _isCurrentReadBinding(readBinding)) {
      Error.throwWithStackTrace(originalError, originalStackTrace);
    }
    if (snapshot.schemaVersion != DwRepoReadSnapshot.currentSchemaVersion) {
      throw StateError(
        'Unsupported repository snapshot schema ${snapshot.schemaVersion}.',
      );
    }
    if (snapshot.scope != readBinding.scope) {
      throw StateError('Repository snapshot scope does not match the reader.');
    }

    final response = DwApiResponse<Value>.fromJson(snapshot.responseJson);
    final value = processApiResponse<Value>(
      response,
      updateListeners: updateListeners,
    );
    if (!await _isCurrentReadBinding(readBinding)) {
      Error.throwWithStackTrace(originalError, originalStackTrace);
    }
    return DwRepoReadResult<Value>(
      value: value,
      origin: DwRepoReadOrigin.localSnapshot,
    );
  }

  static StateError _readBindingChangedError() =>
      StateError('Repository read binding changed before processing response.');

  static StateError _writeBindingChangedDispatchError() =>
      StateError('Repository write binding changed before dispatch.');

  static StateError _writeBindingChangedResponseError() => StateError(
    'Repository write binding changed before processing response.',
  );

  static StateError _writeBindingChangedEnqueueError() => StateError(
    'Repository write binding changed before enqueueing mutation.',
  );

  static StateError _writeBindingChangedOptimisticResponseError() => StateError(
    'Repository write binding changed before processing optimistic response.',
  );

  static Future<_DwRepoReadCapture?> _captureReadBinding() async {
    final store = localReads;
    if (store == null) return null;

    final binding = await store.resolveBinding();
    if (binding == null || !identical(localReads, store)) return null;
    if (!await store.isBindingCurrent(binding)) return null;
    _retainReadBinding(binding);
    return _DwRepoReadCapture(store: store, binding: binding);
  }

  static Future<_DwPreparedWrite<DwModelWrapper>?>
  _capturePreparedSaveWrite<Model extends SerializableModel>({
    required Model model,
    String? apiGroup,
  }) => _capturePreparedWrite<DwModelWrapper>(
    preparePlan: (store, binding) => store.prepareSaveMutation(
      binding: binding,
      model: model,
      apiGroup: apiGroup,
    ),
    validateOptimisticResponse: _validateOptimisticSaveResponse<Model>,
    buildMutation: (binding, metadata, mutationId, createdAtUtc) {
      final className = DwModelWrapper.getClassNameForObject(model);
      return DwRepoMutation.save(
        scope: binding.scope,
        className: className,
        entityType: className.split('.').last,
        mutationId: mutationId,
        apiGroup: apiGroup,
        entityId: _modelIdOf(model),
        protocolPayload: DwModelWrapper.wrap(model: model).toJson(),
        opaqueMetadata: metadata,
        createdAtUtc: createdAtUtc,
      );
    },
  );

  static Future<_DwPreparedWrite<bool>?>
  _capturePreparedDeleteWrite<Model extends SerializableModel>({
    required Model model,
    required int modelId,
    String? apiGroup,
  }) => _capturePreparedWrite<bool>(
    preparePlan: (store, binding) => store.prepareDeleteMutation(
      binding: binding,
      model: model,
      apiGroup: apiGroup,
    ),
    validateOptimisticResponse: _validateOptimisticDeleteResponse,
    buildMutation: (binding, metadata, mutationId, createdAtUtc) {
      final className = DwModelWrapper.getClassNameForObject(model);
      return DwRepoMutation.delete(
        scope: binding.scope,
        className: className,
        entityType: className.split('.').last,
        entityId: modelId,
        mutationId: mutationId,
        apiGroup: apiGroup,
        protocolPayload: <String, dynamic>{'modelId': modelId},
        opaqueMetadata: metadata,
        createdAtUtc: createdAtUtc,
      );
    },
  );

  static Future<_DwPreparedWrite<Value>?> _capturePreparedWrite<Value>({
    required Future<DwRepoWritePlan<Value>?> Function(
      DwRepoLocalWrites store,
      DwRepoBinding binding,
    )
    preparePlan,
    required void Function(DwApiResponse<Value> response)
    validateOptimisticResponse,
    required DwRepoMutation Function(
      DwRepoBinding binding,
      Map<String, dynamic>? opaqueMetadata,
      String mutationId,
      DateTime createdAtUtc,
    )
    buildMutation,
  }) async {
    final store = localWrites;
    if (store == null) return null;

    final binding = await store.resolveBinding();
    if (binding == null || !identical(localWrites, store)) return null;
    if (!await store.isBindingCurrent(binding)) return null;

    _retainWriteBinding(binding);
    try {
      final plan = await preparePlan(store, binding);
      if (plan == null) {
        _releaseWriteBinding(binding);
        return null;
      }
      if (!await _isCurrentWriteBindingParts(store, binding)) {
        throw _writeBindingChangedDispatchError();
      }
      final mutationId = _newMutationId();
      final createdAtUtc = DateTime.now().toUtc();
      return _DwPreparedWrite<Value>(
        store: store,
        binding: binding,
        mutation: buildMutation(
          binding,
          plan.opaqueMetadata,
          mutationId,
          createdAtUtc,
        ),
        optimisticResponse: plan.optimisticResponse,
        validateOptimisticResponse: validateOptimisticResponse,
      );
    } catch (_) {
      _releaseWriteBinding(binding);
      rethrow;
    }
  }

  static Future<bool> _isCurrentReadBinding(
    _DwRepoReadCapture readBinding,
  ) async {
    final store = localReads;
    if (!identical(store, readBinding.store)) return false;
    if (!readBinding.binding.isActive) return false;
    return store!.isBindingCurrent(readBinding.binding);
  }

  static Future<bool> _isCurrentWriteBinding<Value>(
    _DwPreparedWrite<Value> preparedWrite,
  ) async {
    return _isCurrentWriteBindingParts(
      preparedWrite.store,
      preparedWrite.binding,
    );
  }

  static Future<bool> _isCurrentWriteBindingParts(
    DwRepoLocalWrites store,
    DwRepoBinding binding,
  ) async {
    final currentStore = localWrites;
    if (!identical(currentStore, store)) return false;
    if (!binding.isActive) return false;
    return currentStore!.isBindingCurrent(binding);
  }

  static void _retainReadBinding(DwRepoBinding binding) {
    _activeReadBindings.update(
      binding,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  static void _releaseReadBinding(DwRepoBinding binding) {
    final count = _activeReadBindings[binding];
    if (count == null || count == 1) {
      _activeReadBindings.remove(binding);
      return;
    }
    _activeReadBindings[binding] = count - 1;
  }

  static void _retainWriteBinding(DwRepoBinding binding) {
    _activeWriteBindings.update(
      binding,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  static void _releaseWriteBinding(DwRepoBinding binding) {
    final count = _activeWriteBindings[binding];
    if (count == null || count == 1) {
      _activeWriteBindings.remove(binding);
      return;
    }
    _activeWriteBindings[binding] = count - 1;
  }

  static int? _modelIdOf(SerializableModel model) {
    final modelId = model.toJson()['id'];
    return modelId is int ? modelId : null;
  }

  static void _validateOptimisticResponse<Value>(
    DwApiResponse<Value> response,
  ) {
    if (response.error != null || !response.isOk) {
      throw StateError(
        'Repository optimistic response must be a successful result.',
      );
    }
    for (final wrapper in response.updatedModels ?? const <DwModelWrapper>[]) {
      if (wrapper.className == 'unknown' || wrapper.modelId == null) {
        throw StateError(
          'Repository optimistic updatedModels must have stable identities.',
        );
      }
    }
  }

  static void _validateOptimisticSaveResponse<Model extends SerializableModel>(
    DwApiResponse<DwModelWrapper> response,
  ) {
    _validateOptimisticResponse<DwModelWrapper>(response);
    final wrapper = response.value;
    if (wrapper == null) {
      throw StateError(
        'Repository optimistic save response must include a model wrapper.',
      );
    }
    if (wrapper.model is! Model) {
      throw StateError(
        'Repository optimistic save response must match the saved model type.',
      );
    }
  }

  static void _validateOptimisticDeleteResponse(DwApiResponse<bool> response) {
    _validateOptimisticResponse<bool>(response);
    if (response.value != true) {
      throw StateError(
        'Repository optimistic delete response must resolve to true.',
      );
    }
  }

  static String _newMutationId() {
    final buffer = StringBuffer();
    for (var index = 0; index < 16; index++) {
      buffer.write(
        _mutationRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
      );
    }
    return buffer.toString();
  }

  /// One-shot server-side count of [Model] rows matching [filter].
  static Future<int> count<Model extends SerializableModel>({
    DwBackendFilter? filter,
    String? apiGroupOverride,
  }) async {
    final response = await dw.serverTransport.getCount(
      className: typeName<Model>(),
      filter: filter,
      apiGroup: apiGroupOverride,
    );
    return processApiResponse<int>(response, updateListeners: false) ?? 0;
  }

  static K? processApiResponse<K>(
    DwApiResponse<K> response, {
    bool updateListeners = true,
  }) {
    // debugPrint(response.toJson().toString());
    // if (response.error != null) {
    //   dw.notify.error(response.error!);
    // } else if (response.warning != null) {
    //   dw.notify.warning(response.warning!);
    // }

    if (updateListeners && (response.updatedModels ?? []).isNotEmpty) {
      DwRepository.updateListeningStates(
        wrappedModelUpdates: response.updatedModels ?? [],
      );
    }

    // A rule saying no and a server breaking both arrive in `error`, and only
    // the server knows which it built. `isRefusal` is that knowledge: answered
    // with a [DwRefusal], the message reaches the user in the words the rule
    // was written in, and the app's error policy can sort it out by type
    // instead of by matching the text.
    if (response.error != null) {
      throw response.isRefusal
          ? DwRefusal(response.error!)
          : Exception(response.error);
    }
    if (!response.isOk) {
      throw StateError('Repository response reported an unsuccessful read.');
    }

    return response.value;
  }
}

class _DwRepoReadCapture {
  const _DwRepoReadCapture({required this.store, required this.binding});

  final DwRepoLocalReads store;
  final DwRepoBinding binding;

  DwRepoScope get scope => binding.scope;
}

class _DwPreparedWrite<Value> {
  const _DwPreparedWrite({
    required this.store,
    required this.binding,
    required this.mutation,
    required this.optimisticResponse,
    required this.validateOptimisticResponse,
  });

  final DwRepoLocalWrites store;
  final DwRepoBinding binding;
  final DwRepoMutation? mutation;
  final DwApiResponse<Value>? optimisticResponse;
  final void Function(DwApiResponse<Value> response) validateOptimisticResponse;
}
