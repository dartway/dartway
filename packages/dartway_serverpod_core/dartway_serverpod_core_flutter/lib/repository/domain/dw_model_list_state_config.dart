import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dw_pagination_strategy.dart';

class DwRelationUpdatesConfig<Model extends SerializableModel,
    RelationModel extends SerializableModel> {
  final Model Function(Model parentModel, List<DwModelWrapper> relatedModels)
      copyWithRelatedModels;
  final String relationKey;
  final Set<int> Function(Model model)? parentIdsGetter;

  const DwRelationUpdatesConfig({
    required this.copyWithRelatedModels,
    required this.relationKey,
    this.parentIdsGetter,
  });

  Type get relationModelType => RelationModel;

  addUpdatesListener(
    void Function(
      List<DwModelWrapper> wrappedModelUpdates,
      String relationKey,
      Model Function(Model parentModel, List<DwModelWrapper> relatedModels)
          copyWithRelatedModels,
      Set<int>? Function(Model model)? parentIdsGetter,
    ) relationUpdatesListener,
  ) {
    DwRepository.addUpdatesListener<RelationModel>(
      (updates) => relationUpdatesListener(
        updates,
        relationKey,
        copyWithRelatedModels,
        parentIdsGetter,
      ),
    );
  }
}

class DwModelListStateConfig<Model extends SerializableModel>
    implements DwInfiniteListViewConfig<Model> {
  final DwBackendFilter? backendFilter;
  // final int? pageSize;
  final String? apiGroupOverride;
  final Function(List<DwModelWrapper>)? customUpdatesListener;
  final List<DwRelationUpdatesConfig<Model, SerializableModel>>?
      relationUpdatesConfigs;
  final int Function(Model a, Model b)? updatesSortingMethod;
  final DwPaginationStrategy? paginationStrategy;

  const DwModelListStateConfig({
    this.backendFilter,
    // this.pageSize,
    this.apiGroupOverride,
    this.customUpdatesListener,
    this.relationUpdatesConfigs,
    this.updatesSortingMethod,
    this.paginationStrategy,
  });

  @override
  Future<bool> loadNextPage(WidgetRef ref) {
    return ref
        .read(DwRepository.modelListStateProvider<Model>()(this).notifier)
        .loadNextPage();
  }

  @override
  AsyncValue<List<Model>> watchAsyncValue(WidgetRef ref) {
    return ref.watchModelList<Model>(customConfig: this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DwModelListStateConfig<Model> &&
            backendFilter == other.backendFilter &&
            paginationStrategy == other.paginationStrategy &&
            apiGroupOverride == other.apiGroupOverride &&
            customUpdatesListener == other.customUpdatesListener &&
            relationUpdatesConfigs == other.relationUpdatesConfigs &&
            updatesSortingMethod == other.updatesSortingMethod;
  }

  @override
  int get hashCode =>
      backendFilter.hashCode ^
      paginationStrategy.hashCode ^
      apiGroupOverride.hashCode ^
      customUpdatesListener.hashCode ^
      relationUpdatesConfigs.hashCode ^
      updatesSortingMethod.hashCode;

  DwModelListStateConfig<Model> copyWith({
    DwBackendFilter? backendFilter,
    int? pageSize,
    String? apiGroupOverride,
    Function(List<DwModelWrapper>)? customUpdatesListener,
    int Function(Model a, Model b)? updatesSortingMethod,
  }) {
    return DwModelListStateConfig<Model>(
      backendFilter: backendFilter ?? this.backendFilter,
      paginationStrategy: paginationStrategy ?? this.paginationStrategy,
      apiGroupOverride: apiGroupOverride ?? this.apiGroupOverride,
      customUpdatesListener:
          customUpdatesListener ?? this.customUpdatesListener,
      relationUpdatesConfigs:
          relationUpdatesConfigs ?? this.relationUpdatesConfigs,
      updatesSortingMethod: updatesSortingMethod ?? this.updatesSortingMethod,
    );
  }

  @override
  String toString() {
    return 'DwModelListStateConfig<$Model>('
        'backendFilter: $backendFilter, '
        'paginationStrategy: $paginationStrategy, '
        'apiGroupOverride: $apiGroupOverride, '
        'customUpdatesListener: $customUpdatesListener, '
        'relationUpdatesConfigs: $relationUpdatesConfigs, '
        'updatesSortingMethod: $updatesSortingMethod'
        ')';
  }
}
