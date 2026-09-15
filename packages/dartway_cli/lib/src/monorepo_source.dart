import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'toolkit_manifest.dart';

/// Resolves a checkout of the DartWay monorepo to read `toolkit/` and
/// `template/` from.
///
/// Source priority:
/// 1. an explicit local checkout (`--local-repo` or `DARTWAY_MONOREPO_DIR`) —
///    used when developing the framework itself;
/// 2. a shallow clone of [branch] cached in `~/.dartway/monorepo`, when a
///    channel was chosen ([channelChosen]);
/// 3. the checkout this CLI runs from ([cliCheckout]), when it runs from one;
/// 4. a shallow clone of [branch] — the default channel.
///
/// The third is what makes a CLI and its template one revision. A CLI
/// activated from a checkout or a git ref belongs to the framework beside it,
/// and cloning `stable` instead handed a project the template of another
/// framework — which is exactly what the rewrite's CLI did, producing the 0.x
/// skeleton. Only a CLI with nothing beside it (pub.dev's cache, a compiled
/// executable) takes the channel without being asked.
class MonorepoSource {
  /// [environment] is injectable because the fallback below is a seam that has
  /// already produced one bug: a caller that checked the `--local-repo`
  /// argument instead of asking this object got a different answer whenever
  /// `DARTWAY_MONOREPO_DIR` was the thing in play. [cliCheckout] is injectable
  /// for the same reason, and defaults to the checkout found beside this CLI.
  MonorepoSource({
    required String branch,
    String? localDir,
    bool channelChosen = false,
    Map<String, String>? environment,
    Directory? Function() cliCheckout = findCliCheckout,
  }) : this._(
         branch: branch,
         namedDir: (localDir != null && localDir.isNotEmpty)
             ? localDir
             : (environment ?? Platform.environment)['DARTWAY_MONOREPO_DIR'],
         channelChosen: channelChosen,
         cliCheckout: cliCheckout,
       );

  MonorepoSource._({
    required this.branch,
    required String? namedDir,
    required bool channelChosen,
    required Directory? Function() cliCheckout,
  }) : isNamedCheckout = namedDir != null && namedDir.isNotEmpty,
       localDir = (namedDir != null && namedDir.isNotEmpty)
           ? namedDir
           : (channelChosen ? null : cliCheckout()?.path);

  static const defaultRepoUrl = 'https://github.com/dartway/dartway.git';
  static const defaultBranch = 'stable';

  final String branch;

  /// The checkout the toolkit and the template are read from, or null for a
  /// clone of [branch].
  final String? localDir;

  /// Whether [localDir] was named — by `--local-repo`, `--framework-path` or
  /// `DARTWAY_MONOREPO_DIR` — rather than found beside the CLI.
  final bool isNamedCheckout;

  /// The checkout this CLI runs from, or null when there is none beside it.
  ///
  /// Asked of the package configuration rather than of `Platform.script`:
  /// a globally activated CLI runs from a snapshot in pub's cache, while its
  /// package still resolves to where it was activated from — a checkout for
  /// `--source path`, pub's clone of the repository for `--source git`, and
  /// pub.dev's unpacked archive, which holds no framework, for a hosted one.
  static Directory? findCliCheckout() {
    final library = Isolate.resolvePackageUriSync(
      Uri.parse('package:dartway_cli/'),
    );
    return library == null ? null : cliCheckoutAround(library);
  }

  /// The monorepo holding the `dartway_cli` library at [library] (its `lib/`),
  /// or null when [library] is not inside one.
  static Directory? cliCheckoutAround(Uri library) {
    if (library.scheme != 'file') return null;
    final package = p.dirname(p.normalize(library.toFilePath()));
    final root = p.dirname(p.dirname(package));
    final isMonorepo =
        p.basename(p.dirname(package)) == 'packages' &&
        File(p.join(package, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(root, 'template')).existsSync() &&
        Directory(p.join(root, 'toolkit')).existsSync();
    return isMonorepo ? Directory(root) : null;
  }

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
  Future<ToolkitProvenance> provenance(
    Directory resolved, {
    Map<String, String> settings = const {},
  }) async => ToolkitProvenance(
    source: isLocalCheckout ? resolved.path : repoUrl,
    channel: isLocalCheckout ? null : branch,
    commit: await monorepoCommit(resolved),
    cliVersion: dartwayCliVersion,
    installedAt: DateTime.now().toUtc().toIso8601String(),
    settings: settings,
  );

  /// Returns the monorepo root, cloning or updating the cache if needed.
  Future<Directory> resolve() async {
    final local = localDir;
    if (local != null && local.isNotEmpty) {
      final localRepoDir = Directory(local);
      if (!localRepoDir.existsSync()) {
        throw StateError('Local monorepo directory not found: $local');
      }
      stdout.writeln(
        isNamedCheckout
            ? 'Using local DartWay monorepo: ${localRepoDir.path}'
            : 'Using the DartWay monorepo this CLI runs from: '
                  '${localRepoDir.path}',
      );
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
