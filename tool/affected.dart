// What a change can break, for one CI job (shard).
//
// Usage, from the repository root:
//   dart run tool/affected.dart [--base <rev>] [--head <rev>] [--shard <name>]
//
// Prints the selection on one line, space-separated — the value
// `tool/checks.sh` takes as DW_CHECKS_ONLY — and an empty line when the
// change touches nothing in the shard. A package path runs its whole suite,
// a `_test.dart` path that file alone. Without --base, every package: a
// push to master and the nightly run test everything.
//
// Shards are the jobs of `.github/workflows/checks.yml`: the generator and
// the CLI hold the two longest suites and run alone, `rest` is everything
// else, `services` is the whole set for `tool/checks.sh services`, which
// keeps what it runs, and `analyze` is the packages whose code the change
// reaches, for `tool/checks.sh analyze`.
//
// What counts as affected is `lib/src/affected_suites.dart`.

import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';

const _alone = {
  'generator': 'packages/dartway_generator',
  'cli': 'packages/dartway_cli',
};
const _shards = ['generator', 'cli', 'rest', 'services', 'analyze'];

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

  final all = {for (final package in packages) package.path};
  var affected = Affected(all, all);
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
      String? read(String path) {
        final file = File(path);
        return file.existsSync() ? file.readAsStringSync() : null;
      }

      affected = affectedChecks(
        packages,
        changed,
        closures: {
          for (final MapEntry(key: test, value: narrow) in narrowTests.entries)
            test: importClosure([test, ...narrow.closureOf], packages, read),
        },
        testFiles: _tracked(['*_test.dart']),
      );
      stderr.writeln(
        '${changed.length} files changed since $base; '
        '${affected.code.length} of ${packages.length} packages reached',
      );
    }
  }

  bool inPackage(String entry, String package) =>
      entry == package || entry.startsWith('$package/');
  final selected = switch (shard) {
    'analyze' => affected.code,
    final name? when _alone.containsKey(name) => affected.suites.where(
      (entry) => inPackage(entry, _alone[name]!),
    ),
    'rest' => affected.suites.where(
      (entry) => !_alone.values.any((package) => inPackage(entry, package)),
    ),
    _ => affected.suites,
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
