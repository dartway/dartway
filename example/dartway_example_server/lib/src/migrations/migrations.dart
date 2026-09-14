// Maintained by `migrate create`: one entry per migration file in this
// directory, in id order.
import 'package:dartway_core_server/dartway_core_server.dart';

import 'm20260914_131904_initial.dart';
import 'm20260914_183459_chat.dart';

final List<DwDatabaseMigration> appMigrations = [
  const M20260914131904Initial(),
  const M20260914183459Chat(),
];
