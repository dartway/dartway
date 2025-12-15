import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwCrudConfig<T extends TableRow> {
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
  final DwGetListConfig<T>? getListConfig;

  /// Rules for creating or updating models (insert + update).
  final DwSaveConfig<T>? saveConfig;

  /// Rules for deleting models.
  final DwDeleteConfig<T>? deleteConfig;

  String get className => T.toString();
}
