import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/serverpod_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The compose file and the project's two Dockerfiles are one contract with no
/// schema to hold it: compose names the files by convention, hands the web
/// image a build argument and hands the server image its arguments as a
/// command. These tests pin the parts a silent change would break at deploy
/// time on someone else's machine.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_deploy_images_');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  DwDeployTarget targetIn(Directory root, {String? serverEntrypoint}) =>
      DwDeployTarget(
        environment: 'staging',
        host: '203.0.113.10',
        sshUser: 'root',
        deployUser: 'deployer',
        os: 'ubuntu',
        repo: 'git@github.com:acme/shop.git',
        branch: 'master',
        sslEmail: 'ops@example.com',
        webAppDomain: 'app.example.com',
        serverEntrypoint: serverEntrypoint,
      );

  DwServerpodConfig serverpodConfig() => DwServerpodConfig(
    environment: 'staging',
    relativePath: 'shop_server/config/staging.yaml',
    apiServer: DwServerEndpoint(
      name: 'apiServer',
      port: 8080,
      publicHost: 'api.example.com',
      publicPort: 443,
      publicScheme: 'https',
    ),
    insightsServer: null,
    webServer: null,
    databaseHost: 'postgres',
    databasePort: 5432,
    databaseName: 'shop',
    databaseUser: 'shop',
    redisEnabled: false,
    redisHost: null,
  );

  DwDeployContext contextIn(Directory root, {String? serverEntrypoint}) =>
      DwDeployContext(
        projectRoot: root,
        serverPackage: 'shop_server',
        flutterPackage: 'shop_flutter',
        target: targetIn(root, serverEntrypoint: serverEntrypoint),
        serverpod: serverpodConfig(),
      );

  void writeDockerfile(String package, String contents) {
    final file = File(p.join(root.path, package, 'Dockerfile'))
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  DwDeployCheck checkNamed(String id) =>
      dwLocalDeployChecks.firstWhere((check) => check.id == id);

  group('dockerfiles-present', () {
    test('names every image the compose file would fail to build', () async {
      final verdict = await checkNamed(
        'dockerfiles-present',
      ).evaluate(contextIn(root));

      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('shop_server/Dockerfile'));
      expect(verdict.detail, contains('shop_flutter/Dockerfile'));
    });

    test('passes once both exist', () async {
      writeDockerfile('shop_server', 'FROM alpine\n');
      writeDockerfile('shop_flutter', 'FROM nginx\n');

      final verdict = await checkNamed(
        'dockerfiles-present',
      ).evaluate(contextIn(root));

      expect(verdict.passed, isTrue);
    });
  });

  group('dockerfile-entrypoint-form', () {
    test(
      'rejects shell form, which swallows the migration arguments',
      () async {
        writeDockerfile(
          'shop_server',
          'FROM alpine\nENTRYPOINT ./server --mode=\$runmode\n',
        );

        final verdict = await checkNamed(
          'dockerfile-entrypoint-form',
        ).evaluate(contextIn(root));

        expect(verdict.passed, isFalse);
        expect(verdict.fix, contains('server_entrypoint'));
      },
    );

    test('accepts exec form', () async {
      writeDockerfile(
        'shop_server',
        'FROM alpine\nENTRYPOINT ["/app/server"]\nCMD ["--mode=production"]\n',
      );

      final verdict = await checkNamed(
        'dockerfile-entrypoint-form',
      ).evaluate(contextIn(root));

      expect(verdict.passed, isTrue);
    });

    test(
      'accepts shell form once server_entrypoint names the binary',
      () async {
        writeDockerfile(
          'shop_server',
          'FROM alpine\nENTRYPOINT ./server --mode=\$runmode\n',
        );

        final verdict = await checkNamed(
          'dockerfile-entrypoint-form',
        ).evaluate(contextIn(root, serverEntrypoint: '/app/server'));

        expect(verdict.passed, isTrue);
      },
    );
  });

  group('rendered compose file', () {
    String renderCompose() => DwInfraRenderer(
      projectRoot: root,
      target: targetIn(root),
      serverpod: serverpodConfig(),
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
    ).composeFile;

    test('gives the web image the API address from the Serverpod config', () {
      expect(
        renderCompose(),
        contains('DW_BACKEND_URL: https://api.example.com/'),
      );
    });

    test('states the run mode as a command an exec-form image receives', () {
      expect(renderCompose(), contains('"--mode=staging"'));
    });
  });
}
