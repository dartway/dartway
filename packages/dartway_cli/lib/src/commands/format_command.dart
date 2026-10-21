import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../checker/dw_shared_layout.dart'
    show dwHasGeneratedHeader, dwIsGeneratedName;
import '../pinned_dart.dart';
import '../project_layout.dart';
import '../project_refresh.dart';
import '../toolkit_manifest.dart';

/// `dartway format`: `dart format` on the Dart the project pins, over the
/// Dart files the branch changed.
///
/// Two Darts format the same file differently, and a `dart format` over a
/// whole package with whichever `dart` the PATH offers rewrote files the task
/// never touched; CI, on the pinned SDK, then disagreed with both. So the
/// formatter is the pinned Flutter's (`.fvmrc`), and by default it sees only
/// the files changed against the base branch, the untracked ones included.
/// Generated files are the generator's to shape, and a migration is sealed
/// by its checksum — reformatting one stops the server — so neither is ever
/// handed to the formatter.
class FormatCommand extends Command<int> {
  /// [directory] is where the project is looked for, and [environment] the
  /// one the pinned SDK is looked up in; tests name theirs.
  FormatCommand({String? directory, Map<String, String>? environment})
    : _directory = directory,
      _environment = environment {
    argParser
      ..addFlag(
        'all',
        negatable: false,
        help: 'Every Dart file of the project, not only the changed ones.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help:
            'Write nothing; list the files that are not formatted and fail '
            'when there is one. For CI.',
      )
      ..addOption(
        'base',
        help:
            'The Git ref to compare against (the merge base with it). '
            'Default: origin/<the base branch the toolkit records>, or master.',
      );
  }

  final String? _directory;
  final Map<String, String>? _environment;

  @override
  String get name => 'format';

  @override
  String get description =>
      'Format the Dart files changed against the base branch with the Dart '
      'the project pins (.fvmrc); generated files and migrations are left '
      'alone.';

  @override
  String get invocation => 'dartway format [--all] [--check] [--base <ref>]';

  /// The most characters one `dart format` command line may take: Windows
  /// refuses one past 8191, and the other systems allow more.
  static const _commandLineLimit = 8000;

  /// [files] cut into the runs one `dart format` is given each, so that the
  /// command line of every run — [fixed] characters of executable and options
  /// plus a quoted path and a space apiece — stays under the limit. A path
  /// too long to share a line goes alone.
  static List<List<String>> batches(List<String> files, {int fixed = 0}) {
    final result = <List<String>>[];
    var batch = <String>[];
    var length = fixed;
    for (final file in files) {
      final cost = file.length + 3;
      if (batch.isNotEmpty && length + cost > _commandLineLimit) {
        result.add(batch);
        batch = <String>[];
        length = fixed;
      }
      batch.add(file);
      length += cost;
    }
    if (batch.isNotEmpty) result.add(batch);
    return result;
  }

