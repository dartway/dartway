import 'package:collection/collection.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/src/private/dw_singleton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dw_repository.dart';

class DwSingleModelState<Model extends SerializableModel>
    extends AsyncNotifier<Model?> {
  DwSingleModelStateConfig<Model> config;
  DwRepoReadOrigin? _lastReadOrigin;

  DwSingleModelState(this.config);

  /// The source of the latest backend read, for stale-data diagnostics.
  DwRepoReadOrigin? get lastReadOrigin => _lastReadOrigin;

  @override
  Future<Model?> build() async {
    ref.onDispose(
      () => DwRepository.removeUpdatesListener<Model>(_updatesListener),
    );

    final globalTimestamp = ref.watch(dwGlobalRefreshStateProvider);

    debugPrint(
      "Getting single ${DwRepository.typeName<Model>()} "
      "with filter ${config.backendFilter} "
      "and timestamp $globalTimestamp",
    );

    final readResult = config.initialModel != null
        ? null
        : await DwRepository.executeRead<Model, DwModelWrapper>(
            queryKey: config.queryKey,
            readStrategy: config.readStrategy,
            onlineRequest: () => dw.serverTransport.getOne(
              className: DwRepository.typeName<Model>(),
              filter: config.backendFilter,
              apiGroup: config.apiGroupOverride,
            ),
          );

    _lastReadOrigin = readResult?.origin;
    final fetchedWrappedModel = readResult != null ? readResult.value : null;

    DwRepository.addUpdatesListener<Model>(_updatesListener);

    return config.initialModel != null
        ? config.initialModel as Model
        : (fetchedWrappedModel == null
              ? null
              : fetchedWrappedModel.model as Model);
  }

  /// Reads the model either from state or from backend.
  /// - Awaits the current `future` if already loading.
  /// - If `forceFetch = false` → return cached/loaded value.
  /// - If `forceFetch = true` → always fetch fresh from backend.
  Future<Model?> read({bool forceFetch = false}) async {
    if (!forceFetch) {
      // this will wait for loading if needed
      final current = await future;
      return current;
    }

    // always fetch from backend when forced or no cached value
    final readResult = await DwRepository.executeRead<Model, DwModelWrapper>(
      queryKey: config.queryKey,
      readStrategy: config.readStrategy,
      onlineRequest: () => dw.serverTransport.getOne(
        className: DwRepository.typeName<Model>(),
        filter: config.backendFilter,
        apiGroup: config.apiGroupOverride,
      ),
    );
    _lastReadOrigin = readResult.origin;

    final model = readResult.value?.model as Model?;
    state = AsyncValue.data(model);
    return model;
  }

  void _updatesListener(List<DwModelWrapper> wrappedModelUpdates) async {
    return await future.then((currentState) async {
      if (currentState == null) return;

      final currentId = (currentState as dynamic).id;
      final match = wrappedModelUpdates.firstWhereOrNull(
        (e) => e.modelId == currentId,
      );

      if (match != null) {
        debugPrint(
          "Updating singleState ${DwRepository.typeName<Model>()} "
          "with id $currentId",
        );
        state = AsyncValue.data(match.isDeleted ? null : match.model as Model);
      }
    });
  }
}
