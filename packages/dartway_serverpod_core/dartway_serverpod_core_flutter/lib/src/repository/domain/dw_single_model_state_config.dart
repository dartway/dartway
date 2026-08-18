import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../dw_repository.dart';
import 'dw_repo_query_key.dart';
import 'dw_repo_read_strategy.dart';

class DwSingleModelStateConfig<Model extends SerializableModel> {
  final DwBackendFilter backendFilter;
  final String? apiGroupOverride;
  final Model? initialModel;
  final DwRepoReadStrategy readStrategy;

  const DwSingleModelStateConfig._({
    required this.backendFilter,
    this.apiGroupOverride,
    this.initialModel,
    this.readStrategy = DwRepoReadStrategy.networkOnly,
  });

  factory DwSingleModelStateConfig({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    Model? initialModel,
    DwRepoReadStrategy readStrategy = DwRepoReadStrategy.networkOnly,
  }) {
    assert(
      id != null || filter != null,
      'Either id or filter must be provided',
    );

    final backendFilter =
        filter ??
        DwBackendFilter<int>.value(
          type: DwBackendFilterType.equals,
          fieldName: 'id',
          fieldValue: id!,
        );

    return DwSingleModelStateConfig._(
      backendFilter: backendFilter,
      apiGroupOverride: apiGroupOverride,
      initialModel: initialModel,
      readStrategy: readStrategy,
    );
  }

  DwSingleModelStateConfig<Model> copyWith({
    DwBackendFilter? backendFilter,
    String? apiGroupOverride,
    Model? initialModel,
    DwRepoReadStrategy? readStrategy,
  }) {
    return DwSingleModelStateConfig<Model>._(
      backendFilter: backendFilter ?? this.backendFilter,
      apiGroupOverride: apiGroupOverride ?? this.apiGroupOverride,
      initialModel: initialModel ?? this.initialModel,
      readStrategy: readStrategy ?? this.readStrategy,
    );
  }

  /// Storage identity for the backend request represented by this config.
  DwRepoQueryKey<Model> get queryKey => DwRepoQueryKey<Model>.getOne(
    modelClassName: DwRepository.typeName<Model>(),
    apiGroup: apiGroupOverride,
    filters: backendFilter.toJson(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DwSingleModelStateConfig<Model> &&
          backendFilter == other.backendFilter &&
          apiGroupOverride == other.apiGroupOverride &&
          initialModel == other.initialModel &&
          readStrategy == other.readStrategy;

  @override
  int get hashCode =>
      backendFilter.hashCode ^
      apiGroupOverride.hashCode ^
      initialModel.hashCode ^
      readStrategy.hashCode;

  @override
  String toString() =>
      'DwSingleModelStateConfig<$Model>('
      'backendFilter: $backendFilter, '
      'apiGroupOverride: $apiGroupOverride, '
      'initialModel: $initialModel, '
      'readStrategy: $readStrategy'
      ')';
}
