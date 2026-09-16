import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Reading the build context out of a project's own files.
///
/// Images are built from the project root and name package directories one by
/// one, so the package graph ends up written down three times: as `path:`
/// dependencies in a pubspec, as `COPY` lines in a Dockerfile, and as the
/// allow-list of a `.dockerignore` that denies by default. The three have to
/// agree, and nothing makes them.
///
/// Both failures are silent where people look. A directory a Dockerfile never
/// names does not enter the context, and `pub get` inside the image fails as
/// exit code 66 — three layers from the cause, pointing at neither the
/// Dockerfile nor the package. A directory the ignore file never admits fails
/// louder, at the `COPY` itself, but only for whoever builds the image; a
/// checkout compiles fine either way, because inside it the path resolves.
///
/// This lives in `lib/` rather than in a test because both readers need it: the
/// template's own regression test, and `dartway deploy check`, which is the
/// only place a project that has left the skeleton behind gets told.

/// What a Dockerfile takes from the build context.
typedef BuildContextReads = ({
  /// `COPY . .` — the whole context, so every directory is satisfied and
  /// nothing can be missing from it.
  bool wholeContext,

  /// Top-level directories named one by one.
  Set<String> directories,
});

/// The directories [dockerfile] copies out of the build context.
///
/// `COPY --from=<stage>` is excluded deliberately: it reads an earlier stage's
/// filesystem, not the context, so counting it would let a multi-stage file
/// claim directories that were never sent to the daemon.
BuildContextReads readsOf(File dockerfile) {
  final directories = <String>{};
  var wholeContext = false;

  for (final line in dockerfile.readAsLinesSync()) {
    final copy = RegExp(r'^\s*COPY\s+(.*)$').firstMatch(line);
    if (copy == null) continue;

    final arguments = copy
        .group(1)!
        .split(RegExp(r'\s+'))
        .where((argument) => argument.isNotEmpty)
        .toList();
    if (arguments.any((argument) => argument.startsWith('--from='))) continue;

    final sources = arguments
        .where((argument) => !argument.startsWith('--'))
        .toList();
    // The last argument is the destination; everything before it is a source.
    if (sources.length < 2) continue;
    for (final source in sources.sublist(0, sources.length - 1)) {
      if (source == '.' || source == './') {
        wholeContext = true;
        continue;
      }
      if (RegExp(r'^([a-z0-9_]+)/').firstMatch(source) case final match?) {
        directories.add(match.group(1)!);
      }
    }
  }

  return (wholeContext: wholeContext, directories: directories);
}

/// Top-level directory patterns a `.dockerignore` lets back into the context:
/// names (`app`) or globs (`*_server`), as the file writes them.
///
/// A glob is how an ignore file avoids restating the package list at all —
/// `!*_server/` admits the server package whatever the project is called, so
/// the file has nothing to update when a package is added or renamed.
///
/// Returns null when the file is absent or does not deny by default — then
/// everything is in the context already and there is nothing to admit.
Set<String>? admittedBy(File ignoreFile) {
  if (!ignoreFile.existsSync()) return null;

  var deniesEverything = false;
  final admitted = <String>{};
  for (final raw in ignoreFile.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line == '**' || line == '*') deniesEverything = true;
    if (RegExp(r'^!([a-z0-9_*?]+)/').firstMatch(line) case final match?) {
      admitted.add(match.group(1)!);
    }
  }
  return deniesEverything ? admitted : null;
}

/// Whether [patterns], as [admittedBy] read them, admit [directory].
///
/// `*` and `?` as `.dockerignore` reads them within one path segment.
bool admits(Set<String> patterns, String directory) {
  for (final pattern in patterns) {
    final regex = RegExp(
      '^${pattern.split('').map((c) => switch (c) {
        '*' => '[^/]*',
        '?' => '[^/]',
        _ => RegExp.escape(c),
      }).join()}\$',
    );
    if (regex.hasMatch(directory)) return true;
  }
  return false;
}

/// Sibling packages [pubspec] depends on by path, by directory name.
///
/// Only paths that stay inside the project — the directory above the package.
/// One that leaves it is not a package to copy, since no `COPY` can reach it;
/// [outsideContextProblems] names it, and counting it here as well would
/// answer the same cause with advice that cannot work.
Set<String> pathDependenciesOf(File pubspec) {
  if (!pubspec.existsSync()) return const {};
  final document = loadYaml(pubspec.readAsStringSync());
  final dependencies = document is YamlMap ? document['dependencies'] : null;
  if (dependencies is! YamlMap) return const {};
  final packageDirectory = p.normalize(pubspec.absolute.parent.path);
  final projectRoot = p.dirname(packageDirectory);
  return {
    for (final MapEntry(:key, :value) in dependencies.entries)
      if (value is YamlMap && value['path'] is String)
        if (p.isWithin(
          projectRoot,
          p.normalize(p.join(packageDirectory, value['path'] as String)),
        ))
          key.toString(),
  };
}

