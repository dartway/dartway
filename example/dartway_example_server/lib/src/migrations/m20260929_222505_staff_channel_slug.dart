// dart format off
// Draft written by `migrate create`. Review it before applying:
// from now on it is an ordinary migration, and it is yours.
import 'package:dartway_core_server/dartway_core_server.dart';

final class M20260929222505StaffChannelSlug extends DwDatabaseMigration {
  const M20260929222505StaffChannelSlug();

  @override
  String get id => '20260929_222505_staff_channel_slug';

  @override
  String get checksum => '97d7c9a625f8e2080cb756da0fbe1981';

  @override
  Future<void> up(DwMigrationContext m) async {
    await m.addColumn(
      'chat_channel',
      DwColumnSchema('slug', 'text', nullable: true, unique: true),
    );
    // The seed step finds a channel by its slug. A channel that exists
    // already takes the slug of its title — `Front desk` → `front-desk` —
    // which is the slug the seed declares for it, so the seed adopts it
    // rather than adding a second one. Separators at the ends are dropped
    // (`Coaches!` → `coaches`), a title with no letter or digit becomes
    // `channel`, and a slug two titles share is kept by the oldest channel,
    // the others taking their id after it — so no title can fail this.
    await m.backfill(r"""
UPDATE chat_channel AS channel SET slug = numbered.slug
FROM (
  SELECT id,
         CASE WHEN row_number() OVER (PARTITION BY base ORDER BY id) = 1
              THEN base ELSE base || '-' || id END AS slug
  FROM (
    SELECT id,
           coalesce(nullif(trim(BOTH '-' FROM
             lower(regexp_replace(title, '[^A-Za-z0-9]+', '-', 'g'))), ''),
             'channel') AS base
    FROM chat_channel
  ) AS based
) AS numbered
WHERE channel.id = numbered.id""");
    await m.alterColumnNullability('chat_channel', 'slug', nullable: false);
  }

  @override
  Future<void> down(DwMigrationContext m) async {
    await m.dropColumn('chat_channel', 'slug');
  }
}
