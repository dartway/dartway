import 'package:dartway_orm/dartway_orm.dart';

part 'app_setting.dw.dart';

/// Hand-written in the exact shape `dartway generate` produces.
///
/// Covers single-column unique constraints — one of them on a foreign key (a
/// one-to-one reference) — a `jsonb` map, and columns named like SQL
/// keywords (`key`, `value`), which only work because every identifier is
/// quoted.
@DwSqlTable('app_setting')
final class AppSettingRow extends DwTableRow with _$AppSettingRow {
  const AppSettingRow({
    this.id,
    required this.key,
    required this.value,
    this.limits = const {},
    this.featuredServiceId,
    required this.updatedAt,
  });

  @override
  final int? id;

  @DwUniqueColumn()
  final String key;

  final String value;
  final Map<String, int> limits;

  @DwUniqueColumn()
  @DwForeignKey('club_service', onDelete: DwOnDelete.setNull)
  final int? featuredServiceId;

  @DwDefaultValue.now()
  final DateTime updatedAt;

  static const tableDef = AppSettingTable();
}
