/// Which suites a change can break, for `tool/affected.dart`.
///
/// A suite is affected when a file it can read changed: a file of its own
/// package, of a package it depends on (`dependencies`, `dev_dependencies`
/// or `dependency_overrides` — every one of them reaches its tests), or one
/// of the paths outside its package the suite is known to read
/// ([readsOutside]). The graph comes from the pubspecs rather than a list of
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
];

/// Paths outside its own package a suite reads, by package. A trailing `/`
/// names a directory and everything under it; `*` matches one path segment.
///
/// `dartway_cli` copies `template/` (`create`, `update`), checks `example/`,
/// reads the toolkit, the docs and the root README/CLAUDE.md for the names
/// they cite, and every package's pubspec for the framework's versions.
/// `dartway_generator` generates over the example's shared and server
/// packages. The
/// lints test runs the analyzer over its own `example/`, which is a package
/// of its own. `tool`'s suites read `template/`.
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
  'tool': ['template/'],
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
  final hit = <String>{};
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
    hit
      ..addAll(readers)
      ..addAll([?owner]);
  }
  // Dependents, to the fixed point: a package is affected once anything it
  // depends on is.
  final dependents = <String, Set<String>>{};
  for (final package in packages) {
    for (final dependency in package.dependencies) {
      final local = byName[dependency];
      if (local == null || local.path == package.path) continue;
      (dependents[local.path] ??= {}).add(package.path);
    }
  }
  final queue = [...hit];
  while (queue.isNotEmpty) {
    for (final dependent
        in dependents[queue.removeLast()] ?? const <String>{}) {
      if (hit.add(dependent)) queue.add(dependent);
    }
  }
  return hit;
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
