/// Which checks a change can break, for `tool/affected.dart`.
///
/// A package's suite is affected when a file it can read changed: a file of
/// its own package, of a package it depends on (`dependencies`,
/// `dev_dependencies` or `dependency_overrides` — every one of them reaches
/// its tests), or one of the paths outside its package the suite is known to
/// read ([readsOutside]). The graph comes from the pubspecs rather than a
/// list of paths per workflow job, because a hand-written list is exactly
/// what #165 slipped past: the suite that broke belonged to a package the
/// author had no reason to open, and it would have been missing from their
/// list too.
///
/// A few test files take minutes each and run the CLI or the generator as a
/// program over a project of their own; they would hold up every change to
/// their package for code they never execute. Each of them is named in
/// [narrowTests] with what it runs and reads, and runs on that alone — its
/// package's other suites keep the rule above.
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
    'docs/migrations/2026-09-30-persisted-row-id.md',
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

/// Paths no suite reads: a change here runs nothing.
const readByNoSuite = ['LICENSE', '.gitignore', '.github/', '.vscode/'];

/// What a test file in [narrowTests] runs and reads, instead of its
/// package's rule.
///
/// It is affected when one of these changed:
/// - the code of a package in [runtime]: a file of the package outside its
///   `test/`, or the same of a package it depends on through `dependencies:`
///   (what a program built on it loads — not its dev dependencies, which only
///   its own suites load);
/// - a file in the import closure of the test file and of [closureOf] —
///   relative imports and `package:` imports of this repository's packages,
///   followed to the end, with the pubspec of every package the closure
///   enters;
/// - a path matching [reads], globbed as in [readsOutside];
/// - a file of its own package's `test/` that is not another test file — the
///   fixtures, goldens and support code a suite reads by path.
final class NarrowTest {
  const NarrowTest({
    this.runtime = const [],
    this.closureOf = const [],
    this.reads = const [],
  });

  final List<String> runtime;
  final List<String> closureOf;
  final List<String> reads;
}

/// What every invocation of the CLI loads before the command it names:
/// `bin/dartway.dart` imports every command, and these two of its imports run
/// before any of them. A command's suite that runs the CLI follows these and
/// its own command's closure; the commands it does not call are proved by
/// their own suites and by the analyzer.
const _cliStart = [
  'packages/dartway_cli/lib/src/pinned_cli.dart',
  'packages/dartway_cli/lib/src/project_layout.dart',
];

/// The test files that run on what they execute rather than with their
/// package, by path. Measured on CI before they were narrowed (run
/// 38204871954): `contract_behavior_test` 318 s, `update_command_test`
/// 160 s, `test_external_servers_test` 140 s (215 s with the services).
///
/// - `contract_behavior_test` builds projects on `dartway_core_shared` and
///   `dartway_orm`, runs the generator in them, and runs the CLI's `generate`
///   and `check`.
/// - `update_command_test` runs `dartway update` against this repository:
///   the template's lock, the toolkit, the migration notes, the lints plugin
///   and every package's pubspec.
/// - `test_external_servers_test` runs `dartway test` over a project on
///   `dartway_core_server`, and with the services over `example/`.
/// - `server_contract_test` runs the generator's program.
const narrowTests = {
  'packages/dartway_generator/test/contract_behavior_test.dart': NarrowTest(
    runtime: [
      'packages/dartway_generator',
      'packages/dartway_core_shared',
      'packages/dartway_orm',
    ],
    closureOf: [
      ..._cliStart,
      'packages/dartway_cli/lib/src/commands/generate_command.dart',
      'packages/dartway_cli/lib/src/commands/check_command.dart',
    ],
    reads: ['packages/dartway_cli/bin/dartway.dart'],
  ),
  'packages/dartway_cli/test/update_command_test.dart': NarrowTest(
    closureOf: [
      ..._cliStart,
      'packages/dartway_cli/lib/src/commands/update_command.dart',
    ],
    reads: [
      'packages/dartway_cli/bin/dartway.dart',
      'template/',
      'toolkit/',
      'docs/migrations/',
      'packages/dartway_lints/',
      'packages/*/pubspec.yaml',
    ],
  ),
  'packages/dartway_cli/test/test_external_servers_test.dart': NarrowTest(
    runtime: [
      'packages/dartway_core_server',
      'example/dartway_example_server',
      'example/dartway_example_shared',
    ],
    closureOf: [
      ..._cliStart,
      'packages/dartway_cli/lib/src/commands/test_command.dart',
    ],
    reads: [
      'packages/dartway_cli/bin/dartway.dart',
      'example/*',
      'example/dartway_example_server/',
      'example/dartway_example_shared/',
    ],
  ),
  'packages/dartway_cli/test/server_contract_test.dart': NarrowTest(
    runtime: ['packages/dartway_generator'],
  ),
};

