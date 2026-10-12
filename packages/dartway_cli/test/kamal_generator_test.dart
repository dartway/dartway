import 'dart:io';

import 'package:dartway_cli/src/deploy/kamal.dart';
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

  void configure({bool bundled = true, String name = 'staging'}) {
    final extra = bundled
        ? '  storage: bundled\n  storage_domain: files.example.com\n'
        : '  storage: external\n';
    write('deploy/config.yaml', configYaml(environment: name, extra: extra));
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
      write(
        'deploy/config.yaml',
        configYaml(extra: '  trusted_proxy_networks: [172.18.0.0/16]\n'),
      );
      final files = DwKamalGenerator(root).render();
      final base = loadYaml(files['deploy/kamal/api.yml']!) as Map;
      final stage = loadYaml(files['deploy/kamal/api.stage.yml']!) as Map;
      expect((base['proxy'] as Map)['forward_headers'], true);
      final web = loadYaml(files['deploy/kamal/web.yml']!) as Map;
      expect((web['proxy'] as Map).containsKey('forward_headers'), false);
      expect(
        (base['proxy'] as Map)['run']['options']['sysctl'],
        'net.ipv4.tcp_congestion_control=bbr',
      );
      expect(
        (stage['env'] as Map)['clear']['DW_TRUSTED_PROXY_NETWORKS'],
        '172.18.0.0/16',
      );
      expect((stage['env'] as Map)['clear']['DW_HTTP_BEHIND_PROXY'], 'true');
    },
  );

  YamlMap yaml(Map<String, String> files, String path) =>
      loadYaml(files[path]!) as YamlMap;

  for (final bundled in [true, false]) {
    test(
      'renders stage and prod with ${bundled ? 'bundled' : 'external'} storage',
      () {
        configure(bundled: bundled);
        final staging = File(
          p.join(root.path, 'deploy/config.yaml'),
        ).readAsStringSync();
        write(
          'deploy/config.yaml',
          staging +
              File('test/fixtures/kamal/production.yaml')
                  .readAsStringSync()
                  .replaceFirst(
                    'storage: bundled',
                    'storage: ${bundled ? 'bundled' : 'external'}',
                  )
                  .replaceFirst(
                    '  storage_domain: files.production.example.com\n',
                    bundled
                        ? '  storage_domain: files.production.example.com\n'
                        : '',
                  ),
        );
        final files = DwKamalGenerator(root).render();
        final api = yaml(files, 'deploy/kamal/api.yml');
        expect(api['image'], 'acme/shop-api');
        expect(api['proxy'].containsKey('path_prefixes'), false);
        expect(api['proxy'].containsKey('strip_path_prefix'), false);
        expect(api['proxy']['run']['version'], 'v0.10.2');
        expect(api['proxy']['buffering'], {
          'requests': false,
          'responses': false,
        });
        final web = yaml(files, 'deploy/kamal/web.yml');
        expect(web['proxy']['buffering'], {
          'requests': false,
          'responses': false,
        });
        expect(api['deploy_timeout'], 30);
        expect(api['drain_timeout'], 30);
        expect(api['retain_containers'], 5);
        expect(api['builder']['arch'], 'amd64');
        expect(api['registry']['password'], ['KAMAL_REGISTRY_PASSWORD']);
        for (final dest in ['stage', 'prod']) {
          final production = dest == 'prod';
          final apiHost = production
              ? 'api.production.example.com'
              : 'api.example.com';
          final appHost = production
              ? 'app.production.example.com'
              : 'app.example.com';
          final storageHost = production
              ? 'files.production.example.com'
              : 'files.example.com';
          final host = production ? '203.0.113.20' : '203.0.113.10';
          final target = yaml(files, 'deploy/kamal/api.$dest.yml');
          expect(target['proxy']['hosts'], [apiHost]);
          expect(target['servers']['web']['hosts'], [host]);
          expect(target['ssh'], {
            'user': production ? 'production_operator' : 'root',
          });
          final webTarget = yaml(files, 'deploy/kamal/web.$dest.yml');
          expect(webTarget['proxy']['hosts'], [appHost]);
          expect(webTarget['servers']['web']['hosts'], [host]);
          expect(webTarget['ssh'], target['ssh']);
          expect(webTarget['env']['clear'], {
            'DW_API_ORIGIN': 'https://$apiHost',
          });
          final clear = target['env']['clear'];
          expect(clear['DW_DATABASE_HOST'], 'shop-api-postgres-$dest');
          expect(clear['DW_ALLOWED_ORIGINS'], 'https://$appHost');
          expect(target['accessories']['postgres']['host'], host);
          expect(
            target['accessories']['postgres']['image'],
            'postgres:17-alpine',
          );
          expect(target['accessories']['postgres']['env']['secret'], [
            'POSTGRES_PASSWORD:DW_DATABASE_PASSWORD',
          ]);
          expect(target['accessories']['postgres'].containsKey('port'), false);
          expect(target['env']['secret'], contains('DW_DATABASE_PASSWORD'));
          if (bundled) {
            expect(clear['DW_STORAGE_PROVISION'], 'true');
            expect(clear['DW_STORAGE_VERIFY_BUCKETS'], 'false');
            expect(clear['DW_STORAGE_ENDPOINT'], 'https://$storageHost');
            expect(
              target['env']['secret'],
              containsAll(['DW_STORAGE_ACCESS_KEY', 'DW_STORAGE_SECRET_KEY']),
            );
            final storage = yaml(files, 'deploy/kamal/storage.$dest.yml');
            expect(storage['proxy']['hosts'], [storageHost]);
            expect(storage['servers']['web']['hosts'], [host]);
            expect(storage['ssh'], target['ssh']);
            expect(storage['env']['secret'], [
              'RUSTFS_ACCESS_KEY:DW_STORAGE_ACCESS_KEY',
              'RUSTFS_SECRET_KEY:DW_STORAGE_SECRET_KEY',
            ]);
          } else {
            expect(clear.containsKey('DW_STORAGE_ENDPOINT'), false);
            expect(files.containsKey('deploy/kamal/storage.yml'), false);
          }
        }
        final studio = yaml(files, 'deploy/studio.yml');
        expect(studio['services'], [if (bundled) 'storage', 'api', 'web']);
        expect(studio['environments'], ['stage', 'prod']);
        final workflow = yaml(files, '.github/workflows/images.yml');
        final imageJob = workflow['jobs']['images'];
        const configuredBranches =
            '''contains(fromJSON('["master","production"]'), github.event.workflow_run.head_branch)''';
        expect(imageJob['if'], contains(configuredBranches));
        final imageStep = (imageJob['steps'] as YamlList)
            .cast<YamlMap>()
            .singleWhere((step) => step['id'] == 'image');
        expect(imageStep['env']['PUBLISH'], contains(configuredBranches));
        for (final entry
            in imageJob['strategy']['matrix']['include'] as YamlList) {
          final service = entry['service'] as String;
          expect(
            entry['kamal_service'],
            yaml(files, 'deploy/kamal/$service.yml')['service'],
          );
        }
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
        expect(web['proxy']['healthcheck']['path'], '/');
        for (final path in files.keys.where(
          (path) => RegExp(r'deploy/kamal/.*\.yml$').hasMatch(path),
        )) {
          final proxy = yaml(files, path)['proxy'] as YamlMap;
          expect(
            proxy.containsKey('ssl') && proxy.containsKey('path_prefixes'),
            false,
            reason: path,
          );
        }
        expect(web['builder'].containsKey('args'), false);
        expect(
          files.values.every((text) => text.startsWith(kamalGeneratedHeader)),
          true,
        );
      },
    );
  }

  for (final (extra, key) in [
    ('  site:\n    domain: example.com\n    source: app_site/build\n', 'site:'),
  ]) {
    test('refuses unsupported $key instead of silently omitting it', () {
      write('deploy/config.yaml', configYaml(extra: extra));
      expect(
        () => DwKamalGenerator(root).generate(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(key),
              contains("Kamal topology doesn't support this yet"),
              contains('deploy run'),
            ),
          ),
        ),
      );
      expect(Directory(p.join(root.path, 'deploy/kamal')).existsSync(), false);
    });
  }

  test('secret files belong only to their API destination, never to images', () {
    write(
      'deploy/config.yaml',
      'requires:\n  files: [db-ca.pem]\n' +
          configYaml(
            extra:
                '  storage: external\n  requires:\n    files: [fcm-stage.json]\n',
          ) +
          File('test/fixtures/kamal/production.yaml')
              .readAsStringSync()
              .replaceFirst('storage: bundled', 'storage: external')
              .replaceFirst(
                '  storage_domain: files.production.example.com\n',
                '',
              ) +
          '  requires:\n    files: [fcm-prod.json]\n',
    );
    final files = DwKamalGenerator(root).render();
    for (final (destination, user) in [
      ('stage', 'deployer'),
      ('prod', 'production_deployer'),
    ]) {
      final api = yaml(files, 'deploy/kamal/api.$destination.yml');
      expect(api['volumes'], [
        '/home/$user/.config/shop/db-ca.pem:/run/secrets/db-ca.pem:ro',
        '/home/$user/.config/shop/fcm-$destination.json:/run/secrets/fcm-$destination.json:ro',
      ]);
      expect(
        yaml(files, 'deploy/kamal/web.$destination.yml').containsKey('volumes'),
        false,
      );
      expect(api['env']['secret'], isNot(contains('fcm-$destination.json')));
    }
    expect(
      yaml(files, 'deploy/kamal/api.yml')['hooks_path'],
      'deploy/kamal/hooks/api',
    );
    expect(files.containsKey(kamalSecretFilesHookPath), true);
    expect(files['.github/workflows/images.yml'], isNot(contains('fcm-')));
    expect(
      yaml(files, 'deploy/kamal/web.yml').containsKey('hooks_path'),
      false,
    );
  });

  test(
    'secret hook is executable, checked without writes and removed when obsolete',
    () {
      write(
        'deploy/config.yaml',
        configYaml(extra: '  requires:\n    files: [fcm.json]\n'),
      );
      final generator = DwKamalGenerator(root)..generate();
      final hook = File(p.join(root.path, kamalSecretFilesHookPath));
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
      expect(
        generator.generate(check: true),
        contains(kamalSecretFilesHookPath),
      );
      expect(hook.existsSync(), true);
      generator.generate();
      expect(hook.existsSync(), false);
      expect(generator.generate(check: true), isEmpty);
    },
  );

  test('an external site requires no Kamal service', () {
    write(
      'deploy/config.yaml',
      configYaml(extra: '  site:\n    domain: example.com\n    source: none\n'),
    );
    expect(
      DwKamalGenerator(root).render().containsKey('deploy/studio.yml'),
      true,
    );
  });

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

  test('privileged image builds reject fork PRs and PRs cannot write caches', () {
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
    final build = steps.singleWhere(
      (step) => step['uses'] == 'docker/build-push-action@v6',
    );
    expect(
      build['with']['cache-to'],
      r"${{ steps.image.outputs.publish == 'true' && format('type=gha,mode=max,scope={0}', matrix.service) || '' }}",
    );
    final checkout = steps.singleWhere(
      (step) => step['uses'] == 'actions/checkout@v4',
    );
    expect(checkout['with']['persist-credentials'], false);
  });

  for (final branch in ['main', 'deploy/production', "deploy/o'hare"]) {
    test('image publication follows the configured branch $branch', () {
      write(
        'deploy/config.yaml',
        configYaml().replaceFirst('branch: master', 'branch: $branch'),
      );
      final workflow = yaml(
        DwKamalGenerator(root).render(),
        '.github/workflows/images.yml',
      );
      final job = workflow['jobs']['images'] as YamlMap;
      final branches = '["${branch.replaceAll("'", "''")}"]';
      final predicate =
          "contains(fromJSON('$branches'), github.event.workflow_run.head_branch)";
      expect(job['if'], contains(predicate));
      expect(
        job['if'],
        contains("github.event.workflow_run.event == 'pull_request'"),
      );
      final image = (job['steps'] as YamlList).cast<YamlMap>().singleWhere(
        (step) => step['id'] == 'image',
      );
      expect(
        image['env']['PUBLISH'],
        r"${{ github.event.workflow_run.event == 'push' && " +
            predicate +
            ' }}',
      );
    });
  }

  test('requires are names only and external database has no accessory', () {
    write(
      'deploy/config.yaml',
      configYaml(
        extra: '''
  database: external
  storage: external
  requires:
    secrets: [SMS_API_TOKEN, DW_STORAGE_PUBLIC_BUCKET, DW_STORAGE_PUBLIC_BASE_URL]
''',
      ),
    );
    final files = DwKamalGenerator(root).render();
    final api = yaml(files, 'deploy/kamal/api.stage.yml');
    expect(api.containsKey('accessories'), false);
    expect(
      api['env']['secret'],
      containsAll([
        'SMS_API_TOKEN',
        'DW_DATABASE_HOST',
        'DW_STORAGE_PUBLIC_BUCKET',
        'DW_STORAGE_PUBLIC_BASE_URL',
      ]),
    );
  });

  test('unknown deployment is refused by name', () {
    configure(name: 'preview');
    expect(
      () => DwKamalGenerator(root).render(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('preview'),
        ),
      ),
    );
  });

  for (final name in ['Shop', 'shop.name', '-shop']) {
    test(
      'invalid repository project name $name names project: and its value',
      () {
        write(
          'deploy/config.yaml',
          configYaml().replaceFirst('acme/shop.git', 'acme/$name.git'),
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
      write(
        'deploy/config.yaml',
        configYaml(extra: '  project: shop_2-test\n'),
      );
      final files = DwKamalGenerator(root).render();
      final api = yaml(files, 'deploy/kamal/api.yml');
      expect(api['service'], 'shop_2-test-api');
      expect(api['image'], 'acme/shop_2-test-api');
      final workflow = yaml(files, '.github/workflows/images.yml');
      final steps = (workflow['jobs']['images']['steps'] as YamlList)
          .cast<YamlMap>();
      final identity = steps.singleWhere((step) => step['id'] == 'image');
      expect(identity['env']['REPOSITORY'], 'acme/shop_2-test');
      expect(identity['run'], isNot(contains('tr ')));
    },
  );

  test('invalid explicit project name is refused without lowercasing', () {
    write('deploy/config.yaml', configYaml(extra: '  project: Shop\n'));
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

  test('removing bundled storage removes obsolete generated files', () {
    final generator = DwKamalGenerator(root)..generate();
    configure(bundled: false);
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
