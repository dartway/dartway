// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_orm/dartway_orm.dart';

final class M20260913211555Initial extends DwMigration {
  const M20260913211555Initial();

  @override
  String get id => '20260913_211555_initial';

  @override
  String get checksum => '38963514f751367a8e751f17531fd387';

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
            references: DwReferences(
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
            references: DwReferences(
              'chat_channel',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'author_profile_id',
            'bigint',
            references: DwReferences(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('text', 'text'),
          DwColumnSchema('created_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('chat_message_channel_id_id_idx', ['channel_id', 'id']),
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
            references: DwReferences(
              'club_service',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'coach_profile_id',
            'bigint',
            nullable: true,
            references: DwReferences(
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
            references: DwReferences(
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
            references: DwReferences(
              'club_session',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'client_profile_id',
            'bigint',
            references: DwReferences(
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
            references: DwReferences(
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
