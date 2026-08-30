import 'dart:io';

import 'package:path/path.dart' as p;

import 'toolkit_manifest.dart';

/// Resolves a checkout of the DartWay monorepo to read `toolkit/` and
/// `template/` from.
///
/// Source priority:
/// 1. an explicit local checkout (`--local-repo` or `DARTWAY_MONOREPO_DIR`) —
///    used when developing the framework itself;
/// 2. a shallow clone of [branch] cached in `~/.dartway/monorepo`.
class MonorepoSource {
  /// [environment] is injectable because the fallback below is a seam that has
  /// already produced one bug: a caller that checked the `--local-repo`
  /// argument instead of asking this object got a different answer whenever
  /// `DARTWAY_MONOREPO_DIR` was the thing in play.
  MonorepoSource({
    required this.branch,
    String? localDir,
    Map<String, String>? environment,
  }) : localDir = (localDir != null && localDir.isNotEmpty)
           ? localDir
           : (environment ?? Platform.environment)['DARTWAY_MONOREPO_DIR'];

  static const defaultRepoUrl = 'https://github.com/dartway/dartway.git';
  static const defaultBranch = 'stable';

  final String branch;
  final String? localDir;

  /// Whether the toolkit comes from a checkout on this machine rather than
  /// from a channel.
  ///
  /// **The single answer to that question.** Both entry points — the
  /// `--local-repo` argument and the `DARTWAY_MONOREPO_DIR` variable — are
  /// already folded into [localDir] by the constructor, so anything that asks
  /// here cannot disagree with what [resolve] will actually do. Asking the
  /// argument instead is how a channel refusal fired over a channel that was
  /// never going to be touched.
  bool get isLocalCheckout => localDir != null && localDir!.isNotEmpty;

  String get repoUrl =>
      Platform.environment['DARTWAY_REPO_URL'] ?? defaultRepoUrl;

  Directory get _cacheDir {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    return Directory(p.join(home, '.dartway', 'monorepo'));
  }

  /// Where an install from this source came from, for the manifest.
  ///
  /// Built here rather than at each call site: the two commands used to repeat
  /// the same ternaries over the raw argument, and repeating a condition is how
  /// the two copies of it stopped agreeing.
  Future<ToolkitProvenance> provenance(Directory resolved) async =>
      ToolkitProvenance(
        source: isLocalCheckout ? resolved.path : repoUrl,
        channel: isLocalCheckout ? null : branch,
        commit: await monorepoCommit(resolved),
        cliVersion: dartwayCliVersion,
        installedAt: DateTime.now().toUtc().toIso8601String(),
      );

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
      await _runGit([
        'fetch',
        '--depth',
        '1',
        'origin',
        branch,
      ], workingDirectory: cacheDir.path);
      await _runGit([
        'checkout',
        '-B',
        branch,
        'FETCH_HEAD',
      ], workingDirectory: cacheDir.path);
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
