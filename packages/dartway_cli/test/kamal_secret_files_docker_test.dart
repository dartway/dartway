@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_secret_files.dart';
import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/deploy_fixtures.dart';

/// Real Kamal configuration, SSH/SCP and an isolated Docker daemon prove a
/// host file reaches a container without joining its environment.
/// Requires Ruby with `gem install kamal -v 2.12.0 --no-document` on PATH.
void main() {
  test('files stay private and read-only, and rotate on the next boot', () async {
    final ruby = await Process.run('ruby', [
      '-rkamal',
      '-e',
      'puts Kamal::VERSION',
    ]);
    expect(
      ruby.exitCode,
      0,
      reason: 'Install Ruby and Kamal 2.12.0: ${ruby.stderr}',
    );
    final image = 'dw-kamal-secret-files-proof:latest';
    final build = await Process.run('docker', [
      'build',
      '-t',
      image,
      '-f',
      'test/fixtures/kamal/secret-files.Dockerfile',
      'test/fixtures/kamal',
    ]);
    expect(build.exitCode, 0, reason: '${build.stderr}');
    final root = Directory.systemTemp.createTempSync('dw-kamal-files-');
    addTearDown(() => root.deleteSync(recursive: true));
    final key = p.join(root.path, 'identity');
    final keygen = await Process.run('ssh-keygen', [
      '-q',
      '-t',
      'rsa',
      '-b',
      '2048',
      '-N',
      '',
      '-f',
      key,
    ]);
    expect(keygen.exitCode, 0, reason: '${keygen.stderr}');
    final name = 'dw-kamal-files-${DateTime.now().microsecondsSinceEpoch}';
    final start = await Process.run('docker', [
      'run',
      '-d',
      '--privileged',
      '--name',
      name,
      '-p',
      '127.0.0.1::22',
      '-e',
      'DOCKER_TLS_CERTDIR=',
      '--mount',
      'type=bind,source=$key.pub,target=/fixture.pub,readonly',
      image,
      'sh',
      '-c',
      r'''set -eu
for user in root deployer; do
  if [ "$user" != root ]; then adduser -D "$user"; fi
  passwd -d "$user" >/dev/null
  directory=$(eval echo "~$user")/.ssh
  mkdir -p "$directory"
  cp /fixture.pub "$directory/authorized_keys"
  chmod 700 "$directory"
  chmod 600 "$directory/authorized_keys"
  chown -R "$user:$user" "$directory"
done
echo 'deployer ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/deployer
ssh-keygen -A >/dev/null
dockerd-entrypoint.sh >/tmp/docker.log 2>&1 &
exec /usr/sbin/sshd -D -e -o PermitRootLogin=prohibit-password -o PasswordAuthentication=no
''',
    ]);
    expect(start.exitCode, 0, reason: '${start.stderr}');
    addTearDown(() => Process.run('docker', ['rm', '-f', '-v', name]));
    final published = await Process.run('docker', ['port', name, '22']);
    final port = int.parse((published.stdout as String).trim().split(':').last);
    final ssh = _FixtureSsh(port, key, p.join(root.path, 'known_hosts'));
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    DwSshResult ready;
    do {
      ready = await ssh.run('docker info >/dev/null 2>&1');
      if (ready.ok) break;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } while (DateTime.now().isBefore(deadline));
    expect(ready.ok, true, reason: ready.stderr);

    void write(String path, String text) {
      final file = File(p.join(root.path, path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
    }

    for (final role in ['server', 'flutter', 'shared']) {
      write('shop_$role/pubspec.yaml', 'name: shop_$role\n');
    }
    write(
      'shop_flutter/pubspec.lock',
      File('test/fixtures/kamal/hosted.lock').readAsStringSync(),
    );
    write(
      'deploy/config.yaml',
      configYaml(
        extra: '  requires:\n    files: [fcm.json]\n',
      ).replaceFirst('203.0.113.10', '127.0.0.1'),
    );
    DwKamalGenerator(root).generate();
    final api = File(p.join(root.path, 'deploy/kamal/api.stage.yml'));
    final config = Map<String, dynamic>.from(
      loadYaml(api.readAsStringSync()) as YamlMap,
    );
    // Kamal resolves the runner's credentials; store and mount paths stay
    // exactly as generated. No test-only path enters production code.
    final sshConfig = p.join(root.path, 'ssh_config');
    File(sshConfig).writeAsStringSync(
      'Host 127.0.0.1\n  UserKnownHostsFile ${ssh.knownHosts}\n',
    );
    config['ssh'] = {
      'user': 'root',
      'port': port,
      'keys': [key],
      'keys_only': true,
      'config': [sshConfig],
    };
    api.writeAsStringSync(jsonEncode(config));
    Future<ProcessResult> hook({
      String host = '127.0.0.1',
      String destination = 'stage',
    }) => Process.run(
      p.join(root.path, kamalSecretFilesHookPath),
      [],
      workingDirectory: root.path,
      environment: {
        'KAMAL_DESTINATION': destination,
        'KAMAL_SERVICE': 'shop-api',
        'KAMAL_HOSTS': host,
      },
    );
    final target = DwDeployTarget.load(
      projectRoot: root,
      environment: 'staging',
    );
    final store = DwSecretStore(ssh: ssh, target: target);
    final source = File(p.join(root.path, 'fcm.json'));
    const first = '{"private_key":"first-test-key"}';
    const second = '{"private_key":"second-test-key"}';
    Future<void> deliver(String content) async {
      source.writeAsStringSync(content);
      final result = await store.putFile(source, name: 'fcm.json');
      expect(result.ok, true, reason: result.stderr);
      expect('${result.stdout}${result.stderr}', isNot(contains(content)));
    }

    await deliver(first);
    final storedKey = await store.setSecret(
      key: 'SMS_API_TOKEN',
      value: 'store-key-must-not-be-mounted',
    );
    expect(storedKey.ok, true, reason: storedKey.stderr);
    final metadata = await ssh.run(
      'stat -c "%a %U" /home/deployer/.config/shop /home/deployer/.config/shop/fcm.json',
    );
    expect(metadata.ok, true, reason: metadata.stderr);
    final directoryMetadata = metadata.stdout
        .trim()
        .split('\n')
        .first
        .split(' ');
    expect(int.parse(directoryMetadata.first, radix: 8) & 0x1ff, 0x1c0);
    expect(directoryMetadata.last, 'deployer');
    expect(metadata.stdout.trim().split('\n').last, '600 deployer');
    final failedUpload = await store.putFile(
      File(p.join(root.path, 'missing.json')),
      name: 'fcm.json',
    );
    expect(failedUpload.ok, false);
    final leftovers = await ssh.run(
      "find /tmp -maxdepth 1 -name 'dw-secret-*'; find /home/deployer/.config/shop -maxdepth 1 -name '.dw-file.*'",
    );
    expect(leftovers.ok, true);
    expect(leftovers.stdout.trim(), isEmpty);
    final checked = await hook();
    expect(checked.exitCode, 0, reason: '${checked.stderr}');
    expect('${checked.stdout}${checked.stderr}', isNot(contains(first)));

    // Kamal produces the flags Docker receives; the test does not implement
    // a second translation of the generator's volume syntax.
    final flags = await Process.run('ruby', [
      '-rkamal',
      '-rjson',
      '-e',
      'config = Kamal::Configuration.create_from(config_file: Pathname.new("deploy/kamal/api.yml"), destination: "stage"); puts JSON.generate(config.volume_args)',
    ], workingDirectory: root.path);
    expect(flags.exitCode, 0, reason: '${flags.stderr}');
    final mounts = (jsonDecode(flags.stdout as String) as List).cast<String>();
    final pull = await ssh.run('docker pull alpine:3.23 >/dev/null');
    expect(pull.ok, true, reason: pull.stderr);
    String quoted(String value) => "'${value.replaceAll("'", "'\\''")}'";
    final boot = await ssh.run(
      'docker run -d --name api-first ${mounts.map(quoted).join(' ')} alpine:3.23 sleep 86400',
    );
    expect(boot.ok, true, reason: boot.stderr);
    Future<DwSshResult> read(String container) =>
        ssh.run('docker exec $container cat /run/secrets/fcm.json');
    expect((await read('api-first')).stdout, first);
    final writeRefused = await ssh.run(
      "docker exec api-first sh -c 'echo overwrite >/run/secrets/fcm.json'",
    );
    expect(writeRefused.ok, false);
    expect((await read('api-first')).stdout, first);
    expect(
      (await ssh.run(
        'docker exec api-first test ! -e /run/secrets/secrets.env',
      )).ok,
      true,
    );
    expect(
      (await ssh.run('chmod 400 /home/deployer/.config/shop/fcm.json')).ok,
      true,
    );
    expect((await hook()).exitCode, 0);
    await deliver(second);
    expect((await hook()).exitCode, 0);
    final reboot = await ssh.run(
      'docker run -d --name api-second ${mounts.map(quoted).join(' ')} alpine:3.23 sleep 86400',
    );
    expect(reboot.ok, true, reason: reboot.stderr);
    expect((await read('api-second')).stdout, second);
    // Replacing the host inode leaves the serving container on its previous
    // credential, while a replacement receives the delivered version.
    expect((await read('api-first')).stdout, first);

    for (final (command, diagnostic) in [
      ('chmod 644 /home/deployer/.config/shop/fcm.json', 'mode 400 or 600'),
      (
        'chmod 600 /home/deployer/.config/shop/fcm.json; chmod 755 /home/deployer/.config/shop',
        'mode 700',
      ),
      (
        'chmod 700 /home/deployer/.config/shop; chown root:root /home/deployer/.config/shop/fcm.json',
        'same owner',
      ),
      (
        'rm /home/deployer/.config/shop/fcm.json; mkdir /home/deployer/.config/shop/fcm.json',
        'Missing, empty or invalid',
      ),
      (
        'rmdir /home/deployer/.config/shop/fcm.json; ln -s /etc/passwd /home/deployer/.config/shop/fcm.json',
        'Missing, empty or invalid',
      ),
      (
        'rm /home/deployer/.config/shop/fcm.json; touch /home/deployer/.config/shop/fcm.json',
        'Missing, empty or invalid',
      ),
      ('rm /home/deployer/.config/shop/fcm.json', 'Missing, empty or invalid'),
    ]) {
      expect((await ssh.run(command)).ok, true);
      final refused = await hook();
      expect(refused.exitCode, isNot(0), reason: diagnostic);
      expect(refused.stderr, contains(diagnostic));
      expect('${refused.stdout}${refused.stderr}', isNot(contains(second)));
      expect((await read('api-first')).stdout, first);
    }
    final invalidHost = await hook(host: '203.0.113.99');
    expect(invalidHost.exitCode, isNot(0));
    expect(invalidHost.stderr, contains('outside the API configuration'));
    expect((await hook(destination: '../stage')).exitCode, isNot(0));

    await deliver(second);
    config['ssh']['user'] = 'deployer';
    api.writeAsStringSync(jsonEncode(config));
    final ordinaryUser = await hook();
    expect(ordinaryUser.exitCode, 0, reason: '${ordinaryUser.stderr}');
    expect(ssh.uploadDirectoryModes, isNotEmpty);
    expect(ssh.uploadDirectoryModes, everyElement('700'));
  });
}

class _FixtureSsh extends DwSshRunner {
  _FixtureSsh(this.port, String identity, this.knownHosts)
    : super(
        host: '127.0.0.1',
        user: 'root',
        identityFile: identity,
        connectTimeoutSeconds: 1,
      );
  final int port;
  final String knownHosts;
  final uploadDirectoryModes = <String>[];

  @override
  Future<DwSshResult> upload(String localPath, String remotePath) async {
    final mode = await run("stat -c %a '${p.posix.dirname(remotePath)}'");
    expect(mode.ok, true, reason: mode.stderr);
    uploadDirectoryModes.add(mode.stdout.trim());
    return super.upload(localPath, remotePath);
  }

  @override
  List<String> get connectionOptions => [
    ...super.connectionOptions,
    '-o',
    'Port=$port',
    '-o',
    'UserKnownHostsFile=$knownHosts',
  ];
}
