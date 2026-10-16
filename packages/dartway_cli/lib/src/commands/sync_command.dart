import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../project_refresh.dart';
import '../toolkit_manifest.dart';
import 'generate_command.dart';

/// `dartway sync [<ref>]`: merges the base branch into the current one and
/// leaves nothing derived to resolve by hand (D-158).
///
/// Derived files — generated code, locks, localizations, the migrations
/// registry — conflicted on every merge of two tasks, and resolving them took
/// a model run each time while their content was never in question: it is
/// whatever the generators make of the merged sources. So a conflict in a
/// derived file takes either side, and the generators then run over the
/// merged tree. Translations merge by key. Only a conflict in a source the
/// author wrote is left to resolve.
class SyncCommand extends Command<int> {
  /// [regenerate] remakes the derived files of a project root; tests replace
  /// the package resolution and the generators it runs by default.
  SyncCommand({Future<int> Function(String root)? regenerate})
    : _regenerate = regenerate ?? _regenerateProject {
    argParser.addFlag(
      'continue',
      negatable: false,
      help:
          'Finish a sync stopped at a conflict, once the conflicted sources are '
          'resolved and added.',
    );
  }

  final Future<int> Function(String root) _regenerate;

  static Future<int> _regenerateProject(String root) async {
    final resolved = await resolvePackages(root);
    if (resolved != 0) return resolved;
    return GenerateCommand.invoke(root, const []);
  }

  @override
  String get name => 'sync';

  @override
  String get description =>
      'Merge the base branch in, resolve the derived files by regenerating '
      'them, and commit.';

  @override
  String get invocation => 'dartway sync [<ref>] [--continue]';

  @override
  Future<int> run() async {
    final root = GenerateCommand.projectRootOf(Directory.current.path);
    if (root == null) {
      throw StateError(
        'No DartWay project at or above ${Directory.current.path}.',
      );
    }
    final top = (await _git(root, ['rev-parse', '--show-toplevel'])).trim();
    if (!argResults!.flag('continue')) {
      if ((await _git(top, [
        'status',
        '--porcelain',
        '--untracked-files=no',
      ])).trim().isNotEmpty) {
        stderr.writeln(
          'Commit or stash the changes first: sync merges into a clean tree.',
        );
        return 1;
      }
      final ref = argResults!.rest.firstOrNull ?? 'origin/${_baseBranch(root)}';
      if (ref.startsWith('origin/'))
        await _git(top, ['fetch', 'origin'], check: true);
      final merge = await Process.run('git', [
        'merge',
        '--no-ff',
        '--no-commit',
        ref,
      ], workingDirectory: top);
      stdout.write(merge.stdout);
      if (merge.exitCode != 0 && !await _merging(top)) {
        stderr.write(merge.stderr);
        return 1;
      }
    }

    final derived = _DerivedFiles(root, top);
    final conflicted = LineSplitter.split(
      await _git(top, ['diff', '--name-only', '--diff-filter=U']),
    ).toList();
    final unresolved = <String>[];
    for (final path in conflicted) {
      if (derived.isGenerated(path)) {
        await _git(top, ['checkout', '--theirs', '--', path], check: true);
      } else if (await derived.isRegistry(path)) {
        await derived.rebuildRegistry(path);
      } else if (path.endsWith('.arb')) {
        final merged = await _mergeArb(top, path);
        if (merged == null) {
          unresolved.add(path);
          continue;
        }
        File(p.join(top, path)).writeAsStringSync(merged);
      } else {
        unresolved.add(path);
        continue;
      }
      await _git(top, ['add', '--', path], check: true);
    }
    if (unresolved.isNotEmpty) {
      stderr
        ..writeln('Conflicts in sources, resolve them and `git add`:')
        ..writeln(unresolved.map((path) => '  $path').join('\n'))
        ..writeln('then run `dartway sync --continue`.');
      return 1;
    }

    final regenerated = await _regenerate(root);
    if (regenerated != 0) return regenerated;
    for (final registry in await derived.registries()) {
      await derived.rebuildRegistry(registry);
    }
    final changed = await derived.changed();
    if (changed.isNotEmpty) {
      await _git(top, ['add', '-A', '--', ...changed], check: true);
    }

    final staged = await Process.run('git', [
      'diff',
      '--cached',
      '--quiet',
    ], workingDirectory: top);
    if (await _merging(top)) {
      await _git(top, ['commit', '--no-edit'], check: true);
    } else if (staged.exitCode != 0) {
      await _git(top, [
        'commit',
        '-m',
        'chore: regenerate derived files',
      ], check: true);
    }
    stdout.writeln(
      'Synced: ${(await _git(top, ['log', '-1', '--format=%h %s'])).trim()}',
    );
    return 0;
  }

  static String _baseBranch(String root) =>
      ToolkitProvenance.read(
        Directory(root),
      )?.setting(ToolkitProvenance.baseBranchSetting) ??
      'master';
}

Future<bool> _merging(String top) async =>
    (await Process.run('git', [
      'rev-parse',
      '-q',
      '--verify',
      'MERGE_HEAD',
    ], workingDirectory: top)).exitCode ==
    0;

/// Which paths of the project are derived, and how each is remade.
class _DerivedFiles {
  _DerivedFiles(this.root, this.top);

  final String root;
  final String top;

  static const _registryHeader = '// Maintained by `migrate create`';

