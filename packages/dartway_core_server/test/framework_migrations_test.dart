import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// The framework's migrations against databases that are not empty: the ones
/// development runs of the rewrite left behind.
///
/// `dw_stored_file` gained its `bucket` when uploads moved to two buckets. The
/// first text of that migration added the column `NOT NULL` outright and
/// failed on any table that already held a file, and the database stayed
/// where it was, unable to start. Its correction must do two things at once:
/// migrate a table with rows — once the bucket those rows really are in is
/// recorded, since no migration can know it — and leave every database that
/// applied the first text exactly as it is.
void main() {
  late DwTestDatabase database;
  late DwPostgresDatabase opened;

  setUp(() async {
    database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    opened = await DwPostgresDatabase.open(database.config);
  });
  tearDown(() async {
    await opened.close();
    await database.drop();
  });

  final framework = DwAppServer.frameworkMigrations;
  DwDatabaseMigration named(String id) =>
      framework.singleWhere((migration) => migration.id == id);
  final bucket = named('20260914_180000_dw_stored_file_bucket');
  List<DwDatabaseMigration> upTo(String id) => [
    for (final migration in framework)
      if (migration.id.compareTo(id) <= 0) migration,
  ];

  DwMigrationRunner runner(List<DwDatabaseMigration> migrations) =>
      DwMigrationRunner(opened.db, migrations: {'dw': migrations});

  Future<void> insertFile() async {
    await opened.db.execute('INSERT INTO dw_account (id) VALUES (1)');
    await opened.db.execute(
      "INSERT INTO dw_stored_file (account_id, purpose, object_key, "
      "visibility, file_name, content_type, byte_size, confirmed_at) VALUES "
      "(1, 'avatar', 'avatar/1/a.png', 'public', 'a.png', 'image/png', 10, "
      'now())',
    );
  }

  /// Columns and constraints of `dw_stored_file`, as Postgres describes them.
  Future<List<String>> storedFileShape() async => [
    for (final row in await opened.db.query(
      "SELECT column_name || ' ' || data_type || ' ' || is_nullable || ' ' || "
      "coalesce(column_default, '-') AS line FROM information_schema.columns "
      "WHERE table_name = 'dw_stored_file' ORDER BY column_name",
    ))
      row['line']! as String,
    for (final row in await opened.db.query(
      "SELECT conname || ' ' || pg_get_constraintdef(oid) AS line "
      "FROM pg_constraint WHERE conrelid = 'dw_stored_file'::regclass "
      'ORDER BY conname',
    ))
      row['line']! as String,
  ];

  test('a table holding files stops the migration and says what to '
      'record, and migrates once it is recorded', () async {
    await runner(upTo('20260914_000000_dw_stored_file')).apply();
    await insertFile();

    await expectLater(
      runner(framework).apply(),
      throwsA(
        isA<DwMigrationFailed>().having(
          (failure) => '$failure',
          'text',
          allOf(
            contains('20260914_180000_dw_stored_file_bucket'),
            contains('1 rows of dw_stored_file were uploaded before'),
            contains('DW_STORAGE_BUCKET'),
            contains("UPDATE dw_stored_file SET bucket = '<that bucket>'"),
          ),
        ),
      ),
    );
    final statuses = await runner(framework).status();
    expect({
      for (final status in statuses) status.ref.id: status.state,
    }, containsPair(bucket.id, DwMigrationState.pending));

    // What the failure says to run, with the bucket the files are in.
    await opened.db.execute(
      'ALTER TABLE dw_stored_file ADD COLUMN bucket text; '
      "UPDATE dw_stored_file SET bucket = 'club';",
    );
    final run = await runner(framework).apply();
    expect(run.migrations.map((ref) => ref.id), [
      bucket.id,
      '20260914_220000_dw_keys_and_identities',
    ]);
    expect(
      (await opened.db.query(
        'SELECT bucket FROM dw_stored_file',
      )).map((row) => row['bucket']),
      ['club'],
    );
    await expectLater(
      opened.db.execute(
        "INSERT INTO dw_stored_file (account_id, purpose, object_key, "
        "visibility, file_name, content_type, byte_size) VALUES "
        "(1, 'avatar', 'avatar/1/b.png', 'public', 'b.png', 'image/png', 10)",
      ),
      throwsA(anything),
      reason: 'a file without a bucket is refused from here on',
    );
  });

  test('an empty table migrates without being asked anything', () async {
    await runner(upTo('20260914_000000_dw_stored_file')).apply();
    final run = await runner(framework).apply();
    expect(run.migrations.map((ref) => ref.id), contains(bucket.id));
  });

  test('a database that applied the first text keeps its ledger row, and '
      'is left what the correction leaves', () async {
    await runner(framework).apply();
    final corrected = await storedFileShape();
    await database.drop();
    await opened.close();

    database = await DwTestDatabase.create(
      admin: adminConfig(),
      prefix: 'server_test',
    );
    opened = await DwPostgresDatabase.open(database.config);
    await runner([
      ...upTo('20260914_000000_dw_stored_file'),
      const _FirstBucketText(),
    ]).apply();
    expect(
      bucket.supersededChecksums,
      contains(const _FirstBucketText().checksum),
      reason: 'the correction accepts exactly the text it replaces',
    );

    final run = await runner(framework).apply();
    expect(run.migrations.map((ref) => ref.id), [
      '20260914_220000_dw_keys_and_identities',
    ]);
    expect(
      (await runner(framework).status()).map((status) => status.state),
      everyElement(DwMigrationState.applied),
    );
    expect(await storedFileShape(), corrected);
  });
}

/// `20260914_180000_dw_stored_file_bucket` as it was first written and
/// applied, sealed the way the framework seals its SQL migrations.
final class _FirstBucketText extends DwDatabaseMigration {
  const _FirstBucketText();

  static const _up = [
    'ALTER TABLE dw_stored_file ADD COLUMN bucket text NOT NULL',
    'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object_key',
    'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object '
        'UNIQUE (bucket, object_key)',
  ];
  static const _down = [
    'ALTER TABLE dw_stored_file DROP CONSTRAINT dw_stored_file_object',
    'ALTER TABLE dw_stored_file ADD CONSTRAINT dw_stored_file_object_key '
        'UNIQUE (object_key)',
    'ALTER TABLE dw_stored_file DROP COLUMN bucket',
  ];

  @override
  String get id => '20260914_180000_dw_stored_file_bucket';

  @override
  String get checksum => sha256
      .convert(utf8.encode([..._up, '--down--', ..._down].join(';\n')))
      .toString();

  @override
  Future<void> up(DwMigrationContext m) async {
    for (final statement in _up) {
      await m.sql(statement);
    }
  }
}
