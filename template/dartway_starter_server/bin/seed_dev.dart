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
/// `dart run bin/seed_dev.dart` from this package, against the database
/// `deploy/config.yaml > local` names. Never against production: the personas'
/// fixed code is access to their accounts.
///
/// One transaction, because `runInContext` is one: a seed that failed
/// half-way would otherwise leave half of itself behind.
///
/// It brings up **this project's own server** on a port nobody listens to and
/// does its work in a real context, so the accounts are created by the
/// project's real `DwAuthConfig` — the same `onAccountCreated` that a sign-in
/// runs. A seed that declared an auth configuration of its own would be a
/// second copy of it, and the copy is wrong the first time the real one gains
/// a field.
Future<void> main() async {
  final env = DwLocalEnvironment.overlay(Platform.environment);
  final server = DartwayStarterServer.build(
    database: DwDatabaseConfig.fromEnvironment(env),
    // The same storage the real server is configured with: a server built
    // without it declares no file jobs, and the job runner would drop the
    // recurring rows of the one that does.
    storage: AppFiles.storageConfig(env),
    // Bound to whatever port is free: the seed serves nobody, it only needs
    // what a server has — a migrated database, the project's auth, a context.
    port: 0,
  );
  await server.start();
  try {
    await server.runInContext(_seed, scope: 'seed');
  } finally {
    await server.stop();
  }
}

Future<void> _seed(DwCallContext ctx) async {
  if (await ctx.db.userProfiles.exists(
    where: (t) => t.testVerificationCode.isNotNull(),
  )) {
    ctx.log.info('already seeded');
    return;
  }

  Future<void> persona(
    String identifier,
    String firstName, {
    String? lastName,
    UserRole role = UserRole.user,
    bool fixedCode = false,
    bool marketing = false,
  }) async {
    final (:accountId, created: _) = await ctx.accounts.ensure(
      DwIdentifierKind.of(identifier),
      identifier,
    );
    final profile = (await ctx.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    ))!;
    await ctx.db.userProfiles.update(
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

  ctx.log.info(
    'seeded: admin 79990000001, members 79990000002 and boris@example.com '
    '— code $personaCode; 15 more members for the admin table',
  );
}
