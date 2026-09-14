import 'dart:io';
import 'dart:math';

import 'test_database.dart';

/// An S3-compatible storage container that exists for the length of one test
/// run — the storage twin of [TestDatabase], and for the same reasons: nothing
/// shared with the development MinIO or with another project, nothing fixed,
/// nothing that survives.
///
/// A suite's `DwTestStorage` creates buckets of its own on it per test file
/// and drops them afterwards, so the container needs nothing but its keys.
class TestStorage {
  TestStorage({required this.image});

  final String image;

  /// The root user a suite signs its requests with.
  static const accessKey = 'dartway-test';

  /// Generated per run, and never leaves the process: the container listens
  /// on loopback only and is gone at the end.
  static final _secretKey = () {
    final random = Random.secure();
    return 'dw-${List.generate(24, (_) => random.nextInt(36).toRadixString(36)).join()}';
  }();

  /// Starts the container and returns it, or null when Docker could not.
  ///
  /// No host port is named (`127.0.0.1::9000`), so two runs cannot collide,
  /// and the data lives in memory, so a container leaked by a killed run holds
  /// nothing the next one could find.
  Future<EphemeralStorage?> start() async {
    final run = await _docker([
      'run',
      '--detach',
      '--rm',
      '--publish',
      '127.0.0.1::9000',
      '--tmpfs',
      '/data',
      '--env',
      'MINIO_ROOT_USER=$accessKey',
      '--env',
      'MINIO_ROOT_PASSWORD=$_secretKey',
      image,
      'server',
      '/data',
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
    return EphemeralStorage(id: id, port: port, secretKey: _secretKey);
  }

  /// Polls MinIO's readiness endpoint: the container reports "Started" before
  /// the server inside it answers.
  Future<bool> waitUntilReady(
    EphemeralStorage storage,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request = await client.getUrl(
            storage.endpoint.replace(path: '/minio/health/ready'),
          );
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == 200) return true;
        } on IOException {
          // Not listening yet.
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> remove(EphemeralStorage storage) async {
    await _docker(['rm', '--force', storage.id]);
  }

  Future<int?> _publishedPort(String id) async {
    final result = await _docker(['port', id, '9000/tcp']);
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

/// A running test storage: what the suite needs to reach it, and what the run
/// needs to remove it.
class EphemeralStorage {
  const EphemeralStorage({
    required this.id,
    required this.port,
    required this.secretKey,
  });

  final String id;
  final int port;
  final String secretKey;

  Uri get endpoint => Uri(scheme: 'http', host: '127.0.0.1', port: port);

  /// The coordinates in the names the server reads — `DW_STORAGE_*`, as
  /// `DwFileStorageConfig.fromEnvironment` and `DwTestStorage.create` take
  /// them. No bucket names: a suite makes buckets of its own per file.
  Map<String, String> storageEnvironment() => {
    'DW_STORAGE_ENDPOINT': '$endpoint',
    'DW_STORAGE_ACCESS_KEY': TestStorage.accessKey,
    'DW_STORAGE_SECRET_KEY': secretKey,
  };
}
