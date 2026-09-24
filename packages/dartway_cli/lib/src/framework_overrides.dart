// Points a created project at a local monorepo's framework packages by path.
//
// A project `dartway create` makes normally resolves the DartWay family from
// pub.dev (`^0.20.0`). `create --framework-path` is for building against a
// local checkout instead — this tree's own unreleased changes, or a fork —
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
/// two levels deep at most; a package's own `example/` is not a package of
/// the framework.
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
    for (final grandchild in child.listSync().whereType<Directory>()) {
      if (p.basename(grandchild.path) == 'example') continue;
      take(grandchild);
    }
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
    '# local checkout rather than pub.dev. Remove this block once the versions',
    '# above are published.',
    'dependency_overrides:',
    for (final MapEntry(key: name, value: directory) in overrides.entries) ...[
      '  $name:',
      "    path: '${directory.replaceAll("'", "''")}'",
    ],
  ];
}
