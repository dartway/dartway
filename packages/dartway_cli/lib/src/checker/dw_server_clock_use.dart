import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';

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
    final code = DwDartSource(content, interpolationsAsCode: true).code;
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
}
