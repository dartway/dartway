import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

_filter<T>(T? model, bool Function(T model) filter) =>
    model != null ? filter(model) : false;

extension RefModelListStateExtensions on Ref {
  Future<List<T>> watchModelList<T extends SerializableModel>({
    DwBackendFilter? backendFilter,
    DwModelListStateConfig<T>? customConfig,
    bool Function(T model)? frontendFilter,
  }) async {
    final items = await watch(
      DwRepository.modelListStateProvider<T>()(
            customConfig ??
                DwModelListStateConfig<T>(backendFilter: backendFilter),
          )
          .future,
    );

    return frontendFilter == null
        ? items
        : items.where((e) => _filter(e, frontendFilter)).toList();
  }

  loadNextPageForCustomizedModelListMore<T extends SerializableModel>({
    required DwModelListStateConfig<T> config,
  }) =>
      read(
        DwRepository.modelListStateProvider<T>()(config).notifier,
      ).loadNextPage();
}
