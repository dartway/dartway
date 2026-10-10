import 'dart:io';

import 'package:dartway_cli/src/deploy/kamal.dart';
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
  DwHttpRoute.get('/orders/:id/events/:event', handler),
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
          '$staging${staging.replaceFirst('staging:', 'production:')}',
        );
        final files = DwKamalGenerator(root).render();
        final api = yaml(files, 'deploy/kamal/api.yml');
        expect(api['image'], 'acme/shop-api');
        expect(api['proxy']['path_prefixes'], [
          '/dw',
          '/health',
          '/github',
          '/orders',
        ]);
        expect(api['proxy']['strip_path_prefix'], false);
        expect(api['proxy']['run']['version'], 'v0.10.2');
        expect(api['proxy']['buffering'], {
          'requests': false,
          'responses': false,
        });
        expect(api['deploy_timeout'], 30);
        expect(api['drain_timeout'], 30);
        expect(api['retain_containers'], 5);
        expect(api['builder']['arch'], 'amd64');
        expect(api['registry']['password'], ['KAMAL_REGISTRY_PASSWORD']);
        for (final dest in ['stage', 'prod']) {
          final target = yaml(files, 'deploy/kamal/api.$dest.yml');
          expect(target['proxy']['hosts'], [
            'api.example.com',
            'app.example.com',
          ]);
          expect(target['servers']['web']['hosts'], ['203.0.113.10']);
          expect(target['ssh'], {'user': 'root'});
          final clear = target['env']['clear'];
          expect(clear['DW_DATABASE_HOST'], 'shop-api-postgres-$dest');
          expect(
            target['accessories']['postgres']['image'],
            'postgres:17-alpine',
          );
          expect(target['accessories']['postgres']['env']['secret'], [
            'POSTGRES_PASSWORD:DW_DATABASE_PASSWORD',
          ]);
          expect(target['env']['secret'], contains('DW_DATABASE_PASSWORD'));
          if (bundled) {
            expect(clear['DW_STORAGE_PROVISION'], 'true');
            expect(clear['DW_STORAGE_VERIFY_BUCKETS'], 'false');
            expect(clear['DW_STORAGE_ENDPOINT'], 'https://files.example.com');
            expect(
              target['env']['secret'],
              containsAll(['DW_STORAGE_ACCESS_KEY', 'DW_STORAGE_SECRET_KEY']),
            );
            final storage = yaml(files, 'deploy/kamal/storage.$dest.yml');
            expect(storage['proxy']['hosts'], ['files.example.com']);
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
        expect(studio['check']['args'], [
          '--project',
          '/project',
          '--env',
          '{env}',
        ]);
        expect(
          studio['check']['image'],
          'ghcr.io/dartway/dartway-check:0.24.0',
        );
        final web = yaml(files, 'deploy/kamal/web.yml');
        expect(web['proxy']['healthcheck']['path'], '/');
        expect(web['builder'].containsKey('args'), false);
        expect(
          files.values.every((text) => text.startsWith(kamalGeneratedHeader)),
          true,
        );
      },
    );
  }

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

  for (final expression in [
    'path',
    "'/foo/\$id'",
    "'/foo' + '/bar'",
    "'/foo' '/bar'",
  ]) {
    test('non-literal route $expression names file and line', () {
      write(
        'shop_server/lib/routes.dart',
        '\nDwHttpRoute.post($expression, handler);\n',
      );
      expect(
        () => DwKamalGenerator(root).render(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('shop_server/lib/routes.dart:2'),
          ),
        ),
      );
    });
  }

  test('--check catches an added route without changing files', () {
    final generator = DwKamalGenerator(root);
    generator.generate();
    expect(generator.generate(check: true), isEmpty);
    final api = File(p.join(root.path, 'deploy/kamal/api.yml'));
    final before = api.readAsStringSync();
    write(
      'shop_server/lib/new_route.dart',
      "DwHttpRoute.post('/new-webhook', handler);",
    );
    expect(generator.generate(check: true), ['deploy/kamal/api.yml']);
    expect(api.readAsStringSync(), before);
    generator.generate();
    expect(generator.generate(check: true), isEmpty);
  });

  test('CLI --check returns failure for the same stale route config', () async {
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
    final stale = await check();
    expect(stale.exitCode, 1);
    expect(stale.stderr, contains('deploy/kamal/api.yml'));
    expect(generator.generate(check: true), ['deploy/kamal/api.yml']);
  });

  test('decodes literal escapes and ignores route-looking strings', () {
    write('shop_server/lib/routes.dart', r'''
final ignored = "DwHttpRoute.post('/ignored', handler)";
DwHttpRoute.get('/\x67ithub', handler);
DwHttpRoute.get(r'/orders/:id', handler);
DwHttpRoute.get(/* comment */ '/\u{0066}iles', handler);
''');
    expect(
      DwKamalGenerator.routePrefixes(
        ProjectLayout.detect(root).serverPackageDir,
      ),
      ['/dw', '/health', '/github', '/orders', '/files'],
    );
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
