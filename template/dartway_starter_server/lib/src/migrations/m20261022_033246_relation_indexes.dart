// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20261022033246RelationIndexes extends DwDatabaseMigration {
  const M20261022033246RelationIndexes();

  @override
  String get id => '20261022_033246_relation_indexes';

  @override
  String get checksum => '03262091ea65c5fb665b3960c94faa9e';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.createIndex(
      'user_profile',
      DwIndexSchema('user_profile_avatar_file_id_idx', ['avatar_file_id']),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropIndex('user_profile_avatar_file_id_idx');
  }
}
