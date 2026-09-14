// Draft written by `migrate create`, reviewed: `created_at` is renamed to
// `sent_at` rather than dropped and re-added, so existing messages keep their
// time.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260914183459Chat extends DwDatabaseMigration {
  const M20260914183459Chat();

  @override
  String get id => '20260914_183459_chat';

  @override
  String get checksum => '7d2ad0d0a208227f4100ade83651786f';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.dropIndex('chat_message_channel_id_created_at_id_idx');
    await m.createTable(
      DwTableSchema(
        'chat_message_attachment',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'message_id',
            'bigint',
            references: DwForeignKey(
              'chat_message',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'file_id',
            'bigint',
            unique: true,
            references: DwForeignKey(
              'dw_stored_file',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('position', 'bigint'),
          DwColumnSchema('width', 'bigint', nullable: true),
          DwColumnSchema('height', 'bigint', nullable: true),
        ],
        indexes: [
          DwIndexSchema('chat_message_attachment_message_id_position_idx', [
            'message_id',
            'position',
          ]),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'chat_message_reaction',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'message_id',
            'bigint',
            references: DwForeignKey(
              'chat_message',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'profile_id',
            'bigint',
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('reaction', 'text'),
        ],
        indexes: [
          DwIndexSchema('chat_message_reaction_message_id_profile_id_key', [
            'message_id',
            'profile_id',
          ], unique: true),
        ],
      ),
    );
    await m.createTable(
      DwTableSchema(
        'chat_read_position',
        columns: [
          DwColumnSchema.primaryKey(),
          DwColumnSchema(
            'profile_id',
            'bigint',
            references: DwForeignKey(
              'user_profile',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'channel_id',
            'bigint',
            references: DwForeignKey(
              'chat_channel',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema(
            'message_id',
            'bigint',
            references: DwForeignKey(
              'chat_message',
              onDelete: DwOnDelete.cascade,
            ),
          ),
          DwColumnSchema('sent_at', 'timestamp with time zone'),
        ],
        indexes: [
          DwIndexSchema('chat_read_position_profile_id_channel_id_key', [
            'profile_id',
            'channel_id',
          ], unique: true),
        ],
      ),
    );
    await m.renameColumn('chat_message', 'created_at', 'sent_at');
    await m.addColumn(
      'chat_message',
      DwColumnSchema('edited_at', 'timestamp with time zone', nullable: true),
    );
    await m.addColumn(
      'chat_message',
      DwColumnSchema('pinned_at', 'timestamp with time zone', nullable: true),
    );
    await m.addColumn(
      'chat_message',
      DwColumnSchema(
        'pinned_by_profile_id',
        'bigint',
        nullable: true,
        references: DwForeignKey('user_profile', onDelete: DwOnDelete.setNull),
      ),
    );
    await m.addColumn(
      'chat_message',
      DwColumnSchema(
        'reply_to_message_id',
        'bigint',
        nullable: true,
        references: DwForeignKey('chat_message', onDelete: DwOnDelete.setNull),
      ),
    );
    await m.addColumn(
      'chat_message',
      DwColumnSchema('deleted_at', 'timestamp with time zone', nullable: true),
    );
    await m.createIndex(
      'chat_message',
      DwIndexSchema('chat_message_channel_id_sent_at_id_idx', [
        'channel_id',
        'sent_at',
        'id',
      ]),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropIndex('chat_message_channel_id_sent_at_id_idx');
    await m.dropColumn('chat_message', 'deleted_at');
    await m.dropColumn('chat_message', 'reply_to_message_id');
    await m.dropColumn('chat_message', 'pinned_by_profile_id');
    await m.dropColumn('chat_message', 'pinned_at');
    await m.dropColumn('chat_message', 'edited_at');
    await m.renameColumn('chat_message', 'sent_at', 'created_at');
    await m.dropTable('chat_read_position');
    await m.dropTable('chat_message_reaction');
    await m.dropTable('chat_message_attachment');
    await m.createIndex(
      'chat_message',
      DwIndexSchema('chat_message_channel_id_created_at_id_idx', [
        'channel_id',
        'created_at',
        'id',
      ]),
    );
  }
}
