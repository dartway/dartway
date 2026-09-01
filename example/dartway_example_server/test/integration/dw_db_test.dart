import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import 'test_tools/serverpod_test_tools.dart';

/// `dw.db(session)` is what an application reaches for when the model is a type
/// parameter — a data migration, a background cleanup, an export. Serverpod's
/// per-model repositories cannot express that, and its generic equivalents are
/// `@internal`.
///
/// So the test is written the way such code is written: through a helper that
/// knows nothing about the model it is handed.
void main() {
  // Before anything registers: a missing database is knowable here, and
  // `withServerpod` silences the output that would have said so.
  requireTestDatabase();

  withServerpod(
    'Given generic database access through dw.db',
    (sessionBuilder, endpoints) {
      setUp(() {
        initDartwayCore(
          passwords: const {
            'dwVerificationCodeSalt': 'test-verification-code-salt',
            'dwAuthKeySalt': 'test-auth-key-salt',
          },
        );
      });

      test(
        'the five operations round-trip a row of an unknown model',
        () async {
          final session = sessionBuilder.build();

          final inserted = await dw
              .db(session)
              .insertRow<AppSetting>(
                AppSetting(settingKey: _settingKey, settingValue: 'initial'),
              );
          expect(inserted.id, isNotNull);

          final updated = await dw
              .db(session)
              .updateRow<AppSetting>(
                inserted.copyWith(settingValue: 'updated'),
              );
          expect(updated.settingValue, 'updated');

          final found = await dw
              .db(session)
              .find<AppSetting>(
                where: AppSetting.t.settingKey.equals(_settingKey),
              );
          expect(found.single.settingValue, 'updated');

          expect(
            await dw
                .db(session)
                .count<AppSetting>(
                  where: AppSetting.t.settingKey.equals(_settingKey),
                ),
            1,
          );

          await dw.db(session).deleteRow<AppSetting>(updated);
          expect(
            await dw
                .db(session)
                .count<AppSetting>(
                  where: AppSetting.t.settingKey.equals(_settingKey),
                ),
            0,
          );
        },
      );

      test(
        'a caller that does not know the model still gets its rows',
        () async {
          final session = sessionBuilder.build();
          await dw
              .db(session)
              .insertRow<AppSetting>(
                AppSetting(
                  settingKey: '${_sweepPrefix}a',
                  settingValue: 'stale',
                ),
              );
          await dw
              .db(session)
              .insertRow<AppSetting>(
                AppSetting(
                  settingKey: '${_sweepPrefix}b',
                  settingValue: 'stale',
                ),
              );

          expect(
            await _sweep<AppSetting>(
              session,
              where: AppSetting.t.settingValue.equals('stale'),
            ),
            2,
          );
          expect(
            await dw
                .db(session)
                .count<AppSetting>(
                  where: AppSetting.t.settingValue.equals('stale'),
                ),
            0,
          );
        },
      );

      test('every operation can be pinned to an open transaction', () async {
        final session = sessionBuilder.build();

        // Rolled back by hand — the point is that the writes inside a
        // transaction are visible to `dw.db` reads carrying the same handle,
        // and gone once it unwinds.
        await expectLater(
          session.db.transaction((transaction) async {
            await dw
                .db(session)
                .insertRow<AppSetting>(
                  AppSetting(
                    settingKey: _transactionalKey,
                    settingValue: 'pending',
                  ),
                  transaction: transaction,
                );

            expect(
              await dw
                  .db(session)
                  .count<AppSetting>(
                    where: AppSetting.t.settingKey.equals(_transactionalKey),
                    transaction: transaction,
                  ),
              1,
            );

            throw _Abort();
          }),
          throwsA(isA<_Abort>()),
        );

        expect(
          await dw
              .db(session)
              .count<AppSetting>(
                where: AppSetting.t.settingKey.equals(_transactionalKey),
              ),
          0,
        );
      });
    },
    runMode: 'test',
    applyMigrations: true,
    // The default: everything written here is rolled back with the test.
    testServerOutputMode: testServerOutputMode,
  );
}

/// The kind of helper `dw.db` exists for: one body, any model.
Future<int> _sweep<T extends TableRow>(
  Session session, {
  required Expression where,
  Transaction? transaction,
}) async {
  final db = dw.db(session);
  final stale = await db.find<T>(where: where, transaction: transaction);
  for (final row in stale) {
    await db.deleteRow<T>(row, transaction: transaction);
  }
  return stale.length;
}

class _Abort implements Exception {}

const _settingKey = 'dw_db_test_round_trip';
const _sweepPrefix = 'dw_db_test_sweep_';
const _transactionalKey = 'dw_db_test_transactional';