  @override
  Future<int> run() async {
    if (argResults!.rest.isNotEmpty) {
      usageException('Unexpected arguments: ${argResults!.rest.join(' ')}.');
    }
    final directory = _directory ?? Directory.current.path;
    final root = findPackageProjectRoot(Directory(directory));
    if (root == null) {
      throw StateError('No DartWay project at or above $directory.');
    }
    final layout = ProjectLayout.detect(root);
    final dart = DwPinnedDart.resolve([
      layout.flutterPackageDir,
      root,
    ], environment: _environment);

    final top = (await _git(root.path, [
      'rev-parse',
      '--show-toplevel',
    ])).trim();
    final within = p.relative(root.path, from: top);
    final scope = ['--', if (within != '.') within];

    final List<String> candidates;
    final String what;
    if (argResults!.flag('all')) {
      candidates = _paths(
        await _git(top, [
          'ls-files',
          '-z',
          '--cached',
          '--others',
          '--exclude-standard',
          ...scope,
        ]),
      );
      what = 'the project';
    } else {
      final base = argResults!.option('base') ?? _defaultBase(root, top);
      final String mergeBase;
      try {
        mergeBase = (await _git(top, ['merge-base', 'HEAD', base])).trim();
      } on StateError {
        throw StateError(
          'No merge base with $base: fetch it, name another with --base, or '
          'format the whole project with --all.',
        );
      }
      candidates = {
        ..._paths(
          await _git(top, [
            'diff',
            '-z',
            '--name-only',
            '--diff-filter=d',
            mergeBase,
            ...scope,
          ]),
        ),
        ..._paths(
          await _git(top, [
            'ls-files',
            '-z',
            '--others',
            '--exclude-standard',
            ...scope,
          ]),
        ),
      }.toList();
      what = 'the files changed against $base';
    }

    final generated = localizationOutputs(root.path, top);
    final files = [
      for (final path in candidates..sort())
        if (_formattable(top, path, generated)) path,
    ];
    final check = argResults!.flag('check');
    stdout.writeln(
      '${check ? 'Checking' : 'Formatting'} ${files.length} Dart '
      'file${files.length == 1 ? '' : 's'} of $what with ${dart.describe()}.',
    );
    if (files.isEmpty) return 0;

    final unformatted = <String>[];
    final options = [
      'format',
      if (check) ...['--output=none', '--set-exit-if-changed'],
    ];
    final fixed = dart.executable.length + 3 + options.join(' ').length + 1;
    for (final batch in batches(files, fixed: fixed)) {
      final ProcessResult result;
      try {
        // Not through a shell: the executable is resolved, and a shell would
        // read the metacharacters of a path.
        result = await Process.run(dart.executable, [
          ...options,
          ...batch,
        ], workingDirectory: top);
      } on ProcessException catch (error) {
        throw StateError(
          'Could not start ${dart.executable}: ${error.message}.',
        );
      }
      final output = result.stdout as String;
      if (check) {
        unformatted.addAll([
          for (final line in output.split('\n'))
            if (line.startsWith('Changed ')) line.substring('Changed '.length),
        ]);
        if (result.exitCode != 0 && result.exitCode != 1) {
          stderr.write('$output${result.stderr}');
          return result.exitCode;
        }
      } else {
        stdout.write(output);
        stderr.write(result.stderr);
        if (result.exitCode != 0) return result.exitCode;
      }
    }
    if (unformatted.isEmpty) return 0;
    stderr
      ..writeln('Not formatted:')
      ..writeln(unformatted.map((path) => '  $path').join('\n'))
      ..writeln(
        'Run `dartway format${argResults!.flag('all') ? ' --all' : ''}`.',
      );
    return 1;
  }

  /// `origin/<base branch>` when the remote has it, the local branch
  /// otherwise.
  static String _defaultBase(Directory root, String top) {
    final branch =
        ToolkitProvenance.read(
          root,
        )?.setting(ToolkitProvenance.baseBranchSetting) ??
        ToolkitProvenance.read(
          Directory(top),
        )?.setting(ToolkitProvenance.baseBranchSetting) ??
        'master';
    final remote = Process.runSync('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      'origin/$branch^{commit}',
    ], workingDirectory: top);
    return remote.exitCode == 0 ? 'origin/$branch' : branch;
  }

  /// Whether [path] is a Dart file still there that is neither generated
  /// nor a migration.
  static bool _formattable(String top, String path, List<String> outputs) {
    if (!path.endsWith('.dart')) return false;
    final file = File(p.join(top, path));
    if (!file.existsSync()) return false;
    final source = file.readAsStringSync();
    return !_isGenerated(path, source, outputs) && !_isMigration(source);
  }

  /// A generated file: by its name (`*.dw.dart`, `*.g.dart`), its folder
  /// (`lib/generated/`), a localization output, or the header a generator
  /// writes.
  static bool _isGenerated(String path, String source, List<String> outputs) =>
      dwIsGeneratedName(path) ||
      p.posix.split(path).contains('generated') ||
      outputs.any(path.startsWith) ||
      dwHasGeneratedHeader(source);

  /// A migration: a file declaring a `DwDatabaseMigration`, sealed by the
  /// checksum of its source. The registry beside them is an ordinary file.
  static bool _isMigration(String source) =>
      RegExp(r'\bextends\s+DwDatabaseMigration\b').hasMatch(source);

  static List<String> _paths(String output) =>
      output.split('\x00').where((path) => path.isNotEmpty).toList();
}

Future<String> _git(String directory, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: directory);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed in $directory: '
      '${(result.stderr as String).trim()}',
    );
  }
  return result.stdout as String;
}