/// A package of this repository: its directory and what it depends on.
final class RepoPackage {
  const RepoPackage(
    this.path,
    this.name,
    this.dependencies, [
    this.runtimeDependencies = const {},
  ]);

  /// Reads a Dart package from its `pubspec.yaml`.
  factory RepoPackage.fromPubspec(String path, String pubspec) {
    final document = parsePubspec(pubspec);
    final name = pubspecValue(document, 'name');
    if (name == null) throw FormatException('$path/pubspec.yaml has no name');
    Set<String> keys(String section) => {
      if (document[section] case final Map<Object?, Object?> entries)
        ...entries.keys.whereType<String>(),
    };
    return RepoPackage(path, name, {
      ...keys('dependencies'),
      ...keys('dev_dependencies'),
      ...keys('dependency_overrides'),
    }, keys('dependencies'));
  }

  /// Relative to the repository root, `/`-separated: `packages/dartway_orm`.
  final String path;

  /// The pubspec `name:`; a `js/*` package, which no Dart package depends
  /// on, carries its path.
  final String name;

  /// Every package named in its pubspec, local or not.
  final Set<String> dependencies;

  /// The packages under `dependencies:` alone: what its own code loads.
  final Set<String> runtimeDependencies;
}

/// What a change can break.
final class Affected {
  const Affected(this.code, this.suites);

  /// The packages whose code the change reaches: the packages it touches and
  /// every package depending on one of them, through any section. What
  /// `analyze` covers.
  final Set<String> code;

  /// What `test` and `services` run: a package path is its whole suite, a
  /// `_test.dart` path that file alone.
  final Set<String> suites;
}

/// What [changed] files can break — everything when one of them cannot be
/// placed (see the library comment).
///
/// [closures] is the import closure of each of [narrowTests], as
/// [importClosure] computes it; [testFiles] is every test file of the
/// repository, so that a package whose narrow test is not affected can run
/// its other files by name.
Affected affectedChecks(
  Iterable<RepoPackage> packages,
  Iterable<String> changed, {
  Map<String, Set<String>> closures = const {},
  Iterable<String> testFiles = const [],
}) {
  final all = {for (final package in packages) package.path};
  final everything = Affected(all, all);
  final byName = {for (final package in packages) package.name: package};
  final owners = <String>{};
  final runtimeOwners = <String>{};
  final readersHit = <String>{};
  for (final file in changed) {
    if (runsEverything.contains(file)) return everything;
    final owner = _owner(all, file);
    final readers = {
      for (final MapEntry(key: reader, value: globs) in readsOutside.entries)
        if (all.contains(reader) && globs.any((glob) => _matches(glob, file)))
          reader,
    };
    if (owner == null &&
        readers.isEmpty &&
        !readByNoSuite.any((glob) => _matches(glob, file)) &&
        !narrowTests.values.any(
          (narrow) => narrow.reads.any((glob) => _matches(glob, file)),
        )) {
      return everything;
    }
    readersHit.addAll(readers);
    if (owner == null) continue;
    owners.add(owner);
    if (!file.startsWith('$owner/test/')) runtimeOwners.add(owner);
  }

  // Dependents, to the fixed point: a package is affected once the code of
  // anything it depends on is.
  Set<String> reach(Set<String> from, Set<String> Function(RepoPackage) edges) {
    final dependents = <String, Set<String>>{};
    for (final package in packages) {
      for (final dependency in edges(package)) {
        final local = byName[dependency];
        if (local == null || local.path == package.path) continue;
        (dependents[local.path] ??= {}).add(package.path);
      }
    }
    final reached = {...from};
    final queue = [...reached];
    while (queue.isNotEmpty) {
      for (final dependent
          in dependents[queue.removeLast()] ?? const <String>{}) {
        if (reached.add(dependent)) queue.add(dependent);
      }
    }
    return reached;
  }

  final code = reach(owners, (package) => package.dependencies);
  final runtime = reach(
    runtimeOwners,
    (package) => package.runtimeDependencies,
  );

  final narrowHit = <String>{
    for (final MapEntry(key: test, value: narrow) in narrowTests.entries)
      if (_owner(all, test) case final package?)
        if (narrow.runtime.any(runtime.contains) ||
            changed.any(
              (file) =>
                  file == test ||
                  (closures[test]?.contains(file) ?? false) ||
                  narrow.reads.any((glob) => _matches(glob, file)) ||
                  (file.startsWith('$package/test/') &&
                      !file.endsWith('_test.dart') &&
                      _owner(all, file) == package),
            ))
          test,
  };

  // What a suite reads outside its package is the suite's alone: a package
  // depending on the CLI depends on its code, not on the docs its tests
  // read.
  final suites = <String>{};
  for (final package in {...code, ...readersHit}) {
    final skipped = {
      for (final test in narrowTests.keys)
        if (_owner(all, test) == package && !narrowHit.contains(test)) test,
    };
    if (skipped.isEmpty) {
      suites.add(package);
    } else {
      suites.addAll([
        for (final file in testFiles)
          if (_owner(all, file) == package && !skipped.contains(file)) file,
      ]);
    }
  }
  for (final test in narrowHit) {
    if (!suites.contains(_owner(all, test))) suites.add(test);
  }
  return Affected(code, suites);
}

