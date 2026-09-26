import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/image_registry.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:test/test.dart';

/// A registry that answers a manifest HEAD by which repository was asked
/// about — enough to prove `evaluateImagesResolve` actually reads what
/// [DwImageRegistry.resolve] says for *each* image, rather than always
/// passing or judging only the first.
class _PerRepoRegistry {
  late HttpServer server;

  /// Status by repository (`library/postgres`, `library/nginx`, …); a
  /// repository not listed answers 200.
  Map<String, int> statusByRepository = const {};

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      // /v2/<repository>/manifests/<tag>
      final segments = request.uri.pathSegments;
      final repository = segments
          .sublist(1, segments.length - 2)
          .join('/');
      final status = statusByRepository[repository] ?? 200;
      if (status == 200) {
        // A real registry names its own digest; resolve() requires it.
        request.response.headers.set(
          'docker-content-digest',
          'sha256:${'0' * 64}',
        );
      }
      request.response.statusCode = status;
      await request.response.close();
    });
  }

  Future<void> stop() => server.close(force: true);

  DwImageRegistry get registry => DwImageRegistry(
    connectTo: (host: InternetAddress.loopbackIPv4.address, port: server.port),
    scheme: 'http',
    timeout: const Duration(seconds: 3),
  );
}

void main() {
  group('evaluateImagesResolve', () {
    late _PerRepoRegistry fake;

    setUp(() async {
      fake = _PerRepoRegistry();
      await fake.start();
    });
    tearDown(() => fake.stop());

    const images = [
      ('Postgres', 'postgres:17-alpine'),
      ('nginx', 'nginx:1.30.5-alpine'),
    ];

    test('every image resolving is a pass naming all of them', () async {
      final verdict = await evaluateImagesResolve(images, fake.registry);
      expect(verdict.passed, isTrue);
      expect(verdict.detail, contains('postgres:17-alpine'));
      expect(verdict.detail, contains('nginx:1.30.5-alpine'));
    });

    // The regression this exists for: a check whose logic silently ignores
    // what the registry answered would still show green here.
    test('one image gone (404) fails, naming which one and why', () async {
      fake.statusByRepository = {'library/postgres': 404};
      final verdict = await evaluateImagesResolve(images, fake.registry);
      expect(verdict.passed, isFalse);
      expect(verdict.skipped, isFalse);
      expect(verdict.detail, contains('Postgres'));
      expect(verdict.detail, contains('404'));
    });

    test(
      'every image unreachable (transient) is a skip, not a pass and not a '
      'fail — the deploy is not refused over this machine\'s own network',
      () async {
        fake.statusByRepository = {
          'library/postgres': 503,
          'library/nginx': 503,
        };
        final verdict = await evaluateImagesResolve(images, fake.registry);
        expect(verdict.passed, isFalse);
        expect(verdict.skipped, isTrue);
        expect(verdict.detail, contains('could not ask'));
      },
    );

    test(
      'a real failure on one image outweighs a transient one on another — '
      'the deploy is refused, not merely skipped, when anything is '
      'definitely wrong, and both are named (L1: a transient result beside '
      'a definite one must not go unmentioned)',
      () async {
        fake.statusByRepository = {
          'library/postgres': 404,
          'library/nginx': 503,
        };
        final verdict = await evaluateImagesResolve(images, fake.registry);
        expect(verdict.passed, isFalse);
        expect(verdict.skipped, isFalse);
        expect(verdict.detail, contains('404'));
        expect(verdict.detail, contains('Postgres'));
        expect(
          verdict.detail,
          contains('nginx'),
          reason: 'the transient nginx result must still be visible, not '
              'silently dropped because a definite failure took priority',
        );
        expect(verdict.detail, contains('503'));
      },
    );
  });

  group('the images-resolve check declaration', () {
    test('is a remote check with no SSH', () {
      final check = dwRemoteDeployChecks.firstWhere(
        (c) => c.id == 'images-resolve',
      );
      expect(check.stage, DwDeployCheckStage.remote);
      expect(check.requiresSsh, isFalse);
      expect(check.severity, DwCheckSeverity.error);
    });
  });
}
