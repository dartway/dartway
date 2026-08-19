import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dw_repository.dart';
import 'dw_pagination_strategy.dart';

class DwRelationUpdatesConfig<
  Model extends SerializableModel,
  RelationModel extends SerializableModel
> {
  final Model Function(Model parentModel, List<DwModelWrapper> relatedModels)
  copyWithRelatedModels;
  final String relationKey;
  final Set<int> Function(Model model)? parentIdsGetter;

  /// Stores the wrapped listener so it can be removed later.
  Function(List<DwModelWrapper>)? _wrappedListener;

  DwRelationUpdatesConfig({
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
    )
    relationUpdatesListener,
  ) {
    _wrappedListener = (updates) => relationUpdatesListener(
      updates,
      relationKey,
      copyWithRelatedModels,
      parentIdsGetter,
    );
    DwRepository.addUpdatesListener<RelationModel>(_wrappedListener!);
  }

  void removeUpdatesListener() {
    if (_wrappedListener != null) {
      DwRepository.removeUpdatesListener<RelationModel>(_wrappedListener!);
      _wrappedListener = null;
    }
  }
}

class DwModelListStateConfig<Model extends SerializableModel>
    implements DwInfiniteListViewConfig<Model> {
  final DwBackendFilter? backendFilter;
  final List<DwOrderBy>? orderByList;
  // final int? pageSize;
  final String? apiGroupOverride;
  final Function(List<DwModelWrapper>)? customUpdatesListener;
  final List<DwRelationUpdatesConfig<Model, SerializableModel>>?
  relationUpdatesConfigs;
  final int Function(Model a, Model b)? updatesSortingMethod;
  final DwPaginationStrategy? paginationStrategy;
  final DwRepoReadStrategy readStrategy;

  DwModelListStateConfig({
    this.backendFilter,
    List<DwOrderBy>? orderByList,
    // this.pageSize,
    this.apiGroupOverride,
    this.customUpdatesListener,
    this.relationUpdatesConfigs,
    this.updatesSortingMethod,
    this.paginationStrategy,
    this.readStrategy = DwRepoReadStrategy.networkOnly,
  }) : orderByList = orderByList == null
           ? null
           : List<DwOrderBy>.unmodifiable(orderByList);

  /// Builds the storage identity for one concrete list request.
  ///
  /// The supplied [pagination] comes from the pagination strategy at request
  /// time, so a later page cannot reuse the first page's offline snapshot.
  DwRepoQueryKey<Model> queryKeyFor(
    DwPaginationParams pagination, {
    DwBackendFilter? requestFilter,
  }) => DwRepoQueryKey<Model>.getAll(
    modelClassName: DwRepository.typeName<Model>(),
    apiGroup: apiGroupOverride,
    filters: (requestFilter ?? backendFilter)?.toJson(),
    ordering: orderByList?.map((orderBy) => orderBy.toJson()).toList(),
    pagination: pagination.toQueryMap(),
  );

  @override
  Future<bool> loadNextPage(WidgetRef ref) {
    return ref
        .read(DwRepository.modelListStateProvider<Model>()(this).notifier)
        .loadNextPage();
  }

  @override
  AsyncValue<List<Model>> watchAsyncValue(WidgetRef ref) {
    return ref.watch(DwRepository.modelListStateProvider<Model>()(this));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DwModelListStateConfig<Model> &&
            backendFilter == other.backendFilter &&
            listEquals(orderByList, other.orderByList) &&
            paginationStrategy == other.paginationStrategy &&
            apiGroupOverride == other.apiGroupOverride &&
            customUpdatesListener == other.customUpdatesListener &&
            relationUpdatesConfigs == other.relationUpdatesConfigs &&
            updatesSortingMethod == other.updatesSortingMethod &&
            readStrategy == other.readStrategy;
  }

  @override
  int get hashCode =>
      backendFilter.hashCode ^
      Object.hash(
        orderByList == null,
        Object.hashAll(orderByList ?? const []),
      ) ^
      paginationStrategy.hashCode ^
      apiGroupOverride.hashCode ^
      customUpdatesListener.hashCode ^
      relationUpdatesConfigs.hashCode ^
      updatesSortingMethod.hashCode ^
      readStrategy.hashCode;

  DwModelListStateConfig<Model> copyWith({
    DwBackendFilter? backendFilter,
    List<DwOrderBy>? orderByList,
    int? pageSize,
    String? apiGroupOverride,
    Function(List<DwModelWrapper>)? customUpdatesListener,
    int Function(Model a, Model b)? updatesSortingMethod,
    DwRepoReadStrategy? readStrategy,
  }) {
    return DwModelListStateConfig<Model>(
      backendFilter: backendFilter ?? this.backendFilter,
      orderByList: orderByList ?? this.orderByList,
      paginationStrategy: paginationStrategy ?? this.paginationStrategy,
      apiGroupOverride: apiGroupOverride ?? this.apiGroupOverride,
      customUpdatesListener:
          customUpdatesListener ?? this.customUpdatesListener,
      relationUpdatesConfigs:
          relationUpdatesConfigs ?? this.relationUpdatesConfigs,
      updatesSortingMethod: updatesSortingMethod ?? this.updatesSortingMethod,
      readStrategy: readStrategy ?? this.readStrategy,
    );
  }

  @override
  String toString() {
    return 'DwModelListStateConfig<$Model>('
        'backendFilter: $backendFilter, '
        'orderByList: $orderByList, '
        'paginationStrategy: $paginationStrategy, '
        'apiGroupOverride: $apiGroupOverride, '
        'customUpdatesListener: $customUpdatesListener, '
        'relationUpdatesConfigs: $relationUpdatesConfigs, '
        'updatesSortingMethod: $updatesSortingMethod, '
        'readStrategy: $readStrategy'
        ')';
  }
}
