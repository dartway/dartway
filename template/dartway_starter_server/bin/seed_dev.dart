import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';
import 'package:dartway_starter_server/src/entities/people.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The code every seeded persona signs in with instead of a delivered one.
const personaCode = '111111';

/// Development data: an administrator and two members who sign in with a
/// fixed code — one by phone, one by e-mail — and enough members to page
/// through the admin table. Refuses to run twice.
///
/// `dart run bin/seed_dev.dart` against the database in `DW_DATABASE_*` — on a
/// developer's machine, the one `deploy/config.yaml > local` names — after the
/// server has migrated it once. Never against production: the personas'
/// fixed code is access to their accounts.
Future<void> main() async {
  final database = await DwPostgresDatabase.open(
    DwDatabaseConfig.fromEnvironment(
      DwLocalEnvironment.overlay(Platform.environment),
    ),
  );
  try {
    final db = database.db;
    if (await db.userProfiles.exists(
      where: (t) => t.testVerificationCode.isNotNull(),
    )) {
      stdout.writeln('Already seeded.');
      return;
    }
    // One transaction: a seed that fails half-way leaves nothing behind.
    await db.transaction((tx) async {
      // No server runs while seeding, so nobody is subscribed and nothing is
      // published: the accounts are made the way sign-in makes them, with
      // the profile alone.
      final accounts = DwAccountService(
        tx,
        DwAuthConfig(
          normalize: AuthIdentifier.normalize,
          deliverCode: (ctx, kind, identifier, code) async {},
          onAccountCreated: (ctx, accountId, kind, identifier, origin) =>
              AppAuth.createProfile(ctx, accountId, origin),
        ),
      );

      Future<void> persona(
        String identifier,
        String firstName, {
        String? lastName,
        UserRole role = UserRole.user,
        bool fixedCode = false,
        bool marketing = false,
      }) async {
        final (:accountId, created: _) = await accounts.ensure(
          AuthIdentifier.kindOf(identifier),
          identifier,
        );
        final profile = (await tx.userProfiles.findFirst(
          where: (t) => t.accountId.equals(accountId),
        ))!;
        await tx.userProfiles.update(
          profile.copyWith(
            firstName: firstName,
            lastName: lastName == null
                ? const DwFieldPatch.keep()
                : DwFieldPatch.set(lastName),
            role: role,
            agreedForMarketing: marketing,
            testVerificationCode: fixedCode
                ? const DwFieldPatch.set(personaCode)
                : const DwFieldPatch.keep(),
          ),
        );
      }

      await persona(
        '79990000001',
        'Anna',
        lastName: 'Admin',
        role: UserRole.admin,
        fixedCode: true,
      );
      await persona('79990000002', 'Vera', fixedCode: true, marketing: true);
      await persona('boris@example.com', 'Boris', fixedCode: true);
      // Members to page through: the admin table shows ten at a time.
      const names = [
        'Daria',
        'Egor',
        'Zhanna',
        'Ilya',
        'Kira',
        'Lev',
        'Maria',
        'Nikita',
        'Olga',
        'Pavel',
        'Raisa',
        'Semyon',
        'Tamara',
        'Ulyana',
        'Fedor',
      ];
      for (final (index, name) in names.indexed) {
        await persona(
          '7999100${index.toString().padLeft(4, '0')}',
          name,
          marketing: index.isEven,
        );
      }
    });
    stdout.writeln(
      'Seeded: admin 79990000001, members 79990000002 and boris@example.com '
      '— code $personaCode; 15 more members for the admin table.',
    );
  } finally {
    await database.close();
  }
}
