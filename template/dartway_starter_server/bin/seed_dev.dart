import 'dart:io';

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart'
    show dwAuthenticationHandler;
import 'package:serverpod/serverpod.dart';
import 'package:dartway_starter_server/src/dartway/dartway_core.dart';
import 'package:dartway_starter_server/src/generated/endpoints.dart';
import 'package:dartway_starter_server/src/generated/protocol.dart';

const _adminPhone = '79990000001';
const _userPhone = '79990000003';

/// Dev-only seed: one user per role, so you can sign in the moment the server
/// is up. Sign in with any seeded phone — the OTP code is logged to the console.
///
/// Seed your own domain here as you add models: `_ensureProfile` below is the
/// pattern — find-or-insert, so running the seed twice is safe.
Future<void> main(List<String> args) async {
  if (!args.join(' ').contains('development') &&
      !args.contains('development')) {
    stderr.writeln('seed_dev.dart runs only with: --mode development');
    exitCode = 2;
    return;
  }

  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: dwAuthenticationHandler,
  );
  initDartwayCore(passwords: pod.server.passwords);

  final session = await pod.createSession(enableLogging: false);
  try {
    await _seed(session);
    stdout.writeln('Dev seed completed. Sign in with (OTP code in console):');
    stdout.writeln(' - admin: $_adminPhone');
    stdout.writeln(' - user:  $_userPhone');
  } finally {
    await session.close();
    await pod.shutdown(exitProcess: false);
  }
}

Future<void> _seed(Session session) async {
  await _ensureProfile(session, _adminPhone, 'Alex', role: UserRole.admin);
  await _ensureProfile(session, _userPhone, 'John', role: UserRole.user);

  final settingCount = await AppSetting.db.count(
    session,
    where: (t) => t.settingKey.equals('appName'),
  );
  if (settingCount == 0) {
    await AppSetting.db.insertRow(
      session,
      AppSetting(settingKey: 'appName', settingValue: 'DartwayStarter'),
    );
  }
}

Future<UserProfile> _ensureProfile(
  Session session,
  String phone,
  String firstName, {
  required UserRole role,
  // Seeded users are the Studio demo personas, so they carry a fixed test code.
  String? testVerificationCode = '000000',
}) async {
  final existing = (await UserProfile.db.find(session,
          where: (t) => t.userIdentifier.equals(phone), limit: 1))
      .firstOrNull;
  if (existing != null) {
    if (existing.testVerificationCode != testVerificationCode) {
      existing.testVerificationCode = testVerificationCode;
      return UserProfile.db.updateRow(session, existing);
    }
    return existing;
  }

  return UserProfile.db.insertRow(
    session,
    UserProfile(
      userIdentifier: phone,
      phone: phone,
      firstName: firstName,
      role: role,
      agreedForMarketingCommunications: false,
      conditionsAcceptedAt: DateTime.now(),
      testVerificationCode: testVerificationCode,
    ),
  );
}
