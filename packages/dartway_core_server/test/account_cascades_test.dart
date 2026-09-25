import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Deleting an account is part of every server. What it takes with it is the
/// project's own foreign keys — and a project learns that here, at startup,
/// not from its stand.
void main() {
  late DwTestDatabase database;

  setUp(() async {
    database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'cascades_test',
    );
  });
  tearDown(() => database.drop());

  /// A server over [migration], with [onAccountDeleting] or without it.
  Future<DwTestServer> start(
    DwDatabaseMigration migration, {
    Future<void> Function(DwCallContext ctx, int accountId)? onAccountDeleting,
  }) {
    final app = TestApp();
    return DwTestServer.start(
      app.server(
        database.config,
        migrations: [migration],
        auth: DwAuthConfig(
          accountDeletion: DwAccountDeletion.byMember,
          normalize: (kind, raw) => raw.trim().toLowerCase(),
          deliverCode: (ctx, kind, identifier, code, accountId) async {},
          onAccountDeleting: onAccountDeleting,
        ),
      ),
    );
  }

  test('a project whose rows hang off the account and says nothing about '
      'deletion does not start, and the tables are named — all of them, '
      'not just the one that names dw_account', () async {
    await expectLater(
      start(const _CascadingSchema()),
      throwsA(
        isA<DwStartupException>().having(
          (e) => e.toString(),
          'problems',
          allOf(
            contains('user_profile'),
            contains('survey_answer'),
            contains('onAccountDeleting'),
            // The path, not only the name: a table hanging off the profile
            // rather than off the account is where somebody else's rows turn
            // up, and the shape says so without anyone knowing the domain.
            contains('dw_account → user_profile'),
            contains('dw_account → user_profile → survey_answer'),
            // The question anybody reading that list asks next is who to
            // tell; the answer is not what to publish but that publishing
            // from here is possible at all.
            contains('ctx.publish'),
          ),
        ),
      ),
    );
  });

  test('with the deletion declared, it starts and says on every start what '
      'goes with an account', () async {
    RecordingLogger.lines.clear();
    final server = await start(
      const _CascadingSchema(),
      onAccountDeleting: (ctx, accountId) async {},
    );
    addTearDown(server.stop);
    final said = RecordingLogger.lines.join('\n');
    expect(said, contains('deleting an account also deletes'));
    expect(said, contains('dw_account → user_profile'));
    expect(said, contains('dw_account → user_profile → survey_answer'));
  });

  test('two tables on the account are two paths of one hop, and neither is '
      'shown under the other', () async {
    // What a flat list invites: a reviewer and an author disagreed about how
    // two such tables were connected, and the author's answer — one under the
    // other — was wrong. A path cannot be read that way.
    RecordingLogger.lines.clear();
    final server = await start(
      const _TwoOnTheAccountSchema(),
      onAccountDeleting: (ctx, accountId) async {},
    );
    addTearDown(server.stop);
    final said = RecordingLogger.lines.join('\n');
    expect(said, contains('dw_account → push_device'));
    expect(said, contains('dw_account → push_delivery'));
    expect(said, isNot(contains('push_device → push_delivery')));
  });

  test('a project that points at the account without a cascade is not asked '
      'anything: nothing of its own would go', () async {
    final server = await start(const _NoCascadeSchema());
    addTearDown(server.stop);
    expect(server.port, greaterThan(0), reason: 'it is serving');
  });

  test("the framework's own rows are not the project's business", () async {
    // `dw_identity`, `dw_auth_key` and the rest cascade by design, and a
    // project that has nothing of its own hears nothing about them.
    RecordingLogger.lines.clear();
    final server = await start(
      const _NoCascadeSchema(),
      onAccountDeleting: (ctx, accountId) async {},
    );
    addTearDown(server.stop);
    expect(RecordingLogger.lines.join('\n'), isNot(contains('dw_identity')));
  });
}

/// A profile hanging off the account, and answers hanging off the profile —
/// the shape that emptied a project's survey data on its first deletion.
final class _CascadingSchema extends DwDatabaseMigration {
  const _CascadingSchema();

  @override
  String get id => '20260918_000000_cascading_schema';

  @override
  String get checksum => 'cascading-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('''
    CREATE TABLE user_profile (
      id bigserial PRIMARY KEY,
      account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE
    );
    CREATE TABLE survey_answer (
      id bigserial PRIMARY KEY,
      profile_id bigint NOT NULL REFERENCES user_profile (id) ON DELETE CASCADE,
      answer text NOT NULL
    );
  ''');

  @override
  Future<void> down(DwMigrationContext m) =>
      m.sql('DROP TABLE survey_answer, user_profile');
}

final class _NoCascadeSchema extends DwDatabaseMigration {
  const _NoCascadeSchema();

  @override
  String get id => '20260918_000000_no_cascade_schema';

  @override
  String get checksum => 'no-cascade-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('''
    CREATE TABLE user_profile (
      id bigserial PRIMARY KEY,
      account_id bigint REFERENCES dw_account (id) ON DELETE SET NULL
    );
  ''');

  @override
  Future<void> down(DwMigrationContext m) => m.sql('DROP TABLE user_profile');
}

/// Two tables hanging off the account by their own keys, with nothing between
/// them — the shape whose connection was guessed wrong from a flat list.
final class _TwoOnTheAccountSchema extends DwDatabaseMigration {
  const _TwoOnTheAccountSchema();

  @override
  String get id => '20260918_000000_two_on_the_account';

  @override
  String get checksum => 'two-on-the-account-1';

  @override
  Future<void> up(DwMigrationContext m) => m.sql('''
    CREATE TABLE push_device (
      id bigserial PRIMARY KEY,
      account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE
    );
    CREATE TABLE push_delivery (
      id bigserial PRIMARY KEY,
      account_id bigint NOT NULL REFERENCES dw_account (id) ON DELETE CASCADE,
      device_ids bigint[] NOT NULL DEFAULT '{}'
    );
  ''');

  @override
  Future<void> down(DwMigrationContext m) =>
      m.sql('DROP TABLE push_delivery, push_device');
}
