import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_source.dart';
import 'dw_flutter_inspector.dart';
import 'dw_shared_layout.dart';

/// Whether [source] is seed data: directives and top-level constants, each
/// initialised with a row draft (`New<Entity>Row(…)`) or a collection of
/// nothing but drafts — the rows a `DwSeedRows` step writes, kept in a
/// `<feature>_<part>_rows.dart` of their own when they outgrow the row
/// class's file.
///
/// Recognised by what it declares rather than by a name or a marker, so the
/// exemption cannot be claimed by a file that also holds anything else: a
/// class, a function, a `final`, a constant of another value, a helper call
/// among the rows — and it is measured like any other file. Seed rows are
/// constants anyway: a value computed at start rewrites the row at every
/// start.
bool dwIsSeedDataFile(String source) {
  final code = DwDartSource(
    source,
  ).code.replaceAll(RegExp(r'\b(?:library|import|export|part)\b[^;]*;'), '');
  var drafts = 0;
  var i = 0;
  while (code.substring(i).trim().isNotEmpty) {
    final declaration = RegExp(
      r'\s*const\s+(?:[\w<>?,\s]+?\s+)?[A-Za-z_$][\w$]*\s*=',
    ).matchAsPrefix(code, i);
    if (declaration == null) return false;
    final end = _topLevelEnd(code, declaration.end);
    if (end < 0) return false;
    final count = _draftsIn(code.substring(declaration.end, end).trim());
    if (count == null) return false;
    drafts += count;
    i = end + 1;
  }
  return drafts > 0;
}

/// The `;` closing the declaration whose initializer starts at [from], or -1.
int _topLevelEnd(String code, int from) {
  var depth = 0;
  for (var i = from; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ';' && depth == 0) return i;
  }
  return -1;
}

/// How many drafts [expression] is — one draft, or a list, set or map
/// literal of drafts only — or null when it is anything else.
int? _draftsIn(String expression) {
  final draft = RegExp(r'^New[A-Z]\w*Row\s*(?:\.\s*\w+\s*)?\(');
  if (draft.hasMatch(expression)) {
    final open = expression.indexOf('(');
    return _closing(expression, open) == expression.length - 1 ? 1 : null;
  }
  final collection = RegExp(
    r'^(?:const\s+)?(?:<[^\[\{]*>\s*)?([\[\{])',
  ).firstMatch(expression);
  if (collection == null) return null;
  final open = collection.end - 1;
  if (_closing(expression, open) != expression.length - 1) return null;
  final body = expression.substring(open + 1, expression.length - 1);
  var count = 0;
  for (final element in _splitTopLevel(body)) {
    final trimmed = element.trim();
    if (trimmed.isEmpty) continue;
    if (_draftsIn(trimmed) != 1) return null;
    count++;
  }
  return count;
}

int _closing(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final c = text[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

List<String> _splitTopLevel(String body) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ',' && depth == 0) {
      parts.add(body.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(body.substring(start));
  return parts;
}

/// File size in the server and the shared package ([DwCheckType.fileLong],
/// [DwCheckType.fileTooLong]; dartway/dartway#383): the thresholds and
/// severities of the Flutter package's zones, over every file of `lib/`.
///
/// Passed over: generated code (`lib/generated/`, `*.dw.dart`, `*.g.dart`,
/// `*.freezed.dart`, each with its generated header), the server's
/// migrations (`lib/src/migrations/`, drafted by `migrate.dart` and sealed
/// after), and seed data ([dwIsSeedDataFile]) — none of them collects
/// responsibilities, and a split would only scatter a table of rows or a
/// generated registry. Tests are not measured, as in the Flutter package: a
/// test file is a list of independent cases, and one that grows too long
/// splits by scenario (`<folder>_<scenario>_acceptance_test.dart`).
///
/// Until this ran, the server and the shared package had no limit at all,
/// and each project's largest files were there: an MCP tool catalogue of
/// 2861 lines, handler files of 1100–1900, a shared file of 76 types.
class DwPackageFileSizeInspector {
  DwPackageFileSizeInspector({
    this.serverPackageDir,
    this.sharedPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _longEnabled = _enabled(
         DwCheckType.fileLong,
         filterType,
         filterSeverity,
       ),
       _tooLongEnabled = _enabled(
         DwCheckType.fileTooLong,
         filterType,
         filterSeverity,
       );

  final Directory? serverPackageDir;
  final Directory? sharedPackageDir;

  final bool _longEnabled;
  final bool _tooLongEnabled;
  final _long = <String>[];
  final _tooLong = <String>[];

  static bool _enabled(
    DwCheckType type,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  ) =>
      (filterType == null || filterType == type) &&
      (filterSeverity == null || filterSeverity == type.severity);

  /// [DwCheckType.fileLong]'s findings.
  List<String> get longFindings => List.unmodifiable(_long);

  /// [DwCheckType.fileTooLong]'s findings.
  List<String> get tooLongFindings => List.unmodifiable(_tooLong);

  /// Prints the section and returns the number of error findings — none:
  /// length is advice here as it is in the Flutter package.
  int run({DwCheckTally? tally}) {
    if (!_longEnabled && !_tooLongEnabled) return 0;
    _checkPackage(serverPackageDir, server: true);
    _checkPackage(sharedPackageDir, server: false);

    if (_long.isEmpty && _tooLong.isEmpty) return 0;
    print('\n📏 Server and shared file size:\n');
    for (final finding in _tooLong) {
      print('  ${DwCheckType.fileTooLong.reportLabel}: $finding');
    }
    for (final finding in _long) {
      print('  ${DwCheckType.fileLong.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.fileTooLong, _tooLong.length);
    tally?.add(DwCheckType.fileLong, _long.length);
    int errors(DwCheckType type, List<String> findings) =>
        type.severity == DwCheckSeverity.error ? findings.length : 0;
    return errors(DwCheckType.fileTooLong, _tooLong) +
        errors(DwCheckType.fileLong, _long);
  }

  void _checkPackage(Directory? package, {required bool server}) {
    if (package == null) return;
    final lib = Directory(p.join(package.path, 'lib'));
    if (!lib.existsSync()) return;
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final rel = p.relative(file.path, from: lib.path).replaceAll(r'\', '/');
      final segments = rel.split('/');
      if (segments.any((s) => s.startsWith('.'))) continue;
      final source = file.readAsStringSync();
      // Generated by name and by header, as the shared layout reads it: a
      // hand-written file under a generated name is measured.
      if ((segments.first == 'generated' || dwIsGeneratedName(rel)) &&
          dwHasGeneratedHeader(source)) {
        continue;
      }
      if (server && rel.startsWith('src/migrations/')) continue;
      // Counted as the Flutter package counts, so one file reads the same
      // number wherever it sits.
      final lines = source.split('\n').length;
      if (lines <= dwFileLongThreshold) continue;
      if (server && dwIsSeedDataFile(source)) continue;
      final label = '${p.basename(package.path)}/lib/$rel';
      final split = server
          ? 'split a kind into <feature>_<part>_<kind>.dart files'
          : 'split it into src/<feature>/<feature>_<part>.dart files';
      if (lines > dwFileTooLongThreshold) {
        if (_tooLongEnabled) {
          _tooLong.add(
            '$label is $lines lines (>$dwFileTooLongThreshold) — worth '
            'restructuring: $split',
          );
        }
      } else if (_longEnabled) {
        _long.add(
          '$label is $lines lines (>$dwFileLongThreshold) — undesirable, '
          'not critical',
        );
      }
    }
  }
}
