// export 'descriptor/repository_descriptor.dart';
// export 'state/nit_repository_state.dart';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/dw_model_list_state_config.dart';
import 'domain/dw_single_model_state_config.dart';
import 'states/dw_model_list_state.dart';
import 'states/dw_single_model_state.dart';

class DwRepository {
  static const int mockModelId = 0;
  static final globalRefreshTriggerProvider = StateProvider<DateTime>(
    (ref) => DateTime.now(),
  );

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
        'Updating Listening States for $className with ${updateMap[className]!.length} objects. Active listeners: ${_updateListeners.keys}.',
      );
      for (var listener in _updateListeners[className] ?? []) {
        listener(updateMap[className]);
      }
    }
  }

  static final _modelListStateProviders = <Type,
      AsyncNotifierProviderFamily<DwModelListState, List<dynamic>,
          DwModelListStateConfig>>{};

  static AsyncNotifierProviderFamily<DwModelListState<T>, List<T>,
          DwModelListStateConfig<T>>
      modelListStateProvider<T extends SerializableModel>() {
    if (_modelListStateProviders[T] == null) {
      _modelListStateProviders[T] = AsyncNotifierProviderFamily<
          DwModelListState<T>,
          List<T>,
          DwModelListStateConfig<T>>(DwModelListState<T>.new);
    }

    return _modelListStateProviders[T] as AsyncNotifierProviderFamily<
        DwModelListState<T>, List<T>, DwModelListStateConfig<T>>;
  }

  static final _singleModelStateProviders = <Type,
      AsyncNotifierProviderFamily<DwSingleModelState, dynamic,
          DwSingleModelStateConfig>>{};

  static AsyncNotifierProviderFamily<DwSingleModelState<T>, T?,
          DwSingleModelStateConfig<T>>
      singleModelProvider<T extends SerializableModel>() {
    if (_singleModelStateProviders[T] == null) {
      _singleModelStateProviders[T] = AsyncNotifierProviderFamily<
          DwSingleModelState<T>,
          T?,
          DwSingleModelStateConfig<T>>(DwSingleModelState<T>.new);
    }

    return _singleModelStateProviders[T] as AsyncNotifierProviderFamily<
        DwSingleModelState<T>, T?, DwSingleModelStateConfig<T>>;
  }
}
