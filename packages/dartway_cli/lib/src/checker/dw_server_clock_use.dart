import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';

/// The server reads the time from its clock, `ctx.now`
/// ([DwCheckType.forbiddenDateTimeNow], dartway/dartway#385).
///
/// `DateTime.now()` in a server's `lib/` is a time no test can set: the
/// server's clock (`DwAppServer(clock: …)`) is what a `DwTestClock` moves,
/// and what the job queue decides due times by. So the system clock is
/// refused anywhere under `lib/` — the factory file beside `src/` included —
/// in every spelling that reads it: `DateTime.now`, `DateTime.timestamp`,
/// called or torn off, and `clock.now()` of `package:clock` in a file that
/// imports it, under a prefix or without one. Comments and strings are not
/// code. `bin/`, `test/` and `tool/` stay free: a seed or a test decides its
/// own time.
class DwServerClockInspector {
  DwServerClockInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.forbiddenDateTimeNow) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.forbiddenDateTimeNow.severity);

  final Directory? serverPackageDir;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  static final _systemNow = RegExp(
    r'\bDateTime\s*\.\s*(now|timestamp)\b(?!\s*[\w$])',
  );

  /// `import 'package:clock/…'`, and its `as` prefix when it has one.
  static final _clockImport = RegExp(
    r'''^\s*import\s+['"]package:clock/[^'"]*['"]\s*(?:as\s+(\w+))?''',
    multiLine: true,
  );

  /// `clock.now` reached through [prefix] (`c.clock.now`), or unprefixed.
  static RegExp _clockNow(String? prefix) => RegExp(
    '(?<![\\w\$.])${prefix == null ? '' : '${RegExp.escape(prefix)}\\s*\\.\\s*'}'
    'clock\\s*\\.\\s*now\\b',
  );

  /// What reads the system clock in [content], as `(line, spelling)`.
  static List<(int, String)> readsIn(String content) {
    final code = withoutCommentsAndStrings(content);
    final matches = [
      ..._systemNow.allMatches(code),
      for (final import in _clockImport.allMatches(content))
        ..._clockNow(import.group(1)).allMatches(code),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return [
      for (final match in matches)
        (
          '\n'.allMatches(code.substring(0, match.start)).length + 1,
          match.group(0)!.replaceAll(RegExp(r'\s'), ''),
        ),
    ];
  }

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (!_enabled || server == null) return 0;
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
      for (final (line, spelling) in readsIn(file.readAsStringSync())) {
        _findings.add(
          '`$spelling` — ${p.relative(file.path, from: server.parent.path)}'
          ':$line; read `ctx.now`, the server\'s clock',
        );
      }
    }
    if (_findings.isEmpty) return 0;
    print('\n📌 Server clock:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.forbiddenDateTimeNow.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.forbiddenDateTimeNow, _findings.length);
    return DwCheckType.forbiddenDateTimeNow.severity == DwCheckSeverity.error
        ? _findings.length
        : 0;
  }

  /// [content] with comments removed and string contents blanked, newlines
  /// kept, so a match is reported on its own line.
  static String withoutCommentsAndStrings(String content) {
    final out = StringBuffer();
    var i = 0;
    void keepNewlines(int from, int to) {
      out.write('\n' * '\n'.allMatches(content.substring(from, to)).length);
    }

    while (i < content.length) {
      if (content.startsWith('//', i)) {
        final end = content.indexOf('\n', i);
        i = end < 0 ? content.length : end;
        continue;
      }
      if (content.startsWith('/*', i)) {
        final close = content.indexOf('*/', i + 2);
        final end = close < 0 ? content.length : close + 2;
        keepNewlines(i, end);
        i = end;
        continue;
      }
      final char = content[i];
      if (char == "'" || char == '"') {
        final raw = i > 0 && content[i - 1] == 'r';
        final delimiter = content.startsWith(char * 3, i) ? char * 3 : char;
        var j = i + delimiter.length;
        // An interpolation is code: `'${DateTime.now()}'` reads the clock.
        final interpolated = StringBuffer();
        while (j < content.length && !content.startsWith(delimiter, j)) {
          if (!raw && content.startsWith(r'${', j)) {
            var depth = 0;
            var k = j + 1;
            for (; k < content.length; k++) {
              if (content[k] == '{') depth++;
              if (content[k] == '}' && --depth == 0) break;
            }
            interpolated.write(' ${content.substring(j + 2, k)} ');
            j = k + 1;
            continue;
          }
          j += !raw && content[j] == r'\' ? 2 : 1;
        }
        final end = j + delimiter.length > content.length
            ? content.length
            : j + delimiter.length;
        // Newlines inside the interpolations are kept by the text itself.
        final code = interpolated.toString();
        out.write('""$code');
        final skipped =
            '\n'.allMatches(content.substring(i, end)).length -
            '\n'.allMatches(code).length;
        out.write('\n' * (skipped < 0 ? 0 : skipped));
        i = end;
        continue;
      }
      out.write(char);
      i++;
    }
    return out.toString();
  }
}
