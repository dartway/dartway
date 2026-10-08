import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stack.dart';
import 'web_cache.dart';

/// One observation of a deployed stack from outside it.
class DwProbeResult {
  const DwProbeResult.pass(this.title, this.detail)
    : passed = true,
      warning = false;
  const DwProbeResult.warning(this.title, this.detail)
    : passed = true,
      warning = true;
  const DwProbeResult.fail(this.title, this.detail)
    : passed = false,
      warning = false;

  final String title;
  final bool passed;
  final bool warning;

  /// What was observed. Stated on success too, so the report describes the
  /// deployment rather than merely approving of it.
  final String detail;

  @override
  String toString() =>
      '${warning
          ? 'warn'
          : passed
          ? 'ok  '
          : 'FAIL'} $title — $detail';
}

/// Asks a deployed stack the questions a browser and a mobile app would, over
/// the network, and judges the answers — not whether something answered.
///
/// Used by `deploy run` after the proxy restart, by `deploy check`, and by the
/// local proof, which points [connectTo] at a loopback port so the very same
/// requests, with the very same `Host` and `Origin`, reach a stack on this
/// machine. That sameness is the point: the proof proves these probes.
class DwOutsideProbe {
  DwOutsideProbe({this.connectTo, this.timeout = const Duration(seconds: 15)});

  /// Where to open connections instead of resolving the URL's host — for the
  /// local proof. Null in production: DNS answers, as it does for everyone.
  final ({String host, int port})? connectTo;

  final Duration timeout;

  HttpClient _client() {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..autoUncompress = false;
    final redirect = connectTo;
    if (redirect != null) {
      client.connectionFactory = (uri, proxyHost, proxyPort) =>
          Socket.startConnect(redirect.host, redirect.port);
    }
    return client;
  }

