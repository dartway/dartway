@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_runtime_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/deploy_fixtures.dart';

/// Real Go routing, Docker inspection and forwarding chains inside an isolated
/// daemon. No global kamal-proxy, network or application is changed on the host.
void main() {
  test(
    'native checks follow real routes and the app preserves the client peer',
    () async {
      const version = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final root = Directory.systemTemp.createTempSync('dw-native-runtime-');
      addTearDown(() => root.deleteSync(recursive: true));
      void write(String path, String text) {
        final file = File(p.join(root.path, path));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(text);
      }

      for (final role in ['server', 'shared', 'flutter']) {
        write('shop_$role/pubspec.yaml', 'name: shop_$role\n');
      }
      write(
        'shop_flutter/pubspec.lock',
        File('test/fixtures/kamal/hosted.lock').readAsStringSync(),
      );
      const extra =
          '  trusted_proxy_networks: [172.28.0.0/16]\n'
          '  requires:\n    files: [account.json]\n';
      write('deploy/config.yaml', configYaml(extra: extra));
      final files = DwKamalGenerator(root).render();
      for (final entry in files.entries) write(entry.key, entry.value);
      write('fixture/api.conf', '''server {
 listen 8080;
 location = /health { return 200 "ok"; }
 location = /dw/health { add_header ETag '"$version"'; return 200 "ok"; }
 location = /dw/peer { return 200 "\$http_x_forwarded_for"; }
}''');
      // The actual project-owned nginx and API entry point, not a remembered copy.
      final template = Directory('../../template/dartway_starter_flutter');
      write(
        'fixture/web.conf',
        File(p.join(template.path, 'nginx.conf')).readAsStringSync(),
      );
      write(
        'fixture/proxy.sh',
        File(
          p.join(template.path, 'docker-entrypoint.d/20-dartway-api-proxy.sh'),
        ).readAsStringSync(),
      );
      write('fixture/index.html', '<html>native fixture</html>');
      await _run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        p.join(root.path, 'fixture/key.pem'),
        '-out',
        p.join(root.path, 'fixture/cert.pem'),
        '-days',
        '1',
        '-subj',
        '/CN=api.example.com',
        '-addext',
        'subjectAltName=DNS:api.example.com,DNS:app.example.com',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
      ]);
      final daemon = 'dw-native-${DateTime.now().microsecondsSinceEpoch}';
      await _run('docker', [
        'build',
        '-t',
        'dw-kamal-secret-files-proof:latest',
        '-f',
        'test/fixtures/kamal/secret-files.Dockerfile',
        'test/fixtures/kamal',
      ]);
      await _run('docker', [
        'run',
        '-d',
        '--privileged',
        '--name',
        daemon,
        '-e',
        'DOCKER_TLS_CERTDIR=',
        'dw-kamal-secret-files-proof:latest',
      ]);
      addTearDown(() => Process.run('docker', ['rm', '-fv', daemon]));
      Future<String> inside(List<String> args) =>
          _run('docker', ['exec', daemon, 'docker', ...args]);
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (true) {
        final ready = await Process.run('docker', [
          'exec',
          daemon,
          'docker',
          'info',
        ]);
        if (ready.exitCode == 0) break;
        if (DateTime.now().isAfter(deadline))
          fail('Isolated Docker daemon did not start');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await _run('docker', ['cp', '${root.path}/fixture', '$daemon:/fixture']);
      await inside(['pull', 'nginx:1.30.5-alpine']);
      await inside(['pull', 'basecamp/kamal-proxy:v0.10.2']);
      await inside(['pull', 'postgres:17-alpine']);
      await inside(['network', 'create', '--subnet', '172.28.0.0/16', 'kamal']);
      await inside([
        'network',
        'create',
        '--subnet',
        '172.29.0.0/16',
        'visitors',
      ]);
      await _run('docker', [
        'exec',
        daemon,
        'sh',
        '-c',
        '''set -eu
mkdir -p /home/deployer/.config/shop /root/shop-api-postgres-stage/postgres
printf '%s' 'fixture-file' >/home/deployer/.config/shop/account.json
chmod 700 /home/deployer/.config/shop
chmod 600 /home/deployer/.config/shop/account.json
chmod +x /fixture/proxy.sh
chmod 444 /fixture/key.pem
''',
      ]);
      for (final role in ['api', 'web']) {
        await inside([
          'tag',
          'nginx:1.30.5-alpine',
          'ghcr.io/acme/shop-$role:$version',
        ]);
      }
      final api = (await inside([
        'run',
        '-d',
        '--name',
        'shop-api-web-stage-$version',
        '--network',
        'kamal',
        '--label',
        'service=shop-api',
        '--label',
        'role=web',
        '--label',
        'destination=stage',
        '-v',
        '/fixture/api.conf:/etc/nginx/conf.d/default.conf:ro',
        '-v',
        '/home/deployer/.config/shop/account.json:/run/secrets/account.json:ro',
        'ghcr.io/acme/shop-api:$version',
      ])).trim();
      await inside([
        'run',
        '-d',
        '--name',
        'shop-api-postgres-stage',
        '--network',
        'kamal',
        '--label',
        'service=shop-api-postgres-stage',
        '-v',
        '/root/shop-api-postgres-stage/postgres:/var/lib/postgresql/data',
        'postgres:17-alpine',
        'sleep',
        'infinity',
      ]);
      await inside([
        'run',
        '-d',
        '--name',
        'kamal-proxy',
        '--network',
        'kamal',
        '--network-alias',
        'api.example.com',
        '--network-alias',
        'app.example.com',
        '-v',
        '/fixture:/fixture:ro',
        'basecamp/kamal-proxy:v0.10.2',
      ]);
      await inside(['network', 'connect', 'visitors', 'kamal-proxy']);
      final web = (await inside([
        'run',
        '-d',
        '--name',
        'shop-web-web-stage-$version',
        '--network',
        'kamal',
        '--label',
        'service=shop-web',
        '--label',
        'role=web',
        '--label',
        'destination=stage',
        '-e',
        'DW_API_ORIGIN=https://api.example.com',
        '-v',
        '/fixture/web.conf:/etc/nginx/conf.d/default.conf:ro',
        '-v',
        '/fixture/proxy.sh:/docker-entrypoint.d/20-dartway-api-proxy.sh:ro',
        '-v',
        '/fixture/cert.pem:/etc/ssl/certs/ca-certificates.crt:ro',
        '-v',
        '/fixture/index.html:/usr/share/nginx/html/index.html:ro',
        'ghcr.io/acme/shop-web:$version',
      ])).trim();
      Future<void> route(String role, String target) async {
        final base = loadYaml(files['deploy/kamal/$role.yml']!) as Map;
        final proxy = base['proxy'] as Map;
        final targetName = (await inside([
          'inspect',
          '--format',
          '{{.Name}}',
          target,
        ])).trim().substring(1);
        await inside([
          'exec',
          'kamal-proxy',
          'kamal-proxy',
          'deploy',
          'shop-$role-web-stage',
          '--target',
          '$targetName:${proxy['app_port']}',
          '--host',
          '$role.example.com'.replaceFirst('web.', 'app.'),
          '--tls',
          '--tls-certificate-path',
          '/fixture/cert.pem',
          '--tls-private-key-path',
          '/fixture/key.pem',
          '--health-check-path',
          role == 'web' ? '/' : '/health',
          if (proxy['forward_headers'] == true) '--forward-headers',
        ]);
      }

      await route('api', api);
      await route('web', web);
      final ssh = _DaemonSsh(daemon);
      final context = DwDeployContext(
        projectRoot: root,
        stack: stackFrom(projectRoot: root, extra: extra),
        ssh: ssh,
        version: version,
      );
      Future<DwDeployVerdict> check(String name, DwDeployContext ctx) =>
          dwKamalRemoteDeployChecks
              .firstWhere((check) => check.id == name)
              .evaluate(ctx);
      for (final name in [
        'stack-identity',
        'kamal-routing',
        'secret-files',
        'kamal-data-mounts',
        'kamal-proxy-trust',
      ]) {
        final verdict = await check(name, context);
        expect(verdict.passed, true, reason: '$name: ${verdict.detail}');
      }
      final proxyAddress = (await inside([
        'inspect',
        '--format',
        '{{(index .NetworkSettings.Networks "visitors").IPAddress}}',
        'kamal-proxy',
      ])).trim();
      await inside([
        'run',
        '-d',
        '--name',
        'visitor',
        '--network',
        'visitors',
        '-v',
        '/fixture/cert.pem:/fixture-ca.pem:ro',
        'nginx:1.30.5-alpine',
        'sleep',
        'infinity',
      ]);
      final client = (await inside([
        'inspect',
        '--format',
        '{{(index .NetworkSettings.Networks "visitors").IPAddress}}',
        'visitor',
      ])).trim();
      Future<String> peer(String host) async => (await inside([
        'exec',
        'visitor',
        'curl',
        '--silent',
        '--show-error',
        '--fail',
        '--max-time',
        '5',
        '--cacert',
        '/fixture-ca.pem',
        '--resolve',
        '$host:443:$proxyAddress',
        '-H',
        'X-Forwarded-For: 203.0.113.99',
        'https://$host/dw/peer',
      ])).trim();
      final direct = await peer('api.example.com');
      expect(direct.split(',').map((part) => part.trim()), [
        '203.0.113.99',
        client,
      ]);
      final throughApp = await peer('app.example.com');
      expect(throughApp.split(',').first.trim(), client);
      expect(throughApp, isNot(contains('203.0.113.99')));
      expect(throughApp.split(','), hasLength(3), reason: throughApp);
      // A healthy desired container does not prove that the selected route still
      // points at it. Use a real old target and a fresh inspection context.
      final old = (await inside([
        'run',
        '-d',
        '--network',
        'kamal',
        '-v',
        '/fixture/api.conf:/etc/nginx/conf.d/default.conf:ro',
        'nginx:1.30.5-alpine',
      ])).trim();
      await route('api', old);
      final after = DwDeployContext(
        projectRoot: root,
        stack: stackFrom(projectRoot: root, extra: extra),
        ssh: ssh,
        version: version,
      );
      expect((await check('stack-identity', after)).passed, true);
      expect((await check('kamal-routing', after)).passed, false);
    },
    skip: 'Needs Docker; run -t docker --run-skipped.',
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<String> _run(String command, List<String> arguments) async {
  final result = await Process.run(command, arguments);
  if (result.exitCode != 0)
    throw StateError('$command failed: ${result.stderr}');
  return result.stdout as String;
}

final class _DaemonSsh extends DwSshRunner {
  _DaemonSsh(this.daemon) : super(host: 'isolated', user: 'root');
  final String daemon;
  @override
  Future<DwSshResult> runAs(String deployUser, String command) async {
    final result = await Process.run('docker', [
      'exec',
      daemon,
      'sh',
      '-c',
      command,
    ]);
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }
}
