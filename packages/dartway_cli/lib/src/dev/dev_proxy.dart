import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'web_directory.dart';

/// One origin on the developer's machine in the shape production has (R2.7):
/// `/dw/*` — the `/dw/live` socket included — and `/health` go to the API,
/// everything else to the Flutter web app.
///
/// The server answers no CORS by design, so a web app has to reach it on its
/// own origin; `flutter run -d chrome` serves on a port of its own, and without
/// this every project writes the same proxy again.
///
/// **The `Host` header is passed through unchanged**, as the deployed Nginx
/// does (`proxy_set_header Host $http_host`). The server lets a browser open
/// the live socket when its `Origin` names the host the request was sent to;
/// behind this proxy the browser's `Origin` is the proxy's origin and so is its
/// `Host`, and the check passes with no `DW_ALLOWED_ORIGINS`. A proxy that
/// rewrote `Host` to the API's address would make every browser socket
/// cross-origin. `X-Forwarded-For`, `X-Real-IP` and `X-Forwarded-Proto` are
/// added the way the deployed Nginx adds them.
///
/// Upgrades — the live socket, and the web dev server's own sockets for hot
/// reload — are tunnelled as bytes once the upstream is reached: frames, close
/// codes, subprotocols and extensions pass untouched, because nothing here
/// speaks WebSocket. HTTP responses are streamed unbuffered, so server-sent
/// events arrive as they are sent.
final class DwDevProxy {
  /// A proxy to [api] and either the web dev server at [webServer] or the
  /// build in [webDirectory].
  DwDevProxy({
    required this.api,
    this.webServer,
    this.webDirectory,
    Iterable<String> apiPaths = const [],
    void Function(String line)? log,
  }) : apiPaths = List.unmodifiable(apiPaths.map(_normalizePrefix)),
       _log = log ?? stderr.writeln,
       assert(
         (webServer == null) != (webDirectory == null),
         'exactly one of webServer and webDirectory',
       );

  /// Where `/dw/*` and `/health` go: `http://localhost:8080`.
  final Uri api;

  /// The Flutter web dev server everything else goes to.
  final Uri? webServer;

  /// The build everything else is served from, when there is no dev server.
  final DwWebDirectory? webDirectory;

  final void Function(String line) _log;

  final List<HttpServer> _servers = [];
  final Set<Socket> _tunnelSockets = {};
  final Set<String> _unreachable = {};
  final HttpClient _client = HttpClient()
    ..autoUncompress = false
    ..userAgent = null
    ..connectionTimeout = const Duration(seconds: 5);

  /// The project's external doors (`DwHttpRoute` paths such as `/mcp` or
  /// `/github`) that go to the API as well. In production they live on the
  /// API host, which proxies everything; locally they share the one origin, so
  /// the proxy has to be told which paths are doors rather than app routes.
  final List<String> apiPaths;

