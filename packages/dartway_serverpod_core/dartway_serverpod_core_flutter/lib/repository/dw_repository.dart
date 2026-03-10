// export 'descriptor/repository_descriptor.dart';
// export 'state/nit_repository_state.dart';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../private/dw_singleton.dart';
import 'domain/dw_model_list_state_config.dart';
import 'domain/dw_single_model_state_config.dart';
import 'states/dw_model_list_state.dart';
import 'states/dw_single_model_state.dart';

class DwRepository {
  static const int mockModelId = 0;

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

  static Future<Model> saveModel<Model extends SerializableModel>(
    Model model, {
    String? apiGroupOverride,
  }) async {
    return await dw.endpointCaller.dwCrud
        .saveModel(
          wrappedModel: DwModelWrapper.wrap(model: model),
          apiGroup: apiGroupOverride,
        )
        .then((response) => processApiResponse<DwModelWrapper>(response))
        .then((res) => res!.model as Model);
  }

  static Future<bool> deleteModel<T extends SerializableModel>(
    T model, {
    String? apiGroupOverride,
  }) async {
    // TODO: подумать, как сделать это получше, может апи поменять или засылать objectWrapper.deleted просто

    final modelId = model.toJson()['id'];
    if (modelId == null) {
      // notifyUser(NitNotification.warning(
      //   'Мое',
      // ));
      return true;
    }
    return await dw.endpointCaller.dwCrud
        .delete(
          className: DwModelWrapper.getClassNameForObject(model),
          modelId: modelId,
          apiGroup: apiGroupOverride,
        )
        .then((response) => processApiResponse<bool>(response) ?? false);
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

    if (response.error != null) {
      throw Exception(response.error);
    }

    return response.value;
  }
}
