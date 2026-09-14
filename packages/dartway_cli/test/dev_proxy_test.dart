import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/commands/dev_command.dart';
import 'package:dartway_cli/src/dev/dev_proxy.dart';
import 'package:test/test.dart';

/// `dartway dev proxy` against fake upstreams: an API that echoes what reached
/// it (HTTP and a WebSocket), and a web dev server that streams and has a
/// socket of its own.
void main() {
  late _FakeApi api;
  late _FakeWeb web;
  late DwDevProxy proxy;
  late List<String> logged;
  late HttpClient client;

  setUp(() async {
    api = await _FakeApi.start();
    web = await _FakeWeb.start();
    logged = [];
    proxy = DwDevProxy(api: api.base, webServer: web.base, log: logged.add);
    await proxy.start(port: 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await proxy.stop();
    await api.close();
    await web.close();
  });

  Uri at(String pathAndQuery) =>
      Uri.parse('http://127.0.0.1:${proxy.port}$pathAndQuery');

  group('routing', () {
    test('the framework paths go to the API, everything else to the web', () {
      for (final path in ['/dw', '/dw/', '/dw/live', '/dw/SignIn', '/health']) {
        expect(DwDevProxy.isApiPath(path), isTrue, reason: path);
      }
      for (final path in [
        '/',
        '/dwarf',
        '/health/x',
        '/healthz',
        '/main.dart.js',
        '/app/dw/live',
      ]) {
        expect(DwDevProxy.isApiPath(path), isFalse, reason: path);
      }
    });

    test('project doors named by apiPaths go to the API too', () {
      final withDoors = DwDevProxy(
        api: Uri.parse('http://localhost:8080'),
        webServer: Uri.parse('http://localhost:5000'),
        apiPaths: ['/mcp', '/github/'],
      );
      for (final path in [
        '/mcp',
        '/mcp/tools',
        '/github',
        '/github/push',
        '/dw/x',
      ]) {
        expect(withDoors.routesToApi(path), isTrue, reason: path);
      }
      for (final path in ['/mcpx', '/githubber', '/', '/app/mcp']) {
        expect(withDoors.routesToApi(path), isFalse, reason: path);
      }
      expect(
        () => DwDevProxy(
          api: Uri.parse('http://localhost:8080'),
          webServer: Uri.parse('http://localhost:5000'),
          apiPaths: ['mcp'],
        ),
        throwsArgumentError,
      );
    });

    test('a connection closed by the client before a request does not end the '
        'proxy', () async {
      for (var i = 0; i < 20; i++) {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          proxy.port,
        );
        if (i.isEven) socket.add('POST /mcp HTTP/1.1\r\nhost: x\r\n'.codeUnits);
        socket.destroy();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final health = await _get(client, at('/health'));
      expect(health.status, 200);
    });

    test('a call reaches the API and a page reaches the web server', () async {
      final health = await _get(client, at('/health'));
      expect((health.status, health.body), (200, 'api ok'));

      final page = await _get(client, at('/some/route?tab=2&q=a%20b'));
      expect(page.status, 200);
      expect(page.body, 'web /some/route?tab=2&q=a%20b');
    });
  });

  group('HTTP to the API', () {
    test('keeps the browser\'s Host, and adds the forwarding headers the '
        'deployed Nginx adds', () async {
      final request = await client.postUrl(at('/dw/Echo?x=1'));
      request.headers
        ..set('x-custom', 'kept')
        ..set('authorization', 'Bearer t')
        ..contentType = ContentType.json;
      request.write('{"hello":"world"}');
      final response = await request.close();
      final seen =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, Object?>;

      expect(response.statusCode, 201);
      expect(seen['method'], 'POST');
      expect(seen['uri'], '/dw/Echo?x=1');
      expect(seen['body'], '{"hello":"world"}');
      expect(seen['host'], '127.0.0.1:${proxy.port}');
      expect(seen['x-custom'], 'kept');
      expect(seen['authorization'], 'Bearer t');
      expect(seen['content-type'], 'application/json; charset=utf-8');
      expect(seen['x-forwarded-for'], '127.0.0.1');
      expect(seen['x-real-ip'], '127.0.0.1');
      expect(seen['x-forwarded-proto'], 'http');
      expect(seen['user-agent'], isNot(contains('proxy')));
    });

    test('passes the answer back as it was: status, reason, repeated and '
        'custom headers', () async {
      final response = await (await client.postUrl(at('/dw/Echo'))).close();
      await response.drain<void>();

      expect(response.statusCode, 201);
      expect(response.reasonPhrase, 'Made');
      expect(response.headers['x-api'], ['yes']);
      expect(response.headers['set-cookie'], hasLength(2));
      expect(response.headers.value('x-frame-options'), isNull);
    });

    test('a redirect is the browser\'s to follow, not the proxy\'s', () async {
      final request = await client.getUrl(at('/dw/redirect'));
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, 302);
      expect(response.headers.value('location'), '/elsewhere');
    });

    test('a compressed body passes compressed', () async {
      client.autoUncompress = false;
      final response = await (await client.getUrl(at('/dw/gzip'))).close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      expect(response.headers.value('content-encoding'), 'gzip');
      expect(response.contentLength, bytes.length);
      expect(utf8.decode(gzip.decode(bytes)), 'squeezed');
    });

    test('a request body sent in chunks arrives whole', () async {
      final request = await client.postUrl(at('/dw/Echo'));
      request.headers.chunkedTransferEncoding = true;
      request.write('part one, ');
      await request.flush();
      request.write('part two');
      final seen =
          jsonDecode(await utf8.decodeStream(await request.close()))
              as Map<String, Object?>;

      expect(seen['body'], 'part one, part two');
    });

    test('HEAD answers the headers of GET without a body', () async {
      final response = await (await client.openUrl(
        'HEAD',
        at('/health'),
      )).close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      expect(response.statusCode, 200);
      expect(response.contentLength, 'api ok'.length);
      expect(bytes, isEmpty);
    });
  });

  group('the live socket', () {
    Future<WebSocket> connect([String path = '/dw/live?v=1']) =>
        WebSocket.connect(
          'ws://localhost:${proxy.port}$path',
          headers: {'origin': 'http://localhost:${proxy.port}'},
        );

    test('carries text and binary frames both ways', () async {
      final socket = await connect();
      final frames = StreamIterator(socket);

      socket.add('ping');
      expect(await frames.moveNext(), isTrue);
      expect(frames.current, 'echo ping');

      socket.add([1, 2, 3, 255]);
      expect(await frames.moveNext(), isTrue);
      expect(frames.current, [1, 2, 3, 255]);

      await socket.close();
    });

    test(
      'the upgrade reaches the API with the browser\'s Host and Origin',
      () async {
        final socket = await connect('/dw/live?v=1&app=1.0.0%2B1');
        final frames = StreamIterator(socket);
        socket.add('headers');
        expect(await frames.moveNext(), isTrue);
        final seen =
            jsonDecode(frames.current as String) as Map<String, Object?>;

        expect(seen['host'], 'localhost:${proxy.port}');
        expect(seen['origin'], 'http://localhost:${proxy.port}');
        expect(seen['uri'], '/dw/live?v=1&app=1.0.0%2B1');
        expect(seen['x-forwarded-proto'], 'http');
        await socket.close();
      },
    );

    test('a close code and reason from the server reach the browser', () async {
      final socket = await connect();
      socket.add('close 4003 dw.updateRequired');
      await socket.drain<void>();

      expect(socket.closeCode, 4003);
      expect(socket.closeReason, 'dw.updateRequired');
    });

    test('a close code from the browser reaches the server', () async {
      final socket = await connect();
      final frames = StreamIterator(socket);
      socket.add('ping');
      await frames.moveNext();
      await socket.close(4100, 'leaving');

      final (code, reason) = await api.lastClose.future.timeout(
        const Duration(seconds: 5),
      );
      expect((code, reason), (4100, 'leaving'));
    });

    test(
      'a refused upgrade reaches the browser as the server answered it',
      () async {
        final request = await client.getUrl(at('/dw/live?refuse=1'));
        request.headers
          ..set('connection', 'Upgrade')
          ..set('upgrade', 'websocket')
          ..set('sec-websocket-version', '13')
          ..set('sec-websocket-key', base64.encode(List.filled(16, 7)));
        final response = await request.close();

        expect(response.statusCode, 403);
        expect(await utf8.decodeStream(response), 'origin not allowed');
      },
    );

    test('stopping the proxy ends open sockets', () async {
      final socket = await connect();
      await proxy.stop();
      await socket.drain<void>().timeout(const Duration(seconds: 5));
      expect(socket.readyState, WebSocket.closed);
    });
  });

  group('the web dev server', () {
    test(
      'a streamed response arrives as it is sent, not when it ends',
      () async {
        final response = await (await client.getUrl(at('/stream'))).close();
        final chunks = StreamIterator(response.transform(utf8.decoder));

        expect(await chunks.moveNext(), isTrue);
        expect(chunks.current, 'data: first\n\n');
        // The second event is only written once the first has been read here.
        web.release.complete();
        final rest = StringBuffer();
        while (await chunks.moveNext()) {
          rest.write(chunks.current);
        }
        expect(rest.toString(), 'data: second\n\n');
      },
    );

    test('its own socket (hot reload) is tunnelled too', () async {
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${proxy.port}/\$dwdsws',
      );
      final frames = StreamIterator(socket);
      socket.add('reload');
      expect(await frames.moveNext(), isTrue);
      expect(frames.current, 'web echo reload');
      await socket.close();
    });
  });

  group('an upstream that is not there', () {
    test(
      'is answered 502 naming it, and logged once until it answers again',
      () async {
        final port = api.port;
        final base = api.base;
        await api.close();

        final first = await _get(client, at('/health'));
        final second = await _get(client, at('/dw/Echo'));
        expect(first.status, 502);
        expect(first.body, contains('nothing answers at $base'));
        expect(second.status, 502);
        expect(
          logged.where((line) => line.contains('nothing answers')),
          hasLength(1),
        );

        api = await _FakeApi.start(port: port);
        final back = await _get(client, at('/health'));
        expect(back.status, 200);
        expect(logged.last, contains('answers again'));
      },
    );

    test('a socket to it is refused with 502 before the upgrade', () async {
      await web.close();
      final request = await client.getUrl(at('/\$dwdsws'));
      request.headers
        ..set('connection', 'Upgrade')
        ..set('upgrade', 'websocket')
        ..set('sec-websocket-version', '13')
        ..set('sec-websocket-key', base64.encode(List.filled(16, 7)));
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, 502);
    });
  });

  group('dartway dev web', () {
    test('runs Flutter\'s web server compiled against the proxy origin', () {
      expect(
        dwFlutterRunArguments(
          webPort: 51234,
          backendUrl: Uri.parse('http://localhost:8000'),
          extra: ['--profile'],
        ),
        [
          'run',
          '-d',
          'web-server',
          '--web-port',
          '51234',
          '--web-hostname',
          'localhost',
          '--dart-define=DW_BACKEND_URL=http://localhost:8000',
          '--profile',
        ],
      );
    });

    test('picks the project\'s Flutter: an FVM link, an FVM pin, the PATH', () {
      final root = Directory.systemTemp.createTempSync('dw_dev_flutter');
      addTearDown(() => root.deleteSync(recursive: true));

      List<String> resolved({String? override}) {
        final (executable, prefix) = flutterCommand(
          override: override,
          searched: [root],
        );
        return [executable, ...prefix];
      }

      expect(resolved(), ['flutter']);
      expect(resolved(override: 'fvm flutter'), ['fvm', 'flutter']);

      File('${root.path}/.fvmrc').writeAsStringSync('{"flutter":"3.44.0"}');
      expect(resolved(), ['fvm', 'flutter']);

      final linked = File(
        '${root.path}/.fvm/flutter_sdk/bin/'
        '${Platform.isWindows ? 'flutter.bat' : 'flutter'}',
      )..createSync(recursive: true);
      expect(resolved(), [linked.path]);
    });
  });
}

