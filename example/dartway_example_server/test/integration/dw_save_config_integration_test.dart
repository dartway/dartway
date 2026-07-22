import 'dart:async';

import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

const _testKeyPrefix = 'dw_save_config_lock_test_';

void main() {
  withServerpod(
    'DwSaveConfig transactional update validation',
    (sessionBuilder, endpoints) {
      setUpAll(() {
        DwCore.init<UserProfile>(
          userProfileTable: UserProfile.t,
          crudConfigurations: const [],
          dtoConfigurations: const [],
          userProfileConstructor:
              (session, {required registrationRequest}) async =>
                  throw UnsupportedError(
                    'User registration is outside this test suite',
                  ),
          dwAlerts: DwAlerts.init(),
        );
      });

      setUp(() => _clearTestSettings(sessionBuilder.build()));
      tearDown(() => _clearTestSettings(sessionBuilder.build()));

      test(
        'default update path preserves the existing callback lifecycle',
        () async {
          final session = sessionBuilder.build();
          final stored = await AppSetting.db.insertRow(
            session,
            AppSetting(
              settingKey: '${_testKeyPrefix}default',
              settingValue: 'initial',
            ),
          );
          final callbackOrder = <String>[];
          DwSaveContext<AppSetting>? allowContext;
          DwSaveContext<AppSetting>? validateContext;

          final response = await DwSaveConfig<AppSetting>(
            allowSave: (session, context) async {
              callbackOrder.add('allow');
              allowContext = context;
              expect(context.transaction, isNull);
              expect(context.initialModel?.settingValue, 'initial');
              return true;
            },
            validateSave: (session, context) async {
              callbackOrder.add('validate');
              validateContext = context;
              expect(context.transaction, isNull);
              return null;
            },
            beforeSaveTransaction: (session, context) async {
              callbackOrder.add('before');
              expect(context.transaction, isNotNull);
            },
            afterSaveTransaction: (session, context) async {
              callbackOrder.add('after');
              expect(context.transaction, isNotNull);
            },
            afterSaveTransform: (session, context) async {
              callbackOrder.add('transform');
            },
          ).save(session, stored.copyWith(settingValue: 'updated'));

          expect(response.isOk, isTrue);
          expect(callbackOrder, [
            'allow',
            'validate',
            'before',
            'after',
            'transform',
          ]);
          expect(identical(allowContext, validateContext), isTrue);
          expect(
            (await AppSetting.db.findById(session, stored.id!))?.settingValue,
            'updated',
          );
        },
      );

      test(
        'opt-in update validation waits for and sees the fresh locked row',
        () async {
          final setupSession = sessionBuilder.build();
          final stored = await AppSetting.db.insertRow(
            setupSession,
            AppSetting(
              settingKey: '${_testKeyPrefix}fresh',
              settingValue: 'stale',
            ),
          );
          final rowLock = await _holdUpdatedSettingRow(
            sessionBuilder.build(),
            settingId: stored.id!,
            settingValue: 'fresh',
          );
          final callbacksEntered = Completer<void>();
          DwSaveContext<AppSetting>? allowContext;
          DwSaveContext<AppSetting>? validateContext;

          final saveFuture =
              DwSaveConfig<AppSetting>(
                lockInitialModelForUpdate: true,
                allowSave: (session, context) async {
                  allowContext = context;
                  expect(context.transaction, isNotNull);
                  if (!callbacksEntered.isCompleted) {
                    callbacksEntered.complete();
                  }
                  return true;
                },
                validateSave: (session, context) async {
                  validateContext = context;
                  expect(context.transaction, isNotNull);
                  return null;
                },
              ).save(
                sessionBuilder.build(),
                stored.copyWith(settingValue: 'requested'),
              );

          try {
            await _waitForLockedSettingReader(sessionBuilder.build());
            expect(callbacksEntered.isCompleted, isFalse);

            rowLock.release();
            await rowLock.completion.timeout(const Duration(seconds: 5));
            final response = await saveFuture.timeout(
              const Duration(seconds: 5),
            );

            expect(response.isOk, isTrue);
            expect(allowContext?.initialModel?.settingValue, 'fresh');
            expect(validateContext?.initialModel?.settingValue, 'fresh');
            expect(identical(allowContext, validateContext), isTrue);
            expect(
              identical(
                allowContext?.initialModel,
                validateContext?.initialModel,
              ),
              isTrue,
            );
            expect(
              (await AppSetting.db.findById(
                setupSession,
                stored.id!,
              ))?.settingValue,
              'requested',
            );
          } finally {
            rowLock.release();
            await rowLock.completion.timeout(const Duration(seconds: 5));
            await saveFuture.timeout(const Duration(seconds: 5));
          }
        },
      );

      test(
        'opt-in flag leaves insert validation before the transaction',
        () async {
          final session = sessionBuilder.build();
          DwSaveContext<AppSetting>? allowContext;
          DwSaveContext<AppSetting>? validateContext;

          final response =
              await DwSaveConfig<AppSetting>(
                lockInitialModelForUpdate: true,
                allowSave: (session, context) async {
                  expect(context.transaction, isNull);
                  allowContext = context;
                  return true;
                },
                validateSave: (session, context) async {
                  expect(context.transaction, isNull);
                  validateContext = context;
                  return null;
                },
              ).save(
                session,
                AppSetting(
                  settingKey: '${_testKeyPrefix}insert',
                  settingValue: 'inserted',
                ),
              );

          expect(response.isOk, isTrue);
          expect(allowContext?.isInsert, isTrue);
          expect(allowContext?.initialModel, isNull);
          expect(allowContext?.transaction, isNotNull);
          expect(identical(allowContext, validateContext), isTrue);
        },
      );

      test('opt-in authorization denial does not update the row', () async {
        final session = sessionBuilder.build();
        final stored = await AppSetting.db.insertRow(
          session,
          AppSetting(
            settingKey: '${_testKeyPrefix}denied',
            settingValue: 'initial',
          ),
        );
        var beforeSaveCalled = false;

        final response = await DwSaveConfig<AppSetting>(
          lockInitialModelForUpdate: true,
          allowSave: (session, context) async {
            expect(context.transaction, isNotNull);
            return false;
          },
          beforeSaveTransaction: (session, context) async {
            beforeSaveCalled = true;
          },
        ).save(session, stored.copyWith(settingValue: 'forbidden'));

        expect(response.isOk, isFalse);
        expect(beforeSaveCalled, isFalse);
        expect(
          (await AppSetting.db.findById(session, stored.id!))?.settingValue,
          'initial',
        );
      });

      test('opt-in validation failure does not update the row', () async {
        final session = sessionBuilder.build();
        final stored = await AppSetting.db.insertRow(
          session,
          AppSetting(
            settingKey: '${_testKeyPrefix}invalid',
            settingValue: 'initial',
          ),
        );
        var beforeSaveCalled = false;

        final response = await DwSaveConfig<AppSetting>(
          lockInitialModelForUpdate: true,
          allowSave: (session, context) async => true,
          validateSave: (session, context) async {
            expect(context.transaction, isNotNull);
            return 'validation failed';
          },
          beforeSaveTransaction: (session, context) async {
            beforeSaveCalled = true;
          },
        ).save(session, stored.copyWith(settingValue: 'invalid'));

        expect(response.isOk, isFalse);
        expect(response.error, 'validation failed');
        expect(beforeSaveCalled, isFalse);
        expect(
          (await AppSetting.db.findById(session, stored.id!))?.settingValue,
          'initial',
        );
      });

      test(
        'opt-in update returns not found when the row disappeared',
        () async {
          final session = sessionBuilder.build();
          final stored = await AppSetting.db.insertRow(
            session,
            AppSetting(
              settingKey: '${_testKeyPrefix}missing',
              settingValue: 'initial',
            ),
          );
          await AppSetting.db.deleteRow(session, stored);
          var allowSaveCalled = false;

          final response = await DwSaveConfig<AppSetting>(
            lockInitialModelForUpdate: true,
            allowSave: (session, context) async {
              allowSaveCalled = true;
              return true;
            },
          ).save(session, stored.copyWith(settingValue: 'updated'));

          expect(response.isOk, isFalse);
          expect(response.error, contains('not found'));
          expect(allowSaveCalled, isFalse);
          expect(await AppSetting.db.findById(session, stored.id!), isNull);
        },
      );

      test(
        'database errors return a stable response without database details',
        () async {
          final session = sessionBuilder.build();
          final stored = await AppSetting.db.insertRow(
            session,
            AppSetting(
              settingKey: '${_testKeyPrefix}database_error_source',
              settingValue: 'initial',
            ),
          );
          final conflictingKey = '${_testKeyPrefix}database_error_conflict';
          await AppSetting.db.insertRow(
            session,
            AppSetting(settingKey: conflictingKey, settingValue: 'existing'),
          );

          final response = await DwSaveConfig<AppSetting>(
            allowSave: (session, context) async => true,
          ).save(session, stored.copyWith(settingKey: conflictingKey));

          expect(response.isOk, isFalse);
          expect(response.error, 'Database error during save');
          expect(response.error, isNot(contains('app_setting_key_unique_idx')));
          expect(response.error, isNot(contains(conflictingKey)));
        },
      );
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

Future<void> _clearTestSettings(Session session) async {
  await session.db.unsafeExecute('''
DELETE FROM "app_setting"
WHERE "settingKey" LIKE @keyPrefix
''', parameters: QueryParameters.named({'keyPrefix': '$_testKeyPrefix%'}));
}

Future<_HeldRowLock> _holdUpdatedSettingRow(
  Session session, {
  required int settingId,
  required String settingValue,
}) async {
  final held = Completer<void>();
  final release = Completer<void>();
  final completion = session.db.transaction((transaction) async {
    final setting = await AppSetting.db.findById(
      session,
      settingId,
      transaction: transaction,
      lockMode: LockMode.forUpdate,
    );
    await AppSetting.db.updateRow(
      session,
      setting!.copyWith(settingValue: settingValue),
      transaction: transaction,
    );
    held.complete();
    await release.future;
  });
  await held.future;
  return _HeldRowLock(release, completion);
}

Future<void> _waitForLockedSettingReader(Session session) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final result = await session.db.unsafeQuery('''
SELECT EXISTS (
  SELECT 1
  FROM pg_stat_activity
  WHERE datname = current_database()
    AND wait_event_type = 'Lock'
    AND query LIKE '%FROM "app_setting"%'
    AND query LIKE '%FOR UPDATE%'
)
''');
    if (result.single.single == true) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Timed out waiting for DwSaveConfig row lock');
}

final class _HeldRowLock {
  _HeldRowLock(this._release, this.completion);

  final Completer<void> _release;
  final Future<void> completion;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }
}
