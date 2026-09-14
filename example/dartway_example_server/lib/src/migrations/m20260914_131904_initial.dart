// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260914131904Initial extends DwDatabaseMigration {
  const M20260914131904Initial();

  @override
  String get id => '20260914_131904_initial';

  @override
  String get checksum => '4821f265fb328734f85d2fc9c2dbbffb';

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
        'chat_channel',
        columns: [DwColumnSchema.primaryKey(), DwColumnSchema('title', 'text')],
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
          DwColumnSchema('phone', 'text'),
          DwColumnSchema('first_name', 'text'),
          DwColumnSchema('last_name', 'text', nullable: true),
          DwColumnSchema('image_url', 'text', nullable: true),
          DwColumnSchema('gender', 'text', nullable: true),
          DwColumnSchema('role', 'text'),
          DwColumnSchema('agreed_for_marketing', 'boolean'),
          DwColumnSchema('conditions_accepted_at', 'timestamp with time zone'),
          DwColumnSchema('test_verification_code', 'text', nullable: true),
        ],
        indexes: [
          DwIndexSchema('user_profile_first_name_idx', ['first_name']),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'chat_message',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'channel_id',
            'bigint',
            references: DwForeignKey(
              'chat_channel',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'author_profile_id',
            'bigint',
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('text', 'text'),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('chat_message_channel_id_created_at_id_idx', [
            'channel_id',
            'created_at',
            'id',
          ]),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'club_service',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema('title', 'text'),
          DwColumnSchema('description', 'text'),
          DwColumnSchema('duration_minutes', 'bigint'),
          DwColumnSchema('price', 'bigint'),
          DwColumnSchema('image_url', 'text', nullable: true),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'club_session',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'service_id',
            'bigint',
            references: DwForeignKey(
              'club_service',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'coach_profile_id',
            'bigint',
            nullable: true,
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.setNull,
            ),
          ),
          DwColumnSchema('starts_at', 'timestamp with time zone'),
          DwColumnSchema('capacity', 'bigint'),
          DwColumnSchema('booked_count', 'bigint'),
        ],
        indexes: [
          DwIndexSchema('club_session_starts_at_idx', ['starts_at']),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'news_post',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'author_profile_id',
            'bigint',
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('title', 'text'),
          DwColumnSchema('text', 'text'),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('news_post_created_at_idx', ['created_at']),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'session_booking',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'session_id',
            'bigint',
            references: DwForeignKey(
              'club_session',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'client_profile_id',
            'bigint',
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('status', 'text'),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('session_booking_client_profile_id_created_at_idx', [
            'client_profile_id',
            'created_at',
          ]),
          DwIndexSchema('session_booking_session_id_status_idx', [
            'session_id',
            'status',
          ]),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'session_review',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'booking_id',
            'bigint',
            unique: true,
            references: DwForeignKey(
              'session_booking',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('rating', 'bigint'),
          DwColumnSchema('text', 'text', nullable: true),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
      ),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropTable('session_review');
    await m.dropTable('session_booking');
    await m.dropTable('news_post');
    await m.dropTable('club_session');
    await m.dropTable('club_service');
    await m.dropTable('chat_message');
    await m.dropTable('user_profile');
    await m.dropTable('chat_channel');
    await m.dropTable('app_setting');
  }
}
