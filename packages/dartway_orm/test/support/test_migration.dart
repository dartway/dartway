import 'package:dartway_orm/dartway_orm.dart';

/// A migration assembled from closures, so each test states exactly what its
/// migrations do.
final class TestMigration extends DwDatabaseMigration {
  TestMigration(
    this.id, {
    this.checksum = 'sealed',
    this.supersededChecksums = const {},
    this.dependsOn = const [],
    this.transactional = true,
    required this.onUp,
    this.onDown,
  });

  @override
  final String id;
  @override
  final String checksum;
  @override
  final Set<String> supersededChecksums;
  @override
  final List<DwMigrationRef> dependsOn;
  @override
  final bool transactional;
  final Future<void> Function(DwMigrationContext m) onUp;
  final Future<void> Function(DwMigrationContext m)? onDown;

  @override
  Future<void> up(DwMigrationContext m) => onUp(m);

  @override
  Future<void> down(DwMigrationContext m) =>
      onDown == null ? m.irreversible() : onDown!(m);
}
