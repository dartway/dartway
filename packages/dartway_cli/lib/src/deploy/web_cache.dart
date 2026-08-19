/// What a browser is allowed to keep of a Flutter web build, and how to read
/// that out of a serving configuration or off the wire.
///
/// The rule everything here rests on: **a Flutter web build hashes nothing.**
/// `index.html`, `flutter_bootstrap.js`, `flutter.js`, `main.dart.js`,
/// `main.dart.wasm`, `flutter_service_worker.js` and every file under `assets/`
/// carry the same name in every build. The "fingerprinted assets are immutable"
/// rule — correct for a bundler that puts a content hash in the name — lands on
/// exactly the files that change on every deploy when applied here. A browser
/// that took one under a long `max-age` does not ask again: it goes on running
/// the previous build, the server goes on serving the new one, and nothing on
/// either side reports a problem.
library;

import 'dart:io';

/// Paths a Flutter web build serves under a name it will reuse in the next
/// build. Every one of them has to be revalidated before reuse.
///
/// Not every build emits every path — a `--wasm` build has no `main.dart.js`,
/// an older Flutter no `flutter_bootstrap.js` — so a probe that comes back 404
/// means "not part of this build", not "a finding".
const List<String> dwFlutterEntryPoints = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/main.dart.wasm',
  '/flutter.js',
  '/flutter_service_worker.js',
  '/version.json',
  '/manifest.json',
  '/assets/AssetManifest.bin.json',
  '/assets/FontManifest.json',
  '/assets/fonts/MaterialIcons-Regular.otf',
  '/assets/assets/images/logo.png',
  '/icons/Icon-192.png',
  '/favicon.png',
  '/canvaskit/canvaskit.js',
  '/canvaskit/canvaskit.wasm',
];

/// The subset worth asking a live server about.
///
/// One request each, and only paths a deployed build almost certainly has. The
/// point is to catch a policy, not to enumerate a build.
const List<String> dwProbedEntryPoints = [
  '/',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/flutter.js',
  '/version.json',
  '/assets/AssetManifest.bin.json',
];

/// How a response may be reused.
enum DwCacheReuse {
  /// The copy may not be reused before the server has confirmed it.
  revalidated,

  /// The copy may be reused for a while without asking. Correct for a name
  /// that carries a content hash, wrong for everything a Flutter build emits.
  freely,

  /// Nothing was said. The browser applies a heuristic of its own, derived
  /// from `Last-Modified` — far less dangerous than a stated `max-age`, and
  /// still nobody's decision.
  unstated,
}

/// The reuse policy a `Cache-Control` value states.
///
/// [expires] is Nginx's `expires` directive, which is a second way of saying
/// the same thing: `expires 1y` becomes `Cache-Control: max-age=31536000`, and
/// `expires -1`/`epoch` becomes `no-cache`. When both are present Nginx emits
/// both headers, and the permissive one is what a browser may act on — so the
/// permissive one is what is judged.
DwCacheReuse dwCacheReuse({String? cacheControl, String? expires}) {
  final fromExpires = _reuseOfExpires(expires);
  final fromHeader = _reuseOfCacheControl(cacheControl);
  if (fromExpires == DwCacheReuse.freely || fromHeader == DwCacheReuse.freely) {
    return DwCacheReuse.freely;
  }
  if (fromExpires == DwCacheReuse.revalidated ||
      fromHeader == DwCacheReuse.revalidated) {
    return DwCacheReuse.revalidated;
  }
  return DwCacheReuse.unstated;
}

DwCacheReuse _reuseOfCacheControl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return DwCacheReuse.unstated;
  }
  final directives = value.toLowerCase();
  if (directives.contains('immutable')) {
    return DwCacheReuse.freely;
  }
  if (directives.contains('no-store') ||
      directives.contains('no-cache') ||
      directives.contains('must-revalidate') ||
      directives.contains('proxy-revalidate')) {
    return DwCacheReuse.revalidated;
  }
  final maxAge = RegExp(r'(?<!s-)max-age\s*=\s*(\d+)').firstMatch(directives);
  if (maxAge == null) {
    return DwCacheReuse.unstated;
  }
  return int.parse(maxAge.group(1)!) > 0
      ? DwCacheReuse.freely
      : DwCacheReuse.revalidated;
}

DwCacheReuse _reuseOfExpires(String? value) {
  final directive = value?.trim().toLowerCase();
  if (directive == null || directive.isEmpty || directive == 'off') {
    return DwCacheReuse.unstated;
  }
  if (directive == '-1' || directive == 'epoch' || directive == '0') {
    return DwCacheReuse.revalidated;
  }
  return DwCacheReuse.freely;
}

/// One `location` block of an Nginx configuration.
class DwNginxLocation {
  const DwNginxLocation({
    required this.modifier,
    required this.pattern,
    required this.body,
  });

  /// `=`, `^~`, `~`, `~*`, or empty for a plain prefix.
  final String modifier;
  final String pattern;
  final String body;

  bool get isRegex => modifier == '~' || modifier == '~*';
  bool get isExact => modifier == '=';

  bool matches(String path) {
    if (isRegex) {
      return RegExp(pattern, caseSensitive: modifier == '~').hasMatch(path);
    }
    if (isExact) {
      return pattern == path;
    }
    return path.startsWith(pattern);
  }

  /// The reuse policy this block states, if it states one.
  DwCacheReuse get reuse => dwCacheReuse(
    cacheControl: _directiveValue(body, _cacheControlDirective),
    expires: _directiveValue(body, _expiresDirective),
  );

