import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension WidgetRefModelAccessExtension on WidgetRef {
  /// Watches the model as an AsyncValue.
  /// May contain `null` if the model is not found.
  AsyncValue<T?> watchMaybeModel<T extends SerializableModel>({
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
    return watch(DwRepository.singleModelProvider<T>()(cfg));
  }

  /// Watches the model as an AsyncValue.
  /// Throws [StateError] if the model resolves to null.
  AsyncValue<T> watchModel<T extends SerializableModel>({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    T? initialModel,
  }) {
    return watchMaybeModel<T>(
      id: id,
      filter: filter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
    ).whenData((res) {
      if (res == null) {
        throw StateError(
          'watchModel<$T>: model not found '
          '(id=$id, filter=$filter, apiGroup=$apiGroupOverride)',
        );
      }
      return res;
    });
  }

  /// One-time read from state or backend.
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

  /// One-time read from state or backend.
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