Future<({int status, String body})> _get(HttpClient client, Uri uri) async {
  final response = await (await client.getUrl(uri)).close();
  return (status: response.statusCode, body: await utf8.decodeStream(response));
}

Map<String, String> _headersOf(HttpRequest request) {
  final seen = <String, String>{};
  request.headers.forEach((name, values) => seen[name] = values.join(', '));
  return seen;
}

final class _FakeApi {
  _FakeApi._(this._server) {
    // What the proxy adds or keeps is asserted; dart:io's own defaults would
    // blur that.
    _server.defaultResponseHeaders.clear();
    _server.listen(_handle);
  }

  static Future<_FakeApi> start({int port = 0}) async =>
      _FakeApi._(await HttpServer.bind(InternetAddress.loopbackIPv4, port));

  final HttpServer _server;
  final Completer<(int?, String?)> lastClose = Completer();

  int get port => _server.port;
  Uri get base => Uri.parse('http://localhost:$port');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    switch (request.uri.path) {
      case '/health':
        response.headers
          ..contentType = ContentType.text
          ..contentLength = 'api ok'.length;
        response.write('api ok');
      case '/dw/live':
        if (request.uri.queryParameters['refuse'] != null) {
          response.statusCode = 403;
          response.write('origin not allowed');
          break;
        }
        final headers = _headersOf(request);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (Object? frame) {
            if (frame is List<int>) {
              socket.add(frame);
            } else if (frame == 'headers') {
              socket.add(jsonEncode({...headers, 'uri': '${request.uri}'}));
            } else if (frame is String && frame.startsWith('close ')) {
              final [_, code, reason] = frame.split(' ');
              socket.close(int.parse(code), reason);
            } else {
              socket.add('echo $frame');
            }
          },
          onDone: () {
            if (!lastClose.isCompleted) {
              lastClose.complete((socket.closeCode, socket.closeReason));
            }
          },
        );
        return;
      case '/dw/redirect':
        response
          ..statusCode = 302
          ..headers.set('location', '/elsewhere');
      case '/dw/gzip':
        final bytes = gzip.encode(utf8.encode('squeezed'));
        response.headers
          ..set('content-encoding', 'gzip')
          ..contentLength = bytes.length;
        response.add(bytes);
      default:
        final body = await utf8.decodeStream(request);
        response
          ..statusCode = 201
          ..reasonPhrase = 'Made'
          ..headers.set('x-api', 'yes')
          ..headers.add('set-cookie', 'a=1; Path=/')
          ..headers.add('set-cookie', 'b=2; Path=/')
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              ..._headersOf(request),
              'method': request.method,
              'uri': '${request.uri}',
              'body': body,
            }),
          );
    }
    await response.close();
  }
}

final class _FakeWeb {
  _FakeWeb._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeWeb> start() async =>
      _FakeWeb._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final Completer<void> release = Completer();

  Uri get base => Uri.parse('http://localhost:${_server.port}');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    switch (request.uri.path) {
      case '/stream':
        // Unbuffered, or dart:io holds the first event back until the end.
        response.bufferOutput = false;
        response.headers.contentType = ContentType('text', 'event-stream');
        response.write('data: first\n\n');
        await response.flush();
        await release.future;
        response.write('data: second\n\n');
      case r'/$dwdsws':
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((frame) => socket.add('web echo $frame'));
        return;
      default:
        response.write('web ${request.uri}');
    }
    await response.close();
  }
}
