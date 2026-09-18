import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/vendor_framework.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

DwDeployCheck _local(String id) =>
    dwLocalDeployChecks.firstWhere((check) => check.id == id);

void main() {
  group('check declarations', () {
    test('every id is unique', () {
      final ids = [
        ...dwLocalDeployChecks,
        ...dwRemoteDeployChecks,
      ].map((check) => check.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('local checks are local and need no server', () {
      expect(
        dwLocalDeployChecks.every((c) => c.stage == DwDeployCheckStage.local),
        isTrue,
      );
      expect(dwLocalDeployChecks.any((c) => c.requiresSsh), isFalse);
      expect(
        dwRemoteDeployChecks.every((c) => c.stage == DwDeployCheckStage.remote),
        isTrue,
      );
    });

    // A deployment does not read the local secrets file, and on CI that file
    // is absent by design.
    test('only the local-secrets coverage is left out of a deployment', () {
      expect(
        dwLocalDeployChecks.where((c) => !c.partOfDeploy).map((c) => c.id),
        ['local-secrets-cover-environment'],
      );
    });

    // The outside check asks the site, not the server: it must still run when
    // SSH has failed.
    test('what the site answers is asked over HTTPS, and errors', () {
      final outside = dwRemoteDeployChecks.firstWhere((c) => c.id == 'outside');
      expect(outside.requiresSsh, isFalse);
      expect(outside.severity, DwCheckSeverity.error);
    });
  });

  group('local checks', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dw_checks_'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String relative, String contents) {
      File(p.join(root.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    DwDeployContext contextFor(DwStack stack) =>
        DwDeployContext(projectRoot: root, stack: stack);

    Future<DwDeployVerdict> evaluate(String id, [DwStack? stack]) =>
        _local(id).evaluate(contextFor(stack ?? stackFrom()));

    test(
      'secret-names: a required secret the compose file sets is refused',
      () async {
        final verdict = await evaluate(
          'secret-names',
          stackFrom(extra: '  requires:\n    secrets: [DW_DATABASE_HOST]\n'),
        );
        expect(verdict.passed, isFalse);
        expect(verdict.detail, contains('DW_DATABASE_HOST'));
      },
    );

    test('server-signals: shell form keeps SIGTERM from the server', () async {
      write('shop_server/Dockerfile', 'FROM alpine\nENTRYPOINT /app/server\n');
      final shell = await evaluate('server-signals');
      expect(shell.passed, isFalse);
      expect(shell.detail, contains('shell form'));

      write(
        'shop_server/Dockerfile',
        'FROM alpine\nENTRYPOINT ["/app/server"]\n',
      );
      expect((await evaluate('server-signals')).passed, isTrue);

      write('shop_server/Dockerfile', 'FROM alpine\n');
      expect((await evaluate('server-signals')).passed, isFalse);
    });

    test(
      'web-backend-url: an undeclared build argument is dropped silently',
      () async {
        write('shop_flutter/Dockerfile', 'FROM nginx\nRUN flutter build web\n');
        expect((await evaluate('web-backend-url')).passed, isFalse);
        write('shop_flutter/Dockerfile', 'FROM nginx\nARG DW_BACKEND_URL\n');
        final verdict = await evaluate('web-backend-url');
        expect(verdict.passed, isTrue);
        expect(verdict.detail, contains('https://app.example.com'));
      },
    );

    test('locked-dependencies: a deploy builds what was committed', () async {
      write('shop_server/Dockerfile', 'FROM dart\nRUN dart pub get\n');
      write('shop_server/pubspec.lock', '# locked\n');
      final loose = await evaluate('locked-dependencies');
      expect(loose.passed, isFalse);
      expect(loose.detail, contains('RUN dart pub get'));
      expect(loose.fix, contains('--enforce-lockfile'));

      write(
        'shop_server/Dockerfile',
        'FROM dart\nRUN dart pub get --enforce-lockfile\n',
      );
      expect((await evaluate('locked-dependencies')).passed, isTrue);

      // The flag is worth nothing without the file it enforces.
      File(p.join(root.path, 'shop_server/pubspec.lock')).deleteSync();
      final unlocked = await evaluate('locked-dependencies');
      expect(unlocked.passed, isFalse);
      expect(unlocked.detail, contains('no pubspec.lock'));
    });

    test('dockerfiles-present names every missing image', () async {
      final verdict = await evaluate('dockerfiles-present');
      expect(verdict.detail, contains('shop_server/Dockerfile'));
      expect(verdict.detail, contains('shop_flutter/Dockerfile'));
    });

    test('docker-context-packages follows the pubspecs', () async {
      write('shop_server/pubspec.yaml', '''
name: shop_server
dependencies:
  shop_shared:
    path: ../shop_shared
''');
      write('shop_shared/pubspec.yaml', 'name: shop_shared\n');
      write(
        'shop_server/Dockerfile',
        'FROM dart\nCOPY shop_server/ shop_server/\n',
      );
      final verdict = await evaluate('docker-context-packages');
      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('does not copy shop_shared'));
    });

    test(
      'nginx-upstreams: the rendered stack alone agrees with itself',
      () async {
        for (final stack in stackVariants().values) {
          final verdict = await evaluate('nginx-upstreams', stack);
          expect(verdict.passed, isTrue, reason: verdict.detail);
        }
      },
    );

    test(
      'nginx-upstreams: a snippet naming an undeclared service fails',
      () async {
        write(
          'deploy/nginx.d/app/extra.conf',
          'location /x { proxy_pass http://redis:6379; }\n',
        );
        final verdict = await evaluate('nginx-upstreams');
        expect(verdict.passed, isFalse);
        expect(verdict.detail, contains('redis'));

        write(
          'deploy/compose.override.yml',
          'services:\n  redis:\n    image: redis\n',
        );
        expect((await evaluate('nginx-upstreams')).passed, isTrue);
      },
    );

    test(
      'override-web-build: a second statement of the app origin warns',
      () async {
        expect((await evaluate('override-web-build')).skipped, isTrue);
        write(
          'deploy/compose.override.yml',
          'services:\n  web:\n    build: .\n',
        );
        final verdict = await evaluate('override-web-build');
        expect(verdict.passed, isFalse);
        expect(_local('override-web-build').severity, DwCheckSeverity.warning);
        write(
          'deploy/compose.override.yml',
          'services:\n  web:\n    labels: [a]\n',
        );
        expect((await evaluate('override-web-build')).passed, isTrue);
      },
    );

    test('local-secrets-cover-environment names what is missing', () async {
      write('deploy/secrets.yaml', "staging:\n  DW_DATABASE_PASSWORD: 'x'\n");
      final stack = stackFrom(
        extra: '  requires:\n    secrets: [SMS_API_TOKEN]\n',
      );
      final verdict = await evaluate('local-secrets-cover-environment', stack);
      expect(verdict.passed, isFalse);
      expect(verdict.detail, 'missing or empty: SMS_API_TOKEN');
    });

    group('in a repository', () {
      setUp(() {
        Process.runSync('git', ['init', '-q'], workingDirectory: root.path);
      });

      test('site-source: a built site Git does not track never reaches the '
          'server', () async {
        final stack = stackFrom(
          extra:
              '  site:\n    domain: example.com\n    source: app_site/build\n',
        );
        expect(
          (await evaluate('site-source', stack)).detail,
          contains('no app_site/build/index.html'),
        );

        write('app_site/build/index.html', '<html></html>');
        final untracked = await evaluate('site-source', stack);
        expect(untracked.passed, isFalse);
        expect(untracked.detail, contains('not in Git'));

        Process.runSync('git', [
          'add',
          'app_site',
        ], workingDirectory: root.path);
        expect((await evaluate('site-source', stack)).passed, isTrue);
      });

      test(
        'local-secrets-untracked: a committed secrets file is an error',
        () async {
          write('deploy/secrets.yaml', 'staging: {}\n');
          expect((await evaluate('local-secrets-untracked')).passed, isTrue);
          Process.runSync('git', [
            'add',
            '-f',
            'deploy/secrets.yaml',
          ], workingDirectory: root.path);
          final verdict = await evaluate('local-secrets-untracked');
          expect(verdict.passed, isFalse);
          expect(verdict.fix, contains('rotated'));
        },
      );
    });
  });

  group('the projects this repository ships', () {
    final repository = () {
      var dir = Directory.current.absolute;
      while (!Directory(p.join(dir.path, 'template')).existsSync()) {
        if (dir.parent.path == dir.path) return null;
        dir = dir.parent;
      }
      return dir;
    }();

    // The example is the project the local stack proof deploys; its deploy
    // files have to pass everything a deployment checks before it builds.
    test(
      'the example passes every local check a deployment runs',
      () async {
        // On a vendored copy, as the local stack proof deploys it: in this
        // repository the example takes the framework by path from
        // `../../packages`, which no image can reach — exactly what
        // `dependencies-inside-context` refuses in a project.
        final sandbox = Directory.systemTemp.createTempSync('dw_example_');
        addTearDown(() => sandbox.deleteSync(recursive: true));
        final root = Directory(p.join(sandbox.path, 'example'));
        copyProject(Directory(p.join(repository!.path, 'example')), root);
        vendorFramework(project: root, monorepo: repository);
        final context = DwDeployContext(
          projectRoot: root,
          stack: DwStack(
            target: targetFrom(),
            serverPackage: 'dartway_example_server',
            flutterPackage: 'dartway_example_flutter',
          ),
        );
        for (final check in dwLocalDeployChecks.where((c) => c.partOfDeploy)) {
          final verdict = await check.evaluate(context);
          expect(
            verdict.passed || verdict.skipped,
            isTrue,
            reason: '${check.id}: ${verdict.detail}',
          );
        }
      },
      skip: repository == null ? 'not inside the monorepo' : null,
    );
  });
}
