import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';

/// A read in a request handler that can return any number of rows
/// ([DwCheckType.unboundedRead], dartway/dartway#644).
///
/// In a server file named `*_handlers.dart`, a repository `find(…)` inside a
/// request handler — `DwCallHandler.single`, `maybe`, `list`, `page`,
/// `table` or `window` — that names neither `limit:` nor `unbounded:` reads
/// every row its filter matches: a list that was small in development and is
/// megabytes a year later. `findById`, `findFirst` and `findByIds` are bounded
/// by what they are asked for and are not reads it looks at; neither are
/// commands, jobs and migrations, whose reads answer nobody's screen.
///
/// A heuristic, so a warning: it reads the handler's own body, not the helpers
/// it calls, and cannot tell a filter on a unique key from any other.
/// Comments and strings are not code.
class DwUnboundedReadInspector {
  DwUnboundedReadInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null || filterType == DwCheckType.unboundedRead) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.unboundedRead.severity);

  final Directory? serverPackageDir;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    final server = serverPackageDir;
    if (!_enabled || server == null) return 0;
    final lib = Directory(p.join(server.path, 'lib'));
    if (!lib.existsSync()) return 0;
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_handlers.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final shown = p.relative(file.path, from: server.parent.path);
      for (final read in unboundedReadsIn(file.readAsStringSync())) {
        _findings.add(
          'a ${read.kind} handler reads rows without a bound — '
          '$shown:${read.line}; make the request a page, table or window, '
          'bound the read with `limit:` (`request.fetchLimit` for a list), or '
          "say why it stays small with `unbounded: '<reason>'`",
        );
      }
    }
    if (_findings.isEmpty) return 0;
    print('\n📏 Bounded reads:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.unboundedRead.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.unboundedRead, _findings.length);
    return 0;
  }

  static final _handlerStart = RegExp(
    r'\bDwCallHandler\s*\.\s*(single|maybe|list|page|table|window)\b',
  );
  static final _find = RegExp(r'\.\s*find\s*\(');
  static final _bound = RegExp(r'\b(limit|unbounded)\s*:');

  /// The reads of one handlers file that name no bound: the line of each,
  /// and the kind of the request handler it sits in.
  static List<({int line, String kind})> unboundedReadsIn(String content) {
    final code = DwDartSource(content).code;
    final reads = <({int line, String kind})>[];
    for (final handler in _handlerStart.allMatches(code)) {
      final open = code.indexOf('(', handler.end);
      if (open < 0) continue;
      // Type arguments may sit between the factory and its parenthesis.
      final between = code.substring(handler.end, open).trim();
      if (between.isNotEmpty && !between.startsWith('<')) continue;
      final close = _matching(code, open);
      if (close < 0) continue;
      for (final find in _find.allMatches(code.substring(open, close))) {
        final start = open + find.end - 1;
        final end = _matching(code, start);
        if (end < 0) continue;
        final arguments = code.substring(start, end);
        final bounded = _bound
            .allMatches(arguments)
            .any((m) => _depthAt(arguments, m.start) == 1);
        if (!bounded) {
          reads.add((line: _lineOf(code, start), kind: handler.group(1)!));
        }
      }
    }
    return reads;
  }

  static int _matching(String code, int open) {
    var depth = 0;
    for (var i = open; i < code.length; i++) {
      if (code[i] == '(') depth++;
      if (code[i] == ')' && --depth == 0) return i;
    }
    return -1;
  }

  /// How many brackets are open at [offset] of [text].
  static int _depthAt(String text, int offset) {
    var depth = 0;
    for (var i = 0; i < offset; i++) {
      if ('([{'.contains(text[i])) depth++;
      if (')]}'.contains(text[i])) depth--;
    }
    return depth;
  }

  static int _lineOf(String code, int offset) =>
      '\n'.allMatches(code.substring(0, offset)).length + 1;
}
