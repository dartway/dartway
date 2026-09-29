import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';

/// The server reaches its environment and other services one way each
/// (dartway/dartway#386):
///
/// - [DwCheckType.forbiddenEnvironmentRead] — `Platform.environment` in the
///   server package's `lib/` outside `lib/src/core/environment.dart`, where
///   the project's `AppEnvironment` reads every variable at start
///   (`DwEnvironmentReader`). In `bin/`, which hands the environment in,
///   `Platform.environment` only as the argument of
///   `DwLocalEnvironment.overlay(…)`, and no map read by a variable's name
///   (`env['PORT']`): an entry point reads through `AppEnvironment.read`;
/// - [DwCheckType.forbiddenHttpClient] — `dart:io`'s `HttpClient(` or an
///   import of `package:http/…` anywhere in `lib/`: an outbound request is
///   `ctx.http`, bounded, logged and faked by the test server.
///
/// Comments and strings are not code; an interpolation is. Known limits:
/// another client package (`dio`, `package:http`'s re-exports through a
/// third package), `WebSocket.connect`, and a conditional import naming
/// `package:http` are not seen.
class DwServerOutsideWorldInspector {
  DwServerOutsideWorldInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _environmentEnabled = _enabled(
         DwCheckType.forbiddenEnvironmentRead,
         filterType,
         filterSeverity,
       ),
       _httpEnabled = _enabled(
         DwCheckType.forbiddenHttpClient,
         filterType,
         filterSeverity,
       );

  final Directory? serverPackageDir;
  final bool _environmentEnabled;
  final bool _httpEnabled;
  final _findings = <(DwCheckType, String)>[];

  /// The one file of `lib/` that reads the environment.
  static final String environmentFile = p.join(
    'lib',
    'src',
    'core',
    'environment.dart',
  );

  List<(DwCheckType, String)> get findings => List.unmodifiable(_findings);

  static bool _enabled(
    DwCheckType type,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  ) =>
      (filterType == null || filterType == type) &&
      (filterSeverity == null || filterSeverity == type.severity);

  static final _environment = RegExp(r'\bPlatform\s*\.\s*environment\b');
  static final _httpClient = RegExp(r'\bHttpClient\s*(\(|\.\s*new\b)');
  static final _httpImport = RegExp(
    r'''^\s*(import|export)\s+['"]package:http/''',
    multiLine: true,
  );
  static final _overlayCall = RegExp(
    r'DwLocalEnvironment\s*\.\s*overlay\s*\(\s*$',
  );
  static final _readByName = RegExp(r'''\[\s*(['"])([A-Z][A-Z0-9_]*)\1\s*\]''');

  /// Lines of [content] that read `Platform.environment`.
  static List<int> environmentReadsIn(String content) =>
      _lines(withoutCommentsAndStrings(content), _environment);

