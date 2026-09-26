@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// `storage-init` runs on every deploy, against a bucket pair that may
/// already hold real objects — this proves the second run is exactly as safe
/// as the first: nothing it did the first time is undone or duplicated, and
/// an object neither run wrote is untouched.
///
/// The storage service is never published to the host in the rendered stack
/// — a deployment reaches it only through the proxy — so every request here,
/// signed or anonymous, runs from a throwaway container on the compose
/// project's own network, exactly as `storage-init` and the deployed server
/// reach it.
void main() {
  const secret = 'dw-test-secret-value';

  late Directory dir;
  late String projectName;
  late DwStack stack;

  ProcessResult compose(List<String> arguments) => Process.runSync(
    'docker',
    ['compose', '-p', projectName, ...arguments],
    workingDirectory: dir.path,
  );

  /// A one-off container on the compose project's network — the generic S3
  /// client image `storage-init` itself uses, entrypoint replaced so it can
  /// run either `aws` or the `curl` the same image ships.
  ProcessResult onNetwork(List<String> arguments, {String entrypoint = 'aws'}) =>
      Process.runSync('docker', [
        'run',
        '--rm',
        '--network',
        '${projectName}_default',
        '--entrypoint',
        entrypoint,
        '-e',
        'AWS_ACCESS_KEY_ID=$secret',
        '-e',
        'AWS_SECRET_ACCESS_KEY=$secret',
        '-e',
        'AWS_DEFAULT_REGION=us-east-1',
        DwStack.storageInitImage,
        ...arguments,
      ]);

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('dw_storage_init_');
    projectName = p.basename(dir.path).toLowerCase();
    stack = stackFrom(
      extra: '  storage: bundled\n  storage_domain: files.example.com\n',
    );
    final renderer = DwStackRenderer(stack: stack);
    File(
      p.join(dir.path, 'docker-compose.yml'),
    ).writeAsStringSync(renderer.composeFile);
    File(p.join(dir.path, '.env')).writeAsStringSync(
      stack.requiredSecretKeys.map((key) => "$key='$secret'\n").join(),
    );

    final up = compose(['up', '-d', '--wait', DwStack.storageService]);
    if (up.exitCode != 0) {
      fail('could not start the storage service: ${up.stderr}');
    }
  });

  tearDownAll(() {
    compose(['down', '--volumes', '--remove-orphans']);
    dir.deleteSync(recursive: true);
  });

  final endpoint = 'http://${DwStack.storageService}:9000';

  /// A real object, written with the server's own keys — standing in for a
  /// file a project's users already uploaded before this deploy.
  void putObject(String bucket, String key, String body) {
    final source = File(p.join(dir.path, 'pre-existing.txt'))
      ..writeAsStringSync(body);
    final result = Process.runSync('docker', [
      'run',
      '--rm',
      '--network',
      '${projectName}_default',
      '-v',
      '${source.path}:/tmp/pre-existing.txt:ro',
      '-e',
      'AWS_ACCESS_KEY_ID=$secret',
      '-e',
      'AWS_SECRET_ACCESS_KEY=$secret',
      '-e',
      'AWS_DEFAULT_REGION=us-east-1',
      DwStack.storageInitImage,
      '--endpoint-url',
      endpoint,
      's3',
      'cp',
      '/tmp/pre-existing.txt',
      's3://$bucket/$key',
    ]);
    if (result.exitCode != 0) {
      fail('could not write the pre-existing object: ${result.stderr}');
    }
  }

  /// An anonymous GET's status code, exactly what a browser or the outside
  /// probe would see — no credentials passed to `curl`, ever.
  int anonymousGet(String bucket, String key) {
    final result = onNetwork([
      '-sS',
      '-o',
      '/dev/null',
      '-w',
      '%{http_code}',
      '$endpoint/$bucket/$key',
    ], entrypoint: 'curl');
    return int.parse((result.stdout as String).trim());
  }

  String anonymousGetBody(String bucket, String key) =>
      onNetwork(['-sS', '$endpoint/$bucket/$key'], entrypoint: 'curl').stdout
          as String;

  test(
    'a second run of storage-init changes nothing it already set, and never '
    'touches an object neither run wrote — the shape of every deploy after '
    'the first',
    () {
      final first = compose(['run', '--rm', '-T', DwStack.storageInitService]);
      expect(first.exitCode, 0, reason: '${first.stderr}\n${first.stdout}');

      putObject(
        stack.publicBucketName,
        'avatar/pre-existing.png',
        'already here before the second run',
      );
      expect(
        anonymousGet(stack.publicBucketName, 'avatar/pre-existing.png'),
        200,
        reason: 'the object must read anonymously once written, as any '
            'public object does',
      );

      final second = compose(['run', '--rm', '-T', DwStack.storageInitService]);
      expect(
        second.exitCode,
        0,
        reason:
            'a second run must not fail on a bucket, a policy or a CORS '
            'rule that already exists: ${second.stderr}\n${second.stdout}',
      );

      // Nothing about access changed, and the pre-existing object nobody but
      // this test wrote is exactly what it was.
      expect(
        anonymousGet(stack.publicBucketName, 'avatar/pre-existing.png'),
        200,
      );
      expect(
        anonymousGetBody(stack.publicBucketName, 'avatar/pre-existing.png'),
        'already here before the second run',
      );
      expect(
        anonymousGet(stack.publicBucketName, DwStack.visibilityProbeKey),
        200,
      );
      expect(
        anonymousGet(stack.privateBucketName, DwStack.visibilityProbeKey),
        403,
      );
    },
  );
}
