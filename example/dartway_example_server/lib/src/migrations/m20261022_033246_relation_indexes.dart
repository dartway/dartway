// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20261022033246RelationIndexes extends DwDatabaseMigration {
  const M20261022033246RelationIndexes();

  @override
  String get id => '20261022_033246_relation_indexes';

  @override
  String get checksum => '23eb8abc40e6e77b5649da5768757d64';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.createIndex(
      'chat_message',
      DwIndexSchema('chat_message_author_profile_id_idx', [
        'author_profile_id',
      ]),
    );
    await m.createIndex(
      'chat_message',
      DwIndexSchema('chat_message_pinned_by_profile_id_idx', [
        'pinned_by_profile_id',
      ]),
    );
    await m.createIndex(
      'chat_message',
      DwIndexSchema('chat_message_reply_to_message_id_idx', [
        'reply_to_message_id',
      ]),
    );
    await m.createIndex(
      'chat_message_reaction',
      DwIndexSchema('chat_message_reaction_profile_id_idx', ['profile_id']),
    );
    await m.createIndex(
      'chat_read_position',
      DwIndexSchema('chat_read_position_channel_id_idx', ['channel_id']),
    );
    await m.createIndex(
      'chat_read_position',
      DwIndexSchema('chat_read_position_message_id_idx', ['message_id']),
    );
    await m.createIndex(
      'club_session',
      DwIndexSchema('club_session_coach_profile_id_idx', ['coach_profile_id']),
    );
    await m.createIndex(
      'club_session',
      DwIndexSchema('club_session_service_id_idx', ['service_id']),
    );
    await m.createIndex(
      'news_post',
      DwIndexSchema('news_post_author_profile_id_idx', ['author_profile_id']),
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropIndex('news_post_author_profile_id_idx');
    await m.dropIndex('club_session_service_id_idx');
    await m.dropIndex('club_session_coach_profile_id_idx');
    await m.dropIndex('chat_read_position_message_id_idx');
    await m.dropIndex('chat_read_position_channel_id_idx');
    await m.dropIndex('chat_message_reaction_profile_id_idx');
    await m.dropIndex('chat_message_reply_to_message_id_idx');
    await m.dropIndex('chat_message_pinned_by_profile_id_idx');
    await m.dropIndex('chat_message_author_profile_id_idx');
  }
}
