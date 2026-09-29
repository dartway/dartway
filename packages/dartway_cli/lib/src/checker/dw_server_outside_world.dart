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
///   (`DwEnvironmentReader`). `bin/` hands the environment in and is not
///   judged;
/// - [DwCheckType.forbiddenHttpClient] — `dart:io`'s `HttpClient(` or an
///   import of `package:http/…` in `lib/src/`: an outbound request is
///   `ctx.http`, bounded, logged and faked by the test server.
///
/// Comments and strings are not code; an interpolation is.
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

  /// Lines of [content] that read `Platform.environment`.
  static List<int> environmentReadsIn(String content) =>
      _lines(withoutCommentsAndStrings(content), _environment);

  /// Lines of [content] that construct `HttpClient` or import `package:http`.
  static List<int> httpClientsIn(String content) => {
    ..._lines(withoutCommentsAndStrings(content), _httpClient),
    ..._lines(content, _httpImport),
  }.toList()..sort();

  static List<int> _lines(String text, RegExp pattern) => [
    for (final match in pattern.allMatches(text))
      '\n'.allMatches(text.substring(0, match.start)).length + 1,
  ];

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (server == null || !(_environmentEnabled || _httpEnabled)) return 0;
    final lib = Directory(p.join(server.path, 'lib'));
    if (!lib.existsSync()) return 0;
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
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
      if (_httpEnabled && p.isWithin(p.join('lib', 'src'), relative)) {
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
  static String withoutCommentsAndStrings(String content) {
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
