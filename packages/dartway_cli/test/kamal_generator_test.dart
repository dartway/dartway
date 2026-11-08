import 'dart:io';

import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_contract.dart';
import 'package:dartway_cli/src/deploy/kamal_secret_files.dart';
import 'package:dartway_cli/src/project_layout.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory root;

  void write(String path, String text) {
    final file = File(p.join(root.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  void configure({bool storage = true, String extra = '', String top = ''}) {
    write(
      'deploy/config.yaml',
      '${top}kamal:\n'
          '  repo: git@github.com:acme/shop.git\n'
          '  storage: $storage\n'
          '$extra',
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('kamal-generator-');
    for (final role in ['server', 'flutter', 'shared']) {
      write('shop_$role/pubspec.yaml', 'name: shop_$role\n');
    }
    write('shop_server/lib/routes.dart', '''
// DwHttpRoute.post('/comment', handler);
/* DwHttpRoute.get('/ignored', handler); */
final routes = [
  DwHttpRoute.post('/github', handler),
  DwHttpRoute.get('/orders/events', handler),
  DwHttpRoute.any('/github', handler),
];
''');
    write(
      'shop_flutter/pubspec.lock',
      File('test/fixtures/kamal/hosted.lock').readAsStringSync(),
    );
    configure();
  });
  tearDown(() => root.deleteSync(recursive: true));

  YamlMap yaml(Map<String, String> files, String path) =>
      loadYaml(files[path]!) as YamlMap;

  test(
    'native generation refuses ingress snippets instead of silently discarding them',
    () {
      write('deploy/nginx.d/http/quota.conf', 'limit_req_zone fixture;\n');
      expect(
        () => DwKamalGenerator(root).render(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message.toString(),
            'message',
            contains('callRateLimits'),
          ),
        ),
      );
    },
  );

  test(
    'native ingress trust and BBR are carried into generated configuration',
    () {
      final files = DwKamalGenerator(root).render();
      final api = files['deploy/kamal/api.yml']!;
      expect(api, contains('  forward_headers: true\n'));
      expect(files['deploy/kamal/web.yml'], isNot(contains('forward_headers')));
      expect(api, contains('sysctl: "net.ipv4.tcp_congestion_control=bbr"'));
      expect(
        api,
        contains(
          'DW_TRUSTED_PROXY_NETWORKS: <%= (trusted_proxy_networks).to_json %>',
        ),
      );
      expect(api, contains('DW_HTTP_BEHIND_PROXY: "true"'));
      expect(yaml(files, 'deploy/studio.yml')['values'], [
        'DW_TRUSTED_PROXY_NETWORKS',
      ]);
    },
  );

  test('image builds pass the workflow run number to every service', () {
    final workflow = yaml(
      DwKamalGenerator(root).render(),
      '.github/workflows/images.yml',
    );
    final steps = workflow['jobs']['images']['steps'] as YamlList;
    final build = steps.cast<YamlMap>().singleWhere(
      (step) => step['uses'] == 'docker/build-push-action@v6',
    );
    expect(
      build['with']['build-args'],
      r'BUILD_NUMBER=${{ github.run_number }}',
    );
  });

  for (final storage in [true, false]) {
    test(
      'renders one environment-free contract ${storage ? 'with' : 'without'} storage',
      () {
        configure(storage: storage);
        final files = DwKamalGenerator(root).render();
        final services = [if (storage) 'storage', 'api', 'web'];
        expect(files.keys.toSet(), {
          for (final service in services) 'deploy/kamal/$service.yml',
          if (storage) 'deploy/kamal/storage/Dockerfile',
          'deploy/studio.yml',
          '.github/workflows/images.yml',
        });
        for (final service in services) {
          final text = files['deploy/kamal/$service.yml']!;
          expect(text, startsWith(kamalGeneratedHeader));
          expect(text, contains('service: "shop-$service"'));
          expect(text, contains('image: "acme/shop-$service"'));
          expect(text, contains('minimum_version: "2.12.0"'));
          expect(text, contains('hosts: [<%= (host).to_json %>]'));
          expect(text, contains('user: <%= (ssh_user).to_json %>'));
          expect(text, contains("ENV['KAMAL_DESTINATION'] == environment"));
          expect(text, contains('version: "v0.10.2"'));
          expect(text, contains('requests: false'));
          expect(text, contains('deploy_timeout: 30'));
          expect(text, contains('retain_containers: 5'));
          expect(text, contains('password: ["KAMAL_REGISTRY_PASSWORD"]'));
          // No environment, host or domain is written into the repository.
          for (final literal in ['stage', 'prod', 'staging', 'example.com']) {
            expect(
              text,
              isNot(contains(literal)),
              reason: '$service: $literal',
            );
          }
        }
        final api = files['deploy/kamal/api.yml']!;
        expect(api, contains("STUDIO_BUNDLED_DATABASE"));
        expect(api, contains('<% if bundled_database -%>\naccessories:\n'));
        expect(
          api,
          contains(
            "DW_DATABASE_HOST: <%= ('shop-api-postgres-' + environment).to_json %>",
          ),
        );
        expect(api, contains('image: "postgres:17-alpine"'));
        expect(
          api,
          contains('secret: ["POSTGRES_PASSWORD:DW_DATABASE_PASSWORD"]'),
        );
        expect(api, contains('healthcheck:\n    path: "/health"'));
        expect(
          files['deploy/kamal/web.yml'],
          contains("DW_API_ORIGIN: <%= ('https://' + domain_api).to_json %>"),
        );
        expect(files['deploy/kamal/web.yml'], contains('path: "/"'));
        expect(files['deploy/kamal/web.yml'], isNot(contains('BUNDLED')));
        if (storage) {
          expect(api, contains('<% if bundled_storage -%>'));
          expect(api, contains('DW_STORAGE_PROVISION: "true"'));
          expect(
            api,
            contains(
              "DW_STORAGE_ENDPOINT: <%= (value.call('DW_STORAGE_ENDPOINT')).to_json %>",
            ),
          );
          final store = files['deploy/kamal/storage.yml']!;
          expect(store, contains('unless bundled_storage'));
          expect(
            store,
            contains(
              "volumes: [<%= ('shop-storage-data-' + environment + ':/data').to_json %>]",
            ),
          );
          expect(store, contains('RUSTFS_ACCESS_KEY:DW_STORAGE_ACCESS_KEY'));
        } else {
          expect(api, isNot(contains('STORAGE')));
        }

        final studio = yaml(files, 'deploy/studio.yml');
        expect(studio.containsKey('environments'), false);
        expect(studio['project'], 'shop');
        expect(studio['services'], services);
        expect(studio['environment'], {
          'name': 'STUDIO_ENVIRONMENT',
          'host': 'STUDIO_HOST',
          'ssh_user': 'STUDIO_SSH_USER',
        });
        expect(studio['kamal']['config'], 'deploy/kamal/{service}.yml');
        expect(studio['kamal']['destination'], '{env}');
        expect(studio['kamal']['destination_config'], {
          'path': 'deploy/kamal/{service}.{env}.yml',
          'content': '{}',
        });
        expect(studio['ingress'], {
          'api': {'variable': 'STUDIO_DOMAIN_API', 'service': 'api'},
          'app': {'variable': 'STUDIO_DOMAIN_APP', 'service': 'web'},
          if (storage)
            'files': {
              'variable': 'STUDIO_DOMAIN_FILES',
              'service': 'storage',
              'component': 'storage',
            },
        });
        expect(studio['components']['database'], {
          'variable': 'STUDIO_BUNDLED_DATABASE',
          'provider': {'service': 'api', 'accessory': 'postgres'},
          'bundled': <String, Object?>{},
          'external': {
            'secrets': [
              'DW_DATABASE_HOST',
              'DW_DATABASE_PORT',
              'DW_DATABASE_NAME',
              'DW_DATABASE_USER',
            ],
          },
        });
        if (storage) {
          final component = studio['components']['storage'];
          expect(component['provider'], {'service': 'storage'});
          expect(component['bundled']['secrets'], [
            'DW_STORAGE_ACCESS_KEY',
            'DW_STORAGE_SECRET_KEY',
          ]);
          expect(component['external']['values'], ['DW_STORAGE_ENDPOINT']);
          expect(
            component['external']['optional_values'],
            contains('DW_STORAGE_PUBLIC_BUCKET'),
          );
        } else {
          expect((studio['components'] as YamlMap).keys, ['database']);
        }
        expect(studio['secrets'], [
          'KAMAL_REGISTRY_PASSWORD',
          'DW_DATABASE_PASSWORD',
        ]);
        expect(
          studio['secrets_import'],
          '~/.kamal/apps/shop-api-{env}/env/roles/web.env',
        );
        expect(studio['check']['args'], [
          '--project',
          '/project',
          '--env',
          '{env}',
          '--version',
          '{version}',
        ]);
        expect(
          studio['check']['image'],
          'ghcr.io/dartway/dartway-check:0.24.0',
        );
        expect(studio['check']['environment'], [
          'STUDIO_DOMAIN_API',
          'STUDIO_DOMAIN_APP',
          if (storage) ...['STUDIO_DOMAIN_FILES', 'STUDIO_BUNDLED_STORAGE'],
        ]);
        final manifest = DwKamalManifest.parse(files['deploy/studio.yml']!);
        expect(manifest.services, services);
        expect(manifest.components.map((c) => c.name), [
          'database',
          if (storage) 'storage',
        ]);

        final workflow = yaml(files, '.github/workflows/images.yml');
        expect(workflow['concurrency'], {
          'group': 'images-\${{ github.event.workflow_run.head_branch }}',
          'cancel-in-progress': false,
        });
        final imageJob = workflow['jobs']['images'];
        for (final entry
            in imageJob['strategy']['matrix']['include'] as YamlList) {
          expect(entry['kamal_service'], 'shop-${entry['service']}');
        }
        expect(
          (imageJob['strategy']['matrix']['include'] as YamlList).map(
            (entry) => entry['service'],
          ),
          services,
        );
        final buildStep = (imageJob['steps'] as YamlList)
            .cast<YamlMap>()
            .singleWhere(
              (step) =>
                  '${step['uses']}'.startsWith('docker/build-push-action'),
            );
        expect(
          buildStep['with']['labels'],
          contains(r'service=${{ matrix.kamal_service }}'),
        );
      },
    );
  }

  test('a Kamal project keeps no deployment sections', () {
    write(
      'deploy/config.yaml',
      '${configYaml()}kamal:\n  repo: git@github.com:acme/shop.git\n',
    );
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('staging'), contains('Studio')),
        ),
      ),
    );
    write('deploy/config.yaml', 'local:\n  DW_DATABASE_PORT: 8090\n');
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('kamal:'), contains('repo:')),
        ),
      ),
    );
    configure(extra: '  host: 203.0.113.10\n');
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('unknown key "host"'),
        ),
      ),
    );
  });

  test('regeneration removes destination files of the previous contract', () {
    for (final file in Directory(
      'test/fixtures/kamal/legacy',
    ).listSync().whereType<File>()) {
      if (p.basename(file.path) == 'config.yaml') continue;
      write('deploy/kamal/${p.basename(file.path)}', file.readAsStringSync());
    }
    write('deploy/kamal/api.preview.yml', '{}\n');
    final generator = DwKamalGenerator(root);
    expect(
      generator.generate(check: true),
      containsAll([
        'deploy/kamal/api.stage.yml',
        'deploy/kamal/storage.prod.yml',
        'deploy/kamal/web.yml',
      ]),
    );
    generator.generate();
    expect(
      Directory(p.join(root.path, 'deploy/kamal'))
          .listSync()
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .toSet(),
      // Studio's empty destination file is not the generator's.
      {'storage.yml', 'api.yml', 'web.yml', 'api.preview.yml'},
    );
    expect(generator.generate(check: true), isEmpty);
  });

  for (final (extra, key) in [
    ('  site:\n    domain: example.com\n    source: app_site/build\n', 'site:'),
  ]) {
    test('refuses unknown $key instead of silently omitting it', () {
      configure(extra: extra);
      expect(
        () => DwKamalGenerator(root).generate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('unknown key "site"'),
          ),
        ),
      );
      expect(Directory(p.join(root.path, 'deploy/kamal')).existsSync(), false);
    });
  }

  test('secret files belong only to the API, never to images', () {
    configure(top: 'requires:\n  files: [db-ca.pem, fcm.json]\n');
    final files = DwKamalGenerator(root).render();
    expect(
      files['deploy/kamal/api.yml'],
      contains(
        'volumes: ["/home/dw_admin/.config/shop/db-ca.pem:/run/secrets/db-ca.pem:ro",'
        '"/home/dw_admin/.config/shop/fcm.json:/run/secrets/fcm.json:ro"]',
      ),
    );
    expect(
      files['deploy/kamal/api.yml'],
      contains('hooks_path: "deploy/kamal/hooks/api"'),
    );
    expect(files['deploy/kamal/web.yml'], isNot(contains('volumes')));
    expect(files['deploy/kamal/web.yml'], isNot(contains('hooks_path')));
    expect(files.containsKey(kamalSecretFilesHookPath), true);
    expect(files['.github/workflows/images.yml'], isNot(contains('fcm')));
    expect(yaml(files, 'deploy/studio.yml')['secret_files'], {
      'directory': '/home/dw_admin/.config/shop',
      'names': ['db-ca.pem', 'fcm.json'],
    });
    configure(
      top: 'requires:\n  files: [fcm.json]\n',
      extra: '  deploy_user: deployer\n',
    );
    expect(
      DwKamalGenerator(root).render()['deploy/kamal/api.yml'],
      contains(
        '"/home/deployer/.config/shop/fcm.json:/run/secrets/fcm.json:ro"',
      ),
    );
  });

  test(
    'secret hook is executable, checked without writes and removed when obsolete',
    () {
      configure(top: 'requires:\n  files: [fcm.json]\n');
      final generator = DwKamalGenerator(root)..generate();
      final hook = File(p.join(root.path, kamalSecretFilesHookPath));
      expect(
        hook.readAsStringSync(),
        allOf(
          contains('File.expand_path("deploy/kamal/api.yml")'),
          isNot(contains('__dir__')),
        ),
        reason:
            'Studio runs hooks through a symlink into read-only source; the '
            'destination config exists only in the working directory.',
      );
      expect(generator.generate(check: true), isEmpty);
      if (!Platform.isWindows) {
        expect(hook.statSync().mode & 0x49, isNot(0));
        expect(Process.runSync('chmod', ['644', hook.path]).exitCode, 0);
        expect(
          generator.generate(check: true),
          contains(kamalSecretFilesHookPath),
        );
        expect(hook.statSync().mode & 0x49, 0);
        generator.generate();
        expect(hook.statSync().mode & 0x49, isNot(0));
      }
      configure();
      final next = DwKamalGenerator(root);
      expect(next.generate(check: true), contains(kamalSecretFilesHookPath));
      expect(hook.existsSync(), true);
      next.generate();
      expect(hook.existsSync(), false);
      expect(next.generate(check: true), isEmpty);
    },
  );

  test('refuses a vendored CLI path in the project git work tree', () {
    write(
      'shop_flutter/pubspec.lock',
      File('test/fixtures/kamal/path.lock').readAsStringSync(),
    );
    write('framework/packages/dartway_cli/pubspec.yaml', 'name: dartway_cli\n');
    for (final args in [
      ['init'],
      ['add', 'framework/packages/dartway_cli/pubspec.yaml'],
      [
        '-c',
        'user.name=Test',
        '-c',
        'user.email=test@example.com',
        'commit',
        '-m',
        'test: vendored CLI fixture',
      ],
    ]) {
      final result = Process.runSync('git', ['-C', root.path, ...args]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    expect(
      () => DwKamalGenerator(root).generate(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('dartway_cli'),
            contains('git work tree'),
            contains('pin'),
            contains('git ref'),
          ),
        ),
      ),
    );
    expect(Directory(p.join(root.path, 'deploy/kamal')).existsSync(), false);
  });

  test('privileged image builds reject CI from forks', () {
    final workflow = yaml(
      DwKamalGenerator(root).render(),
      '.github/workflows/images.yml',
    );
    final job = workflow['jobs']['images'] as YamlMap;
    expect(
      job['if'],
      contains(
        'github.event.workflow_run.head_repository.full_name == github.repository',
      ),
    );
    final steps = (job['steps'] as YamlList).cast<YamlMap>();
    final checkout = steps.singleWhere(
      (step) => step['uses'] == 'actions/checkout@v4',
    );
    expect(checkout['with']['persist-credentials'], false);
  });

  test('images skip PR CI and publish pushed and hand-started CI', () {
    final workflow = yaml(
      DwKamalGenerator(root).render(),
      '.github/workflows/images.yml',
    );
    final job = workflow['jobs']['images'] as YamlMap;
    expect(job['if'], isNot(contains('head_branch')));
    expect(job['if'], contains("workflow_run.conclusion == 'success'"));
    expect(job['if'], contains("workflow_run.event == 'push'"));
    expect(job['if'], contains("workflow_run.event == 'workflow_dispatch'"));
    expect(job['if'], isNot(contains("workflow_run.event == 'pull_request'")));
    final build = (job['steps'] as YamlList).cast<YamlMap>().singleWhere(
      (step) => step['uses'] == 'docker/build-push-action@v6',
    );
    expect(build['with']['push'], true);
    expect(
      build['with']['cache-to'],
      r'type=gha,mode=max,scope=${{ matrix.service }}',
    );
  });

  test('requires.secrets cannot name what the contract sets in env.clear', () {
    configure(
      top: 'requires:\n  secrets: [SMS_API_TOKEN, DW_STORAGE_PUBLIC_BUCKET]\n',
    );
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('DW_STORAGE_PUBLIC_BUCKET'),
            contains('requires.secrets'),
          ),
        ),
      ),
    );
    configure(top: 'requires:\n  secrets: [SMS_API_TOKEN]\n');
    final files = DwKamalGenerator(root).render();
    expect(files['deploy/kamal/api.yml'], contains('    - "SMS_API_TOKEN"\n'));
    expect(
      yaml(files, 'deploy/studio.yml')['secrets'],
      contains('SMS_API_TOKEN'),
    );
  });

  for (final name in ['Shop', 'shop.name', '-shop']) {
    test(
      'invalid repository project name $name names project: and its value',
      () {
        write(
          'deploy/config.yaml',
          'kamal:\n  repo: git@github.com:acme/$name.git\n',
        );
        expect(
          () => DwKamalGenerator(root).render(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('project:'), contains(name)),
            ),
          ),
        );
      },
    );
  }

  test(
    'explicit valid project name owns both service and image identities',
    () {
      configure(extra: '  project: shop_2-test\n');
      final files = DwKamalGenerator(root).render();
      expect(
        files['deploy/kamal/api.yml'],
        contains('service: "shop_2-test-api"'),
      );
      expect(
        files['deploy/kamal/api.yml'],
        contains('image: "acme/shop_2-test-api"'),
      );
      final workflow = yaml(files, '.github/workflows/images.yml');
      final steps = (workflow['jobs']['images']['steps'] as YamlList)
          .cast<YamlMap>();
      final identity = steps.singleWhere((step) => step['id'] == 'image');
      expect(identity['env']['REPOSITORY'], 'acme/shop_2-test');
      expect(identity['run'], isNot(contains('tr ')));
    },
  );

  test('invalid explicit project name is refused without lowercasing', () {
    configure(extra: '  project: Shop\n');
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('project:'), contains('Shop')),
        ),
      ),
    );
  });

  test('--check ignores server route changes', () {
    final generator = DwKamalGenerator(root);
    generator.generate();
    expect(generator.generate(check: true), isEmpty);
    final api = File(p.join(root.path, 'deploy/kamal/api.yml'));
    final before = api.readAsStringSync();
    write(
      'shop_server/lib/new_route.dart',
      "DwHttpRoute.post('/new-webhook', handler);\n"
          "DwHttpRoute.get('/', handler);",
    );
    expect(generator.generate(check: true), isEmpty);
    expect(api.readAsStringSync(), before);
  });

  test('CLI --check ignores server route changes', () async {
    final generator = DwKamalGenerator(root)..generate();
    Future<ProcessResult> check() => Process.run(Platform.resolvedExecutable, [
      '--packages=${p.absolute('../../.dart_tool/package_config.json')}',
      p.absolute('bin/dartway.dart'),
      'deploy',
      'kamal',
      '--check',
    ], workingDirectory: root.path);
    expect((await check()).exitCode, 0);
    write(
      'shop_server/lib/new_route.dart',
      "DwHttpRoute.post('/new', handler);",
    );
    expect((await check()).exitCode, 0);
    expect(generator.generate(check: true), isEmpty);
  });

  test('removing storage removes obsolete generated files', () {
    DwKamalGenerator(root).generate();
    configure(storage: false);
    final generator = DwKamalGenerator(root);
    expect(
      generator.generate(check: true),
      contains('deploy/kamal/storage.yml'),
    );
    generator.generate();
    expect(
      File(p.join(root.path, 'deploy/kamal/storage.yml')).existsSync(),
      false,
    );
    expect(generator.generate(check: true), isEmpty);
  });

  test('a path checkout without git names the unresolved CLI lock', () async {
    write(
      'shop_flutter/pubspec.lock',
      File('test/fixtures/kamal/path.lock').readAsStringSync(),
    );
    Directory(
      p.join(root.path, 'framework/packages/dartway_cli'),
    ).createSync(recursive: true);
    Directory(p.join(root.path, 'empty-bin')).createSync();
    write('resolve_tag.dart', '''
import 'dart:io';
import 'package:dartway_cli/src/deploy/kamal.dart';
import 'package:dartway_cli/src/deploy/kamal_contract.dart';
import 'package:dartway_cli/src/project_layout.dart';
void main(List<String> args) {
  try {
    DwKamalGenerator.checkImageTag(ProjectLayout.detect(Directory(args.single)));
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
''');
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        '--packages=${p.absolute('../../.dart_tool/package_config.json')}',
        p.join(root.path, 'resolve_tag.dart'),
        root.path,
      ],
      environment: {'PATH': p.join(root.path, 'empty-bin')},
    );
    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains('pubspec.lock: cannot resolve a check image tag'),
    );
    expect(result.stderr, isNot(contains('ProcessException')));
  });

  for (final source in ['git', 'hosted', 'path']) {
    test('check image tag from $source lock fixture', () {
      write(
        'shop_flutter/pubspec.lock',
        File('test/fixtures/kamal/$source.lock').readAsStringSync(),
      );
      var expected = source == 'hosted'
          ? '0.24.0'
          : '0123456789abcdef0123456789abcdef01234567';
      if (source == 'path') {
        final checkout = Directory(
          p.join(root.path, 'framework/packages/dartway_cli'),
        )..createSync(recursive: true);
        write(
          'framework/packages/dartway_cli/pubspec.yaml',
          'name: dartway_cli\n',
        );
        void git(List<String> args) {
          final result = Process.runSync('git', ['-C', checkout.path, ...args]);
          expect(result.exitCode, 0, reason: '${result.stderr}');
        }

        git(['init']);
        git(['add', 'pubspec.yaml']);
        git([
          '-c',
          'user.name=Test',
          '-c',
          'user.email=test@example.com',
          'commit',
          '-m',
          'test: fixture',
        ]);
        expected =
            (Process.runSync('git', [
                      '-C',
                      checkout.path,
                      'rev-parse',
                      'HEAD',
                    ]).stdout
                    as String)
                .trim();
      }
      expect(
        DwKamalGenerator.checkImageTag(ProjectLayout.detect(root)),
        expected,
      );
    });
  }
}
