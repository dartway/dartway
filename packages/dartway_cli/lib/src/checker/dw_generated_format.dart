import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';

/// How the check reaches `dart format`. Injected so the tests can drive the
/// reporting without an SDK in the loop: what is worth asserting here is what
/// the finding *says* — a finding nobody can act on is the failure mode this
/// rule is most exposed to.
///
/// Returns `null` when the formatter could not be run at all.
typedef DwFormatProbe = ProcessResult? Function(List<String> arguments);

/// Verifies that the Serverpod-generated code is committed formatted — in
/// **both** packages.
///
/// The generator writes through the `dart_style` bundled with the Serverpod
/// CLI, while the code already in the repository was formatted by the project's
/// SDK. Nothing reconciles the two, so the difference surfaces as a generation
/// run that rewrites files the change never went near; the framework's answer
/// is a `dart format` pass as the last step of `generate` → `create-migration`
/// → `format` (`create-migration` regenerates, so an earlier pass is undone).
///
/// This rule is what keeps that step from being optional. It is a warning, not
/// an error — see [DwCheckType.generatedCodeUnformatted] for why, and why the
/// message has to carry the command rather than the diagnosis.
class DwGeneratedFormatInspector {
  DwGeneratedFormatInspector({
    this.serverPackageDir,
    this.clientPackageDir,
    DwFormatProbe? probe,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _probe = probe ?? _runDartFormat,
       _enabled =
           (filterType == null ||
               filterType == DwCheckType.generatedCodeUnformatted) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.generatedCodeUnformatted.severity);

  /// Where `serverpod generate` writes the server half.
  static const serverGeneratedPath = 'lib/src/generated';

  /// …and the client half. One command writes both; one rule holds both.
  static const clientGeneratedPath = 'lib/src/protocol';

  final Directory? serverPackageDir;
  final Directory? clientPackageDir;

  final DwFormatProbe _probe;
  final bool _enabled;
  final _findings = <String>[];

  /// The findings, in the order they were made. Exposed for the tests, like
  /// the layout rule's: the report is printed, the wording is the contract.
  List<String> get findings => List.unmodifiable(_findings);

  /// The command that fixes every finding, or null when there is nothing to
  /// fix. Kept separate from the findings because it names *all* the paths,
  /// including the ones that came back clean — formatting half of the
  /// generated code is the state this rule exists to prevent.
  String? get fixCommand {
    if (_findings.isEmpty) return null;
    final paths = _targets.map((t) => t.display).toList();
    return 'dart format ${paths.join(' ')}';
  }

  /// Runs the check and prints the section. Returns the number of
  /// error-severity findings — none today, and the arithmetic rather than a
  /// literal `0` so that changing the severity changes the exit code with it.
  int run() {
    if (!_enabled) return 0;

    final targets = _targets;
    if (targets.isEmpty) return 0;

    for (final target in targets) {
      final unformatted = _unformattedFilesIn(target.dir);
      if (unformatted == null || unformatted.isEmpty) continue;

      final shown = unformatted.take(3).join(', ');
      final rest = unformatted.length - 3;
      _findings.add(
        '${target.display} — ${unformatted.length} '
        '${unformatted.length == 1 ? 'file is' : 'files are'} not formatted '
        '($shown${rest > 0 ? ', +$rest more' : ''})',
      );
    }

    if (_findings.isEmpty) return 0;

    print('\n🖨️  Generated code formatting:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.generatedCodeUnformatted.reportLabel}: $finding');
    }
    print(
      '\n  Fix — from ${_projectRoot?.path ?? 'the project root'}:\n'
      '    $fixCommand\n'
      '  Both paths together: `serverpod generate` writes them as one artefact, '
      'and formatting\n'
      '  only one of them moves the diff to whoever formats the other. Run it '
      'after\n'
      '  `create-migration`, which regenerates and would undo an earlier pass.\n'
      '  Judged against the dart_style of the SDK running this check '
      '(Dart $_dartVersion) —\n'
      '  if your team is split across SDK versions, that is what this is '
      'reporting.',
    );

    return DwCheckType.generatedCodeUnformatted.severity ==
            DwCheckSeverity.error
        ? _findings.length
        : 0;
  }

  /// The generated trees that actually exist. A project with no models yet has
  /// neither, and a Flutter package checked on its own has no server beside it
  /// — in both cases the rule has nothing to say and says nothing.
  List<({Directory dir, String display})> get _targets {
    final root = _projectRoot;
    final targets = <({Directory dir, String display})>[];

    void add(Directory? packageDir, String relative) {
      if (packageDir == null) return;
      final dir = Directory(p.join(packageDir.path, relative));
      if (!dir.existsSync()) return;
      final display = root == null
          ? dir.path
          : p.relative(dir.path, from: root.path).replaceAll(r'\', '/');
      targets.add((dir: dir, display: display));
    }

    add(serverPackageDir, serverGeneratedPath);
    add(clientPackageDir, clientGeneratedPath);
    return targets;
  }

  Directory? get _projectRoot => (serverPackageDir ?? clientPackageDir)?.parent;

  /// The file names `dart format` would rewrite, or null when the formatter
  /// could not judge — it is missing from `PATH`, or it failed to parse
  /// something. Neither is this rule's business, and inventing a finding out
  /// of a failed probe is how a check earns its reputation for lying.
  List<String>? _unformattedFilesIn(Directory dir) {
    final result = _probe([
      'format',
      '--output=none',
      '--set-exit-if-changed',
      dir.path,
    ]);
    if (result == null) return null;
    if (result.exitCode == 0) return const [];
    if (result.exitCode != 1) return null;

    // `--output=none` reports one `Changed <path>` line per file, then a
    // summary. The names are what makes the finding actionable; the count
    // alone would not tell anyone whether their own change is in there.
    return LineSplitter.split('${result.stdout}')
        .where((line) => line.startsWith('Changed '))
        .map((line) => p.basename(line.substring('Changed '.length).trim()))
        .toList();
  }

  static ProcessResult? _runDartFormat(List<String> arguments) {
    try {
      return Process.runSync('dart', arguments);
    } on ProcessException {
      return null;
    }
  }

  static String get _dartVersion {
    final match = RegExp(r'^\d+\.\d+\.\d+').firstMatch(Platform.version);
    return match?.group(0) ?? Platform.version;
  }
}
