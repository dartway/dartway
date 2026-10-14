// Points a created project at the framework packages from one immutable tree.
//
// A project `dartway create` makes normally pins the DartWay family to the
// template commit. `create --framework-path` uses a local checkout instead —
// this tree's own unreleased changes, or a fork —
// answering the question "does what this tree hands a stranger build, test
// and run?" by resolving the same pubspecs against the same tree the
// template was written against — the way the template itself resolves
// inside the monorepo, with absolute paths instead of `../../packages`.
//
// `tool/vendor_framework.dart` answers a neighbouring question for Docker,
// where a build context cannot reach a path outside the project and the
// packages have to be copied in.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'vendor_framework.dart';

/// The framework packages of [monorepo], by name → absolute directory.
///
/// Every `pubspec.yaml` under `packages/` whose name starts with `dartway_`,
/// one level deep; a package's own `example/` is not a package of the
/// framework.
Map<String, String> frameworkPackageDirectories(Directory monorepo) {
  final packagesDir = Directory(p.join(monorepo.path, 'packages'));
  if (!packagesDir.existsSync()) {
    throw StateError(
      'No packages/ in ${monorepo.path}: --framework-path names the root of a '
      'DartWay monorepo checkout.',
    );
  }
  final found = <String, String>{};
  void take(Directory dir) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return;
    final name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync())?.group(1);
    if (name == null || !name.startsWith('dartway_')) return;
    found[name] = p.normalize(dir.absolute.path);
  }

  for (final child in packagesDir.listSync().whereType<Directory>()) {
    take(child);
  }
  return found;
}

/// The overrides a project package with [pubspec] needs to resolve against
/// [packages] (`frameworkPackageDirectories`): every framework package it
/// reaches — its own dependencies and dev dependencies, and what those depend
/// on in turn — and nothing else.
///
/// A framework package's dev dependencies are not followed: pub never
/// resolves a dependency's dev dependencies, and an override for a package
/// nothing reaches only drags its pubspec (and its SDK constraints) into the
/// solve.
Map<String, String> frameworkOverridesFor(
  String pubspec,
  Map<String, String> packages,
) {
  final edges = {
    for (final MapEntry(key: name, value: directory) in packages.entries)
      name: dartwayDependenciesOf(
        File(p.join(directory, 'pubspec.yaml')).readAsStringSync(),
        includeDev: false,
      ),
  };
  final reached = reachableFrom(dartwayDependenciesOf(pubspec), edges);
  return {
    for (final name in reached.toList()..sort())
      if (packages[name] case final directory?) name: directory,
  };
}

/// [lines] of a pubspec without its `dependency_overrides` block, and without
/// the comment lines and blank lines directly above it.
List<String> withoutDependencyOverrides(List<String> lines) {
  final blockStart = lines.indexWhere(
    (line) => line.trimRight() == 'dependency_overrides:',
  );
  if (blockStart == -1) return lines;

  var start = blockStart;
  while (start > 0 &&
      (lines[start - 1].startsWith('#') || lines[start - 1].trim().isEmpty)) {
    start--;
  }
  // The block ends at the next top-level line (a key or a comment).
  var end = blockStart + 1;
  while (end < lines.length &&
      (lines[end].trim().isEmpty || lines[end].startsWith(' '))) {
    end++;
  }
  return [...lines.sublist(0, start), ...lines.sublist(end)];
}

/// [lines] with a `dependency_overrides` block naming [overrides] appended —
/// after removing any block already there.
List<String> withFrameworkOverrides(
  List<String> lines,
  Map<String, String> overrides,
) {
  final kept = withoutDependencyOverrides(lines);
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  if (overrides.isEmpty) return kept;
  return [
    ...kept,
    '',
    '# Written by `dartway create --framework-path`: the framework comes from a',
    '# local checkout rather than the immutable git commit.',
    'dependency_overrides:',
    for (final MapEntry(key: name, value: directory) in overrides.entries) ...[
      '  $name:',
      "    path: '${directory.replaceAll("'", "''")}'",
    ],
  ];
}

/// [lines] with overrides for the reached package [names], all pinned to the
/// same immutable DartWay repository [commit].
List<String> withFrameworkGitOverrides(
  List<String> lines,
  Iterable<String> names, {
  required String url,
  required String commit,
}) {
  final kept = withoutDependencyOverrides(lines);
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  final sorted = names.toList()..sort();
  if (sorted.isEmpty) return kept;
  return [
    ...kept,
    '',
    '# Written by `dartway create`: the framework is pinned to the template',
    '# commit.',
    '# `dartway update --target <sha>` moves this pin.',
    'dependency_overrides:',
    for (final name in sorted) ...[
      '  $name:',
      '    git:',
      '      url: $url',
      '      path: packages/$name',
      '      ref: $commit',
    ],
  ];
}

/// Moves `ref:` fields in framework git overrides, whatever they currently
/// name (a branch, a tag, or a quoted or unquoted commit).
String moveFrameworkGitOverrideRefs(String source, String commit) {
  final lines = source.split('\n');
  final start = lines.indexWhere((line) => line == 'dependency_overrides:');
  if (start < 0) return source;
  var inFrameworkEntry = false;
  for (var index = start + 1; index < lines.length; index++) {
    final line = lines[index];
    if (line.isNotEmpty && !line.startsWith(' ')) break;
    final entry = RegExp(r'^  (dartway_[a-z0-9_]+):$').firstMatch(line);
    if (entry != null) {
      inFrameworkEntry = true;
      continue;
    }
    if (RegExp(r'^  [A-Za-z_][A-Za-z0-9_]*:').hasMatch(line)) {
      inFrameworkEntry = false;
    }
    if (inFrameworkEntry) {
      final ref = RegExp(
        r'^(\s+ref:\s*)(["\x27]?)([^#\r\n]*?)(["\x27]?)(\s*(?:#.*)?)$',
      ).firstMatch(line);
      if (ref != null) {
        final openingQuote = ref.group(2)!;
        final closingQuote = ref.group(4)!;
        final matchingQuotes =
            openingQuote.isNotEmpty && openingQuote == closingQuote;
        lines[index] =
            '${ref.group(1)}${matchingQuotes ? openingQuote : ''}$commit'
            '${matchingQuotes ? closingQuote : ''}${ref.group(5)}';
      }
    }
  }
  return lines.join('\n');
}
