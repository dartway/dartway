// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929222505StaffChannelSlug extends DwDatabaseMigration {
  const M20260929222505StaffChannelSlug();

  @override
  String get id => '20260929_222505_staff_channel_slug';

  @override
  String get checksum => '777f12ca5dbbeb3748e6702239a6cd71';

  @override
  Future<void> up(DwMigrationContext m) async {
    // The seed step finds a channel by its slug. A channel that exists
    // already takes the slug of its title — `Front desk` → `front-desk` —
    // which is the slug the seed declares for it, so the seed adopts it
    // rather than adding a second one.
    await m.addColumn(
      'chat_channel',
      DwColumnSchema('slug', 'text', unique: true),
      backfill: r"lower(regexp_replace(title, '[^A-Za-z0-9]+', '-', 'g'))",
    );
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropColumn('chat_channel', 'slug');
  }
}
