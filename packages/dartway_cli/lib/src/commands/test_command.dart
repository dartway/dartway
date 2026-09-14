import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../deploy/stack.dart';
import '../project_layout.dart';
import '../test_database.dart';
import '../test_storage.dart';

/// Runs the server package's tests against a database — and an S3-compatible
/// storage — that belong to the run.
///
/// The arrangement it replaces was the other way round: the database belonged
/// to the *project*, as a `postgres_test` service on a hardcoded host port, and
/// both halves of that went wrong quietly.
///
/// **The port.** Every project created from the template asked for the same
/// one. The second container up does not get it — and does not fail either:
/// Docker starts it with the port simply unpublished, and the suite then
/// connects to the neighbour's database. Where the neighbour's schema is close
/// enough for migrations to apply, the run is green having verified nothing.
///
/// **The lifetime.** The service declared no volume, on the stated reasoning
/// that a test database surviving a restart is a liability — but the `postgres`
/// image declares an anonymous one, and Compose keeps it. Rows outlived the run
/// that wrote them, and turned up as arithmetic (`Expected: <2>, Actual: <3>`)
/// several hypotheses away from their cause.
///
/// Both disappear once nothing is fixed and nothing is shared: the container is
/// started here, published on whatever port Docker has free, and removed when
/// the run ends. The coordinates arrive as `DW_DATABASE_*` — what
/// `DwDatabaseConfig.fromEnvironment` reads, and what `DwTestDatabase` creates
/// each test file's own database from. The storage arrives the same way, as
/// `DW_STORAGE_ENDPOINT`/`_ACCESS_KEY`/`_SECRET_KEY`, where `DwTestStorage`
/// creates each test file's buckets.
///
/// **Why the environment.** It is a property of the process; a test file
/// cannot opt out of it, where a per-file configuration is one a file can
/// forget — in one real project such an override was honoured by 25 of 29
/// files, which is worse than none.
class TestCommand extends Command<int> {
  TestCommand() {
    argParser
      ..addFlag(
        'keep',
        negatable: false,
        help:
            'Leave the database container running after the tests, and print '
            'how to reach it. For inspecting what a failing run left behind.',
      )
      ..addOption(
        'image',
        help:
            'Postgres image to run. Defaults to the one a deployment runs '
            '(${DwStack.postgresImage}).',
      )
      ..addFlag(
        'storage',
        defaultsTo: true,
        help:
            'Also start a MinIO for the run and pass DW_STORAGE_* to the '
            'suite. --no-storage for a server without uploads.',
      )
      ..addOption(
        'storage-image',
        help:
            'MinIO image to run. Defaults to the one a deployment runs '
            '(${DwStack.minioImage}).',
      );
  }

  /// Long enough for a cold image on a busy machine, short enough that a
  /// container which will never come up does not hold the run.
  static const _readinessTimeout = Duration(seconds: 60);

  /// The image a deployment runs (`dartway deploy`), so the suite does not
  /// quietly test against a different major than production.
  static const _defaultImage = DwStack.postgresImage;

  /// The container's superuser and maintenance database: a suite creates a
  /// database per test file from there, which takes `CREATEDB`.
  static const _user = 'postgres';
  static const _maintenanceDatabase = 'postgres';

  @override
  String get name => 'test';

  @override
  String get description =>
      'Run the server tests against a database and a storage created for '
      'this run and thrown away with it.';

  @override
  String get invocation => 'dartway test [-- <dart test arguments>]';

  @override
  Future<int> run() async {
    final layout = ProjectLayout.detect(Directory.current);
    final serverDir = layout.serverPackageDir;
    if (!serverDir.existsSync()) {
      stderr.writeln('No server package at ${serverDir.path}.');
      return 1;
    }

    final image = argResults?['image'] as String? ?? _defaultImage;
    final withStorage = argResults?['storage'] as bool? ?? true;
    final storageImage =
        argResults?['storage-image'] as String? ?? DwStack.minioImage;
    final keep = argResults?['keep'] as bool? ?? false;

    final database = TestDatabase(
      image: image,
      name: _maintenanceDatabase,
      user: _user,
    );
    final storage = TestStorage(image: storageImage);

    stdout.writeln(
      'Starting $image${withStorage ? ' and $storageImage' : ''} for this '
      'run…',
    );
    final (ephemeral, ephemeralStorage) = await (
      database.start(),
      withStorage ? storage.start() : Future<EphemeralStorage?>.value(),
    ).wait;

    Future<void> cleanUp() async {
      if (keep) {
        stdout.writeln(_keptMessage(ephemeral, ephemeralStorage));
        return;
      }
      if (ephemeral != null) await database.remove(ephemeral);
      if (ephemeralStorage != null) await storage.remove(ephemeralStorage);
    }

    if (ephemeral == null || (withStorage && ephemeralStorage == null)) {
      stderr.writeln(
        'Could not start the test ${ephemeral == null ? 'database' : 'storage'}. '
        'Is the Docker daemon running? `dartway doctor` says which '
        'prerequisite is missing.',
      );
      if (ephemeral != null) await database.remove(ephemeral);
      if (ephemeralStorage != null) await storage.remove(ephemeralStorage);
      return 1;
    }

    // The containers have to go even when the run does not end normally: an
    // abandoned one holds a port and, worse, holds rows that the next run
    // would find. Ctrl-C is the common case and is not an exception a
    // `finally` sees.
    //
    // `--keep` survives the interrupt, because an interrupted run is exactly
    // the one somebody wants to look inside.
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) async {
        await cleanUp();
        exit(130);
      }),
    ];

    try {
      final (databaseReady, storageReady) = await (
        database.waitUntilReady(ephemeral, _readinessTimeout),
        ephemeralStorage == null
            ? Future.value(true)
            : storage.waitUntilReady(ephemeralStorage, _readinessTimeout),
      ).wait;
      if (!databaseReady || !storageReady) {
        stderr.writeln(
          'The ${databaseReady ? 'storage' : 'database'} container started '
          'but never began accepting connections within '
          '${_readinessTimeout.inSeconds}s.',
        );
        return 1;
      }
      stdout.writeln(
        'Database ready on localhost:${ephemeral.port}'
        '${ephemeralStorage == null ? '' : ', storage on ${ephemeralStorage.endpoint}'}; '
        'each test file creates a database${ephemeralStorage == null ? '' : ' and buckets'} '
        'of its own.',
      );

      final test = await Process.start(
        'dart',
        ['test', ...argResults!.rest],
        workingDirectory: serverDir.path,
        environment: {
          ...ephemeral.databaseEnvironment(
            name: _maintenanceDatabase,
            user: _user,
          ),
          ...?ephemeralStorage?.storageEnvironment(),
        },
        mode: ProcessStartMode.inheritStdio,
      );
      return await test.exitCode;
    } finally {
      for (final signal in signals) {
        await signal.cancel();
      }
      await cleanUp();
    }
  }

  static String _keptMessage(
    EphemeralDatabase? database,
    EphemeralStorage? storage,
  ) => [
    '',
    if (database != null)
      'Kept: database container ${database.id} on localhost:${database.port}.',
    if (storage != null)
      'Kept: storage container ${storage.id} on ${storage.endpoint} '
          '(access key ${TestStorage.accessKey}).',
    'Remove them with `docker rm -f '
        '${[?database?.id, ?storage?.id].join(' ')}`.',
  ].join('\n');
}
