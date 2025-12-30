import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dw_no_pagination.dart';
import '../domain/dw_pagination_strategy.dart';

class DwModelListState<Model extends SerializableModel>
    extends FamilyAsyncNotifier<List<Model>, DwModelListStateConfig<Model>>
// implements ModelManagerInterface<Model>
{
  late DwPaginationStrategy _paginationStrategy;
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
    final globalTimestamp = ref.watch(
      DwRepository.globalRefreshTriggerProvider,
    );

    debugPrint(
      "Building state for ${DwRepository.typeName<Model>()} with timestamp $globalTimestamp",
    );

    _paginationStrategy = config.paginationStrategy ?? DwNoPagination();

    _paginationStrategy.reset();

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
    if (_paginationStrategy.hasMore == false) return false;

    final current = await future;
    final data = await _loadData();

    state = AsyncValue.data([
      ...current,
      ..._processData(data),
    ]);

    return _paginationStrategy.hasMore;

    // return await future.then((currentState) async {
    //   final data = await _loadData();

    //   state = AsyncValue.data(<Model>[...currentState, ..._processData(data)]);

    //   return data.length == arg.pageSize;
    // });
  }

  _processData(List<DwModelWrapper> data) => data.map((e) => e.model as Model);

  Future<List<DwModelWrapper>> _loadData() async {
    if (!_paginationStrategy.hasMore) return [];

    final params = _paginationStrategy.buildParams();

    final filter = DwBackendFilter.and(
      <DwBackendFilter>[
        if (arg.backendFilter != null) arg.backendFilter!,
        if (params.afterId != null)
          DwBackendFilter.value(
            type: DwBackendFilterType.greaterThan,
            fieldName: 'id',
            fieldValue: params.afterId,
          ),
        if (params.beforeId != null)
          DwBackendFilter.value(
            type: DwBackendFilterType.lessThan,
            fieldName: 'id',
            fieldValue: params.beforeId,
          ),
      ],
    );

    final response = await dw.endpointCaller.dwCrud.getAll(
      className: DwRepository.typeName<Model>(),
      filter: filter,
      limit: params.limit,
      offset: params.offset,
    );

    final result = ref.processApiResponse(response);

    final data = result ?? [];

    _paginationStrategy.onPageLoaded(data);

    return data;

    // final result = await dw.endpointCaller.dwCrud
    //     .getAll(
    //       className: DwRepository.typeName<Model>(),
    //       filter: arg.backendFilter,
    //       limit: arg.pageSize,
    //       offset: arg.pageSize != null ? (_nextPage++ * arg.pageSize!) : null,
    //     )
    //     .then(
    //       (response) => ref.processApiResponse<List<DwModelWrapper>>(
    //         response,
    //         // updateListeners: false,
    //       ),
    //     );

    // if (result == null) return <DwModelWrapper>[];

    // // ref.updateRepository(result, updateListeners: false);

    // return result;
  }

  void _updatesListener(List<DwModelWrapper> wrappedModelUpdates) async {
    // Collect all IDs from the incoming updates to identify what's new or changed
    final ids = wrappedModelUpdates.map((e) => e.modelId).toSet();

    // If a custom sorting method is provided, sort the updates accordingly
    if (arg.updatesSortingMethod != null) {
      wrappedModelUpdates.sort(
        (a, b) => arg.updatesSortingMethod!(a.model as Model, b.model as Model),
      );
    }

    // Wait for the current state to be loaded from the future
    final current = await future;

    // Keep only those current items that are not affected by updates (matching modelId)
    final currentList = current
        .where((e) => !ids.contains((e as dynamic).id)) // filter by id match
        .cast<Model>() // cast to the correct type
        .toList(); // convert to list

    final res = <Model>[]; // Final merged result list

    int i = 0; // index for currentList
    int j = 0; // index for wrappedModelUpdates

    // Merge both lists in a single pass using sorted order if provided
    while (i < currentList.length || j < wrappedModelUpdates.length) {
      // Safely get current entity or null if out of bounds
      final Model? currentEntity =
          i < currentList.length ? currentList[i] : null;

      // Safely get next update or null if out of bounds
      final DwModelWrapper? update =
          j < wrappedModelUpdates.length ? wrappedModelUpdates[j] : null;

      // If no more updates, just add remaining current entities
      if (update == null) {
        res.add(currentEntity!);
        i++;
        continue;
      }

      // If no more current entities, just add valid updates
      if (currentEntity == null) {
        if (!update.isDeleted && // not marked for deletion
            (arg.backendFilter == null || // passes backend filter
                arg.backendFilter!.filterUpdate(update.jsonSerialization))) {
          res.add(update.model as Model);
        }
        j++;
        continue;
      }

      // Compare order: update vs current entity using sorting method (or default to insert update first)
      final cmp = arg.updatesSortingMethod
              ?.call(update.model as Model, currentEntity) ??
          -1;

      if (cmp <= 0) {
        // Insert update if not deleted and passes filter
        if (!update.isDeleted &&
            (arg.backendFilter == null ||
                arg.backendFilter!.filterUpdate(update.jsonSerialization))) {
          res.add(update.model as Model);
        }
        j++; // move to next update
      } else {
        res.add(currentEntity); // insert current entity
        i++; // move to next current
      }
    }

    // Push the merged list to state
    state = AsyncValue.data(res);

    // final ids = wrappedModelUpdates.map((e) => e.modelId).toSet();

    // state = state.whenData((value) {
    //   return [
    //     ...wrappedModelUpdates
    //         .where((e) => !e.isDeleted)
    //         .map((e) => e.model as Model),
    //     ...value.where((e) => !ids.contains((e as dynamic).id)),
    //   ];
    // });

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
        final parentIds = parentIdsGetter != null
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
