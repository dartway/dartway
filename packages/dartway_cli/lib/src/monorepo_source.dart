import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves a checkout of the DartWay monorepo to read `toolkit/` and
/// `example/` from.
///
/// Source priority:
/// 1. an explicit local checkout (`--local-repo` or `DARTWAY_MONOREPO_DIR`) —
///    used when developing the framework itself;
/// 2. a shallow clone of [branch] cached in `~/.dartway/monorepo`.
class MonorepoSource {
  MonorepoSource({required this.branch, String? localDir})
    : localDir =
          (localDir != null && localDir.isNotEmpty)
              ? localDir
              : Platform.environment['DARTWAY_MONOREPO_DIR'];

  static const defaultRepoUrl = 'https://github.com/dartway/dartway.git';
  static const defaultBranch = 'stable';

  final String branch;
  final String? localDir;

  String get repoUrl =>
      Platform.environment['DARTWAY_REPO_URL'] ?? defaultRepoUrl;

  Directory get _cacheDir {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return Directory(p.join(home, '.dartway', 'monorepo'));
  }

  /// Returns the monorepo root, cloning or updating the cache if needed.
  Future<Directory> resolve() async {
    final local = localDir;
    if (local != null && local.isNotEmpty) {
      final localRepoDir = Directory(local);
      if (!localRepoDir.existsSync()) {
        throw StateError('Local monorepo directory not found: $local');
      }
      stdout.writeln('Using local DartWay monorepo: ${localRepoDir.path}');
      return localRepoDir;
    }

    final cacheDir = _cacheDir;
    if (Directory(p.join(cacheDir.path, '.git')).existsSync()) {
      stdout.writeln('Updating DartWay monorepo cache (branch: $branch)...');
      await _runGit(
        ['fetch', '--depth', '1', 'origin', branch],
        workingDirectory: cacheDir.path,
      );
      await _runGit(
        ['checkout', '-B', branch, 'FETCH_HEAD'],
        workingDirectory: cacheDir.path,
      );
    } else {
      stdout.writeln('Cloning $repoUrl (branch: $branch)...');
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      cacheDir.parent.createSync(recursive: true);
      await _runGit([
        'clone',
        '--depth',
        '1',
        '--branch',
        branch,
        repoUrl,
        cacheDir.path,
      ]);
    }
    return cacheDir;
  }

  Future<void> _runGit(List<String> args, {String? workingDirectory}) async {
    final result = await Process.run(
      'git',
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed:\n${result.stderr}');
    }
  }
}
