// Maintained by `migrate create`: one entry per migration file in this
// directory, in id order.
import 'package:dartway_core_server/dartway_core_server.dart';

import 'package:dartway_starter_server/src/migrations/m20260914_204255_initial.dart';
import 'package:dartway_starter_server/src/migrations/m20260929_221916_settings_in_framework.dart';
import 'package:dartway_starter_server/src/migrations/m20261022_033246_relation_indexes.dart';

final List<DwDatabaseMigration> appMigrations = [
  const M20260914204255Initial(),
  const M20260929221916SettingsInFramework(),
  const M20261022033246RelationIndexes(),
];