/// Every sibling package an image for [package] has to carry, transitively.
///
/// Transitive because the graph is: the client is a path dependency of the
/// Flutter package, and whatever the client pulls in by path has to be in the
/// context too. A check that stopped at the first level would pass the case it
/// exists for.
Set<String> packagesNeededBy(Directory projectRoot, String package) {
  final pending = <String>{
    ...pathDependenciesOf(
      File(p.join(projectRoot.path, package, 'pubspec.yaml')),
    ),
  };
  final needed = <String>{};
  while (pending.isNotEmpty) {
    final name = pending.first;
    pending.remove(name);
    if (!needed.add(name)) continue;
    pending.addAll(
      pathDependenciesOf(File(p.join(projectRoot.path, name, 'pubspec.yaml'))),
    );
  }
  return needed;
}

/// Everything wrong with the build context of [packages], as sentences.
///
/// Empty means every package reaches every image that needs it. Pure over the
/// files it reads, so the rule is testable without standing up a deployment.
List<String> buildContextProblems({
  required Directory projectRoot,
  required Iterable<String> packages,
}) {
  final admitted = admittedBy(File(p.join(projectRoot.path, '.dockerignore')));
  final problems = <String>[];

  for (final package in packages) {
    final dockerfile = File(p.join(projectRoot.path, package, 'Dockerfile'));
    if (!dockerfile.existsSync()) continue;

    final reads = readsOf(dockerfile);
    final needed = packagesNeededBy(projectRoot, package)..add(package);

    // `COPY . .` takes the whole context, so nothing the Dockerfile names can
    // be missing — it names nothing. What the ignore file admits still decides
    // what "the whole context" contains, so that half is checked either way.
    if (!reads.wholeContext) {
      final uncopied = (needed.difference(reads.directories)).toList()..sort();
      if (uncopied.isNotEmpty) {
        problems.add(
          '$package/Dockerfile does not copy ${uncopied.join(', ')}',
        );
      }
    }

    if (admitted != null) {
      final wanted = reads.wholeContext ? needed : reads.directories;
      final excluded =
          wanted.where((directory) => !admits(admitted, directory)).toList()
            ..sort();
      if (excluded.isNotEmpty) {
        problems.add(
          '.dockerignore keeps ${excluded.join(', ')} out of the '
          '$package build context',
        );
      }
    }
  }

  return problems;
}

/// The pubspec sections `dart pub get` inside an image resolves.
///
/// `dev_dependencies` included: the template's Dockerfiles run a plain
/// `dart pub get`, which resolves them too, so a dev tool taken by path from
/// outside fails the build the same way a runtime dependency does.
const _resolvedSections = [
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// Whether [ignoreFile] keeps [package]'s `pubspec_overrides.yaml` out of the
/// context — by the name pub gives the file, on its own line.
bool _ignoresOverridesFile(File ignoreFile, String package) {
  if (!ignoreFile.existsSync()) return false;
  const name = 'pubspec_overrides.yaml';
  return ignoreFile
      .readAsLinesSync()
      .map((line) => line.trim())
      .any(
        (line) =>
            line == '**/$name' || line == '*/$name' || line == '$package/$name',
      );
}

/// Path dependencies of [packages] that point outside [projectRoot], as
/// sentences.
///
/// The build context is the project root and nothing above it, so such a
/// dependency cannot reach the image: `dart pub get` fails inside the build as
/// exit code 66 on a package it cannot find, while every checkout on the
/// author's machine resolves. It is the natural state of a project built
/// against an unpublished framework — a local checkout beside the project —
/// and `deploy run` is the wrong moment to learn it.
///
/// `pubspec_overrides.yaml` is read as well, unless `.dockerignore` keeps it
/// out: pub applies it wherever it finds it, the role-suffix allow-list admits
/// it with the rest of the package, and it is exactly where a local checkout is
/// meant to live.
List<String> outsideContextProblems({
  required Directory projectRoot,
  required Iterable<String> packages,
}) {
  final root = p.normalize(projectRoot.absolute.path);
  final ignoreFile = File(p.join(root, '.dockerignore'));
  final all = <String>{
    for (final package in packages) ...{
      package,
      ...packagesNeededBy(projectRoot, package),
    },
  }.toList()..sort();

  final problems = <String>[];
  for (final package in all) {
    final directory = p.join(root, package);
    final files = [
      (File(p.join(directory, 'pubspec.yaml')), _resolvedSections),
      if (!_ignoresOverridesFile(ignoreFile, package))
        (
          File(p.join(directory, 'pubspec_overrides.yaml')),
          const ['dependency_overrides'],
        ),
    ];
    for (final (file, sections) in files) {
      if (!file.existsSync()) continue;
      final document = loadYaml(file.readAsStringSync());
      if (document is! YamlMap) continue;
      for (final section in sections) {
        final entries = document[section];
        if (entries is! YamlMap) continue;
        for (final MapEntry(:key, :value) in entries.entries) {
          if (value is! YamlMap || value['path'] is! String) continue;
          final resolved = p.normalize(
            p.join(directory, value['path'] as String),
          );
          if (resolved == root || p.isWithin(root, resolved)) continue;
          problems.add(
            '$package/${p.basename(file.path)} takes $key from '
            '${value['path']}, outside the build context',
          );
        }
      }
    }
  }
  return problems;
}
