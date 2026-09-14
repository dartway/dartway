import 'package:dartway_core_server/dartway_core_server.dart';

part 'settings.dw.dart';

/// One app setting, one row: saving a setting writes only its own row, so two
/// admins editing different settings cannot overwrite each other.
@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow with _$AppSettingRow {
  const AppSettingRow({this.id, required this.key, required this.value});

  @override
  final int? id;

  @DwUniqueColumn()
  final String key;

  final String value;

  static const tableDef = AppSettingTable();
}
