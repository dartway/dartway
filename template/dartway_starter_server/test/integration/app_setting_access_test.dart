import 'package:dartway_starter_server/src/crud/app_setting_crud_config.dart';
import 'package:dartway_starter_server/src/dartway/dartway_core.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The starting point for testing a **rule** in this project.
///
/// `appSettingCrudConfig` says who may write a setting and what makes one
/// valid. That rule runs inside a request and reads the database to answer, so
/// nothing below the server can hold it: a widget test proving the admin panel
/// hides the field proves only that the field is hidden. Copy the shape of this
/// file when a CRUD config grows a rule of its own.
///
/// It runs against a live database, and the run makes its own: `dartway test`
/// from the project root. See the `dartway-testing` skill for which layer a
/// test belongs to.
const _testKey = 'appSettingAccessTest.appName';

void main() {
  withServerpod('Given the app settings CRUD config', (
    sessionBuilder,
    endpoints,
  ) {
    late Session adminSession;
    late Session memberSession;

    setUp(() async {
      // `withServerpod` builds its own Serverpod and never calls `run`, so
      // DartWay has to be booted here — the config's `session.isAdmin` resolves
      // the profile through the core.
      initDartwayCore(
        passwords: const {
          'dwVerificationCodeSalt': 'test-verification-code-salt',
          'dwAuthKeySalt': 'test-auth-key-salt',
        },
      );

      final setupSession = sessionBuilder.build();
      await _wipeTables(setupSession);

      final admin = await _seedProfile(
        setupSession,
        identifier: '+70000000010',
        role: UserRole.admin,
      );
      final member = await _seedProfile(
        setupSession,
        identifier: '+70000000011',
        role: UserRole.user,
      );

      adminSession = _signedInAs(sessionBuilder, admin);
      memberSession = _signedInAs(sessionBuilder, member);
    });

    tearDown(() async => _wipeTables(sessionBuilder.build()));

    test('the admin writes a setting, and the row lands', () async {
      final response = await appSettingCrudConfig.saveConfig!.save(
        adminSession,
        AppSetting(settingKey: _testKey, settingValue: 'Acme'),
      );

      expect(response.isOk, isTrue);
      final stored = await AppSetting.db.find(
        adminSession,
        where: (row) => row.settingKey.equals(_testKey),
      );
      expect(stored.single.settingValue, 'Acme');
    });

    test('a signed-in member is refused, and nothing is written', () async {
      final response = await appSettingCrudConfig.saveConfig!.save(
        memberSession,
        AppSetting(settingKey: _testKey, settingValue: 'Not allowed'),
      );

      expect(response.isOk, isFalse);
      expect(
        await AppSetting.db.find(
          memberSession,
          where: (row) => row.settingKey.equals(_testKey),
        ),
        isEmpty,
        reason: 'a refused save must not reach the table',
      );
    });

    test('an empty key is rejected even for the admin', () async {
      final response = await appSettingCrudConfig.saveConfig!.save(
        adminSession,
        AppSetting(settingKey: '   ', settingValue: 'Acme'),
      );

      expect(response.isOk, isFalse);
      expect(response.error, isNotNull);
    });
  });
}

Session _signedInAs(TestSessionBuilder sessionBuilder, UserProfile profile) =>
    sessionBuilder
        .copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            '${profile.id!}',
            {},
          ),
        )
        .build();

Future<UserProfile> _seedProfile(
  Session session, {
  required String identifier,
  required UserRole role,
}) => UserProfile.db.insertRow(
  session,
  UserProfile(
    userIdentifier: identifier,
    phone: identifier,
    firstName: 'Test',
    role: role,
    agreedForMarketingCommunications: false,
    conditionsAcceptedAt: DateTime.now().toUtc(),
  ),
);

Future<void> _wipeTables(Session session) async {
  await AppSetting.db.deleteWhere(session, where: (_) => Constant.bool(true));
  await UserProfile.db.deleteWhere(session, where: (_) => Constant.bool(true));
}
