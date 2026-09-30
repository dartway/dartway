import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dw_check_tally.dart';
import 'dw_check_type.dart';

/// Reports a server or shared package whose `analysis_options.yaml` does not
/// raise `unnecessary_non_null_assertion` to an error (D-113).
///
/// A stored row's id is `int`, so `row.id!` says nothing — and a `!` that says
/// nothing hides the one that guards a real null. The analyzer finds every
/// such `!` on its own; what the checker holds is that the project asked it to
/// fail on one, rather than print a warning a `--no-fatal-warnings` run and
/// every editor let through.
///
/// Read from the package's own file and the local files it `include:`s, the
/// nearest setting winning, as the analyzer reads them. An include of a
/// package (`package:lints/…`) is not followed: none of ours sets it.
class DwAnalysisOptionsInspector {
  DwAnalysisOptionsInspector({
    required this.packageDirs,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null || filterType == _type) &&
           (filterSeverity == null || filterSeverity == _type.severity);

  static const _type = DwCheckType.redundantBangAllowed;

  /// The diagnostic every server and shared package raises.
  static const diagnostic = 'unnecessary_non_null_assertion';

  /// The server and the shared package; a `null` (not found) is skipped.
  final List<Directory?> packageDirs;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    if (!_enabled) return 0;
    for (final dir in packageDirs) {
      if (dir != null && dir.existsSync()) _inspect(dir);
    }
    if (_findings.isEmpty) return 0;
    print('\n🔎 Analysis options:\n');
    for (final finding in _findings) {
      print('  ${_type.reportLabel}: $finding');
    }
    tally?.add(_type, _findings.length);
    return _type.severity == DwCheckSeverity.error ? _findings.length : 0;
  }

  void _inspect(Directory packageDir) {
    final name = p.basename(packageDir.path);
    final file = File(p.join(packageDir.path, 'analysis_options.yaml'));
    final level = file.existsSync() ? _levelIn(file, <String>{}) : null;
    if (level == 'error') return;
    _findings.add(
      '$name/analysis_options.yaml ${level == null ? 'does not set' : 'sets `$level` for'} '
      '`$diagnostic`: add `analyzer: errors: $diagnostic: error`. A stored '
      "row's id is `int`, and a `!` on it hides the one that guards a real null",
    );
  }

  /// The level [file] gives the diagnostic, or `null` when neither it nor a
  /// local file it includes sets one.
  static String? _levelIn(File file, Set<String> seen) {
    if (!seen.add(file.absolute.path)) return null;
    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException {
      return null;
    }
    if (document is! YamlMap) return null;
    final analyzer = document['analyzer'];
    final errors = analyzer is YamlMap ? analyzer['errors'] : null;
    final own = errors is YamlMap ? errors[diagnostic] : null;
    if (own is String) return own;
    final include = document['include'];
    final includes = include is String
        ? [include]
        : include is YamlList
        ? [for (final entry in include) '$entry']
        : const <String>[];
    // A later include overrides an earlier one.
    for (final path in includes.reversed) {
      if (path.startsWith('package:')) continue;
      final included = File(p.join(file.parent.path, path));
      if (!included.existsSync()) continue;
      if (_levelIn(included, seen) case final level?) return level;
    }
    return null;
  }
}
