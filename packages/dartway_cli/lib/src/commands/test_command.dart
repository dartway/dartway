import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:args/command_runner.dart';

import '../deploy/stack.dart';
import '../project_layout.dart';
import '../test_database.dart';
import '../test_storage.dart';
import '../test_servers.dart';

/// Runs server tests on run-owned containers or explicitly supplied servers.
/// The environment passed to the suite is owned by this run, never inherited.
class TestCommand extends Command<int> {
  TestCommand() {
    argParser
      ..addOption(
        'database-url',
        help:
            'Explicit Postgres test server: postgres://user[:password]@host[:port]/maintenance-db (role needs CREATEDB).',
      )
      ..addOption(
        'storage-url',
        help:
            'Explicit path-style S3 test server: http[s]://access-key:secret-key@host[:port].',
      )
      ..addFlag(
        'allow-remote-test-server',
        negatable: false,
        help:
            'Allow explicit servers outside loopback. Use a dedicated test server only.',
      )
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
            'Also start a storage container for the run and pass DW_STORAGE_* '
            'to the suite. --no-storage for a server without uploads.',
      )
      ..addOption(
        'storage-image',
        help:
            'Storage image to run. Defaults to the one a deployment runs '
            '(${DwStack.storageImage}).',
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

  /// The project [from] is in — its root, or any package of it. The pinned
  /// form, `dart run dartway_cli:dartway test`, runs in the Flutter package
  /// that pins the CLI, where this read only the working directory and
  /// answered that there was no `*_server` package (#289).
  static ProjectLayout projectOf(Directory from) =>
      ProjectLayout.detect(findPackageProjectRoot(from) ?? from);

  @override
  Future<int> run() async {
    final layout = projectOf(Directory.current);
    final serverDir = layout.serverPackageDir;
    if (!serverDir.existsSync()) {
      stderr.writeln('No server package at ${serverDir.path}.');
      return 1;
    }

    final databaseUrl = argResults?['database-url'] as String?;
    final storageUrl = argResults?['storage-url'] as String?;
    final withStorage = argResults?['storage'] as bool? ?? true;
    final keep = argResults?['keep'] as bool? ?? false;
    final allowRemote =
        argResults?['allow-remote-test-server'] as bool? ?? false;
    if ((databaseUrl != null || storageUrl != null) && keep) {
      stderr.writeln(
        '--keep is only available for container runs; external run resources are always removed.',
      );
      return 1;
    }
    if (storageUrl != null && !withStorage) {
      stderr.writeln('--storage-url cannot be combined with --no-storage.');
      return 1;
    }

    final random = Random.secure();
    final runId = List.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    // Drop every inherited service option, including CA, buckets and region.
    // Without a storage flag, even an inherited stage storage is unreachable.
    final environment = {
      for (final entry in Platform.environment.entries)
        if (!entry.key.startsWith('DW_DATABASE_') &&
            !entry.key.startsWith('DW_STORAGE_'))
          entry.key: entry.value,
      'DW_TEST_RUN_ID': runId,
    };
    final external = [
      if (databaseUrl != null) 'database',
      if (storageUrl != null) 'storage',
    ];
    List<String>? workerArguments;
    try {
      final db = databaseUrl == null
          ? null
          : TestServerUrl.parse(databaseUrl, database: true);
      final s3 = storageUrl == null
          ? null
          : TestServerUrl.parse(storageUrl, database: false);
      if (db != null)
        environment.addAll(
          await db.environment(database: true, allowRemote: allowRemote),
        );
      if (s3 != null)
        environment.addAll(
          await s3.environment(database: false, allowRemote: allowRemote),
        );
      if (external.isNotEmpty) {
        workerArguments = testServicesArguments(serverDir, []);
      }
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      return 1;
    } on SocketException {
      stderr.writeln('Could not resolve the explicit test server host.');
      return 1;
    }

    final image = argResults?['image'] as String? ?? _defaultImage;
    final storageImage =
        argResults?['storage-image'] as String? ?? DwStack.storageImage;
    final database = TestDatabase(
      image: image,
      name: _maintenanceDatabase,
      user: _user,
    );
    final storage = TestStorage(image: storageImage);
    final startStorage =
        withStorage && storageUrl == null && databaseUrl == null;
    EphemeralDatabase? ephemeral;
    EphemeralStorage? ephemeralStorage;
    Process? test;
    var interrupted = false;
    var result = 1;
    Future<void>? stopping;
    Future<void> stopTest() => stopping ??= () async {
      final process = test;
      if (process == null) return;
      process.kill(ProcessSignal.sigint);
      try {
        await process.exitCode.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    }();
    final signal = ProcessSignal.sigint.watch().listen((_) {
      interrupted = true;
      if (test != null) unawaited(stopTest());
    });

    Future<int> worker(String operation) async {
      final process = await Process.start(
        Platform.resolvedExecutable,
        [...workerArguments!, operation, ...external],
        workingDirectory: serverDir.path,
        environment: environment,
        includeParentEnvironment: false,
        mode: ProcessStartMode.inheritStdio,
      );
      return process.exitCode;
    }

    Future<int> runSuite() async {
      stdout.writeln(
        'Test run $runId: '
        '${databaseUrl == null ? 'starting $image' : 'explicit Postgres'}; '
        '${storageUrl != null
            ? 'explicit S3'
            : startStorage
            ? 'starting $storageImage'
            : 'storage disabled (no storage server supplied)'}.',
      );
      if (external.isNotEmpty && await worker('check') != 0) return 1;
      if (interrupted) return 130;
      // Sequential ownership: every acquired container is visible to finally,
      // including when the second start fails or the run is interrupted.
      if (databaseUrl == null) {
        ephemeral = await database.start();
        if (ephemeral == null) {
          stderr.writeln(
            'Could not start the test database. Is the Docker daemon running? Run dartway doctor.',
          );
          return 1;
        }
        environment.addAll(
          ephemeral!.databaseEnvironment(
            name: _maintenanceDatabase,
            user: _user,
          ),
        );
      }
      if (interrupted) return 130;
      if (startStorage) {
        ephemeralStorage = await storage.start();
        if (ephemeralStorage == null) {
          stderr.writeln(
            'Could not start the test storage. Is the Docker daemon running? Run dartway doctor.',
          );
          return 1;
        }
        environment.addAll(ephemeralStorage!.storageEnvironment());
      }
      final databaseReady =
          ephemeral == null ||
          await database.waitUntilReady(ephemeral!, _readinessTimeout);
      final storageReady =
          ephemeralStorage == null ||
          await storage.waitUntilReady(ephemeralStorage!, _readinessTimeout);
      if (!databaseReady || !storageReady) {
        stderr.writeln(
          'The test container did not become ready within ${_readinessTimeout.inSeconds}s.',
        );
        return 1;
      }
      if (interrupted) return 130;
      stdout.writeln(
        'Servers ready; each test file creates its own database'
        '${storageUrl != null || ephemeralStorage != null ? ' and buckets' : ''}.',
      );
      test = await Process.start(
        Platform.resolvedExecutable,
        ['test', ...argResults!.rest],
        workingDirectory: serverDir.path,
        environment: environment,
        includeParentEnvironment: false,
        mode: ProcessStartMode.inheritStdio,
      );
      if (interrupted) await stopTest();
      final code = await test!.exitCode;
      if (stopping != null) await stopping;
      return interrupted ? 130 : code;
    }

    try {
      result = await runSuite();
    } on Exception {
      stderr.writeln(
        'Could not run the server tests; check the resolved server package and service availability.',
      );
    } finally {
      // The writer must stop before the sweep, so it cannot create resources
      // behind cleanup. Keep the signal listener alive through the sweep.
      if (test != null) await test!.exitCode;
      try {
        if (external.isNotEmpty && await worker('cleanup') != 0) result = 1;
      } on Exception {
        stderr.writeln('External test server cleanup failed; run id: $runId.');
        result = 1;
      } finally {
        if (keep) {
          stdout.writeln(_keptMessage(ephemeral, ephemeralStorage));
        } else {
          if (ephemeral != null) await database.remove(ephemeral!);
          if (ephemeralStorage != null) await storage.remove(ephemeralStorage!);
        }
        await signal.cancel();
      }
    }
    return interrupted && result != 1 ? 130 : result;
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