  Future<({int status, HttpHeaders headers, String body, int size})> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
    final client = _client();
    try {
      final request = await client.openUrl(method, url).timeout(timeout);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(timeout);
      var bytes = await response
          .fold<List<int>>(<int>[], (all, part) => all..addAll(part))
          .timeout(timeout, onTimeout: () => <int>[]);
      final size = response.contentLength >= 0
          ? response.contentLength
          : bytes.length;
      if (response.headers.value(HttpHeaders.contentEncodingHeader) == 'gzip') {
        bytes = gzip.decode(bytes);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      return (
        status: response.statusCode,
        headers: response.headers,
        body: text,
        size: size,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// `GET <origin>/health` answers 200 `ok`: the server is up, migrated and
  /// reaches its database — through this host's proxy.
  Future<DwProbeResult> health(String origin) async {
    final url = Uri.parse('$origin/health');
    final title = 'GET $url';
    try {
      final answer = await _send('GET', url);
      if (answer.status == 200 && answer.body.trim() == 'ok') {
        return DwProbeResult.pass(title, '200 ok');
      }
      return DwProbeResult.fail(
        title,
        '${answer.status} "${_excerpt(answer.body)}" — expected 200 "ok" from '
        'the DartWay server; 502/504 is the proxy failing to reach it, 503 is '
        'the server without its database',
      );
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    }
  }

  /// `GET <origin>/` answers the web app's `index.html`, and tells the browser
  /// to revalidate it.
  Future<DwProbeResult> appIndex(String origin) async {
    final url = Uri.parse('$origin/');
    final title = 'GET $url';
    try {
      final answer = await _send('GET', url);
      final type = answer.headers.contentType?.mimeType;
      final cacheControl = answer.headers.value(HttpHeaders.cacheControlHeader);
      final body = answer.body.toLowerCase();
      if (answer.status != 200) {
        return DwProbeResult.fail(title, '${answer.status}, expected 200');
      }
      if (type != 'text/html' || !body.contains('<html')) {
        return DwProbeResult.fail(
          title,
          '200, but not an HTML page ($type) — the host is not serving the web '
          'image',
        );
      }
      if (!body.contains('flutter')) {
        return DwProbeResult.fail(
          title,
          '200 HTML that does not load Flutter — a default page rather than '
          'the app',
        );
      }
      if (dwCacheReuse(cacheControl: cacheControl) !=
          DwCacheReuse.revalidated) {
        return DwProbeResult.fail(
          title,
          'index.html is served with Cache-Control "${cacheControl ?? '<none>'}"; '
          'a browser may keep running the previous build after a deploy',
        );
      }
      return DwProbeResult.pass(
        title,
        '200 text/html, Flutter bootstrap, Cache-Control "$cacheControl"',
      );
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    }
  }

  /// Every probed entry point of the web build is revalidated before reuse.
  Future<DwProbeResult> webCache(String origin) async {
    final title = 'cache policy of $origin';
    final freely = <String>[];
    var answered = 0;
    for (final path in dwProbedEntryPoints) {
      try {
        final answer = await _send('GET', Uri.parse('$origin$path'));
        if (answer.status != 200) continue;
        answered++;
        final cacheControl = answer.headers.value(
          HttpHeaders.cacheControlHeader,
        );
        if (dwCacheReuse(cacheControl: cacheControl) == DwCacheReuse.freely) {
          freely.add('$path: $cacheControl');
        }
      } on Object {
        continue;
      }
    }
    if (answered == 0) {
      return DwProbeResult.fail(title, 'no entry point answered 200');
    }
    if (freely.isNotEmpty) {
      return DwProbeResult.fail(
        title,
        'served for reuse without revalidation: ${freely.join('; ')}',
      );
    }
    return DwProbeResult.pass(
      title,
      '$answered entry point(s) revalidate before reuse',
    );
  }

  /// The JavaScript or Wasm application bundle is compressed by the front
  /// proxy. A missing build kind is ignored because Flutter emits one or the
  /// other depending on its renderer.
  Future<DwProbeResult> webCompression(String origin) async {
    final title = 'compression of $origin';
    for (final path in ['/main.dart.js', '/main.dart.wasm']) {
      try {
        final answer = await _send(
          'GET',
          Uri.parse('$origin$path'),
          headers: {HttpHeaders.acceptEncodingHeader: 'gzip'},
        );
        if (answer.status != 200) continue;
        final mimeType = answer.headers.contentType?.mimeType;
        if (mimeType != 'application/javascript' &&
            mimeType != 'text/javascript' &&
            mimeType != 'application/wasm') {
          continue;
        }
        final encoding = answer.headers.value(
          HttpHeaders.contentEncodingHeader,
        );
        if (encoding != 'gzip') {
          return DwProbeResult.fail(
            title,
            '$path (${answer.size} bytes) has Content-Encoding '
            '"${encoding ?? '<none>'}"; expected gzip',
          );
        }
        return DwProbeResult.pass(title, '$path (${answer.size} bytes), gzip');
      } on Object catch (error) {
        return DwProbeResult.fail(title, _describe(error));
      }
    }
    return DwProbeResult.fail(
      title,
      'neither main.dart.js nor main.dart.wasm answered 200 with a '
      'JavaScript or application/wasm Content-Type',
    );
  }

  /// Flutter's startup files must refer to the CanvasKit files bundled into
  /// the web image rather than the default Google CDN.
  Future<DwProbeResult> canvasKitOrigin(String origin) async {
    final title = 'CanvasKit origin of $origin';
    for (final path in ['/', '/flutter_bootstrap.js']) {
      try {
        final answer = await _send('GET', Uri.parse('$origin$path'));
        if (answer.status != 200) continue;
        if (answer.body.contains('www.gstatic.com/flutter-canvaskit') &&
            !_usesLocalCanvasKit(answer.body)) {
          return DwProbeResult.warning(
            title,
            '$path loads www.gstatic.com/flutter-canvaskit; add '
            '--no-web-resources-cdn to flutter build web '
            '(docs/migrations/2026-10-08-local-canvaskit.md)',
          );
        }
      } on Object catch (error) {
        return DwProbeResult.fail(title, _describe(error));
      }
    }
    return DwProbeResult.pass(title, 'startup files do not load gstatic.com');
  }

  static bool _usesLocalCanvasKit(String startup) {
    // Flutter retains its CDN fallback in the loader even for a local build.
    // The generated JSON selects which branch the loader actually uses.
    final config = RegExp(
      r'_flutter\.buildConfig\s*=\s*(\{.*?\})\s*;',
      dotAll: true,
    ).firstMatch(startup);
    if (config == null) return false;
    final buildConfig = jsonDecode(config.group(1)!);
    if (buildConfig is! Map || buildConfig['useLocalCanvasKit'] != true) {
      return false;
    }
    // A loader configuration takes precedence over the generated build flag.
    return !RegExp(
      r'''["']?canvasKitBaseUrl["']?\s*:\s*["'](?:https?:)?//www\.gstatic\.com/flutter-canvaskit''',
    ).hasMatch(startup);
  }

  /// `GET <origin>/dw/live` upgrades to a WebSocket and the DartWay server
  /// speaks on it.
  ///
  /// The probe sends no protocol version, on purpose: it cannot know which
  /// one the deployed server speaks, and the server's documented answer to a
  /// client without one is to accept the upgrade and close with a `dw.` reason
  /// (`dw.protocolUnsupported`) — a browser cannot read the status of a
  /// refused upgrade, only the close of an accepted one. So a 101 followed by
  /// that close proves every hop: the proxy passed the upgrade headers, the
  /// origin check admitted [origin], and what answered is the server.
  Future<DwProbeResult> liveUpgrade(
    String origin, {
    String? browserOrigin,
  }) async {
    final url = Uri.parse(
      '${origin.replaceFirst(RegExp('^http'), 'ws')}/dw/live',
    );
    final title =
        'upgrade $url${browserOrigin == null ? '' : ' from $browserOrigin'}';
    final client = _client();
    try {
      final socket = await WebSocket.connect(
        url.toString(),
        headers: {'origin': ?browserOrigin},
        customClient: client,
      ).timeout(timeout);
      final firstMessage = Completer<Object?>();
      socket.listen(
        (message) {
          if (!firstMessage.isCompleted) firstMessage.complete(message);
        },
        onDone: () {
          if (!firstMessage.isCompleted) firstMessage.complete(null);
        },
        onError: (Object _) {
          if (!firstMessage.isCompleted) firstMessage.complete(null);
        },
      );
      final message = await firstMessage.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      final reason = socket.closeReason;
      final code = socket.closeCode;
      await socket.close();
      if (message != null) {
        return DwProbeResult.pass(title, '101, the server spoke first');
      }
      if (code != null && (reason ?? '').startsWith('dw.')) {
        return DwProbeResult.pass(
          title,
          '101, then the server\'s documented close $code "$reason"',
        );
      }
      return DwProbeResult.fail(
        title,
        '101, but nothing from a DartWay server followed (close '
        '${code ?? '<none>'} "${reason ?? ''}")',
      );
    } on WebSocketException catch (error) {
      return DwProbeResult.fail(
        title,
        'the upgrade was refused: ${error.message} — a 403 is the origin '
        'check, a 400 is a proxy that dropped the Upgrade headers',
      );
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    } finally {
      client.close(force: true);
    }
  }

  /// A browser on [appOrigin] may PUT to [storageOrigin] with the headers a
  /// presigned upload is bound to — the preflight answers for exactly that.
  Future<DwProbeResult> storageCors({
    required String storageOrigin,
    required String bucket,
    required String appOrigin,
  }) async {
    final url = Uri.parse('$storageOrigin/$bucket/dw-cors-probe');
    final title = 'preflight PUT $url from $appOrigin';
    const wanted = ['content-type', 'content-length', 'if-none-match'];
    try {
      final answer = await _send(
        'OPTIONS',
        url,
        headers: {
          'origin': appOrigin,
          'access-control-request-method': 'PUT',
          'access-control-request-headers': wanted.join(','),
        },
      );
      final allowOrigin = answer.headers.value('access-control-allow-origin');
      final methods =
          (answer.headers.value('access-control-allow-methods') ?? '')
              .toUpperCase();
      final headers =
          (answer.headers.value('access-control-allow-headers') ?? '')
              .toLowerCase();
      final problems = [
        if (answer.status < 200 || answer.status >= 300)
          'status ${answer.status}',
        if (allowOrigin != appOrigin && allowOrigin != '*')
          'Access-Control-Allow-Origin is "${allowOrigin ?? '<none>'}"',
        if (!methods.contains('PUT')) 'PUT is not among the allowed methods',
        for (final header in wanted)
          if (!headers.contains(header) && headers != '*')
            '$header is not among the allowed headers',
      ];
      if (problems.isEmpty) {
        return DwProbeResult.pass(
          title,
          '${answer.status}, origin $allowOrigin, headers $headers',
        );
      }
      return DwProbeResult.fail(
        title,
        '${problems.join('; ')} — a browser will refuse every upload',
      );
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    }
  }

  /// Without credentials, the probe object `storage-init` writes reads from
  /// [publicBucket] and is refused from [privateBucket], and neither bucket
  /// lists its keys: the public files open, the private ones are not public.
  Future<DwProbeResult> storageVisibility({
    required String storageOrigin,
    required String publicBucket,
    required String privateBucket,
  }) async {
    final title =
        'anonymous GET of $storageOrigin/{$publicBucket,$privateBucket}/'
        '${DwStack.visibilityProbeKey}';
    try {
      Future<({int status, String body})> get(String path) async {
        final answer = await _send('GET', Uri.parse('$storageOrigin/$path'));
        return (status: answer.status, body: answer.body);
      }

      final public = await get('$publicBucket/${DwStack.visibilityProbeKey}');
      final private = await get('$privateBucket/${DwStack.visibilityProbeKey}');
      final publicListing = await get('$publicBucket?list-type=2');
      final privateListing = await get('$privateBucket?list-type=2');
      final problems = [
        if (public.status != 200 ||
            public.body.trim() != DwStack.visibilityProbeText)
          '$publicBucket answered ${public.status} — public files will not '
              'open',
        if (private.status < 300)
          '$privateBucket answered ${private.status} — every private file is '
              'public',
        if (publicListing.status < 300)
          '$publicBucket lists its keys to anyone',
        if (privateListing.status < 300)
          '$privateBucket lists its keys to anyone',
      ];
      if (problems.isEmpty) {
        return DwProbeResult.pass(
          title,
          'public ${public.status}, private ${private.status}, listings '
          '${publicListing.status} and ${privateListing.status}',
        );
      }
      return DwProbeResult.fail(title, problems.join('; '));
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    }
  }

  /// `GET <origin>/` of the static site answers 200 HTML.
  Future<DwProbeResult> site(String origin) async {
    final url = Uri.parse('$origin/');
    final title = 'GET $url';
    try {
      final answer = await _send('GET', url);
      if (answer.status == 200 &&
          answer.headers.contentType?.mimeType == 'text/html') {
        return DwProbeResult.pass(title, '200 text/html');
      }
      return DwProbeResult.fail(
        title,
        '${answer.status} ${answer.headers.contentType?.mimeType}, expected '
        '200 text/html from the site directory',
      );
    } on Object catch (error) {
      return DwProbeResult.fail(title, _describe(error));
    }
  }

  static String _excerpt(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 80 ? flat : '${flat.substring(0, 80)}…';
  }

  static String _describe(Object error) => switch (error) {
    HandshakeException(:final message) =>
      'TLS handshake failed: $message — the certificate is missing, expired '
          'or does not name this host',
    SocketException(:final message, :final osError) =>
      'cannot connect: $message${osError == null ? '' : ' (${osError.message})'}',
    TimeoutException() => 'no answer within the timeout',
    _ => '$error',
  };
}

/// The questions a deployment of [stack] must answer from outside, in order:
/// health through both hosts, the app page, cache policy, compression and
/// CanvasKit origin, the live socket through both hosts, and — where they
/// exist — the site, the storage
/// CORS rule a browser upload depends on, and what each bucket gives to
/// anyone without keys.
List<Future<DwProbeResult> Function()> dwOutsideProbes(
  DwStack stack,
  DwOutsideProbe probe, {
  bool includeCanvasKitOrigin = true,
}) => [
  () => probe.health(stack.apiOrigin),
  () => probe.health(stack.appOrigin),
  () => probe.appIndex(stack.appOrigin),
  () => probe.webCache(stack.appOrigin),
  () => probe.webCompression(stack.appOrigin),
  if (includeCanvasKitOrigin) () => probe.canvasKitOrigin(stack.appOrigin),
  () => probe.liveUpgrade(stack.apiOrigin),
  () => probe.liveUpgrade(stack.appOrigin, browserOrigin: stack.appOrigin),
  if (stack.siteOrigin case final site?) () => probe.site(site),
  if (stack.storageOrigin case final storage?) ...[
    () => probe.storageCors(
      storageOrigin: storage,
      bucket: stack.privateBucketName,
      appOrigin: stack.appOrigin,
    ),
    () => probe.storageVisibility(
      storageOrigin: storage,
      publicBucket: stack.publicBucketName,
      privateBucket: stack.privateBucketName,
    ),
  ],
];
