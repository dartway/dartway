import 'dart:io';

/// A database container that exists for the length of one test run.
///
/// It is deliberately not a service in the project's `docker-compose.yaml`.
/// A compose service is a shared, named, long-lived thing on a fixed port, and
/// every one of those three properties is wrong for a test database: shared
/// means one project's suite can reach another's rows, named and long-lived
/// mean rows outlive the run that wrote them, and fixed means the second
/// project on a machine loses the port without being told.
class TestDatabase {
  TestDatabase({required this.image, required this.name, required this.user});

  /// The password is generated per run and never leaves the process: the
  /// container it opens is reachable on loopback only and is gone at the end,
  /// so there is nothing for a written-down value to protect.
  static final _password = 'dw_${DateTime.now().microsecondsSinceEpoch}';

  final String image;
  final String name;
  final String user;

  /// Starts the container and returns it, or null when Docker could not.
  ///
  /// `-p 127.0.0.1::5432` is the whole point: no host port is named, so Docker
  /// assigns a free one and two runs on the same machine cannot collide. The
  /// loopback prefix keeps the database off the network — it holds test rows,
  /// but the container also carries a password that is trivially readable from
  /// the process list.
  Future<EphemeralDatabase?> start() async {
    final run = await _docker([
      'run',
      '--detach',
      '--rm',
      '--publish',
      '127.0.0.1::5432',
      // Nothing on disk: not for speed, but so that a container leaked by a
      // killed run cannot hand its rows to the next one.
      '--tmpfs',
      '/var/lib/postgresql/data',
      '--env',
      'POSTGRES_USER=$user',
      '--env',
      'POSTGRES_DB=$name',
      '--env',
      'POSTGRES_PASSWORD=$_password',
      image,
    ]);
    if (run == null || run.exitCode != 0) {
      if (run != null) stderr.write(run.stderr);
      return null;
    }

    final id = (run.stdout as String).trim();
    final port = await _publishedPort(id);
    if (port == null) {
      await _docker(['rm', '--force', id]);
      return null;
    }
    return EphemeralDatabase(id: id, port: port, password: _password);
  }

  /// Polls until Postgres answers, which is not the same moment as the
  /// container being "Started" — there are seconds between them, and a
  /// connection attempt inside that window fails as `connection refused`.
  Future<bool> waitUntilReady(
    EphemeralDatabase database,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final probe = await _docker([
        'exec',
        database.id,
        'pg_isready',
        '--username',
        user,
        '--dbname',
        name,
      ]);
      if (probe?.exitCode == 0) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> remove(EphemeralDatabase database) async {
    await _docker(['rm', '--force', database.id]);
  }

  Future<int?> _publishedPort(String id) async {
    final result = await _docker(['port', id, '5432/tcp']);
    if (result == null || result.exitCode != 0) return null;
    return parsePublishedPort(result.stdout as String);
  }

  Future<ProcessResult?> _docker(List<String> arguments) async {
    try {
      return await Process.run('docker', arguments);
    } on ProcessException {
      return null;
    }
  }
}

/// A running test database: what the suite needs to reach it, and what the run
/// needs to remove it.
class EphemeralDatabase {
  const EphemeralDatabase({
    required this.id,
    required this.port,
    required this.password,
  });

  final String id;
  final int port;
  final String password;

  /// The coordinates, in the form Serverpod reads over `config/test.yaml`.
  ///
  /// `ServerpodConfig.load` reads the run mode's YAML and then applies
  /// `Platform.environment` on top, and `TestServerpod` builds an ordinary
  /// `Serverpod` — so these reach the test server exactly as they reach a
  /// deployed one. The environment is also the one channel a test file cannot
  /// bypass, which a per-file config override is not.
  Map<String, String> serverpodEnvironment({
    required String name,
    required String user,
  }) => {
    'SERVERPOD_DATABASE_HOST': 'localhost',
    'SERVERPOD_DATABASE_PORT': '$port',
    'SERVERPOD_DATABASE_NAME': name,
    'SERVERPOD_DATABASE_USER': user,
    'SERVERPOD_DATABASE_PASSWORD': password,
  };
}

/// Reads the host port out of `docker port <id> 5432/tcp`.
///
/// The output is one or more `<address>:<port>` lines — two when the daemon
/// publishes on both IPv4 and IPv6, and they carry the same port. Split from
/// the right: an IPv6 address is full of colons.
int? parsePublishedPort(String dockerPortOutput) {
  for (final line in dockerPortOutput.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final separator = trimmed.lastIndexOf(':');
    if (separator < 0) continue;
    final port = int.tryParse(trimmed.substring(separator + 1));
    if (port != null) return port;
  }
  return null;
}
