import 'dart:io';

import 'package:path/path.dart' as p;

import '../deploy/web_cache.dart';
import '../project_layout.dart';

/// The `location` rules of the Nginx configuration the template's web image
/// ships (`<project>_flutter/nginx.conf`): what a directory served by
/// `dartway dev proxy --web-dir` falls back to when the project's own
/// configuration cannot be read.
///
/// Only the parts that decide a response are kept — which block serves a path,
/// whether it falls back to `index.html`, and the `Cache-Control` it adds.
/// `web_directory_test.dart` holds this to the template's file, so the two
/// cannot drift apart unnoticed.
const String dwTemplateWebServing = r'''
server {
  location / {
    try_files $uri $uri/ /index.html;
    add_header Cache-Control "no-cache";
  }

  location ~* "\.[0-9a-f]{8,}\.(js|css|wasm|json|png|jpe?g|gif|svg|webp|avif|ico|woff2?|otf|ttf)$" {
    add_header Cache-Control "public, max-age=31536000, immutable";
  }
}
''';

/// A built Flutter web app served the way the deployed web image serves it:
/// the file when there is one, `index.html` for every route that is not a
/// file (a Flutter route lives in the app, not on disk), the `Cache-Control`
/// the image's Nginx adds, and an `ETag` so revalidation costs a 304.
final class DwWebDirectory {
  /// Serves [root] by the `location` blocks of [servingConfiguration] — the
  /// project's web image configuration, [dwTemplateWebServing] when `null` or
  /// when it holds no `location` block.
  DwWebDirectory(Directory root, {String? servingConfiguration})
    : root = Directory(p.normalize(root.absolute.path)),
      _locations = _locationsOf(servingConfiguration);

  /// The build served, for example `<project>_flutter/build/web`.
  final Directory root;

  final List<DwNginxLocation> _locations;

  static List<DwNginxLocation> _locationsOf(String? configuration) {
    final parsed = configuration == null
        ? const <DwNginxLocation>[]
        : dwParseNginxLocations(configuration);
    return parsed.isEmpty
        ? dwParseNginxLocations(dwTemplateWebServing)
        : parsed;
  }

  /// The serving configuration of the web image of the DartWay project around
  /// [directory] — the project root, or a folder up to four levels below it
  /// (`<project>_flutter/build/web`) — or `null` when there is no project or
  /// its Dockerfile ships none.
  static String? projectServingConfiguration(Directory directory) {
    var candidate = Directory(p.normalize(directory.absolute.path));
    for (var level = 0; level <= 4; level++, candidate = candidate.parent) {
      final ProjectLayout layout;
      try {
        layout = ProjectLayout.detect(candidate);
      } on Object {
        continue;
      }
      return dwWebServingConfiguration(
        projectRoot: layout.root,
        dockerfile: File(p.join(layout.flutterPackageDir.path, 'Dockerfile')),
      );
    }
    return null;
  }