  static String _normalizePrefix(String prefix) {
    final trimmed = prefix.trim();
    if (!trimmed.startsWith('/') || trimmed == '/') {
      throw ArgumentError.value(
        prefix,
        'apiPaths',
        'an API path is an absolute prefix such as /mcp',
      );
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Whether [path] belongs to the framework's reserved API paths.
  static bool isApiPath(String path) =>
      path == '/dw' || path.startsWith('/dw/') || path == '/health';

  /// Whether [path] goes to the API: a reserved path or one of [apiPaths]
  /// (the prefix itself or anything below it).
  bool routesToApi(String path) =>
      isApiPath(path) ||
      apiPaths.any((prefix) => path == prefix || path.startsWith('$prefix/'));

  /// The port listened on, once started.
  int get port => _servers.isEmpty
      ? throw StateError('The proxy is not running')
      : _servers.first.port;

  /// The origin to open in the browser and to build the app against
  /// (`DW_BACKEND_URL`).
  Uri get origin => Uri(scheme: 'http', host: 'localhost', port: port);

  /// Listens on [port] (0 for a free one) of the loopback interface — IPv4,
  /// and IPv6 too where the machine has it, so `localhost` answers whichever
  /// address a browser resolves it to.
  Future<void> start({int port = 8000}) async {
    if (_servers.isNotEmpty) throw StateError('The proxy is already running');
    final v4 = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _servers.add(v4);
    try {
      _servers.add(
        await HttpServer.bind(
          InternetAddress.loopbackIPv6,
          v4.port,
          v6Only: true,
        ),
      );
    } on SocketException {
      // No IPv6 loopback, or the port is taken there: IPv4 is enough.
    }
    for (final server in _servers) {
      server
        ..autoCompress = false
        ..serverHeader = null
        ..idleTimeout = const Duration(seconds: 120)
        ..defaultResponseHeaders.clear();
      server.listen(
        (request) => unawaited(_handle(request)),
        // An accept can fail for one connection — a client that closed before
        // the socket was set up surfaces as `OS Error: Invalid argument` from
        // `setOption` on macOS. Unhandled, that error ended the whole proxy;
        // it belongs to that one connection.
        onError: (Object error) =>
            _log('dartway dev proxy: a connection failed to open: $error'),
      );
    }
  }

  /// Stops listening and ends everything in flight: open sockets, streams.
  Future<void> stop() async {
    final servers = List.of(_servers);
    _servers.clear();
    await Future.wait(servers.map((server) => server.close(force: true)));
    for (final socket in List.of(_tunnelSockets)) {
      socket.destroy();
    }
    _tunnelSockets.clear();
    _client.close(force: true);
  }

  /// What goes where, for the startup banner.
  List<String> describe() => [
    '/dw/*, /health  →  $api  (API, live socket included)',
    for (final prefix in apiPaths) '$prefix  →  $api  (external door)',
    if (webServer case final web?)
      'everything else →  $web  (Flutter web dev server)'
    else
      'everything else →  ${webDirectory!.root.path}  (built app, SPA fallback)',
  ];

  Future<void> _handle(HttpRequest request) async {
    try {
      if (routesToApi(request.uri.path)) {
        await _forward(request, api, 'the API');
      } else if (webServer case final web?) {
        await _forward(request, web, 'the Flutter web dev server');
      } else {
        await webDirectory!.serve(request);
      }
    } on Object catch (error) {
      _log('dartway dev proxy: ${request.method} ${request.uri}: $error');
      try {
        request.response.statusCode = HttpStatus.badGateway;
        await request.response.close();
      } on Object {
        // The response had already started; the connection is gone with it.
      }
    }
  }

  Future<void> _forward(HttpRequest request, Uri target, String name) {
    if (_isUpgrade(request)) return _tunnel(request, target, name);
    return _forwardHttp(request, target, name);
  }

  static bool _isUpgrade(HttpRequest request) =>
      request.headers.value(HttpHeaders.upgradeHeader) != null &&
      (request.headers[HttpHeaders.connectionHeader] ?? const []).any(
        (value) => value.toLowerCase().contains('upgrade'),
      );

  /// Hop-by-hop headers: they describe one connection, not the message, and
  /// are never passed on (RFC 9110 §7.6.1). `content-length` and `host` are
  /// set explicitly instead of copied.
  static const _hopByHop = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };

  Future<void> _forwardHttp(
    HttpRequest request,
    Uri target,
    String name,
  ) async {
    final HttpClientRequest outgoing;
    try {
      outgoing = await _client.openUrl(
        request.method,
        Uri.parse('${target.scheme}://${target.authority}${request.uri}'),
      );
    } on Object catch (error) {
      return _badGateway(request, target, name, error);
    }
    _reached(target, name);

    outgoing
      ..followRedirects = false
      ..maxRedirects = 0;
    final headers = outgoing.headers;
    for (final header in [HttpHeaders.userAgentHeader, 'accept-encoding']) {
      headers.removeAll(header);
    }
    request.headers.forEach((header, values) {
      if (_hopByHop.contains(header) ||
          header == HttpHeaders.hostHeader ||
          header == HttpHeaders.contentLengthHeader ||
          _forwardingHeaders.contains(header)) {
        return;
      }
      for (final value in values) {
        headers.add(header, value, preserveHeaderCase: true);
      }
    });
    _forwarding(request).forEach(headers.set);
    if (request.headers.value(HttpHeaders.hostHeader) case final host?) {
      headers.set(HttpHeaders.hostHeader, host);
    }
    if (request.contentLength >= 0) {
      headers.contentLength = request.contentLength;
    } else if (request.headers.chunkedTransferEncoding) {
      headers.chunkedTransferEncoding = true;
    } else {
      headers.contentLength = 0;
    }

    final HttpClientResponse incoming;
    try {
      await outgoing.addStream(request);
      incoming = await outgoing.close();
    } on Object catch (error) {
      return _badGateway(request, target, name, error);
    }

    final response = request.response
      ..bufferOutput = false
      ..statusCode = incoming.statusCode
      ..reasonPhrase = incoming.reasonPhrase;
    incoming.headers.forEach((header, values) {
      if (_hopByHop.contains(header) ||
          header == HttpHeaders.contentLengthHeader) {
        return;
      }
      response.headers.removeAll(header);
      for (final value in values) {
        response.headers.add(header, value, preserveHeaderCase: true);
      }
    });
    if (incoming.contentLength >= 0) {
      response.headers.contentLength = incoming.contentLength;
    }
    try {
      await response.addStream(incoming);
      await response.close();
    } on Object {
      // The browser went away mid-response (a closed tab on an event
      // stream): the upstream connection goes with it.
      try {
        (await incoming.detachSocket()).destroy();
      } on Object {
        // Already closed.
      }
    }
  }

  /// Opens a raw connection to [target], replays the upgrade request on it
  /// with the forwarding headers added, and joins the two sockets. Whatever
  /// the upstream answers — `101`, or a `403` from the origin check — reaches
  /// the browser as it was sent.
  Future<void> _tunnel(HttpRequest request, Uri target, String name) async {
    final Socket upstream;
    try {
      upstream = await Socket.connect(
        target.host,
        target.port,
        timeout: const Duration(seconds: 5),
      );
    } on Object catch (error) {
      return _badGateway(request, target, name, error);
    }
    _reached(target, name);

    final head = StringBuffer('${request.method} ${request.uri} HTTP/1.1\r\n');
    request.headers.forEach((header, values) {
      if (header == HttpHeaders.connectionHeader ||
          _forwardingHeaders.contains(header)) {
        return;
      }
      head.write('$header: ${values.join(', ')}\r\n');
    });
    head.write('connection: Upgrade\r\n');
    _forwarding(request).forEach((header, value) {
      head.write('$header: $value\r\n');
    });
    head.write('\r\n');

    final Socket browser;
    try {
      browser = await request.response.detachSocket(writeHeaders: false);
    } on Object {
      upstream.destroy();
      rethrow;
    }
    _tunnelSockets
      ..add(browser)
      ..add(upstream);
    for (final socket in [browser, upstream]) {
      try {
        socket.setOption(SocketOption.tcpNoDelay, true);
      } on Object {
        // Not every socket takes the option; latency is all it costs.
      }
    }
    upstream.add(latin1.encode(head.toString()));

    void end() {
      browser.destroy();
      upstream.destroy();
      _tunnelSockets
        ..remove(browser)
        ..remove(upstream);
    }

    // Each direction ends by closing its write side, which is how a closed
    // WebSocket ends its TCP connection; the other direction gets a moment to
    // finish its own close before both sockets go.
    Timer? grace;
    Future<void> pump(Stream<List<int>> from, Socket to) async {
      try {
        await to.addStream(from);
        unawaited(to.close().then((_) {}, onError: (Object _) => end()));
        grace ??= Timer(const Duration(seconds: 5), end);
      } on Object {
        end();
      }
    }

    await Future.wait([pump(browser, upstream), pump(upstream, browser)]);
    grace?.cancel();
    end();
  }

  static const _forwardingHeaders = {
    'x-forwarded-for',
    'x-real-ip',
    'x-forwarded-proto',
  };

  /// The headers the deployed Nginx sets on what it passes on.
  static Map<String, String> _forwarding(HttpRequest request) {
    final client = request.connectionInfo?.remoteAddress.address;
    final forwardedFor = [
      ...?request.headers['x-forwarded-for'],
      ?client,
    ].join(', ');
    return {
      if (forwardedFor.isNotEmpty) 'x-forwarded-for': forwardedFor,
      'x-real-ip': ?client,
      'x-forwarded-proto': 'http',
    };
  }

  static String _reason(Object error) => switch (error) {
    SocketException(:final osError?) => osError.message,
    SocketException(:final message) => message,
    HttpException(:final message) => message,
    _ => '$error',
  };

  void _reached(Uri target, String name) {
    if (_unreachable.remove('$target')) {
      _log('dartway dev proxy: $name at $target answers again.');
    }
  }

  Future<void> _badGateway(
    HttpRequest request,
    Uri target,
    String name,
    Object error,
  ) async {
    if (_unreachable.add('$target')) {
      _log(
        'dartway dev proxy: nothing answers at $target ($name): '
        '${_reason(error)}. '
        'Requests to it get 502 until it does.',
      );
    }
    // Drain what the browser sent, so the connection can answer at all.
    try {
      await request.drain<void>();
    } on Object {
      // A body that could not be read changes nothing about the answer.
    }
    final response = request.response
      ..statusCode = HttpStatus.badGateway
      ..headers.contentType = ContentType.text
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(
        'dartway dev proxy: nothing answers at $target ($name). '
        'Is it running?\n',
      );
    await response.close();
  }
}
