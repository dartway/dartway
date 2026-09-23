// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260914204255Initial extends DwDatabaseMigration {
  const M20260914204255Initial();

  @override
  String get id => '20260914_204255_initial';

  @override
  String get checksum => 'c157de565389b56eace82f0574f9caa5';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.createTable(
      DwTableSchema(
        'app_setting',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema('key', 'text', unique: true),
          DwColumnSchema('value', 'text'),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'user_profile',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'account_id',
            'bigint',
            unique: true,
            references: DwForeignKey(
              'dw_account',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('first_name', 'text'),
          DwColumnSchema('last_name', 'text', nullable: true),
          DwColumnSchema('gender', 'text', nullable: true),
          DwColumnSchema(
            'avatar_file_id',
            'bigint',
            nullable: true,
            references: DwForeignKey(
              'dw_stored_file',
              onDelete: DwOnDelete.setNull,
            ),
          ),
          DwColumnSchema('role', 'text'),
          DwColumnSchema('agreed_for_marketing', 'boolean'),
          DwColumnSchema(
            'terms_accepted_at',
            'timestamp with time zone',
            nullable: true,
          ),
          DwColumnSchema('test_verification_code', 'text', nullable: true),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('user_profile_created_at_idx', ['created_at']),
        ],
      ),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropTable('user_profile');
    await m.dropTable('app_setting');
  }
}
