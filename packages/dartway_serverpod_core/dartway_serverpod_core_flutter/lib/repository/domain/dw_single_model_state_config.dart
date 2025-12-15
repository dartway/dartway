import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

class DwSingleModelStateConfig<Model extends SerializableModel> {
  final DwBackendFilter backendFilter;
  final String? apiGroupOverride;
  final Model? initialModel;

  const DwSingleModelStateConfig._({
    required this.backendFilter,
    this.apiGroupOverride,
    this.initialModel,
  });

  factory DwSingleModelStateConfig({
    int? id,
    DwBackendFilter? filter,
    String? apiGroupOverride,
    Model? initialModel,
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
    );
  }

  DwSingleModelStateConfig<Model> copyWith({
    DwBackendFilter? backendFilter,
    String? apiGroupOverride,
    Model? initialModel,
  }) {
    return DwSingleModelStateConfig<Model>._(
      backendFilter: backendFilter ?? this.backendFilter,
      apiGroupOverride: apiGroupOverride ?? this.apiGroupOverride,
      initialModel: initialModel ?? this.initialModel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DwSingleModelStateConfig<Model> &&
          backendFilter == other.backendFilter &&
          apiGroupOverride == other.apiGroupOverride &&
          initialModel == other.initialModel;

  @override
  int get hashCode =>
      backendFilter.hashCode ^
      apiGroupOverride.hashCode ^
      initialModel.hashCode;

  @override
  String toString() =>
      'DwSingleModelStateConfig<$Model>('
      'backendFilter: $backendFilter, '
      'apiGroupOverride: $apiGroupOverride, '
      'initialModel: $initialModel'
      ')';
}
