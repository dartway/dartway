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

/// Top-level directories a `.dockerignore` lets back into the context.
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
    if (RegExp(r'^!([a-z0-9_]+)/').firstMatch(line) case final match?) {
      admitted.add(match.group(1)!);
    }
  }
  return deniesEverything ? admitted : null;
}

/// Sibling packages [pubspec] depends on by path, by directory name.
Set<String> pathDependenciesOf(File pubspec) {
  if (!pubspec.existsSync()) return const {};
  final document = loadYaml(pubspec.readAsStringSync());
  final dependencies = document is YamlMap ? document['dependencies'] : null;
  if (dependencies is! YamlMap) return const {};
  return {
    for (final entry in dependencies.entries)
      if (entry.value is YamlMap && (entry.value as YamlMap)['path'] != null)
        entry.key.toString(),
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
      final excluded = (wanted.difference(admitted)).toList()..sort();
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
