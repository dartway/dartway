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
///
/// Later the column went again: a file's bucket is the one the configuration
/// names for its visibility (D-136), and a table whose rows of one visibility
/// are split across buckets stops that migration until they are in one.
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
  final fromConfig = named('20261009_000002_dw_stored_file_bucket_from_config');
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
    final run = await runner(
      upTo('20261009_000001_dw_identity_provider_email'),
    ).apply();
    expect(run.migrations.map((ref) => ref.id), [
      bucket.id,
      '20260914_220000_dw_keys_and_identities',
      '20260930_000000_dw_setting',
      '20261009_000001_dw_identity_provider_email',
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
      '20260930_000000_dw_setting',
      '20261009_000001_dw_identity_provider_email',
      fromConfig.id,
    ]);
    expect(
      (await runner(framework).status()).map((status) => status.state),
      everyElement(DwMigrationState.applied),
    );
    expect(await storedFileShape(), corrected);
  });

  /// A file recorded with the bucket it was uploaded to, as the column held
  /// it before `fromConfig`.
  Future<void> insertInBucket(
    int id,
    String visibility,
    String bucket,
  ) => opened.db.execute(
    'INSERT INTO dw_stored_file (id, account_id, purpose, bucket, object_key, '
    'visibility, file_name, content_type, byte_size, confirmed_at) VALUES '
    "(@id, 1, 'avatar', @bucket, @key, @visibility, 'a.png', 'image/png', 10, "
    'now())',
    params: {
      'id': id,
      'bucket': bucket,
      'key': 'avatar/1/$id.png',
      'visibility': visibility,
    },
  );

  Future<List<Map<String, Object?>>> storedFiles() async => [
    for (final row in await opened.db.query(
      'SELECT id, visibility, object_key FROM dw_stored_file ORDER BY id',
    ))
      {
        'id': row['id'],
        'visibility': row['visibility'],
        'object_key': row['object_key'],
      },
  ];

  test('one bucket per visibility drops the column and keeps the rows, '
      'each key unique on its own', () async {
    await runner(upTo('20261009_000001_dw_identity_provider_email')).apply();
    await opened.db.execute('INSERT INTO dw_account (id) VALUES (1)');
    await insertInBucket(1, 'public', 'club-public');
    await insertInBucket(2, 'public', 'club-public');
    await insertInBucket(3, 'private', 'club-private');
    final before = await storedFiles();

    final run = await runner(framework).apply();
    expect(run.migrations.map((ref) => ref.id), [fromConfig.id]);

    final shape = await storedFileShape();
    expect(shape, isNot(contains(startsWith('bucket '))));
    expect(shape, contains('dw_stored_file_object_key UNIQUE (object_key)'));
    expect(shape, isNot(contains(startsWith('dw_stored_file_object '))));
    expect(await storedFiles(), before);
  });

  test('files of one visibility in two buckets stop the migration with the '
      'buckets and the statement, and migrate once they are in one', () async {
    await runner(upTo('20261009_000001_dw_identity_provider_email')).apply();
    await opened.db.execute('INSERT INTO dw_account (id) VALUES (1)');
    await insertInBucket(1, 'public', 'club');
    await insertInBucket(2, 'public', 'club-public');
    await insertInBucket(3, 'private', 'club-private');

    await expectLater(
      runner(framework).apply(),
      throwsA(
        isA<DwMigrationFailed>().having(
          (failure) => '$failure',
          'text',
          allOf(
            contains(fromConfig.id),
            contains('public files are in club, club-public'),
            contains(
              "UPDATE dw_stored_file SET bucket = '<bucket>' "
              "WHERE visibility = 'public';",
            ),
            isNot(contains('private files are in')),
          ),
        ),
      ),
    );
    expect({
      for (final status in await runner(framework).status())
        status.ref.id: status.state,
    }, containsPair(fromConfig.id, DwMigrationState.pending));

    // The objects copied into `club-public`, under the same keys.
    await opened.db.execute(
      "UPDATE dw_stored_file SET bucket = 'club-public' "
      "WHERE visibility = 'public'",
    );
    final run = await runner(framework).apply();
    expect(run.migrations.map((ref) => ref.id), [fromConfig.id]);
    expect((await storedFiles()).map((row) => row['id']), [1, 2, 3]);
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
