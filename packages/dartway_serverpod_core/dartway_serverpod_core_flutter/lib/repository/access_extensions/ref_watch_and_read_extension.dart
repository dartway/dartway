import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension RefModelAccessExtension on Ref {
  /// Subscribes to the model state.
  /// May return `null` if the model is not found.
  Future<T?> watchMaybeModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
  }) {
    final cfg = DwSingleModelStateConfig<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    );
    return watch(DwRepository.singleModelProvider<T>()(cfg).future);
  }

  /// Subscribes to the model state.
  /// Throws [StateError] if the model is not found.
  Future<T> watchModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
  }) async {
    final res = await watchMaybeModel<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    );
    if (res == null) {
      throw StateError(
        'watchModel<$T>: model not found '
        '(id=$id, filter=$filter, apiGroup=$apiGroupOverride)',
      );
    }
    return res;
  }

  /// Performs a one-time fetch from the backend.
  /// May return `null` if the model is not found.
  Future<T?> readMaybeModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
    bool forceFetch = false,
  }) {
    final cfg = DwSingleModelStateConfig<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    );
    final notifier = read(DwRepository.singleModelProvider<T>()(cfg).notifier);
    return notifier.read(forceFetch: forceFetch);
  }

  /// Performs a one-time fetch from the backend.
  /// Throws [StateError] if the model is not found.
  Future<T> readModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
    bool forceFetch = false,
  }) async {
    final res = await readMaybeModel<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
      forceFetch: forceFetch,
    );
    if (res == null) {
      throw StateError(
        'readModel<$T>: model not found '
        '(id=$id, filter=$filter, apiGroup=$apiGroupOverride)',
      );
    }
    return res;
  }
}