  /// Localization outputs: `flutter gen-l10n` writes them next to the
  /// templates unless `output-dir` says otherwise.
  late final List<String> _l10nOutputs = [
    for (final (directory, _) in projectPackages(root))
      if (File(p.join(directory.path, 'l10n.yaml')) case final file
          when file.existsSync())
        if (loadYaml(file.readAsStringSync()) case final YamlMap config)
          p.posix.join(
            p.relative(directory.path, from: top).replaceAll(r'\', '/'),
            (config['output-dir'] ?? config['arb-dir'] ?? 'lib/l10n') as String,
            p.basenameWithoutExtension(
              (config['output-localization-file'] ?? 'app_localizations.dart')
                  as String,
            ),
          ),
  ];

  bool isGenerated(String path) =>
      path.contains('/lib/generated/') ||
      path.startsWith('lib/generated/') ||
      path.endsWith('.dw.dart') ||
      p.posix.basename(path) == 'pubspec.lock' ||
      _l10nOutputs.any(
        (stem) => path.startsWith(stem) && path.endsWith('.dart'),
      );

  /// The derived paths the regeneration changed, added or removed.
  Future<List<String>> changed() async => [
    for (final line in LineSplitter.split(
      await _git(top, ['status', '--porcelain', '--untracked-files=all']),
    ))
      if (line.substring(3) case final path
          when isGenerated(path) || p.posix.basename(path) == 'migrations.dart')
        path,
  ];

  Future<bool> isRegistry(String path) async =>
      p.posix.basename(path) == 'migrations.dart' &&
      (await _show(top, ':2:$path') ?? '').startsWith(_registryHeader);

  /// Every registry in the project's packages.
  Future<List<String>> registries() async => [
    for (final line in LineSplitter.split(
      await _git(top, ['ls-files', '--', ':(glob)**/migrations.dart']),
    ))
      if (File(p.join(top, line)).existsSync() &&
          File(
            p.join(top, line),
          ).readAsStringSync().startsWith(_registryHeader))
        line,
  ];

  /// Rewrites the registry at [path] from the migration files beside it: the
  /// list holds nothing a directory listing does not.
  Future<void> rebuildRegistry(String path) async {
    final file = File(p.join(top, path));
    final current = await _show(top, ':2:$path') ?? file.readAsStringSync();
    final lines = LineSplitter.split(current).toList();
    final ormImport = lines.firstWhere(
      (line) =>
          line.startsWith('import ') &&
          !RegExp(r"/m\d[^/']*\.dart'").hasMatch(line),
    );
    final prefix = lines
        .map(
          (line) =>
              RegExp(r"^import '(.*/)m\d[^/']*\.dart';").firstMatch(line)?[1],
        )
        .nonNulls
        .firstOrNull;
    final variable = RegExp(
      r'List<DwDatabaseMigration>\s+(\w+)\s*=',
    ).firstMatch(current)![1]!;
    final migrations = [
      for (final entity in file.parent.listSync())
        if (entity is File &&
            RegExp(r'^m\d.*\.dart$').hasMatch(p.basename(entity.path)))
          entity,
    ]..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final buffer = StringBuffer()
      ..writeln('$_registryHeader: one entry per migration file in this')
      ..writeln('// directory, in id order.')
      ..writeln(ormImport)
      ..writeln();
    for (final migration in migrations) {
      buffer.writeln("import '${prefix ?? ''}${p.basename(migration.path)}';");
    }
    buffer
      ..writeln()
      ..writeln('final List<DwDatabaseMigration> $variable = [');
    for (final migration in migrations) {
      final name = RegExp(
        r'class\s+(\w+)\s+extends\s+DwDatabaseMigration\b',
      ).firstMatch(migration.readAsStringSync())?[1];
      if (name == null) {
        throw StateError('${migration.path} declares no DwDatabaseMigration');
      }
      buffer.writeln('  const $name(),');
    }
    buffer.writeln('];');
    file.writeAsStringSync(buffer.toString());
  }
}

/// Three-way merge of an `.arb` by key: a key either side changed takes that
/// side; a key both changed differently is a real conflict, and null comes
/// back.
Future<String?> _mergeArb(String top, String path) async {
  Map<String, Object?> parse(String? source) =>
      source == null ? {} : (jsonDecode(source) as Map).cast<String, Object?>();
  final base = parse(await _show(top, ':1:$path'));
  final ours = parse(await _show(top, ':2:$path'));
  final theirs = parse(await _show(top, ':3:$path'));
  String key(Object? value) => jsonEncode(value);
  final merged = <String, Object?>{};
  final order = [
    ...ours.keys,
    ...theirs.keys.where((k) => !ours.containsKey(k)),
  ];
  for (final name in order) {
    final (o, t, b) = (ours[name], theirs[name], base[name]);
    final (hasO, hasT, hasB) = (
      ours.containsKey(name),
      theirs.containsKey(name),
      base.containsKey(name),
    );
    if (hasO == hasT && key(o) == key(t)) {
      if (hasO) merged[name] = o;
    } else if (hasO == hasB && key(o) == key(b)) {
      if (hasT) merged[name] = t;
    } else if (hasT == hasB && key(t) == key(b)) {
      if (hasO) merged[name] = o;
    } else {
      return null;
    }
  }
  return '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
}

Future<String?> _show(String top, String object) async {
  final result = await Process.run('git', [
    'show',
    object,
  ], workingDirectory: top);
  return result.exitCode == 0 ? result.stdout as String : null;
}

Future<String> _git(String top, List<String> args, {bool check = false}) async {
  final result = await Process.run('git', args, workingDirectory: top);
  if (check && result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}
