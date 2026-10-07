import 'dart:io';

import 'package:path/path.dart' as p;

import 'monorepo_source.dart';

/// A committed tree, independent of a moving channel or a dirty local checkout.
/// The temporary archive is a read snapshot, not another git worktree.
class DwUpdateTarget {
  DwUpdateTarget._(this.directory, this.commit, this.source, this._scratch);

  final Directory directory;
  final String commit;
  final String source;
  final Directory _scratch;

  static Future<DwUpdateTarget> resolve(
    MonorepoSource source, {
    String? commit,
  }) async {
    if (commit != null && !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(commit)) {
      throw StateError('--target must be a full 40-character commit SHA.');
    }
    final checkout = await source.resolve(target: commit);
    Future<String> git(List<String> args) async {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: checkout.path,
      );
      if (result.exitCode != 0) {
        throw StateError('Cannot read update target: ${result.stderr}');
      }
      return (result.stdout as String).trim();
    }

    final resolved = await git(['rev-parse', '${commit ?? 'HEAD'}^{commit}']);
    final scratch = Directory.systemTemp.createTempSync('dw-update-target-');
    try {
      final archive = p.join(scratch.path, 'target.tar');
      await git(['archive', '--format=tar', '--output=$archive', resolved]);
      final tree = Directory(p.join(scratch.path, 'tree'))..createSync();
      final unpack = await Process.run('tar', [
        '-xf',
        archive,
        '-C',
        tree.path,
      ]);
      if (unpack.exitCode != 0) {
        throw StateError('Cannot unpack update target: ${unpack.stderr}');
      }
      return DwUpdateTarget._(
        tree,
        resolved,
        source.isLocalCheckout ? checkout.absolute.path : source.repoUrl,
        scratch,
      );
    } catch (_) {
      scratch.deleteSync(recursive: true);
      rethrow;
    }
  }

  void dispose() => _scratch.deleteSync(recursive: true);
}
