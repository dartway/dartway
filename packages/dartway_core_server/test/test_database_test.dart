import 'dart:io';

import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'plain dart test retains default and custom database prefixes',
    () async {
      expect(
        Platform.environment['DW_TEST_RUN_ID'],
        isNull,
        reason: 'this suite proves the plain dart test mode',
      );
      for (final prefix in ['dw_test', 'custom_test']) {
        final database = prefix == 'dw_test'
            ? await DwTestDatabase.create()
            : await DwTestDatabase.create(prefix: prefix);
        try {
          expect(database.config.name, matches('^${prefix}_[a-z0-9]{10}\$'));
        } finally {
          await database.drop();
        }
      }
    },
  );
}
