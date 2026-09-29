// A member who deletes their account leaves a tombstone: the profile row
// stays, unlinked from the account and stripped of the person, so that what
// other people hold on to — their messages, their posts, the visits the club
// counted — keeps an author.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260918062959MemberTombstone extends DwDatabaseMigration {
  const M20260918062959MemberTombstone();

  @override
  String get id => '20260918_062959_member_tombstone';

  @override
  String get checksum => '1df626ad307d5b1a1c231a1c8a870451';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.dropForeignKey('user_profile', 'account_id');
    await m.addColumn(
      'user_profile',
      DwColumnSchema('deleted_at', 'timestamp with time zone', nullable: true),
    );
    await m.alterColumnNullability(
      'user_profile',
      'account_id',
      nullable: true,
    );
    await m.addForeignKey(
      'user_profile',
      'account_id',
      DwForeignKey('dw_account', onDelete: DwOnDelete.setNull),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropForeignKey('user_profile', 'account_id');
    // Going back is losing the tombstones: under the old shape a profile
    // without an account cannot exist, and there is no account to invent.
    await m.sql('DELETE FROM user_profile WHERE account_id IS NULL');
    await m.alterColumnNullability(
      'user_profile',
      'account_id',
      nullable: false,
    );
    await m.dropColumn('user_profile', 'deleted_at');
    await m.addForeignKey(
      'user_profile',
      'account_id',
      DwForeignKey('dw_account', onDelete: DwOnDelete.cascade),
    );
  }
}
