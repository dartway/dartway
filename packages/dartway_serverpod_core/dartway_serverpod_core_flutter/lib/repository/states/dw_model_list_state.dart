import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DwModelListState<Model extends SerializableModel>
    extends FamilyAsyncNotifier<List<Model>, DwModelListStateConfig<Model>>
// implements ModelManagerInterface<Model>
{
  late int _nextPage;

  @override
  Future<List<Model>> build(DwModelListStateConfig config) async {
    ref.onDispose(() {
      DwRepository.removeUpdatesListener<Model>(
        config.customUpdatesListener ?? _updatesListener,
      );
      for (var relationConfig in config.relationUpdatesConfigs ?? []) {
        relationConfig.removeUpdatesListener();
      }
    });

    _nextPage = 0;

    final globalTimestamp = ref.watch(
      DwRepository.globalRefreshTriggerProvider,
    );

    debugPrint(
      "Building state for ${DwRepository.typeName<Model>()} with timestamp $globalTimestamp",
    );

    final data = await _loadData();

    DwRepository.addUpdatesListener<Model>(
      config.customUpdatesListener ?? _updatesListener,
    );

    if (config.relationUpdatesConfigs != null) {
      for (var relationConfig in config.relationUpdatesConfigs!) {
        debugPrint(
          'Adding relation updates listener for ${relationConfig.relationModelType}',
        );
        (relationConfig as DwRelationUpdatesConfig<Model, SerializableModel>)
            .addUpdatesListener(_relationUpdatesListener);
      }
    }
    return _processData(data).toList();
  }

  Future<bool> loadNextPage() async {
    return await future.then((currentState) async {
      final data = await _loadData();

      state = AsyncValue.data(<Model>[...currentState, ..._processData(data)]);

      return data.length == arg.pageSize;
    });
  }

  _processData(List<DwModelWrapper> data) => data.map((e) => e.model as Model);

  Future<List<DwModelWrapper>> _loadData() async {
    final result = await dw.endpointCaller.dwCrud
        .getAll(
          className: DwRepository.typeName<Model>(),
          filter: arg.backendFilter,
          limit: arg.pageSize,
          offset: arg.pageSize != null ? (_nextPage++ * arg.pageSize!) : null,
        )
        .then(
          (response) => ref.processApiResponse<List<DwModelWrapper>>(
            response,
            // updateListeners: false,
          ),
        );

    if (result == null) return <DwModelWrapper>[];

    // ref.updateRepository(result, updateListeners: false);

    return result;
  }

  void _updatesListener(List<DwModelWrapper> wrappedModelUpdates) async {
    final ids = wrappedModelUpdates.map((e) => e.modelId).toSet();

    state = state.whenData((value) {
      return [
        ...wrappedModelUpdates
            .where((e) => !e.isDeleted)
            .map((e) => e.model as Model),
        ...value.where((e) => !ids.contains((e as dynamic).id)),
      ];
    });

    // return await future.then((value) async {
    //   state = AsyncValue.data([
    //     ...wrappedModelUpdates
    //         .where((e) => !e.isDeleted)
    //         .map((e) => e.model as Model),
    //     ...value.where((e) => !ids.contains((e as dynamic).id)),
    //   ]);
    // });
  }

  void _relationUpdatesListener(
    List<DwModelWrapper> wrappedModelUpdates,
    String foreignKey,
    Model Function(Model parentModel, List<DwModelWrapper> relatedModels)
    copyWithRelatedModels,
    Set<int>? Function(Model model)? parentIdsGetter,
  ) async {
    state = state.whenData((value) {
      return value.map((model) {
        final parentIds =
            parentIdsGetter != null
                ? parentIdsGetter.call(model)
                : <int>{(model as dynamic).id};

        final relatedModels = wrappedModelUpdates.where(
          (e) => (parentIds ?? {}).contains(e.foreignKeys[foreignKey]),
        );

        if (relatedModels.isEmpty) return model;

        return copyWithRelatedModels(model, relatedModels.toList());
      }).toList();
    });

    // return await future.then((value) async {
    //   state = AsyncValue.data(
    //     value.map((model) {
    //       final parentIds =
    //           parentIdsGetter != null
    //               ? parentIdsGetter.call(model)
    //               : <int>{(model as dynamic).id};

    //       final relatedModels =
    //           wrappedModelUpdates
    //               .where(
    //                 (e) =>
    //                     (parentIds ?? {}).contains(e.foreignKeys[foreignKey]),
    //               )
    //               .toList();

    //       if (relatedModels.isEmpty) return model;

    //       return copyWithRelatedModels(model, relatedModels);
    //     }).toList(),
    //   );
    // });
  }
}
