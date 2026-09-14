import 'dart:typed_data';

import 'package:dartway_orm/dartway_orm.dart';

part 'club_service.dw.dart';

enum ClubServiceKind { group, personal }

/// Hand-written in the exact shape `dartway generate` produces, so the ORM's
/// contract with generated code is exercised without the generator.
///
/// Covers every column type: enum, nullable double, `Duration`, a `jsonb`
/// list, a `now()` default, a nullable `DateTime`, nullable bytes, and a
/// boolean with an SQL default.
@DwTable('club_service')
final class ClubServiceRow extends DwTableRow with _$ClubServiceRow {
  const ClubServiceRow({
    this.id,
    required this.title,
    required this.kind,
    this.price,
    required this.duration,
    this.tags = const [],
    required this.createdAt,
    this.archivedAt,
    this.cover,
    this.active = true,
  });

  @override
  final int? id;

  final String title;
  final ClubServiceKind kind;
  final double? price;
  final Duration duration;
  final List<String> tags;

  @DwDefault.now()
  final DateTime createdAt;

  final DateTime? archivedAt;
  final Uint8List? cover;

  @DwDefault('true')
  final bool active;

  static const table = ClubServiceTable();
}