  static final RegExp _cacheControlDirective = RegExp(
    'add_header' r'\s+' '["\']?Cache-Control["\']?' r'\s+(.+?);',
    caseSensitive: false,
  );

  static final RegExp _expiresDirective = RegExp(
    r'(?:^|[;{\s])expires\s+([^;]+);',
    caseSensitive: false,
  );

  static final RegExp _surroundingQuotes = RegExp('^["\']|["\']\$');

  static String? _directiveValue(String body, RegExp pattern) {
    final match = pattern.firstMatch(body);
    if (match == null) {
      return null;
    }
    return match.group(1)!.trim().replaceAll(_surroundingQuotes, '');
  }
}

/// The `location` blocks of an Nginx configuration, in the order they appear.
///
/// Deliberately not a full Nginx parser: it reads the one construct that
/// decides which rule a path falls under, and ignores everything else. A
/// configuration it cannot make sense of yields no locations, which reads as
/// "nothing is stated" rather than as a false verdict either way.
List<DwNginxLocation> dwParseNginxLocations(String configuration) {
  final locations = <DwNginxLocation>[];
  for (final match in _locationHeader.allMatches(configuration)) {
    final open = match.end - 1;
    final close = _matchingBrace(configuration, open);
    if (close == null) {
      continue;
    }
    locations.add(
      DwNginxLocation(
        modifier: match.group(1) ?? '',
        pattern: _unquote(match.group(2)!),
        body: configuration.substring(open + 1, close),
      ),
    );
  }
  return locations;
}

final RegExp _locationHeader = RegExp(
  r'(?:^|[\s;{}])location\s+(=|\^~|~\*|~)?\s*'
  '("[^"]*"' r"|'[^']*'" r'|\S+)' r'\s*\{',
  multiLine: true,
);

int? _matchingBrace(String text, int open) {
  var depth = 0;
  for (var index = open; index < text.length; index++) {
    switch (text[index]) {
      case '{':
        depth++;
      case '}':
        depth--;
        if (depth == 0) {
          return index;
        }
    }
  }
  return null;
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

/// The block that would serve [path], by Nginx's own precedence: an exact `=`
/// match wins outright; otherwise the longest prefix is remembered, and it wins
/// immediately when it is `^~`; failing that the first matching regex wins; and
/// the remembered prefix is the fallback.
DwNginxLocation? dwLocationFor(List<DwNginxLocation> locations, String path) {
  DwNginxLocation? longestPrefix;
  for (final location in locations) {
    if (location.isExact && location.matches(path)) {
      return location;
    }
    if (!location.isRegex && !location.isExact && location.matches(path)) {
      if (longestPrefix == null ||
          location.pattern.length > longestPrefix.pattern.length) {
        longestPrefix = location;
      }
    }
  }
  if (longestPrefix != null && longestPrefix.modifier == '^~') {
    return longestPrefix;
  }
  for (final location in locations) {
    if (location.isRegex && location.matches(path)) {
      return location;
    }
  }
  return longestPrefix;
}

/// How each of [dwFlutterEntryPoints] would be served by [configuration].
Map<String, DwCacheReuse> dwEntryPointPolicies(String configuration) {
  final locations = dwParseNginxLocations(configuration);
  return {
    for (final path in dwFlutterEntryPoints)
      path: dwLocationFor(locations, path)?.reuse ?? DwCacheReuse.unstated,
  };
}

/// The Nginx configuration the web image is built with, gathered from the
/// Dockerfile that builds it.
///
/// Two shapes are in the wild and both are read: a heredoc written straight
/// into the image, and a `COPY <path> /etc/nginx/...` of a file in the build
/// context. What comes back is the text, not the file — the check is about what
/// the container ends up serving, and a file nothing copies serves nothing.
String? dwWebServingConfiguration({
  required Directory projectRoot,
  required File dockerfile,
}) {
  if (!dockerfile.existsSync()) {
    return null;
  }
  final text = dockerfile.readAsStringSync();
  final buffer = StringBuffer();

  for (final match in _copyHeredoc.allMatches(text)) {
    if (!match.group(2)!.contains('/nginx/')) {
      continue;
    }
    final terminator = match.group(1)!;
    final end = text.indexOf(
      RegExp('^$terminator\\s*\$', multiLine: true),
      match.end,
    );
    buffer.writeln(
      end == -1 ? text.substring(match.end) : text.substring(match.end, end),
    );
  }

  for (final match in _copyFile.allMatches(text)) {
    // `--from` copies out of a build stage, not out of the context — the path
    // it names is inside another image and there is nothing here to read.
    if (match.group(1)!.contains('--from')) {
      continue;
    }
    if (!match.group(3)!.contains('/nginx/')) {
      continue;
    }
    final source = File(
      '${projectRoot.path}/${match.group(2)!}'.replaceAll(r'\', '/'),
    );
    if (source.existsSync()) {
      buffer.writeln(source.readAsStringSync());
    }
  }

  final gathered = buffer.toString().trim();
  return gathered.isEmpty ? null : gathered;
}

final RegExp _copyHeredoc = RegExp(
  r'COPY\s+<<\s*' '["\']?' r'(\w+)' '["\']?' r'\s+(\S+)',
  caseSensitive: false,
);

final RegExp _copyFile = RegExp(
  r'^\s*COPY\s+((?:--\S+\s+)*)([^\s<>-][^\s<>]*)\s+(\S+)\s*$',
  caseSensitive: false,
  multiLine: true,
);
