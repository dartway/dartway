import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'checker/dw_framework_lock.dart';
import 'version_check.dart';

/// Where one framework package stands in a project, against what the framework
/// currently has.
class DwPackageGap {
  DwPackageGap({
    required this.name,
    required this.projectVersion,
    required this.frameworkVersion,
    required this.locations,
    required this.fromGit,
  });

  final String name;

  /// The version the project resolves today. When the project holds several
  /// copies of the same package — a Flutter lock and a server lock — this is
  /// the **lowest** of them: a project is only as updated as its oldest half,
  /// and it is the oldest half that decides which migrations still apply.
  final String projectVersion;

  final String frameworkVersion;

  /// Every `pubspec.lock` the package was found in, sorted. The fix is a
  /// command run in a particular directory, so naming the directories is the
  /// difference between a report and an instruction.
  final List<String> locations;

  /// Whether the project takes this package from git rather than pub.dev.
  /// A hosted package moves by raising a caret; a git one moves by
  /// `dart pub upgrade`, and the two are not the same instruction.
  final bool fromGit;

  bool get isBehind => !isAtLeastVersion(projectVersion, frameworkVersion);

  bool get isAhead =>
      !isBehind && !isAtLeastVersion(frameworkVersion, projectVersion);
}

/// The version of every `dartway_*` package in a monorepo checkout, read from
/// the packages themselves.
///
/// The checkout is the authority rather than pub.dev on purpose: this is the
/// answer to "what would I get by moving to this channel", and a channel is a
/// tree. What is published is a separate question, and a separate check
/// (`tool/caret_check.dart`) already asks it.
Map<String, String> readFrameworkVersions(Directory monorepoDir) {
  final versions = <String, String>{};
  final packagesDir = Directory(p.join(monorepoDir.path, 'packages'));
  if (!packagesDir.existsSync()) return versions;

  void take(Directory dir) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return;
    final Object? document;
    try {
      document = loadYaml(pubspec.readAsStringSync());
    } on YamlException {
      return;
    }
    if (document is! YamlMap) return;
    final name = document['name'];
    final version = document['version'];
    if (name is! String || !name.startsWith('dartway_')) return;
    if (version is! String || version.isEmpty) return;
    versions[name] = version;
  }

  // Two levels, because the multi-package modules (the core, push, offline)
  // keep their packages one directory deeper than the single ones.
  for (final child in packagesDir.listSync().whereType<Directory>()) {
    take(child);
    for (final grandchild in child.listSync().whereType<Directory>()) {
      take(grandchild);
    }
  }

  return versions;
}

/// What the project resolves for each `dartway_*` package, lowest copy wins.
///
/// Read from the lock files rather than from `pubspec.yaml`: a caret says what
/// is allowed, and the question here is what is actually in the tree. It is
/// also the only form in which a git dependency answers at all — pub writes the
/// pinned commit's own `version:` into the lock.
Map<String, DwLockedFrameworkPackage> readProjectFrameworkVersions(
  Directory projectRoot,
) {
  final lowest = <String, DwLockedFrameworkPackage>{};
  for (final lockFile in projectLockFiles(projectRoot)) {
    final locked = readLockedFrameworkPackages(
      lockContents: lockFile.readAsStringSync(),
      location: p.basename(lockFile.parent.path),
    );
    for (final package in locked) {
      final known = lowest[package.name];
      if (known == null || !isAtLeastVersion(package.version, known.version)) {
        lowest[package.name] = package;
      }
    }
  }
  return lowest;
}

/// The project's framework packages against the framework's own versions.
///
/// Only packages the project actually depends on appear: what the framework
/// carries and the project never asked for is not a gap, and listing it would
/// bury the three lines that are.
List<DwPackageGap> compareToFramework({
  required Directory projectRoot,
  required Map<String, String> frameworkVersions,
}) {
  final project = readProjectFrameworkVersions(projectRoot);
  final locations = <String, Set<String>>{};
  final fromGit = <String, bool>{};
  for (final lockFile in projectLockFiles(projectRoot)) {
    for (final package in readLockedFrameworkPackages(
      lockContents: lockFile.readAsStringSync(),
      location: p.basename(lockFile.parent.path),
    )) {
      locations.putIfAbsent(package.name, () => {}).add(package.location);
      fromGit[package.name] = (fromGit[package.name] ?? false) || package.isGit;
    }
  }

  final gaps = <DwPackageGap>[];
  for (final entry in project.entries) {
    final frameworkVersion = frameworkVersions[entry.key];
    if (frameworkVersion == null) continue;
    gaps.add(
      DwPackageGap(
        name: entry.key,
        projectVersion: entry.value.version,
        frameworkVersion: frameworkVersion,
        locations: (locations[entry.key]?.toList() ?? [])..sort(),
        fromGit: fromGit[entry.key] ?? false,
      ),
    );
  }
  gaps.sort((a, b) => a.name.compareTo(b.name));
  return gaps;
}