/// The repository files [entries] load: each of them, every file their
/// directives name — relative, or `package:` of a package in [packages] —
/// followed to the end, and the pubspec of every package the closure enters.
/// [read] gives a file's contents, or null when it does not exist; a missing
/// file stays in the closure, so the change that creates it is seen.
Set<String> importClosure(
  Iterable<String> entries,
  Iterable<RepoPackage> packages,
  String? Function(String path) read,
) {
  final all = {for (final package in packages) package.path};
  final byName = {for (final package in packages) package.name: package.path};
  final closure = <String>{};
  final queue = [...entries];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!closure.add(file)) continue;
    if (_owner(all, file) case final package?) {
      closure.add('$package/pubspec.yaml');
    }
    final source = read(file);
    if (source == null) continue;
    for (final uri in directiveUris(source)) {
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:')) {
        final slash = uri.indexOf('/');
        if (slash < 0) continue;
        final package = byName[uri.substring('package:'.length, slash)];
        if (package != null) {
          queue.add('$package/lib/${uri.substring(slash + 1)}');
        }
      } else if (!uri.contains(':')) {
        final directory = file.contains('/')
            ? file.substring(0, file.lastIndexOf('/'))
            : '';
        queue.add(_normalize('$directory/$uri'));
      }
    }
  }
  return closure;
}

/// The URIs a Dart file's directives name — imports, exports, parts, and the
/// alternatives of a conditional import — read from the top of the file and
/// no further: a test that writes Dart source into a fixture carries
/// `import` lines in its strings, and they are not its own.
List<String> directiveUris(String source) {
  final uris = <String>[];
  final quoted = RegExp(r"""(?:'([^']*)'|"([^"]*)")""");
  var statement = StringBuffer();
  var inDirective = false;
  var inComment = false;
  var annotationDepth = 0;
  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (inComment) {
      if (line.contains('*/')) inComment = false;
      continue;
    }
    if (inDirective) {
      statement.writeln(line);
    } else if (annotationDepth > 0) {
      annotationDepth += _depth(line);
      continue;
    } else if (line.isEmpty || line.startsWith('//') || line.startsWith('#!')) {
      continue;
    } else if (line.startsWith('/*')) {
      inComment = !line.contains('*/');
      continue;
    } else if (line.startsWith('@')) {
      annotationDepth = _depth(line);
      continue;
    } else if (RegExp(r'^(import|export|part|library)\b').hasMatch(line)) {
      inDirective = true;
      statement = StringBuffer()..writeln(line);
    } else {
      break;
    }
    if (line.contains(';')) {
      inDirective = false;
      final text = '$statement';
      if (!text.startsWith('library')) {
        for (final match in quoted.allMatches(text)) {
          uris.add(match.group(1) ?? match.group(2)!);
        }
      }
    }
  }
  return uris;
}

int _depth(String line) =>
    '('.allMatches(line).length - ')'.allMatches(line).length;

String _normalize(String path) {
  final parts = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..' && parts.isNotEmpty && parts.last != '..') {
      parts.removeLast();
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
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
