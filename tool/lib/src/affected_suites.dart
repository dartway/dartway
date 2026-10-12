/// Which suites a change can break, for `tool/affected.dart`.
///
/// A suite is affected when a file it can read changed: a file of its own
/// package, of a package it depends on (`dependencies`, `dev_dependencies`
/// or `dependency_overrides` — every one of them reaches its tests), or one
/// of the paths outside its package the suite is known to read
/// ([readsOutside]), or the code of a package it runs as a program
/// ([runs]). The graph comes from the pubspecs rather than a list of
/// paths per workflow job, because a hand-written list is exactly what #165
/// slipped past: the suite that broke belonged to a package the author had
/// no reason to open, and it would have been missing from their list too.
///
/// What cannot be placed runs everything. A file no package owns and no
/// entry below names — a new top-level directory, a renamed one — is not
/// guessed at: the set that runs is the whole one, and the next line in
/// [readsOutside] or [readByNoSuite] is what narrows it.
library;

import 'pubspec_scan.dart';

/// Files every suite depends on: the SDK pin, the workspace resolution, and
/// the scripts that pick and run the suites. A change to any of them is
/// tested by running everything.
const runsEverything = [
  '.fvmrc',
  'pubspec.yaml',
  'pubspec.lock',
  '.github/workflows/checks.yml',
  'tool/checks.sh',
  'tool/affected.dart',
  'tool/lib/src/affected_suites.dart',
  'tool/lib/src/pubspec_scan.dart',
];

/// Paths outside its own package a suite reads, by package. A trailing `/`
/// names a directory and everything under it; `*` matches one path segment.
///
/// `dartway_cli` copies `template/` (`create`, `update`), checks `example/`,
/// reads the toolkit, the docs and the root README/CLAUDE.md, and every
/// package's pubspec for the framework's versions. `dartway_generator`
/// generates over the example's shared and server packages. The lints test
/// runs the analyzer over its own `example/`, which is a package of its own.
/// `tool`'s suites copy `template/` and hold the repository to itself: the
/// names the docs, the toolkit and the README cite against every package's
/// sources, protocol literals in every `test/` under `packages/`,
/// `template/` and `example/`, and spellings two packages share.
const readsOutside = {
  'packages/dartway_cli': [
    'template/',
    'example/',
    'toolkit/',
    'docs/',
    'deploy/',
    'packages/*/pubspec.yaml',
    'packages/dartway_lints/',
    'README.md',
    'CLAUDE.md',
    'AGENTS.md',
    '.claude/',
    '.agents/',
  ],
  'packages/dartway_generator': [
    'example/dartway_example_shared/',
    'example/dartway_example_server/',
  ],
  'packages/dartway_lints': ['packages/dartway_lints/example/'],
  'tool': [
    'template/',
    'example/',
    'packages/',
    'docs/',
    'toolkit/',
    'README.md',
    'CLAUDE.md',
  ],
};

/// Packages a suite runs as a program, by package: the suite is affected
/// when the code of one of them changes — its own files or a package it
/// depends on — and not when only what that package's suite reads does.
///
/// `dartway_cli` runs the real generator (`server_contract_test`) and runs
/// the example's suites through `dartway test` (`test_external_servers_test`).
/// `dartway_generator` runs the CLI's `bin/dartway.dart` for `generate`,
/// `check` and `--contract-base`.
const runs = {
  'packages/dartway_cli': [
    'packages/dartway_generator',
    'example/dartway_example_server',
    'example/dartway_example_shared',
    'example/dartway_example_flutter',
  ],
  'packages/dartway_generator': ['packages/dartway_cli'],
};

/// Paths no suite reads: a change here runs nothing.
const readByNoSuite = ['LICENSE', '.gitignore', '.github/', '.vscode/'];

/// A package of this repository: its directory and what it depends on.
final class RepoPackage {
  const RepoPackage(this.path, this.name, this.dependencies);

  /// Reads a Dart package from its `pubspec.yaml`.
  factory RepoPackage.fromPubspec(String path, String pubspec) {
    final document = parsePubspec(pubspec);
    final name = pubspecValue(document, 'name');
    if (name == null) throw FormatException('$path/pubspec.yaml has no name');
    return RepoPackage(path, name, {
      for (final section in [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
      ])
        if (document[section] case final Map<Object?, Object?> entries)
          ...entries.keys.whereType<String>(),
    });
  }

  /// Relative to the repository root, `/`-separated: `packages/dartway_orm`.
  final String path;

  /// The pubspec `name:`; a `js/*` package, which no Dart package depends
  /// on, carries its path.
  final String name;

  /// Every package named in its pubspec, local or not.
  final Set<String> dependencies;
}

/// The packages whose suites [changed] files can break — all of [packages]
/// when one of the files cannot be placed (see the library comment).
Set<String> affectedSuites(
  Iterable<RepoPackage> packages,
  Iterable<String> changed,
) {
  final all = {for (final package in packages) package.path};
  final byName = {for (final package in packages) package.name: package};
  final owners = <String>{};
  final readersHit = <String>{};
  for (final file in changed) {
    if (runsEverything.contains(file)) return all;
    final owner = _owner(all, file);
    final readers = {
      for (final MapEntry(key: reader, value: globs) in readsOutside.entries)
        if (all.contains(reader) && globs.any((glob) => _matches(glob, file)))
          reader,
    };
    if (owner == null &&
        readers.isEmpty &&
        !readByNoSuite.any((glob) => _matches(glob, file))) {
      return all;
    }
    readersHit.addAll(readers);
    owners.addAll([?owner]);
  }
  final dependents = <String, Set<String>>{};
  for (final package in packages) {
    for (final dependency in package.dependencies) {
      final local = byName[dependency];
      if (local == null || local.path == package.path) continue;
      (dependents[local.path] ??= {}).add(package.path);
    }
  }
  // Dependents, to the fixed point: a package is affected once the code of
  // anything it depends on is.
  final code = {...owners};
  final queue = [...code];
  while (queue.isNotEmpty) {
    for (final dependent
        in dependents[queue.removeLast()] ?? const <String>{}) {
      if (code.add(dependent)) queue.add(dependent);
    }
  }
  // What a suite reads outside its package is the suite's alone: a package
  // depending on the CLI depends on its code, not on the docs its tests
  // read. A runner follows the code of what it runs, one hop: the generator
  // runs the CLI's program, not the CLI's suites.
  return {
    ...code,
    ...readersHit,
    for (final MapEntry(key: runner, value: programs) in runs.entries)
      if (all.contains(runner) && programs.any(code.contains)) runner,
  };
}

/// The innermost package holding [file]: `packages/dartway_lints/example/…`
/// is the lints example's, not the lints'.
String? _owner(Set<String> packages, String file) {
  String? owner;
  for (final package in packages) {
    if (file.startsWith('$package/') &&
        (owner == null || package.length > owner.length)) {
      owner = package;
    }
  }
  return owner;
}

bool _matches(String glob, String file) {
  final directory = glob.endsWith('/');
  final pattern = directory ? glob.substring(0, glob.length - 1) : glob;
  final globParts = pattern.split('/');
  final fileParts = file.split('/');
  if (directory
      ? fileParts.length <= globParts.length
      : fileParts.length != globParts.length) {
    return false;
  }
  for (var i = 0; i < globParts.length; i++) {
    if (globParts[i] != '*' && globParts[i] != fileParts[i]) return false;
  }
  return true;
}
