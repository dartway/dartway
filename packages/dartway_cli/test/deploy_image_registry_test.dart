import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/image_registry.dart';
import 'package:path/path.dart' as p;
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

  /// Whether a 200 carries `Docker-Content-Digest` — off to prove
  /// [DwImageRegistry.resolve] refuses to call a 200 without one a manifest.
  bool includeDigest = true;

  /// Where a 3xx sends the client — resolve() must never follow it.
  String? redirectTo;

  /// What `/token` answers on its body — a non-JSON string proves a garbled
  /// token response is transient, not a crash.
  String tokenBody = jsonEncode({'token': 'a-fake-token'});

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final host = request.headers.value('host') ?? '';
      final path = request.uri.path;
      final authorization = request.headers.value('authorization');
      requests.add((host: host, path: path, authorization: authorization));

      if (path == '/token') {
        request.response.statusCode = 200;
        request.response.write(tokenBody);
        await request.response.close();
        return;
      }

      if (redirectTo != null) {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set('location', redirectTo!);
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
      if (status == 200 && includeDigest) {
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

    // docker.io and index.docker.io spell out the default registry rather
    // than leaving it implicit — `docker pull docker.io/postgres` and
    // `docker pull postgres` name the same image, so both take the
    // library/ rule and both resolve against the same API host.
    for (final host in ['docker.io', 'index.docker.io']) {
      test('$host is Docker Hub spelled out, not a foreign registry', () {
        final ref = DwImageRef.parse('$host/postgres:17-alpine');
        expect(ref.registryHost, 'registry-1.docker.io');
        expect(ref.repository, 'library/postgres');
        expect(ref.tag, '17-alpine');
      });

      test('$host with an organisation keeps the organisation as-is', () {
        final ref = DwImageRef.parse('$host/rustfs/rustfs:1.0.0');
        expect(ref.registryHost, 'registry-1.docker.io');
        expect(ref.repository, 'rustfs/rustfs');
      });
    }
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

    // N1: a 200 that carries no Docker-Content-Digest is not a manifest — it
    // could be a mirror's or a captive portal's fallback page, and this is
    // the second half of the guard the disabled-redirects change below is
    // the first half of.
    test('a 200 with no Docker-Content-Digest is not treated as resolved', () async {
      fake.manifestStatus = ({required authenticated}) => 200;
      fake.includeDigest = false;
      final result = await fake.registry.resolve('postgres:17-alpine');
      expect(result.ok, isFalse);
      expect(result.detail, contains('Docker-Content-Digest'));
    });

    // N1: without this, an `HttpClient` follows the redirect on its own and
    // resolve() would only ever see whatever the far end answers — which
    // could be an unrelated 200 page, read indistinguishably from a real
    // manifest. Disabling redirects turns that into a plain, visible 3xx.
    test('a redirect is never followed, and never reads as resolved', () async {
      fake.redirectTo = 'http://example.invalid/elsewhere';
      final result = await fake.registry.resolve('postgres:17-alpine');
      expect(result.ok, isFalse);
      expect(result.detail, contains('302'));
    });

    test(
      'a token endpoint answering something that is not JSON is transient, '
      'not a crash',
      () async {
        fake.manifestStatus = ({required authenticated}) =>
            authenticated ? 200 : 401;
        fake.tokenBody = 'this is not json';
        final result = await fake.registry.resolve('postgres:17-alpine');
        expect(result.ok, isFalse);
        expect(result.transient, isTrue);
      },
    );
  });

  group('DwImageRegistry.resolve against a real, untrusted TLS server', () {
    // A self-signed certificate `resolve()` never asks to trust — no
    // `badCertificateCallback` is set — is a real handshake failure, unlike
    // the plain-HTTP fakes above, which a custom `connectionFactory` reaches
    // without TLS at all regardless of `scheme`.
    late Directory certDir;
    late HttpServer tlsServer;

    setUpAll(() async {
      certDir = Directory.systemTemp.createTempSync('dw_image_registry_tls_');
      final keyFile = p.join(certDir.path, 'key.pem');
      final certFile = p.join(certDir.path, 'cert.pem');
      final generated = Process.runSync('openssl', [
        'req', '-x509', '-nodes', '-newkey', 'rsa:2048', '-days', '1',
        '-keyout', keyFile,
        '-out', certFile,
        '-subj', '/CN=untrusted.invalid',
      ]);
      if (generated.exitCode != 0) {
        fail('could not generate a throwaway certificate: ${generated.stderr}');
      }
      final context = SecurityContext()
        ..useCertificateChain(certFile)
        ..usePrivateKey(keyFile);
      tlsServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      tlsServer.listen((request) async {
        request.response.statusCode = 200;
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await tlsServer.close(force: true);
      certDir.deleteSync(recursive: true);
    });

    test('is transient, not a crash', () async {
      final registry = DwImageRegistry(
        connectTo: (
          host: InternetAddress.loopbackIPv4.address,
          port: tlsServer.port,
        ),
        timeout: const Duration(seconds: 3),
      );
      final result = await registry.resolve('postgres:17-alpine');
      expect(result.ok, isFalse);
      expect(result.transient, isTrue, reason: result.detail);
    });
  });
}
