// Which packages' suites a change can break, for one CI job (shard).
//
// Usage, from the repository root:
//   dart run tool/affected.dart [--base <rev>] [--head <rev>] [--shard <name>]
//
// Prints the package paths on one line, space-separated — the value
// `tool/checks.sh` takes as DW_CHECKS_ONLY — and an empty line when the
// change touches nothing in the shard. Without --base, every package: a push
// to master and the nightly run test everything.
//
// Shards are the jobs of `.github/workflows/checks.yml`: the generator and
// the CLI hold the two longest suites and run alone, `rest` is everything
// else, and `services` is the whole set for `tool/checks.sh services`, which
// keeps the packages it runs.
//
// What counts as affected is `lib/src/affected_suites.dart`.

import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';

const _alone = {
  'generator': 'packages/dartway_generator',
  'cli': 'packages/dartway_cli',
};
const _shards = ['generator', 'cli', 'rest', 'services'];

void main(List<String> arguments) {
  String? base, shard;
  var head = 'HEAD';
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--base' when i + 1 < arguments.length:
        base = arguments[++i];
      case '--head' when i + 1 < arguments.length:
        head = arguments[++i];
      case '--shard' when i + 1 < arguments.length:
        shard = arguments[++i];
      default:
        _usage('unknown argument: ${arguments[i]}');
    }
  }
  if (shard != null && !_shards.contains(shard)) {
    _usage('unknown shard: $shard (one of ${_shards.join(', ')})');
  }

  final packages = [
    for (final pubspec in _tracked(['*pubspec.yaml']))
      if (pubspec.endsWith('/pubspec.yaml'))
        RepoPackage.fromPubspec(
          pubspec.substring(0, pubspec.length - '/pubspec.yaml'.length),
          File(pubspec).readAsStringSync(),
        ),
    for (final manifest in _tracked(['js/*/package.json']))
      RepoPackage(
        manifest.substring(0, manifest.length - '/package.json'.length),
        manifest,
        const {},
      ),
  ];

  var affected = {for (final package in packages) package.path};
  if (base != null && base.isNotEmpty) {
    final diff = Process.runSync('git', [
      'diff',
      '--name-only',
      '--no-renames',
      '$base...$head',
    ]);
    if (diff.exitCode != 0) {
      // A base this clone cannot see costs a full run, not a wrong verdict.
      stderr.writeln(
        'cannot diff against $base (${'${diff.stderr}'.trim()}); '
        'running every package',
      );
    } else {
      final changed = '${diff.stdout}'.split('\n').where((l) => l.isNotEmpty);
      affected = affectedSuites(packages, changed);
      stderr.writeln(
        '${changed.length} files changed since $base; '
        '${affected.length} of ${packages.length} packages affected',
      );
    }
  }

  final selected = switch (shard) {
    final name? when _alone.containsKey(name) => affected.where(
      (path) => path == _alone[name],
    ),
    'rest' => affected.where((path) => !_alone.containsValue(path)),
    _ => affected,
  };
  stdout.writeln((selected.toList()..sort()).join(' '));
}

/// Tracked files matching [patterns], as `git ls-files` names them.
List<String> _tracked(List<String> patterns) {
  final result = Process.runSync('git', ['ls-files', '--', ...patterns]);
  if (result.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${result.stderr}');
    exit(1);
  }
  return '${result.stdout}'.split('\n').where((l) => l.isNotEmpty).toList();
}

Never _usage(String problem) {
  stderr
    ..writeln(problem)
    ..writeln(
      'usage: dart run tool/affected.dart [--base <rev>] [--head <rev>] '
      '[--shard ${_shards.join('|')}]',
    );
  exit(64);
}
