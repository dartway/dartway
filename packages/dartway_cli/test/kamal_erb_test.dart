@Tags(['kamal'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_contract.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The generated configuration as Kamal 2.12 itself reads it: ERB rendered by
/// Ruby, names derived by Kamal's own configuration classes. Needs `ruby` and
/// `gem install kamal -v 2.12.0`; `DW_RUBY` and `DW_KAMAL` override the
/// executables.
void main() {
  final ruby = Platform.environment['DW_RUBY'] ?? 'ruby';
  final kamal = Platform.environment['DW_KAMAL'] ?? 'kamal';
  final inspector = p.absolute('test/fixtures/kamal/inspect_config.rb');
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  late Directory root;

  void write(String path, String text) {
    final file = File(p.join(root.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  // Every name either database or storage mode can ask for: an environment's
  // secrets are Studio's, and Kamal resolves only the names a config uses.
  const secrets = [
    'KAMAL_REGISTRY_PASSWORD',
    'DW_DATABASE_PASSWORD',
    'DW_DATABASE_HOST',
    'DW_DATABASE_PORT',
    'DW_DATABASE_NAME',
    'DW_DATABASE_USER',
    'DW_STORAGE_ACCESS_KEY',
    'DW_STORAGE_SECRET_KEY',
    'SMS_API_TOKEN',
  ];

  void project(Directory directory, String config) {
    root = directory;
    for (final role in ['server', 'flutter', 'shared']) {
      write('shop_$role/pubspec.yaml', 'name: shop_$role\n');
    }
    write(
      'shop_flutter/pubspec.lock',
      File('test/fixtures/kamal/hosted.lock').readAsStringSync(),
    );
    write('deploy/config.yaml', config);
    write(
      '.kamal/secrets-common',
      secrets.map((name) => '$name=value-of-$name\n').join(),
    );
  }

  setUp(() {
    project(Directory.systemTemp.createTempSync('kamal-erb-'), '''
requires:
  secrets: [SMS_API_TOKEN]
  files: [fcm.json]
kamal:
  repo: git@github.com:acme/shop.git
  deploy_user: deployer
  storage: true
''');
    DwKamalGenerator(root).generate();
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// What Studio writes before running Kamal with `-d <env>`: Kamal 2.12
  /// requires the destination file, and everything is in the service's own.
  void stub(String destination) {
    for (final service in ['storage', 'api', 'web']) {
      final file = File(
        p.join(root.path, 'deploy/kamal/$service.$destination.yml'),
      );
      if (!file.existsSync()) file.writeAsStringSync('{}\n');
    }
  }

  Future<ProcessResult> run(
    String executable,
    List<String> arguments,
    Map<String, String> variables,
  ) => Process.run(
    executable,
    arguments,
    workingDirectory: root.path,
    environment: {
      for (final MapEntry(:key, :value) in Platform.environment.entries)
        if (!key.startsWith('STUDIO_') && !key.startsWith('DW_STORAGE_'))
          key: value,
      ...variables,
    },
    includeParentEnvironment: false,
  );

  Future<Map<String, Object?>> inspect(
    String service,
    String destination,
    Map<String, String> variables,
  ) async {
    stub(destination);
    final result = await run(ruby, [
      inspector,
      'deploy/kamal/$service.yml',
      destination,
      sha,
    ], variables);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return jsonDecode(result.stdout as String) as Map<String, Object?>;
  }

  Future<String> refusal(
    String service,
    String destination,
    Map<String, String> variables,
  ) async {
    stub(destination);
    final result = await run(ruby, [
      inspector,
      'deploy/kamal/$service.yml',
      destination,
      sha,
    ], variables);
    expect(result.exitCode, isNot(0), reason: '${result.stdout}');
    return result.stderr as String;
  }

  Map<String, String> environment(
    String name, {
    required String host,
    required String sshUser,
    required String domain,
    required bool bundledStorage,
    required bool bundledDatabase,
  }) => {
    'STUDIO_ENVIRONMENT': name,
    'STUDIO_HOST': host,
    'STUDIO_SSH_USER': sshUser,
    'STUDIO_DOMAIN_API': 'api.$domain',
    'STUDIO_DOMAIN_APP': 'app.$domain',
    if (bundledStorage) 'STUDIO_DOMAIN_FILES': 'files.$domain',
    'STUDIO_BUNDLED_STORAGE': '$bundledStorage',
    'STUDIO_BUNDLED_DATABASE': '$bundledDatabase',
    'DW_TRUSTED_PROXY_NETWORKS': '172.18.0.0/16',
    if (!bundledStorage) ...{
      'DW_STORAGE_ENDPOINT': 'https://s3.$domain',
      'DW_STORAGE_PUBLIC_BUCKET': '$name-public',
      'DW_STORAGE_PUBLIC_BASE_URL': 'https://cdn.$domain',
      'DW_STORAGE_PRIVATE_BUCKET': '$name-private',
    },
  };

  final environments = {
    'stage': environment(
      'stage',
      host: '203.0.113.10',
      sshUser: 'root',
      domain: 'stage.example.com',
      bundledStorage: false,
      bundledDatabase: true,
    ),
    'prod': environment(
      'prod',
      host: '203.0.113.20',
      sshUser: 'operator',
      domain: 'example.com',
      bundledStorage: false,
      bundledDatabase: false,
    ),
    'prod-ae': environment(
      'prod-ae',
      host: '203.0.113.30',
      sshUser: 'root',
      domain: 'example.ae',
      bundledStorage: true,
      bundledDatabase: true,
    ),
  };

  test(
    'one configuration deploys the same SHA to three environments that differ only in variables',
    () async {
      final generated = DwKamalGenerator(root).render().keys;
      expect(
        generated.where((path) => RegExp(r'\.[^/]+\.yml$').hasMatch(path)),
        isEmpty,
        reason: 'no destination files are generated',
      );
      final manifest = DwKamalManifest.load(root);
      for (final MapEntry(key: name, value: variables)
          in environments.entries) {
        final resolved = DwKamalEnvironment.resolve(
          manifest,
          name: name,
          variables: variables,
        );
        final bundledStorage = resolved.bundled['storage']!;
        final bundledDatabase = resolved.bundled['database']!;
        final services = [
          for (final service in manifest.services)
            if (service != 'storage' || bundledStorage) service,
        ];
        final kamalSecrets = <String>{'KAMAL_REGISTRY_PASSWORD'};
        stub(name);
        for (final service in services) {
          final cli = await run(kamal, [
            'config',
            '-c',
            'deploy/kamal/$service.yml',
            '-d',
            name,
            '--version',
            sha,
          ], variables);
          expect(
            cli.exitCode,
            0,
            reason: '$name/$service: ${cli.stdout}${cli.stderr}',
          );
          final config = await inspect(service, name, variables);
          expect(config['image'], 'ghcr.io/acme/shop-$service:$sha');
          expect(config['hosts'], [variables['STUDIO_HOST']]);
          expect(config['ssh_user'], variables['STUDIO_SSH_USER']);
          expect(config['labels'], {
            'service': 'shop-$service',
            'role': 'web',
            'destination': name,
          });
          expect(config['container_prefix'], 'shop-$service-web-$name');
          expect(config['app_directory'], '.kamal/apps/shop-$service-$name');
          expect(config['proxy_hosts'], [
            variables[switch (service) {
              'api' => 'STUDIO_DOMAIN_API',
              'web' => 'STUDIO_DOMAIN_APP',
              _ => 'STUDIO_DOMAIN_FILES',
            }],
          ]);
          for (final secret in config['env_secrets'] as List) {
            kamalSecrets.add('$secret'.split(':').last);
          }
          final accessories = config['accessories'] as Map;
          for (final accessory in accessories.values.cast<Map>()) {
            for (final secret in accessory['env_secrets'] as List) {
              kamalSecrets.add('$secret'.split(':').last);
            }
          }
          if (service == 'storage') {
            expect(config['volumes'], ['shop-storage-data-$name:/data']);
          }
          if (service == 'web') {
            expect(config['env_clear'], {
              'DW_API_ORIGIN': 'https://${variables['STUDIO_DOMAIN_API']}',
            });
          }
          if (service != 'api') continue;
          final clear = config['env_clear'] as Map;
          expect(clear['DW_ENVIRONMENT'], name);
          expect(
            clear['DW_ALLOWED_ORIGINS'],
            'https://${variables['STUDIO_DOMAIN_APP']}',
          );
          expect(clear['DW_TRUSTED_PROXY_NETWORKS'], '172.18.0.0/16');
          expect(config['volumes'], [
            '/home/deployer/.config/shop/fcm.json:/run/secrets/fcm.json:ro',
          ]);
          if (bundledStorage) {
            expect(clear['DW_STORAGE_ENDPOINT'], 'https://files.example.ae');
            expect(clear['DW_STORAGE_PROVISION'], 'true');
            expect(clear['DW_STORAGE_PUBLIC_BUCKET'], 'shop-public');
          } else {
            expect(
              clear['DW_STORAGE_ENDPOINT'],
              variables['DW_STORAGE_ENDPOINT'],
            );
            expect(clear['DW_STORAGE_PUBLIC_BUCKET'], '$name-public');
            expect(clear['DW_STORAGE_PRIVATE_BUCKET'], '$name-private');
            expect(clear.containsKey('DW_STORAGE_PROVISION'), false);
            expect(clear.containsKey('DW_STORAGE_REGION'), false);
          }
          if (bundledDatabase) {
            expect(clear['DW_DATABASE_HOST'], 'shop-api-postgres-$name');
            expect(accessories.keys, ['postgres']);
            final postgres = accessories['postgres'] as Map;
            expect(postgres['service'], 'shop-api-postgres-$name');
            expect(postgres['hosts'], [variables['STUDIO_HOST']]);
          } else {
            expect(clear.containsKey('DW_DATABASE_HOST'), false);
            expect(accessories, isEmpty);
            expect(config['env_secrets'], contains('DW_DATABASE_HOST'));
          }
        }
        // What the manifest asks this environment for is what Kamal reads.
        expect(resolved.needs.secrets.toSet(), kamalSecrets);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a fourth environment needs only its variables', () async {
    final before = {
      for (final file
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => !p.split(file.path).contains('.kamal')))
        file.path: file.readAsStringSync(),
    };
    final variables = environment(
      'preview',
      host: '203.0.113.40',
      sshUser: 'root',
      domain: 'preview.example.com',
      bundledStorage: true,
      bundledDatabase: true,
    );
    for (final service in ['storage', 'api', 'web']) {
      final config = await inspect(service, 'preview', variables);
      expect(config['app_directory'], '.kamal/apps/shop-$service-preview');
    }
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (p.split(file.path).contains('.kamal')) continue;
      if (file.path.endsWith('.preview.yml')) continue;
      expect(before[file.path], file.readAsStringSync(), reason: file.path);
    }
    expect(DwKamalGenerator(root).generate(check: true), isEmpty);
  });

  test(
    'missing, malformed or mismatched variables stop Kamal by name',
    () async {
      final stage = environments['stage']!;
      expect(
        await refusal('api', 'stage', {...stage}..remove('STUDIO_HOST')),
        contains('STUDIO_HOST is not set'),
      );
      expect(
        await refusal('api', 'stage', {
          ...stage,
          'STUDIO_BUNDLED_DATABASE': 'yes',
        }),
        contains('STUDIO_BUNDLED_DATABASE is not valid'),
      );
      expect(
        await refusal('api', 'stage', {...stage, 'STUDIO_DOMAIN_API': 'a"b'}),
        contains('STUDIO_DOMAIN_API is not valid'),
      );
      expect(
        await refusal(
          'api',
          'stage',
          {...stage}..remove('DW_STORAGE_ENDPOINT'),
        ),
        contains('DW_STORAGE_ENDPOINT is not set'),
      );
      expect(
        await refusal('web', 'prod', stage),
        contains('Run Kamal with -d stage'),
      );
      expect(
        await refusal('storage', 'stage', stage),
        contains('Storage is external in stage'),
      );
    },
  );

  test(
    'stage and prod keep every name the staging and production destinations had',
    () async {
      // The previous generator's output for the same project, with destination
      // files: what live deployments run under today.
      final legacy = Directory.systemTemp.createTempSync('kamal-legacy-');
      addTearDown(() => legacy.deleteSync(recursive: true));
      final current = root;
      project(
        legacy,
        File('test/fixtures/kamal/legacy/config.yaml').readAsStringSync(),
      );
      for (final file in Directory(
        'test/fixtures/kamal/legacy',
      ).listSync().whereType<File>()) {
        if (file.path.endsWith('.yml')) {
          write(
            'deploy/kamal/${p.basename(file.path)}',
            file.readAsStringSync(),
          );
        }
      }
      root = current;
      Future<Map<String, Object?>> legacyConfig(String service, String dest) {
        root = legacy;
        return inspect(
          service,
          dest,
          const {},
        ).whenComplete(() => root = current);
      }

      for (final (destination, host, domain) in [
        ('stage', '203.0.113.10', 'example.com'),
        ('prod', '203.0.113.20', 'production.example.com'),
      ]) {
        final variables = {
          ...environment(
            destination,
            host: host,
            sshUser: 'root',
            domain: domain,
            bundledStorage: true,
            bundledDatabase: true,
          ),
        };
        for (final service in ['storage', 'api', 'web']) {
          final before = await legacyConfig(service, destination);
          final after = await inspect(service, destination, variables);
          for (final key in [
            'service',
            'image',
            'app_directory',
            'container_prefix',
            'labels',
            'hosts',
            'ssh_user',
            'proxy_hosts',
            'volumes',
            'secrets_path',
            'accessories',
          ]) {
            expect(
              after[key],
              before[key],
              reason: '$destination/$service $key',
            );
          }
          expect(
            (after['env_secrets'] as List).toSet(),
            (before['env_secrets'] as List).toSet(),
            reason: '$destination/$service secrets',
          );
          final clearBefore = Map.of(before['env_clear'] as Map);
          final clearAfter = Map.of(after['env_clear'] as Map);
          if (service == 'api') {
            // The server's DW_ENVIRONMENT label is now the environment's own
            // name rather than the config section's.
            expect(
              clearBefore.remove('DW_ENVIRONMENT'),
              {'stage': 'staging', 'prod': 'production'}[destination],
            );
            expect(clearAfter.remove('DW_ENVIRONMENT'), destination);
          }
          expect(clearAfter, clearBefore, reason: '$destination/$service env');
        }
      }
      expect(
        DwKamalContract('shop').secretsImport('stage'),
        '~/${(await inspect('api', 'stage', environments['stage']!))['secrets_path']}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
