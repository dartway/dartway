import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_tally.dart';
import 'dw_check_type.dart';
import 'dw_dart_outline.dart';
import 'dw_flutter_inspector.dart';

/// Whether [source] is seed data: a file of top-level constants and nothing
/// else, building row drafts (`New<Entity>Row(…)`) — the rows a `DwSeedRows`
/// step writes, kept in a `<feature>_<part>_rows.dart` of their own when they
/// outgrow the row class's file.
///
/// Recognised by what it declares rather than by a name or a marker, so the
/// exemption cannot be claimed by a file that also holds logic: a class, a
/// function, a closure or a `final` beside the rows (a handler list is one)
/// and it is measured like any other file. Seed rows are constants anyway —
/// a value computed at start rewrites the row at every start.
bool dwIsSeedDataFile(String source) {
  final outline = DwDartOutline(source);
  final code = outline.code;
  if (!RegExp(r'\bNew[A-Z]\w*Row\s*\(').hasMatch(code)) return false;
  if (outline.functions.isNotEmpty) return false;
  if (RegExp(r'\b(?:class|mixin|enum|extension|typedef)\b').hasMatch(code)) {
    return false;
  }
  // A closure: an arrow, or a parameter list followed by a body.
  if (code.contains('=>') || RegExp(r'\)\s*(?:async\s*)?\{').hasMatch(code)) {
    return false;
  }
  // A top-level line of formatted code starts a declaration or closes one.
  final topLevel = RegExp(
    r'^(?:import|export|part|library|const)\b|^[\]\)\};]',
  );
  for (final line in code.split('\n')) {
    if (line.trim().isEmpty || line.startsWith(' ')) continue;
    if (!topLevel.hasMatch(line)) return false;
  }
  return true;
}

/// File size in the server and the shared package ([DwCheckType.fileLong],
/// [DwCheckType.fileTooLong]; dartway/dartway#383): the thresholds and
/// severities of the Flutter package's zones, over every file of `lib/`.
///
/// Passed over: generated code (`lib/generated/`, `*.dw.dart`), the server's
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
      if (segments.first == 'generated') continue;
      if (rel.endsWith('.dw.dart') ||
          rel.endsWith('.g.dart') ||
          rel.endsWith('.freezed.dart')) {
        continue;
      }
      if (server && rel.startsWith('src/migrations/')) continue;
      final source = file.readAsStringSync();
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
