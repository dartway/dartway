import 'package:dartway_orm/dartway_orm.dart';

part 'app_setting.dw.dart';

/// Hand-written in the exact shape `dartway generate` produces.
///
/// Covers single-column unique constraints — one of them on a foreign key (a
/// one-to-one reference) — a `jsonb` map, and columns named like SQL
/// keywords (`key`, `value`), which only work because every identifier is
/// quoted.
@DwTable('app_setting')
final class AppSetting extends DwEntity with _$AppSetting {
  const AppSetting({
    this.id,
    required this.key,
    required this.value,
    this.limits = const {},
    this.featuredServiceId,
    required this.updatedAt,
  });

  @override
  final int? id;

  @DwUnique()
  final String key;

  final String value;
  final Map<String, int> limits;

  @DwUnique()
  @DwReferences('club_service', onDelete: DwOnDelete.setNull)
  final int? featuredServiceId;

  @DwDefault.now()
  final DateTime updatedAt;

  static const table = AppSettingTable();
}
