import 'dart:io';

import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:test/test.dart';

/// A stand-in for a deployed host: answers by path, as configured per test,
/// and records the Host header each request arrived with.
class _Site {
  late HttpServer server;
  final hosts = <String>[];
  Future<void> Function(HttpRequest request)? handler;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hosts.add(request.headers.value('host') ?? '');
      await handler!(request);
    });
  }

  DwOutsideProbe get probe => DwOutsideProbe(
    connectTo: (host: InternetAddress.loopbackIPv4.address, port: server.port),
    timeout: const Duration(seconds: 3),
  );
}

void main() {
  late _Site site;

  setUp(() async {
    site = _Site();
    await site.start();
  });
  tearDown(() => site.server.close(force: true));

  Future<void> text(
    HttpRequest request,
    int status,
    String body, {
    Map<String, String> headers = const {},
  }) async {
    request.response.statusCode = status;
    headers.forEach(request.response.headers.set);
    request.response.write(body);
    await request.response.close();
  }

  group('health', () {
    test('passes on 200 ok, reached under the public host name', () async {
      site.handler = (r) => text(r, 200, 'ok');
      final result = await site.probe.health('http://api.example.com');
      expect(result.passed, isTrue, reason: result.detail);
      expect(site.hosts.single, 'api.example.com');
    });

    test(
      'a proxy answering for a server it cannot reach is a failure',
      () async {
        site.handler = (r) => text(r, 502, '<html>Bad Gateway</html>');
        final result = await site.probe.health('http://api.example.com');
        expect(result.passed, isFalse);
        expect(result.detail, contains('502'));
      },
    );
  });

  group('app index', () {
    const index =
        '<!DOCTYPE html><html><head></head><body>'
        '<script src="flutter_bootstrap.js" async></script></body></html>';

    Future<void> page(HttpRequest r, {String? cacheControl}) => text(
      r,
      200,
      index,
      headers: {'content-type': 'text/html', 'cache-control': ?cacheControl},
    );

    test('passes on the Flutter page served for revalidation', () async {
      site.handler = (r) => page(r, cacheControl: 'no-cache');
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('fails on a page a browser may keep across a deploy', () async {
      site.handler = (r) => page(r, cacheControl: 'max-age=2592000');
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('max-age=2592000'));
    });

    test('fails on a default page that is not the app', () async {
      site.handler = (r) => text(
        r,
        200,
        '<html><body>Welcome to nginx!</body></html>',
        headers: {'content-type': 'text/html', 'cache-control': 'no-cache'},
      );
      final result = await site.probe.appIndex('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('does not load Flutter'));
    });
  });

  group('web compression', () {
    test('passes when the JavaScript bundle is gzip encoded', () async {
      site.handler = (request) async {
        if (request.uri.path != '/main.dart.js') {
          return text(request, 404, '');
        }
        expect(request.headers.value('accept-encoding'), contains('gzip'));
        final bytes = gzip.encode(List<int>.filled(2048, 65));
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType(
            'application',
            'javascript',
          )
          ..headers.set('content-encoding', 'gzip')
          ..add(bytes);
        await request.response.close();
      };
      final result = await site.probe.webCompression(
        'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
      expect(result.detail, contains('main.dart.js'));
    });

    test(
      'fails with the file and size when the bundle is uncompressed',
      () async {
        site.handler = (request) => request.uri.path == '/main.dart.js'
            ? text(request, 200, 'x' * 4096)
            : text(request, 404, '');
        final result = await site.probe.webCompression(
          'http://app.example.com',
        );
        expect(result.passed, isFalse);
        expect(result.detail, contains('/main.dart.js (4096 bytes)'));
        expect(result.detail, contains('expected gzip'));
      },
    );
  });

  group('CanvasKit origin', () {
    test('warns when a startup file names the Flutter CDN', () async {
      site.handler = (request) => text(
        request,
        200,
        request.uri.path == '/flutter_bootstrap.js'
            ? 'https://www.gstatic.com/flutter-canvaskit/v1/canvaskit.js'
            : '<html>local bootstrap</html>',
      );
      final result = await site.probe.canvasKitOrigin(
        'http://app.example.com',
      );
      expect(result.warning, isTrue);
      expect(result.detail, contains('--no-web-resources-cdn'));
      expect(result.detail, contains('2026-10-08-local-canvaskit.md'));
    });

    test('passes when startup files use local resources', () async {
      site.handler = (request) => text(request, 200, 'canvaskit/canvaskit.js');
      final result = await site.probe.canvasKitOrigin(
        'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
      expect(result.warning, isFalse);
    });
  });

  group('live upgrade', () {
    test('passes on 101 followed by the documented dw. close', () async {
      String? origin;
      site.handler = (request) async {
        origin = request.headers.value('origin');
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close(4026, 'dw.protocolUnsupported');
      };
      final result = await site.probe.liveUpgrade(
        'http://app.example.com',
        browserOrigin: 'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
      expect(result.detail, contains('4026'));
      expect(origin, 'http://app.example.com');
      expect(site.hosts.single, 'app.example.com');
    });

    test('a 101 from something that is not the server is a failure', () async {
      site.handler = (request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close(1000, 'bye');
      };
      final result = await site.probe.liveUpgrade('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('nothing from a DartWay server'));
    });

    test('a proxy that dropped the Upgrade headers is a failure', () async {
      site.handler = (r) => text(r, 400, 'a WebSocket upgrade is expected');
      final result = await site.probe.liveUpgrade('http://app.example.com');
      expect(result.passed, isFalse);
      expect(result.detail, contains('refused'));
    });
  });

  group('storage CORS', () {
    Future<void> preflight(HttpRequest r, {required String allowOrigin}) =>
        text(
          r,
          204,
          '',
          headers: {
            'access-control-allow-origin': allowOrigin,
            'access-control-allow-methods': 'PUT',
            'access-control-allow-headers':
                r.headers.value('access-control-request-headers') ?? '',
          },
        );

    test('passes when the app origin may PUT with the bound headers', () async {
      site.handler = (r) => preflight(r, allowOrigin: 'http://app.example.com');
      final result = await site.probe.storageCors(
        storageOrigin: 'http://files.example.com',
        bucket: 'shop',
        appOrigin: 'http://app.example.com',
      );
      expect(result.passed, isTrue, reason: result.detail);
    });

    test('fails when the rule admits some other origin', () async {
      site.handler = (r) => preflight(r, allowOrigin: 'https://other.example');
      final result = await site.probe.storageCors(
        storageOrigin: 'http://files.example.com',
        bucket: 'shop',
        appOrigin: 'http://app.example.com',
      );
      expect(result.passed, isFalse);
      expect(result.detail, contains('refuse every upload'));
    });
  });

  group('storage visibility', () {
    const probeText = DwStack.visibilityProbeText;

    Future<void> storage(
      HttpRequest r, {
      int public = 200,
      int private = 403,
      int listing = 403,
    }) {
      final path = r.uri.path;
      if (r.uri.queryParameters.containsKey('list-type')) {
        return text(r, listing, listing < 300 ? '<ListBucketResult/>' : '');
      }
      if (path == '/shop-public/${DwStack.visibilityProbeKey}') {
        return text(r, public, public == 200 ? '$probeText\n' : '');
      }
      if (path == '/shop-private/${DwStack.visibilityProbeKey}') {
        return text(r, private, private == 200 ? '$probeText\n' : '');
      }
      return text(r, 404, '');
    }

    Future<DwProbeResult> run() => site.probe.storageVisibility(
      storageOrigin: 'http://files.example.com',
      publicBucket: 'shop-public',
      privateBucket: 'shop-private',
    );

    test(
      'passes when only the public probe reads, and nothing lists',
      () async {
        site.handler = storage;
        final result = await run();
        expect(result.passed, isTrue, reason: result.detail);
        expect(site.hosts, everyElement('files.example.com'));
      },
    );

    test('fails when the private bucket reads without a signature', () async {
      site.handler = (r) => storage(r, private: 200);
      final result = await run();
      expect(result.passed, isFalse);
      expect(result.detail, contains('every private file is public'));
    });

    test('fails when the public bucket does not read', () async {
      site.handler = (r) => storage(r, public: 403);
      final result = await run();
      expect(result.passed, isFalse);
      expect(result.detail, contains('public files will not open'));
    });

    test('fails when a bucket lists its keys', () async {
      site.handler = (r) => storage(r, listing: 200);
      final result = await run();
      expect(result.passed, isFalse);
      expect(result.detail, contains('shop-public lists its keys to anyone'));
      expect(result.detail, contains('shop-private lists its keys to anyone'));
    });
  });
}
