import 'package:dartway_example_server/src/dartway/dartway_core.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import 'test_tools/serverpod_test_tools.dart';

/// A CRUD config whose save hooks read the caller's profile is the ordinary
/// shape — it is what every config does when the server stamps the author
/// itself rather than trusting the client to send it. This file exists because
/// that shape used to be untestable.
///
/// `beforeSaveTransaction` runs **inside** the save transaction. Until 0.7.0 the
/// profile reads on `dw` had no way to be told about it, so they went to the
/// database on their own connection. In production that is a second query; here
/// it is fatal, and deliberately so: this group runs with the default
/// `rollbackDatabase`, under which the test proxy sees a call that arrives
/// without the active transaction, calls it concurrent, and throws
/// `Concurrent database calls outside an already active transaction are not
/// supported when database rollbacks are enabled`.
///
/// Hence the default rollback here — the point is not that these reads work,
/// it is that a config built this way can be driven through `save()` by a test
/// at all. Note the contrast with the neighbouring files, which switch rollback
/// off because they observe races that must genuinely commit.
void main() {
  // Before anything registers: a missing database is knowable here, and
  // `withServerpod` silences the output that would have said so.
  requireTestDatabase();

  withServerpod(
    'Given save hooks that read the caller profile inside the transaction',
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
        'all three profile reads answer through saveContext.transaction',
        () async {
          final session = sessionBuilder.build();
          final author = await UserProfile.db.insertRow(
            session,
            UserProfile(
              userIdentifier: _identifier,
              phone: _identifier,
              firstName: 'Author',
              role: UserRole.staff,
              agreedForMarketingCommunications: false,
              conditionsAcceptedAt: DateTime.now().toUtc(),
            ),
          );
          final authored = sessionBuilder
              .copyWith(
                authentication: AuthenticationOverride.authenticationInfo(
                  '${author.id!}',
                  {},
                ),
              )
              .build();

          UserProfile? current;
          UserProfile? byId;
          UserProfile? byIdentifier;

          final response =
              await DwSaveConfig<AppSetting>(
                allowSave: (session, saveContext) async => true,
                beforeSaveTransaction: (session, saveContext) async {
                  final transaction = saveContext.transaction;
                  current = await dw.currentUserProfile(
                    session,
                    transaction: transaction,
                  );
                  byId = await dw.getUserProfile(
                    session,
                    saveContext.currentUserId!,
                    transaction: transaction,
                  );
                  byIdentifier = await dw.getUserProfileByIdentifier(
                    session,
                    _identifier,
                    transaction: transaction,
                  );
                  return null;
                },
                // The same read after the write, still inside the transaction: the
                // second hook is where an audit row or a counter would be updated,
                // and it hits the same wall.
                afterSaveTransaction: (session, saveContext) async {
                  final seen = await dw.currentUserProfile(
                    session,
                    transaction: saveContext.transaction,
                  );
                  return seen == null ? 'The author vanished mid-save' : null;
                },
              ).save(
                authored,
                AppSetting(settingKey: _settingKey, settingValue: 'stamped'),
              );

          expect(response.isOk, isTrue, reason: response.error);
          expect(current?.id, author.id);
          expect(byId?.id, author.id);
          expect(byIdentifier?.id, author.id);
        },
      );

      test(
        'a hook sees a profile the same transaction has not committed yet',
        () async {
          final session = sessionBuilder.build();
          final settled =
              await DwSaveConfig<AppSetting>(
                allowSave: (session, saveContext) async => true,
                beforeSaveTransaction: (session, saveContext) async {
                  // Written inside the save transaction and invisible to anything
                  // reading around it — which is the other half of why the reads
                  // take a transaction, and the half that also bites in production.
                  final latecomer = await UserProfile.db.insertRow(
                    session,
                    UserProfile(
                      userIdentifier: _latecomerIdentifier,
                      phone: _latecomerIdentifier,
                      firstName: 'Latecomer',
                      role: UserRole.client,
                      agreedForMarketingCommunications: false,
                      conditionsAcceptedAt: DateTime.now().toUtc(),
                    ),
                    transaction: saveContext.transaction,
                  );

                  final read = await dw.getUserProfile(
                    session,
                    latecomer.id!,
                    transaction: saveContext.transaction,
                  );
                  return read == null
                      ? 'Uncommitted profile not visible'
                      : null;
                },
              ).save(
                session,
                AppSetting(settingKey: _latecomerKey, settingValue: 'stamped'),
              );

          expect(settled.isOk, isTrue, reason: settled.error);
        },
      );
    },
    runMode: 'test',
    applyMigrations: true,
    // Left at the default on purpose — see the note above. Everything these
    // tests write is rolled back with it, so they need no cleanup of their own.
    testServerOutputMode: testServerOutputMode,
  );
}

const _identifier = '+79990002000';
const _latecomerIdentifier = '+79990002001';
const _settingKey = 'dw_core_profile_transaction_test_authored';
const _latecomerKey = 'dw_core_profile_transaction_test_latecomer';
