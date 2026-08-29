import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project_layout.dart';
import '../test_database.dart';

/// Runs the server package's tests against a database that belongs to the run.
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
/// the run ends. `config/test.yaml` keeps stating the shape of the connection;
/// the coordinates arrive as `SERVERPOD_DATABASE_*`, which Serverpod reads over
/// the file.
///
/// **Why the environment and not `configOverride`.** `withServerpod` takes a
/// config override, but it takes it per test file, and a file can be written
/// without it — in one real project such an override was honoured by 25 of 29
/// files, which is worse than none: the four that ignored it broke runs while
/// the mechanism looked like it worked. An environment variable is a property
/// of the process; a test file cannot opt out of it.
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
            'Postgres image to run. Defaults to the one the project already '
            'uses for its development database.',
      );
  }

  /// Long enough for a cold image on a busy machine, short enough that a
  /// container which will never come up does not hold the run.
  static const _readinessTimeout = Duration(seconds: 60);

  /// What the project's own compose file falls back to when it names no image.
  static const _fallbackImage = 'postgres:16';

  @override
  String get name => 'test';

  @override
  String get description =>
      'Run the server tests against a database created for this run and '
      'thrown away with it.';

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

    final connection = _readTestConnection(serverDir);
    final image =
        argResults?['image'] as String? ??
        _developmentImage(serverDir) ??
        _fallbackImage;

    final database = TestDatabase(
      image: image,
      name: connection.name,
      user: connection.user,
    );

    stdout.writeln('Starting $image for this run…');
    final ephemeral = await database.start();
    if (ephemeral == null) {
      stderr.writeln(
        'Could not start the test database. Is the Docker daemon running? '
        '`dartway doctor` says which prerequisite is missing.',
      );
      return 1;
    }

    // The container has to go even when the run does not end normally: an
    // abandoned one holds a port and, worse, holds rows that the next run would
    // find. Ctrl-C is the common case and is not an exception a `finally` sees.
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) async {
        await database.remove(ephemeral);
        exit(130);
      }),
    ];

    try {
      if (!await database.waitUntilReady(ephemeral, _readinessTimeout)) {
        stderr.writeln(
          'The database container started but never began accepting '
          'connections within ${_readinessTimeout.inSeconds}s.',
        );
        return 1;
      }
      stdout.writeln(
        'Database ready on localhost:${ephemeral.port} '
        '(${connection.name}); migrations are applied by the suite.',
      );

      final test = await Process.start(
        'dart',
        ['test', ...argResults!.rest],
        workingDirectory: serverDir.path,
        environment: {
          ...ephemeral.serverpodEnvironment(
            name: connection.name,
            user: connection.user,
          ),
        },
        mode: ProcessStartMode.inheritStdio,
      );
      return await test.exitCode;
    } finally {
      for (final signal in signals) {
        await signal.cancel();
      }
      if (argResults?['keep'] as bool? ?? false) {
        stdout.writeln(
          '\nKept: container ${ephemeral.id} on localhost:${ephemeral.port}. '
          'Remove it with `docker rm -f ${ephemeral.id}`.',
        );
      } else {
        await database.remove(ephemeral);
      }
    }
  }

  /// The database's identity, as the project states it.
  ///
  /// Only the coordinates are the run's to choose; what the database is called
  /// and who connects to it stay the project's, so a developer looking into the
  /// container finds the names they expect.
  ({String name, String user}) _readTestConnection(Directory serverDir) {
    const fallback = (name: 'dartway_test', user: 'postgres');
    final file = File(p.join(serverDir.path, 'config', 'test.yaml'));
    if (!file.existsSync()) return fallback;
    final database = _mapAt(loadYaml(file.readAsStringSync()), ['database']);
    if (database == null) return fallback;
    return (
      name: database['name'] as String? ?? fallback.name,
      user: database['user'] as String? ?? fallback.user,
    );
  }

  /// The image the project's development database runs, so the tests do not
  /// quietly run on a different major than the code is developed against.
  String? _developmentImage(Directory serverDir) {
    final file = File(p.join(serverDir.path, 'docker-compose.yaml'));
    if (!file.existsSync()) return null;
    final services = _mapAt(loadYaml(file.readAsStringSync()), ['services']);
    if (services == null) return null;
    for (final service in services.values) {
      if (service is Map && service['image'] is String) {
        final image = service['image'] as String;
        if (image.startsWith('postgres')) return image;
      }
    }
    return null;
  }

  Map? _mapAt(dynamic document, List<String> path) {
    dynamic node = document;
    for (final key in path) {
      if (node is! Map) return null;
      node = node[key];
    }
    return node is Map ? node : null;
  }
}
