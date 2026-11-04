import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_contract.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
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
    write('deploy/config.yaml', '''
requires:
  files: [account.json]
kamal:
  repo: git@github.com:acme/shop.git
  deploy_user: deployer
  storage: true
''');
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
          [true],
          false,
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
        [false],
        false,
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

  const variables = {
    'STUDIO_HOST': '203.0.113.10',
    'STUDIO_SSH_USER': 'root',
    'STUDIO_DOMAIN_API': 'api.example.com',
    'STUDIO_DOMAIN_APP': 'app.example.com',
    'STUDIO_DOMAIN_FILES': 'files.example.com',
    'STUDIO_BUNDLED_STORAGE': 'true',
    'STUDIO_BUNDLED_DATABASE': 'true',
    'DW_TRUSTED_PROXY_NETWORKS': '172.18.0.0/16',
  };

  DwStack stage([Map<String, String> overrides = const {}]) =>
      DwKamalEnvironment.stack(
        projectRoot: root,
        manifest: DwKamalManifest.load(root),
        name: 'stage',
        variables: {...variables, ...overrides},
        project: DwKamalProject.load(root),
      );

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
        stack: stage(),
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

  test('native ingress requires explicit trust before deployment', () {
    expect(
      () => stage({'DW_TRUSTED_PROXY_NETWORKS': ''}),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('DW_TRUSTED_PROXY_NETWORKS is not set'),
        ),
      ),
    );
  });

  test(
    'an environment with external storage runs no storage service',
    () async {
      final (ctx, ssh) = context();
      final external = DwDeployContext(
        projectRoot: root,
        stack: stage({
          'STUDIO_BUNDLED_STORAGE': 'false',
          'DW_STORAGE_ENDPOINT': 'https://s3.example.net',
        }),
        ssh: ssh,
        version: _version,
      );
      containers.removeAt(0);
      routes.remove('shop-storage-web-stage');
      final verdict = await dwKamalRemoteDeployChecks
          .firstWhere((check) => check.id == 'stack-identity')
          .evaluate(external);
      expect(verdict.passed, true, reason: verdict.detail);
      expect(verdict.detail, startsWith('2 native services'));
      expect(ctx.engine, DwDeployEngine.kamal);
    },
  );

  test('kamal-secrets names what the environment does not give', () {
    final (ctx, _) = context();
    final named = DwDeployContext(
      projectRoot: root,
      stack: ctx.stack,
      kamalEnvironment: DwKamalEnvironment.resolve(
        DwKamalManifest.load(root),
        name: 'stage',
        variables: variables,
      ),
    );
    final missing = kamalSecretsVerdict(named, const {});
    expect(missing.passed, false);
    expect(missing.detail, contains('KAMAL_REGISTRY_PASSWORD'));
    expect(missing.detail, contains('DW_STORAGE_SECRET_KEY'));
    File(p.join(root.path, '.kamal/secrets-common'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        'KAMAL_REGISTRY_PASSWORD=\$(cat token)\n'
        'DW_DATABASE_PASSWORD=x\nDW_STORAGE_ACCESS_KEY=x\n',
      );
    final partial = kamalSecretsVerdict(named, const {
      'DW_STORAGE_SECRET_KEY': 'given',
    });
    expect(partial.passed, true, reason: partial.detail);
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

  test('a rejected target-side file mount fails', () async {
    containers[1][11] = [false];
    expect((await check('secret-files')).passed, false);
  });

  test('incomplete target-side file verification fails closed', () async {
    containers[1][11] = <bool>[];
    expect((await check('secret-files')).passed, false);
  });

  test('invalid target-side file verification fails closed', () async {
    containers[1][11] = ['true'];
    expect((await check('secret-files')).passed, false);
  });

  test(
    'the whole store must not be mounted alongside required files',
    () async {
      containers[1][12] = true;
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
