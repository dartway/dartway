// Maintained by `migrate create`: one entry per migration file in this
// directory, in id order.
import 'package:dartway_core_server/dartway_core_server.dart';

import 'm20260914_131904_initial.dart';
import 'm20260914_183459_chat.dart';
import 'm20260918_062959_member_tombstone.dart';
import 'm20260929_222324_settings_in_framework.dart';
import 'm20260929_222505_staff_channel_slug.dart';

final List<DwDatabaseMigration> appMigrations = [
  const M20260914131904Initial(),
  const M20260914183459Chat(),
  const M20260918062959MemberTombstone(),
  const M20260929222324SettingsInFramework(),
  const M20260929222505StaffChannelSlug(),
];
