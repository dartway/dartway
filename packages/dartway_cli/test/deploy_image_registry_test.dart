import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/image_registry.dart';
import 'package:test/test.dart';

/// A stand-in for a Docker Registry HTTP API v2 host and its token issuer,
/// behind one local server — the same pattern `DwOutsideProbe`'s tests use for
/// a deployed site: every connection is redirected here, and the fake
/// branches on the `Host` header rather than on the URL it was asked for.
class _Registry {
  late HttpServer server;
  final requests = <({String host, String path, String? authorization})>[];

  /// What to answer a manifest HEAD, keyed by whether a bearer token was
  /// presented.
  int Function({required bool authenticated}) manifestStatus =
      ({required authenticated}) => 200;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final host = request.headers.value('host') ?? '';
      final path = request.uri.path;
      final authorization = request.headers.value('authorization');
      requests.add((host: host, path: path, authorization: authorization));

      if (path == '/token') {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'token': 'a-fake-token'}));
        await request.response.close();
        return;
      }

      final status = manifestStatus(authenticated: authorization != null);
      if (status == 401) {
        request.response.statusCode = 401;
        request.response.headers.set(
          'www-authenticate',
          'Bearer realm="http://$host/token",service="registry",'
              'scope="repository:library/postgres:pull"',
        );
        await request.response.close();
        return;
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
  group('DwImageRef.parse', () {
    test('a bare name is a Docker Hub library image', () {
      final ref = DwImageRef.parse('postgres:17-alpine');
      expect(ref.registryHost, 'registry-1.docker.io');
      expect(ref.repository, 'library/postgres');
      expect(ref.tag, '17-alpine');
    });

    test('an org/name is a Docker Hub repository, not library/', () {
      final ref = DwImageRef.parse('rustfs/rustfs:1.0.0');
      expect(ref.registryHost, 'registry-1.docker.io');
      expect(ref.repository, 'rustfs/rustfs');
      expect(ref.tag, '1.0.0');
    });

    test('a host segment is read as the registry', () {
      final ref = DwImageRef.parse('quay.io/minio/minio:RELEASE.2025-09-07');
      expect(ref.registryHost, 'quay.io');
      expect(ref.repository, 'minio/minio');
      expect(ref.tag, 'RELEASE.2025-09-07');
    });

    test('no tag defaults to latest', () {
      expect(DwImageRef.parse('nginx').tag, 'latest');
    });

    // The bug this guards: `library/` is Docker Hub's own rule for a bare
    // name with no registry stated at all — not something any other registry
    // recognises, and not something Docker's own reference parser adds once
    // a host is explicit. `mirror.gcr.io/postgres:17-alpine` is exactly what
    // the renderer puts in the compose file for `registry_mirror:
    // mirror.gcr.io` (DwStack.pinnedImages) — checking `library/postgres`
    // there would ask the mirror about a repository the deploy never pulls.
    test(
      'a bare name behind an explicit host is that host\'s own repository, '
      'not library/ — an explicit host is never Docker Hub\'s default',
      () {
        final ref = DwImageRef.parse('mirror.gcr.io/postgres:17-alpine');
        expect(ref.registryHost, 'mirror.gcr.io');
        expect(ref.repository, 'postgres');
        expect(ref.tag, '17-alpine');
      },
    );
  });

  group('DwImageRegistry.resolve', () {
    late _Registry fake;

    setUp(() async {
      fake = _Registry();
      await fake.start();
    });
    tearDown(() => fake.stop());

    test('a manifest reachable anonymously resolves', () async {
      fake.manifestStatus = ({required authenticated}) => 200;
      final result = await fake.registry.resolve('postgres:17-alpine');
      expect(result.ok, isTrue, reason: result.detail);
    });

    test(
      'a 401 challenge is answered with the anonymous token the registry asks for',
      () async {
        fake.manifestStatus = ({required authenticated}) =>
            authenticated ? 200 : 401;
        final result = await fake.registry.resolve('postgres:17-alpine');
        expect(result.ok, isTrue, reason: result.detail);
        // The manifest HEAD, unauthenticated then with the fetched token.
        final manifestCalls = fake.requests
            .where((r) => r.path.contains('/manifests/'))
            .toList();
        expect(manifestCalls, hasLength(2));
        expect(manifestCalls.first.authorization, isNull);
        expect(manifestCalls.last.authorization, 'Bearer a-fake-token');
      },
    );

    test('a 404 is a clear failure naming the tag', () async {
      fake.manifestStatus = ({required authenticated}) => 404;
      final result = await fake.registry.resolve(
        'rustfs/rustfs:this-tag-does-not-exist',
      );
      expect(result.ok, isFalse);
      expect(result.detail, contains('rustfs/rustfs:this-tag-does-not-exist'));
      expect(result.detail, contains('404'));
    });

    test(
      'a 401 the registry never actually lifts (no token satisfies it) fails '
      'definitely, not loops, and is never treated as transient',
      () async {
        fake.manifestStatus = ({required authenticated}) => 401;
        final result = await fake.registry.resolve('postgres:17-alpine');
        expect(result.ok, isFalse);
        expect(result.transient, isFalse);
        expect(result.detail, contains('401'));
      },
    );

    test('a 404 is definite, not transient', () async {
      fake.manifestStatus = ({required authenticated}) => 404;
      final result = await fake.registry.resolve('postgres:17-alpine');
      expect(result.ok, isFalse);
      expect(result.transient, isFalse);
    });

    test(
      'a 429 (rate-limited) is transient — this machine\'s trouble, not a '
      'fact about the image',
      () async {
        fake.manifestStatus = ({required authenticated}) => 429;
        final result = await fake.registry.resolve('postgres:17-alpine');
        expect(result.ok, isFalse);
        expect(result.transient, isTrue);
        expect(result.detail, contains('429'));
      },
    );

    test('a 5xx from the registry itself is transient', () async {
      fake.manifestStatus = ({required authenticated}) => 503;
      final result = await fake.registry.resolve('postgres:17-alpine');
      expect(result.ok, isFalse);
      expect(result.transient, isTrue);
      expect(result.detail, contains('503'));
    });

    test(
      'an unreachable host fails as transient, with a clear reason, not an '
      'exception',
      () async {
        final registry = DwImageRegistry(
          connectTo: (host: '127.0.0.1', port: 1), // nothing listens here
          scheme: 'http',
          timeout: const Duration(milliseconds: 300),
        );
        final result = await registry.resolve('postgres:17-alpine');
        expect(result.ok, isFalse);
        expect(result.transient, isTrue);
      },
    );
  });
}
