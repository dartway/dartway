import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';
import 'dw_check_tally.dart';

/// How a check runs a Dart command in a package: `dart <arguments>` in
/// [workingDirectory]. Injected so the tests can drive the reporting without
/// an SDK, a resolved project or a database in the loop — what is worth
/// asserting is what a finding *says*.
///
/// Returns `null` when the command could not be started at all.
typedef DwDartProbe =
    ProcessResult? Function(List<String> arguments, String workingDirectory);

ProcessResult? _runDart(List<String> arguments, String workingDirectory) {
  final running = p.basenameWithoutExtension(Platform.resolvedExecutable);
  final dart = running == 'dart' ? Platform.resolvedExecutable : 'dart';
  try {
    return Process.runSync(dart, arguments, workingDirectory: workingDirectory);
  } on ProcessException {
    return null;
  }
}

bool _enabledFor(
  DwCheckType type,
  DwCheckType? filterType,
  DwCheckSeverity? filterSeverity,
) =>
    (filterType == null || filterType == type) &&
    (filterSeverity == null || filterSeverity == type.severity);

/// `dartway_generator --check` over the project: the generated codecs,
/// registry, tables and schema match the sources they are generated from
/// ([DwCheckType.generatedCodeStale]).
///
/// Runs the generator the server package resolved — the one matching the
/// framework the project builds against — and says nothing but a note when
/// the package is not resolved yet: an unresolved package is not stale code,
/// and a finding invented from a probe that could not run is how a check
/// earns its reputation for lying.
class DwGeneratedCodeInspector {
  DwGeneratedCodeInspector({
    required this.serverPackageDir,
    DwDartProbe? probe,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _probe = probe ?? _runDart,
       _enabled = _enabledFor(
         DwCheckType.generatedCodeStale,
         filterType,
         filterSeverity,
       );

  final Directory? serverPackageDir;

  final DwDartProbe _probe;
  final bool _enabled;
  final _findings = <String>[];
  final _notes = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  /// Why the check did not judge, when it did not.
  List<String> get notes => List.unmodifiable(_notes);

  /// Runs the check and prints the section. Returns the number of
  /// error-severity findings.
  int run({DwCheckTally? tally}) {
    final serverDir = serverPackageDir;
    if (!_enabled || serverDir == null || !serverDir.existsSync()) return 0;

    final result = _probe([
      'run',
      'dartway_generator',
      '--project',
      serverDir.parent.path,
      '--check',
    ], serverDir.path);
    final output = [
      ...LineSplitter.split('${result?.stdout ?? ''}'),
      ...LineSplitter.split('${result?.stderr ?? ''}'),
    ];

    switch (result?.exitCode) {
      case 0:
        break;
      case 1
          when output.any(
            (line) =>
                line.trimLeft().startsWith('out of date ') ||
                line.trimLeft().startsWith('stale '),
          ):
        _findings.addAll([
          for (final line in output)
            if (line.trimLeft().startsWith('out of date ') ||
                line.trimLeft().startsWith('stale '))
              line.trim(),
        ]);
      case null:
        _notes.add('`dart` could not be started');
      default:
        // A generation error (a declaration the generator refuses) or an
        // unresolved package: the generator's own words say which.
        _notes.addAll(output.where((line) => line.trim().isNotEmpty).take(5));
    }

    if (_findings.isEmpty && _notes.isEmpty) return 0;
    print('\n🧬 Generated code:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.generatedCodeStale.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.generatedCodeStale, _findings.length);
    if (_findings.isNotEmpty) {
      print(
        '\n  Fix — in the Flutter package of ${serverDir.parent.path}:\n'
        '    dart run dartway_cli:dartway generate\n'
        '  and commit what it writes. Generated files are never edited by '
        'hand.',
      );
    }
    if (_notes.isNotEmpty) {
      print('  Not checked — the generator did not run to a verdict:');
      for (final note in _notes) {
        print('    $note');
      }
    }
    return DwCheckType.generatedCodeStale.severity == DwCheckSeverity.error
        ? _findings.length
        : 0;
  }
}

/// `bin/migrate.dart check` in the server package: the migrations are sealed
/// and registered, replay into the schema the row classes declare, and go down
/// and up again cleanly ([DwCheckType.migrationsDrift]).
///
/// The replay needs a Postgres where throwaway databases can be created,
/// named by `DW_DATABASE_*` in [environment]. Without one the check prints
/// that it did not run — never that the migrations are fine.
class DwMigrationsInspector {
  DwMigrationsInspector({
    required this.serverPackageDir,
    Map<String, String>? environment,
    DwDartProbe? probe,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _environment = environment ?? Platform.environment,
       _probe = probe ?? _runDart,
       _enabled = _enabledFor(
         DwCheckType.migrationsDrift,
         filterType,
         filterSeverity,
       );

  /// The project's migration entry point, relative to the server package.
  static const migrateScript = 'bin/migrate.dart';

  /// `DwMigrationCli.exitCheckFailed`: the check ran and found a difference.
  static const _exitCheckFailed = 3;

  final Directory? serverPackageDir;

  final Map<String, String> _environment;
  final DwDartProbe _probe;
  final bool _enabled;
  final _findings = <String>[];
  final _notes = <String>[];

  List<String> get findings => List.unmodifiable(_findings);
  List<String> get notes => List.unmodifiable(_notes);

  int run({DwCheckTally? tally}) {
    final serverDir = serverPackageDir;
    if (!_enabled || serverDir == null) return 0;
    if (!File(p.join(serverDir.path, migrateScript)).existsSync()) return 0;

    if ((_environment['DW_DATABASE_HOST'] ?? '').isEmpty) {
      _notes.add(
        'no database to replay the migrations on: point DW_DATABASE_* — or '
        'deploy/config.yaml > local, which the entry points read — at a '
        'Postgres where throwaway databases can be created (the development '
        'one will do)',
      );
    } else {
      final result = _probe(['run', migrateScript, 'check'], serverDir.path);
      final output = LineSplitter.split(
        '${result?.stdout ?? ''}',
      ).where((line) => line.trim().isNotEmpty).toList();
      switch (result?.exitCode) {
        case 0:
          break;
        case _exitCheckFailed:
          // `FAIL <what>` lines, each followed by its indented details.
          for (final line in output) {
            if (line.startsWith('FAIL ')) {
              _findings.add(line.substring('FAIL '.length));
            } else if (line.startsWith('       ') && _findings.isNotEmpty) {
              _findings.add('${_findings.removeLast()}\n      ${line.trim()}');
            }
          }
          if (_findings.isEmpty) _findings.add(output.join('\n      '));
        case null:
          _notes.add('`dart` could not be started');
        default:
          _notes.addAll([
            ...output.take(3),
            ...LineSplitter.split(
              '${result?.stderr ?? ''}',
            ).where((line) => line.trim().isNotEmpty).take(3),
          ]);
      }
    }

    if (_findings.isEmpty && _notes.isEmpty) return 0;
    print('\n🗄️  Migrations:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.migrationsDrift.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.migrationsDrift, _findings.length);
    if (_findings.isNotEmpty) {
      print(
        '\n  A schema change the migrations miss: '
        '`dart run $migrateScript create <name>` in ${serverDir.path}.\n'
        '  An edited migration that is applied nowhere yet: '
        '`dart run $migrateScript rehash <id>`.',
      );
    }
    if (_notes.isNotEmpty) {
      print('  Not checked:');
      for (final note in _notes) {
        print('    $note');
      }
    }
    return DwCheckType.migrationsDrift.severity == DwCheckSeverity.error
        ? _findings.length
        : 0;
  }
}
