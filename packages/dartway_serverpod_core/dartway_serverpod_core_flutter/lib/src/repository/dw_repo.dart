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
}