  /// Answers [request] from [root].
  Future<void> serve(HttpRequest request) async {
    final response = request.response;
    if (request.method != 'GET' && request.method != 'HEAD') {
      response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      return response.close();
    }

    final String path;
    final List<String> segments;
    try {
      path = request.uri.path;
      segments = request.uri.pathSegments;
    } on FormatException {
      return _plain(response, HttpStatus.badRequest, 'malformed path');
    }
    if (segments.any(
      (segment) =>
          segment == '..' ||
          segment == '.' ||
          segment.contains('/') ||
          segment.contains(r'\') ||
          segment.contains('\u0000'),
    )) {
      return _plain(response, HttpStatus.badRequest, 'malformed path');
    }

    final served = _resolve(path, segments);
    if (served == null) {
      final index = File(p.join(root.path, 'index.html'));
      return _plain(
        response,
        HttpStatus.notFound,
        index.existsSync()
            ? 'not found'
            : 'no index.html in ${root.path}: build the app first '
                  '(flutter build web)',
      );
    }
    final (file, urlPath) = served;
    await _sendFile(request, file, dwLocationFor(_locations, urlPath));
  }

  /// The file answering [path] and the URL path it is served under — the path
  /// whose `location` decides the headers, as after Nginx's internal redirect.
  (File, String)? _resolve(String path, List<String> segments) {
    final relative = segments.where((segment) => segment.isNotEmpty).toList();
    final target = p.joinAll([root.path, ...relative]);
    if (!p.equals(target, root.path) && !p.isWithin(root.path, target)) {
      return null;
    }

    if (!path.endsWith('/')) {
      final file = File(target);
      if (file.existsSync()) return (file, path);
    }
    // `$uri/`: a directory is answered by its index.
    final directoryIndex = File(p.join(target, 'index.html'));
    if (Directory(target).existsSync() && directoryIndex.existsSync()) {
      final base = path.endsWith('/') ? path : '$path/';
      return (directoryIndex, '${base}index.html');
    }

    final location = dwLocationFor(_locations, path);
    if (location == null || !location.triesFiles) return null;
    final index = File(p.join(root.path, 'index.html'));
    return index.existsSync() ? (index, '/index.html') : null;
  }

  Future<void> _sendFile(
    HttpRequest request,
    File file,
    DwNginxLocation? location,
  ) async {
    final response = request.response;
    final stat = file.statSync();
    final modified = stat.modified.toUtc();
    final seconds = modified.millisecondsSinceEpoch ~/ 1000;
    // Nginx's own form: last modification and size, in hex.
    final etag =
        '"${seconds.toRadixString(16)}-${stat.size.toRadixString(16)}"';

    final headers = response.headers
      ..set(HttpHeaders.etagHeader, etag)
      ..set(HttpHeaders.lastModifiedHeader, HttpDate.format(modified))
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (location?.cacheControl case final cacheControl?) {
      headers.set(HttpHeaders.cacheControlHeader, cacheControl);
    }

    if (_notModified(request.headers, etag, seconds)) {
      response.statusCode = HttpStatus.notModified;
      return response.close();
    }

    headers
      ..contentType = contentTypeOf(file.path)
      ..contentLength = stat.size;
    if (request.method == 'HEAD') return response.close();
    await response.addStream(file.openRead());
    await response.close();
  }

  static bool _notModified(HttpHeaders headers, String etag, int seconds) {
    final ifNoneMatch = headers.value(HttpHeaders.ifNoneMatchHeader);
    if (ifNoneMatch != null) {
      return ifNoneMatch.trim() == '*' ||
          ifNoneMatch
              .split(',')
              .map((tag) => tag.trim().replaceFirst('W/', ''))
              .contains(etag);
    }
    final ifModifiedSince = headers.value(HttpHeaders.ifModifiedSinceHeader);
    if (ifModifiedSince == null) return false;
    try {
      final since = HttpDate.parse(ifModifiedSince);
      return since.millisecondsSinceEpoch ~/ 1000 >= seconds;
    } on HttpException {
      return false;
    }
  }

  static Future<void> _plain(HttpResponse response, int status, String text) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.text
      ..write(text);
    return response.close();
  }

  /// The content type Nginx's `mime.types` gives the files a Flutter web build
  /// emits.
  static ContentType contentTypeOf(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.html' || '.htm' => ContentType.html,
        '.js' || '.mjs' => ContentType('application', 'javascript'),
        '.json' => ContentType.json,
        '.css' => ContentType('text', 'css'),
        '.wasm' => ContentType('application', 'wasm'),
        '.png' => ContentType('image', 'png'),
        '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
        '.gif' => ContentType('image', 'gif'),
        '.svg' => ContentType('image', 'svg+xml'),
        '.webp' => ContentType('image', 'webp'),
        '.avif' => ContentType('image', 'avif'),
        '.ico' => ContentType('image', 'x-icon'),
        '.otf' => ContentType('font', 'otf'),
        '.ttf' => ContentType('font', 'ttf'),
        '.woff' => ContentType('font', 'woff'),
        '.woff2' => ContentType('font', 'woff2'),
        '.txt' => ContentType.text,
        _ => ContentType.binary,
      };
}
