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
// Shards are the jobs of `.github/workflows/checks.yml`, cut so that none
// is long — many short jobs queue better than one long one holds the run.
// The generator and the CLI run alone, and the longest file of each runs
// apart from its package (`contract`, `update`); `rest` is everything else.
// `services` is the set for `tool/checks.sh services`, which keeps what it
// runs, without the CLI's external test servers, which are `services-cli`.
// `analyze` is the packages whose code the change reaches. A job that is
// one part of a shard takes its part in `tool/checks.sh` (DW_TEST_PART),
// which knows which suites run.
//
// What counts as affected is `lib/src/affected_suites.dart`.

import 'dart:io';

import 'package:dartway_repo_tools/dartway_repo_tools.dart';

const _alone = {
  'generator': 'packages/dartway_generator',
  'cli': 'packages/dartway_cli',
};
const _aloneFiles = {
  'contract': 'packages/dartway_generator/test/contract_behavior_test.dart',
  'update': 'packages/dartway_cli/test/update_command_test.dart',
};
final _shards = [
  ..._alone.keys,
  ..._aloneFiles.keys,
  'rest',
  'services',
  'services-cli',
  'analyze',
];

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
  final tests = _tracked(['*_test.dart']);
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
        testFiles: tests,
      );
      stderr.writeln(
        '${changed.length} files changed since $base; '
        '${affected.code.length} of ${packages.length} packages reached',
      );
    }
  }

  bool inPackage(String entry, String package) =>
      entry == package || entry.startsWith('$package/');
  String? owner(String file) => all
      .where((package) => inPackage(file, package))
      .fold<String?>(null, (a, b) => a == null || b.length > a.length ? b : a);
  bool inCli(String entry) => inPackage(entry, _alone['cli']!);
  // A whole package one of whose files runs in a job of its own is listed
  // by its files, so that its job can leave that one out.
  final suites = {
    for (final entry in affected.suites)
      if (_aloneFiles.values.any((file) => owner(file) == entry))
        ...tests.where((file) => owner(file) == entry)
      else
        entry,
  };
  final selected = switch (shard) {
    'analyze' => affected.code,
    final name? when _aloneFiles.containsKey(name) => suites.where(
      (entry) => entry == _aloneFiles[name],
    ),
    final name? when _alone.containsKey(name) => suites.where(
      (entry) =>
          inPackage(entry, _alone[name]!) &&
          !_aloneFiles.values.contains(entry),
    ),
    'rest' => suites.where(
      (entry) => !_alone.values.any((package) => inPackage(entry, package)),
    ),
    'services' => affected.suites.where((entry) => !inCli(entry)),
    'services-cli' => affected.suites.where(inCli),
    _ => affected.suites,
  }.toList()..sort();
  stdout.writeln(selected.join(' '));
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
