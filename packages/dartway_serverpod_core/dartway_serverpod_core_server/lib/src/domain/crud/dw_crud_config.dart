import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'domain/dw_crud_entity.dart';

class DwCrudConfig<T extends TableRow> with DwCrudEntity<T> {
  const DwCrudConfig({
    required this.table,
    this.getModelConfigs,
    this.getListConfig,
    this.saveConfig,
    this.deleteConfig,
  });

  final Table table;

  /// Rules for fetching a single model.
  /// Multiple configs may exist for different filters or access rules.
  final List<DwGetModelConfig<T>>? getModelConfigs;

  /// Rules for fetching lists of models.
  final DwGetModelListConfig<T>? getListConfig;

  /// Rules for creating or updating models (insert + update).
  final DwSaveConfig<T>? saveConfig;

  /// Rules for deleting models.
  final DwDeleteConfig<T>? deleteConfig;
}
