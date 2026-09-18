import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart'
    show DwTestDatabase, DwTestServer;
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
          normalize: (kind, raw) => raw.trim().toLowerCase(),
          deliverCode: (ctx, kind, identifier, code) async {},
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
    expect(said, contains('user_profile'));
    expect(said, contains('survey_answer'));
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