  /// What an entry point in `bin/` reads of the environment by itself, as
  /// `(line, what)`: `Platform.environment` anywhere but inside
  /// `DwLocalEnvironment.overlay(…)`, and a map read by a variable's name.
  static List<(int, String)> entryPointReadsIn(String content) {
    final code = withoutCommentsAndStrings(content);
    final withStrings = withoutCommentsAndStrings(content, keepStrings: true);
    return [
      for (final match in _environment.allMatches(code))
        if (!_overlayCall.hasMatch(code.substring(0, match.start)))
          (_lineOf(code, match.start), '`Platform.environment`'),
      for (final match in _readByName.allMatches(withStrings))
        (_lineOf(withStrings, match.start), "`['${match.group(2)}']`"),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// Lines of [content] that construct `HttpClient` or import `package:http`.
  static List<int> httpClientsIn(String content) => {
    ..._lines(withoutCommentsAndStrings(content), _httpClient),
    ..._lines(
      withoutCommentsAndStrings(content, keepStrings: true),
      _httpImport,
    ),
  }.toList()..sort();

  static final _wordOrPath = RegExp(r'^[\w:/.\-]*$');

  static int _lineOf(String text, int offset) =>
      '\n'.allMatches(text.substring(0, offset)).length + 1;

  static List<int> _lines(String text, RegExp pattern) => [
    for (final match in pattern.allMatches(text)) _lineOf(text, match.start),
  ];

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (server == null || !(_environmentEnabled || _httpEnabled)) return 0;
    List<File> sources(String folder) {
      final directory = Directory(p.join(server.path, folder));
      if (!directory.existsSync()) return const [];
      return directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    }

    if (_environmentEnabled) {
      for (final file in sources('bin')) {
        final shown = p.relative(file.path, from: server.parent.path);
        for (final (line, what) in entryPointReadsIn(file.readAsStringSync())) {
          _findings.add((
            DwCheckType.forbiddenEnvironmentRead,
            '$what — $shown:$line; an entry point reads the environment '
                'through AppEnvironment.read(DwLocalEnvironment.overlay('
                'Platform.environment)) and nothing else',
          ));
        }
      }
    }
    for (final file in sources('lib')) {
      final relative = p.relative(file.path, from: server.path);
      final shown = p.relative(file.path, from: server.parent.path);
      final content = file.readAsStringSync();
      if (_environmentEnabled && relative != environmentFile) {
        for (final line in environmentReadsIn(content)) {
          _findings.add((
            DwCheckType.forbiddenEnvironmentRead,
            '`Platform.environment` — $shown:$line; read the variable in '
                '${p.join('lib', 'src', 'core', 'environment.dart')} '
                '(AppEnvironment) and pass the value in',
          ));
        }
      }
      if (_httpEnabled) {
        for (final line in httpClientsIn(content)) {
          _findings.add((
            DwCheckType.forbiddenHttpClient,
            'an HTTP client of its own — $shown:$line; send through '
                '`ctx.http` (DwOutboundHttp)',
          ));
        }
      }
    }
    if (_findings.isEmpty) return 0;
    print('\n📌 Environment and outbound HTTP:\n');
    var errors = 0;
    for (final (type, finding) in _findings) {
      print('  ${type.reportLabel}: $finding');
      tally?.add(type, 1);
      if (type.severity == DwCheckSeverity.error) errors++;
    }
    return errors;
  }

  /// [content] with comments removed and string contents blanked, newlines
  /// kept so a match is reported on its own line. An interpolation is code:
  /// `'${Platform.environment['X']}'` reads the environment.
  ///
  /// With [keepStrings] a string that is one word or a path stays as it is —
  /// what an import names, and a map read by a literal key, are strings — and
  /// only comments and other strings go.
  static String withoutCommentsAndStrings(
    String content, {
    bool keepStrings = false,
  }) {
    final out = StringBuffer();
    var i = 0;
    void newlinesOf(String skipped) =>
        out.write('\n' * '\n'.allMatches(skipped).length);

    while (i < content.length) {
      if (content.startsWith('//', i)) {
        final end = content.indexOf('\n', i);
        i = end < 0 ? content.length : end;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final close = content.indexOf('*/', i + 2);
        final end = close < 0 ? content.length : close + 2;
        newlinesOf(content.substring(i, end));
        i = end;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        if (keepStrings) {
          final raw = i > 0 && content[i - 1] == 'r';
          final delimiter = content.startsWith(char * 3, i) ? char * 3 : char;
          var j = i + delimiter.length;
          while (j < content.length && !content.startsWith(delimiter, j)) {
            j += !raw && content[j] == r'\' ? 2 : 1;
          }
          final end = j + delimiter.length > content.length
              ? content.length
              : j + delimiter.length;
          final literal = content.substring(i, end);
          final inside = content.substring(
            i + delimiter.length,
            j > content.length ? content.length : j,
          );
          // A word or a path — a variable's name, a `package:` URI — stays;
          // prose, which could hold anything, is blanked like code's strings.
          out.write(_wordOrPath.hasMatch(inside) ? literal : '""');
          out.write('\n' * '\n'.allMatches(literal).length);
          i = end;
          continue;
        }
        final raw = i > 0 && content[i - 1] == 'r';
        final delimiter = content.startsWith(char * 3, i) ? char * 3 : char;
        var j = i + delimiter.length;
        out.write('""');
        while (j < content.length && !content.startsWith(delimiter, j)) {
          if (!raw && content.startsWith(r'${', j)) {
            var depth = 0;
            var k = j + 1;
            for (; k < content.length; k++) {
              if (content[k] == '{') depth++;
              if (content[k] == '}' && --depth == 0) break;
            }
            out.write(' ${content.substring(j + 2, k)} ');
            j = k + 1;
            continue;
          }
          if (content[j] == '\n') out.write('\n');
          j += !raw && content[j] == r'\' ? 2 : 1;
        }
        i = j + delimiter.length > content.length
            ? content.length
            : j + delimiter.length;
        continue;
      }
      out.write(char);
      i++;
    }
    return out.toString();
  }
}
