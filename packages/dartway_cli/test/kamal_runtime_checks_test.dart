import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_runtime_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

const _version = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  late Directory root;
  late List<List<Object?>> containers;
  late Map<String, Object?> routes;

  setUp(() {
    root = Directory.systemTemp.createTempSync('native-runtime-');
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
    write(
      'deploy/config.yaml',
      configYaml(
        extra: '''
  storage: bundled
  storage_domain: files.example.com
  trusted_proxy_networks: [172.18.0.0/16]
  requires:
    files: [account.json]
''',
      ),
    );
    DwKamalGenerator(root).generate();
    containers = [
      for (final (index, service) in ['storage', 'api', 'web'].indexed)
        [
          '${index + 1}' * 64,
          '/shop-$service-web-stage-$_version',
          'ghcr.io/acme/shop-$service:$_version',
          1,
          'healthy',
          'shop-$service',
          'web',
          'stage',
          <List<Object?>>[
            if (service == 'storage')
              [
                'volume',
                '/var/lib/docker/volumes/shop-storage-data-stage/_data',
                '/data',
                'shop-storage-data-stage',
                1,
              ],
            if (service == 'api')
              [
                'bind',
                '/home/deployer/.config/shop/account.json',
                '/run/secrets/account.json',
                '',
                0,
              ],
          ],
          '172.18.0.${index + 3}',
          '',
        ],
      [
        '4' * 64,
        '/shop-api-postgres-stage',
        'postgres:17-alpine',
        1,
        'none',
        'shop-api-postgres-stage',
        null,
        null,
        [
          [
            'bind',
            '/root/shop-api-postgres-stage/postgres',
            '/var/lib/postgresql/data',
            '',
            1,
          ],
        ],
        '172.18.0.8',
        '',
      ],
    ];
    routes = {
      for (final (index, service) in ['storage', 'api', 'web'].indexed)
        'shop-$service-web-stage': {
          'hosts': [
            switch (service) {
              'storage' => 'files.example.com',
              'api' => 'api.example.com',
              _ => 'app.example.com',
            },
          ],
          'path_prefixes': <String>[],
          'tls': true,
          'targets': [
            '${index + 1}' * 64 +
                ':${switch (service) {
                  'storage' => 9000,
                  'api' => 8080,
                  _ => 80,
                }}',
          ],
          'read_targets': <String>[],
          'state': 'running',
          'rollout': {'enabled': false},
        },
    };
  });
  tearDown(() => root.deleteSync(recursive: true));

  String snapshot({
    String congestion = 'bbr',
    String subnet = '172.18.0.0/16',
  }) =>
      '${containers.map(jsonEncode).join('\n')}\nDW_KAMAL_ROUTES\n'
      '${jsonEncode(routes)}\nDW_KAMAL_CONGESTION\n$congestion\nDW_KAMAL_NETWORK\n'
      '${jsonEncode([
        {'Subnet': subnet},
      ])}\n';

  (DwDeployContext, RecordingSsh) context({
    String? output,
    String version = _version,
  }) {
    final ssh = RecordingSsh([
      (
        'docker inspect --format',
        DwSshResult(exitCode: 0, stdout: output ?? snapshot(), stderr: ''),
      ),
    ]);
    return (
      DwDeployContext(
        projectRoot: root,
        stack: stackFrom(
          projectRoot: root,
          extra:
              '  storage: bundled\n  storage_domain: files.example.com\n'
              '  trusted_proxy_networks: [172.18.0.0/16]\n'
              '  requires:\n    files: [account.json]\n',
        ),
        ssh: ssh,
        version: version,
      ),
      ssh,
    );
  }

  Future<DwDeployVerdict> check(
    String name, {
    String? output,
    String version = _version,
  }) {
    final (ctx, _) = context(output: output, version: version);
    return dwKamalRemoteDeployChecks
        .firstWhere((check) => check.id == name)
        .evaluate(ctx);
  }

  test(
    'native checks share one projection and never inspect Compose or environment',
    () async {
      final (ctx, ssh) = context();
      expect(ctx.engine, DwDeployEngine.kamal);
      for (final name in [
        'stack-identity',
        'kamal-routing',
        'secret-files',
        'kamal-data-mounts',
        'kamal-proxy-trust',
        'proxy-congestion-control',
      ]) {
        final verdict = await dwKamalRemoteDeployChecks
            .firstWhere((c) => c.id == name)
            .evaluate(ctx);
        expect(verdict.passed, true, reason: '$name: ${verdict.detail}');
      }
      expect(ssh.issued, hasLength(1));
      expect(ssh.issued.single, isNot(contains('docker compose')));
      expect(ssh.issued.single, isNot(contains('Config.Env')));
      expect(ssh.issued.single, isNot(contains('Health.Log')));
      expect(ssh.issued.single, contains('kamal-proxy list --json'));
    },
  );

  for (final (name, mutate) in <(String, void Function())>[
    ('wrong SHA', () => containers[1][2] = 'ghcr.io/acme/shop-api:${'b' * 40}'),
    ('other destination', () => containers[1][7] = 'prod'),
    ('stopped', () => containers[1][3] = 0),
    ('unhealthy', () => containers[1][4] = 'unhealthy'),
    ('ambiguous active images', () => containers.add(List.of(containers[1]))),
  ]) {
    test('native identity refuses $name', () async {
      mutate();
      expect((await check('stack-identity')).passed, false);
    });
  }

  test(
    'a healthy desired container is insufficient when routing still selects the old one',
    () async {
      (routes['shop-api-web-stage'] as Map)['targets'] = ['${'9' * 64}:8080'];
      expect((await check('stack-identity')).passed, true);
      expect((await check('kamal-routing')).passed, false);
    },
  );

  test('another service claiming the same host fails routing', () async {
    routes['old-api-web-stage'] = Map.of(routes['shop-api-web-stage'] as Map);
    expect((await check('kamal-routing')).passed, false);
  });

  test('native ingress requires explicit trust before deployment', () async {
    final (ctx, _) = context();
    final untrusted = DwDeployContext(
      projectRoot: root,
      stack: stackFrom(
        projectRoot: root,
        extra: '  storage: bundled\n  storage_domain: files.example.com\n',
      ),
      ssh: ctx.ssh,
      version: _version,
    );
    final verdict = await dwKamalRemoteDeployChecks
        .firstWhere((check) => check.id == 'kamal-proxy-trust')
        .evaluate(untrusted);
    expect(verdict.passed, false);
    expect(verdict.detail, contains('trusted_proxy_networks'));
  });

  for (final (field, value) in <(String, Object)>[
    ('hosts', ['api.production.example.com']),
    ('tls', false),
    ('state', 'paused'),
    ('path_prefixes', ['/dw/']),
    ('rollout', {'enabled': true}),
    ('read_targets', ['old:8080']),
  ]) {
    test('native routing refuses wrong $field', () async {
      (routes['shop-api-web-stage'] as Map)[field] = value;
      expect((await check('kamal-routing')).passed, false);
    });
  }

  test('a writable or wrong-source secret file fails', () async {
    final mount = (containers[1][8] as List).single as List;
    mount[4] = 1;
    expect((await check('secret-files')).passed, false);
    mount[4] = 0;
    mount[1] = '/other/account.json';
    expect((await check('secret-files')).passed, false);
  });

  test(
    'the whole store must not be mounted alongside required files',
    () async {
      (containers[1][8] as List).add(['bind', '/store', '/run/secrets', '', 0]);
      expect((await check('secret-files')).passed, false);
    },
  );

  test('old Compose data volumes do not prove native data mounts', () async {
    ((containers[0][8] as List).single as List)[3] = 'shop_storage_data';
    expect((await check('kamal-data-mounts')).passed, false);
  });

  test('wrong native network trust or congestion fails', () async {
    expect(
      (await check(
        'kamal-proxy-trust',
        output: snapshot(subnet: '172.19.0.0/16'),
      )).passed,
      false,
    );
    expect(
      (await check(
        'proxy-congestion-control',
        output: snapshot(congestion: 'cubic'),
      )).passed,
      false,
    );
  });

  test(
    'missing or invalid runtime metadata never falls back to Compose',
    () async {
      expect(
        (await check(
          'stack-identity',
          output: 'legacy compose is healthy',
        )).passed,
        false,
      );
      expect((await check('stack-identity', version: 'master')).passed, false);
    },
  );
}
