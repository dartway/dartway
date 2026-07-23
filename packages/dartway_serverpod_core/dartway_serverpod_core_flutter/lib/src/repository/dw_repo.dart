import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/dw_model_list_state_config.dart';
import 'domain/dw_single_model_state_config.dart';
import 'dw_repository.dart';
import 'states/dw_model_list_state.dart';
import 'states/dw_single_model_state.dart';

/// The single data-access point on the client — `dw.repo`.
///
/// Reads are Riverpod providers you consume natively: `ref.watch(...)` for a
/// reactive value, `ref.read(...future)` for a one-shot, `ref.refresh(...future)`
/// to force a fresh fetch. Writes and realtime are plain methods. Nothing here
/// asks for a `ref` or exposes a provider type name — the whole Riverpod surface
/// an app touches is `ref.watch/read/refresh(dw.repo.<x>(...))`.
///
/// The machinery (state notifiers, the type registry, update dispatch) lives in
/// the internal [DwRepository]; the app never names it. The read providers are
/// the only Riverpod-coupled part, kept in their own methods so they can later
/// move to a `dartway_riverpod` package while the imperative half stays
/// state-management-agnostic.
class DwRepo {
  const DwRepo();

  // --- Reads (providers) -----------------------------------------------------

  /// Reactive single model that must be present — `AsyncValue<T>`; resolves to a
  /// `StateError` in the error state when the model is absent.
  ///
  /// This is a throwing view over [maybeModel] (same fetch, same live updates).
  /// `ref.refresh(dw.repo.model(...).future)` only recomputes this wrapper — to
  /// force a fresh fetch, refresh [maybeModel] instead and this reacts.
  FutureProvider<T> model<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
  }) => DwRepository.throwingSingleModelProvider<T>()(
    DwSingleModelStateConfig<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    ),
  );

  /// Reactive single model that may be absent — `AsyncValue<T?>`.
  AsyncNotifierProvider<DwSingleModelState<T>, T?>
  maybeModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
  }) => DwRepository.singleModelProvider<T>()(
    DwSingleModelStateConfig<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    ),
  );

  /// Reactive model list — `AsyncValue<List<T>>`.
  AsyncNotifierProvider<DwModelListState<T>, List<T>>
  modelList<T extends SerializableModel>({
    DwBackendFilter? backendFilter,
    DwModelListStateConfig<T>? customConfig,
  }) => DwRepository.modelListStateProvider<T>()(
    customConfig ?? DwModelListStateConfig<T>(backendFilter: backendFilter),
  );

  // --- Writes ----------------------------------------------------------------

  /// Creates or updates [model]; returns the persisted model.
  Future<T> saveModel<T extends SerializableModel>(
    T model, {
    String? apiGroupOverride,
  }) => DwRepository.saveModel<T>(model, apiGroupOverride: apiGroupOverride);

  /// Deletes [model]; returns `true` when nothing remains on the server.
  Future<bool> deleteModel<T extends SerializableModel>(
    T model, {
    String? apiGroupOverride,
  }) => DwRepository.deleteModel<T>(model, apiGroupOverride: apiGroupOverride);

  // --- Realtime --------------------------------------------------------------

  /// Registers [onUpdate] for live wrapped-model updates of type [T].
  void addUpdatesListener<T extends SerializableModel>(
    void Function(List<DwModelWrapper> wrappedModelUpdates) onUpdate,
  ) => DwRepository.addUpdatesListener<T>(onUpdate);

  /// Removes a listener previously registered with [addUpdatesListener].
  void removeUpdatesListener<T extends SerializableModel>(
    void Function(List<DwModelWrapper> wrappedModelUpdates) onUpdate,
  ) => DwRepository.removeUpdatesListener<T>(onUpdate);

  // --- Default-model registration --------------------------------------------

  /// Placeholder id for the default model instance that shapes list skeletons.
  int get mockModelId => DwRepository.mockModelId;

  /// Registers [defaultModel] as the default instance for [T]. The list
  /// skeleton is drawn from your own widget built on it, so it resembles the
  /// real content; without registration the first list build throws at runtime.
  void setupRepository<T extends SerializableModel>({
    required T defaultModel,
  }) => DwRepository.setupRepository<T>(defaultModel: defaultModel);

  /// Returns the registered default instance for [T].
  T getDefault<T>() => DwRepository.getDefault<T>();

  // --- Imperative one-shot fetches -------------------------------------------
  //
  // For flows that own their own state and can't be a reactive provider — e.g.
  // anchor/offset pagination. These hide class-name resolution and response
  // unwrapping; prefer the reactive reads above whenever a provider fits.

  /// One-shot list fetch: returns a plain `List<T>`, no manual response
  /// handling. For imperative pagination that manages its own state.
  Future<List<T>> fetchList<T extends SerializableModel>({
    DwBackendFilter? filter,
    List<DwOrderBy>? orderByList,
    int? limit,
    int? offset,
    String? apiGroupOverride,
  }) => DwRepository.fetchList<T>(
    filter: filter,
    orderByList: orderByList,
    limit: limit,
    offset: offset,
    apiGroupOverride: apiGroupOverride,
  );

  /// One-shot server-side count of [T] rows matching [filter].
  Future<int> count<T extends SerializableModel>({
    DwBackendFilter? filter,
    String? apiGroupOverride,
  }) => DwRepository.count<T>(filter: filter, apiGroupOverride: apiGroupOverride);

  /// Applies a **custom** (non-CRUD) endpoint's [DwApiResponse] to the repo:
  /// returns its value (throwing on error) and, unless [updateListeners] is
  /// `false`, dispatches its `updatedModels` so open watchers stay in sync.
  /// CRUD reads/writes go through the providers and [saveModel]/[deleteModel];
  /// reach for this only when you call a bespoke endpoint yourself.
  K? processApiResponse<K>(
    DwApiResponse<K> response, {
    bool updateListeners = true,
  }) => DwRepository.processApiResponse<K>(
    response,
    updateListeners: updateListeners,
  );
}

/// Default-model getter as a static tear-off, for `DwConfig.defaultModelGetter`.
///
/// The config is built while the global `dw` is still being constructed, so it
/// cannot reach `dw.repo` yet (that would be a `LateInitializationError`); and
/// Dart has no generic lambda literal, so a plain tear-off is the only option.
/// After startup, prefer `dw.repo.getDefault`.
T dwGetDefault<T>() => DwRepository.getDefault<T>();
