import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'dw_check_type.dart';

/// One `dartway_*` package as a `pubspec.lock` recorded it.
class DwLockedFrameworkPackage {
  DwLockedFrameworkPackage({
    required this.name,
    required this.url,
    required this.resolvedRef,
    required this.location,
  });

  final String name;

  /// The git repository it came from. Packages from different repositories are
  /// never compared: only refs of one repository are the same kind of thing.
  final String url;

  final String resolvedRef;

  /// The package whose `pubspec.lock` this entry was read from — where
  /// `dart pub upgrade` has to be run to move it.
  final String location;

  /// How a commit is named in a report. The full hash is unreadable and the
  /// first seven characters are what git itself prints.
  String get shortRef =>
      resolvedRef.length > 7 ? resolvedRef.substring(0, 7) : resolvedRef;

  @override
  String toString() => '$name in $location';
}

/// Reads the `dartway_*` git dependencies out of a `pubspec.lock`.
///
/// Only git entries are collected. A hosted dependency carries a version and
/// semver already answers the question this check asks; a path dependency is
/// someone debugging the framework and is deliberate.
List<DwLockedFrameworkPackage> readLockedFrameworkPackages({
  required String lockContents,
  required String location,
}) {
  final Object? document;
  try {
    document = loadYaml(lockContents);
  } on YamlException {
    // A lock file nobody can parse is not this check's finding to make.
    return const [];
  }

  if (document is! YamlMap) return const [];
  final packages = document['packages'];
  if (packages is! YamlMap) return const [];

  final locked = <DwLockedFrameworkPackage>[];
  for (final entry in packages.entries) {
    final name = entry.key;
    final body = entry.value;
    if (name is! String || !name.startsWith('dartway_')) continue;
    if (body is! YamlMap || body['source'] != 'git') continue;

    final description = body['description'];
    if (description is! YamlMap) continue;

    final url = description['url'];
    final resolvedRef = description['resolved-ref'];
    if (url is! String || resolvedRef is! String || resolvedRef.isEmpty) {
      continue;
    }

    locked.add(
      DwLockedFrameworkPackage(
        name: name,
        url: url,
        resolvedRef: resolvedRef,
        location: location,
      ),
    );
  }

  return locked;
}

/// Reports a project whose framework packages are locked to several commits at
/// once.
///
/// An app that consumes DartWay by git states `ref: master` on every package,
/// which reads as "all of it from master" and is not what the lock does: a git
/// dependency is pinned to a commit when it is *added*, and stays there until
/// something upgrades it by name. Add the core in March and the push module in
/// May and the project runs two framework releases against each other — with no
/// version numbers anywhere to make the gap visible, since a git dependency
/// shows none.
///
/// This is otherwise caught by eye, in a file nobody reads, and only after the
/// symptom (a client and a server disagreeing about a protocol, a widget
/// calling an API its own core does not have) has been chased somewhere else.
///
/// A warning rather than an error: the state is wrong but the code is not, and
/// what fixes it is a command rather than an edit.
class DwFrameworkLockInspector {
  DwFrameworkLockInspector({
    required this.projectRoot,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.frameworkRefsDiverged) &&
           (filterSeverity == null ||
               filterSeverity == DwCheckType.frameworkRefsDiverged.severity);

  final Directory projectRoot;

  final bool _enabled;
  final _findings = <String>[];

  /// The findings, in the order they were made. Exposed for the tests: the
  /// report is printed, but what the rule *said* is the thing worth asserting.
  List<String> get findings => List.unmodifiable(_findings);

  /// Runs the check and prints its section. Returns the number of
  /// error-severity findings — zero while this check is a warning, and correct
  /// on its own terms if that ever changes.
  int run() {
    if (!_enabled) return 0;

    _collectFindings();
    if (_findings.isEmpty) return 0;

    print('\n🔗 Framework lock:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.frameworkRefsDiverged.reportLabel}: $finding');
    }

    return DwCheckType.frameworkRefsDiverged.severity == DwCheckSeverity.error
        ? _findings.length
        : 0;
  }

  void _collectFindings() {
    final locked = <DwLockedFrameworkPackage>[];
    for (final lockFile in _lockFiles()) {
      locked.addAll(
        readLockedFrameworkPackages(
          lockContents: lockFile.readAsStringSync(),
          location: p.basename(lockFile.parent.path),
        ),
      );
    }
    if (locked.isEmpty) return;

    final byUrl = <String, List<DwLockedFrameworkPackage>>{};
    for (final package in locked) {
      byUrl.putIfAbsent(package.url, () => []).add(package);
    }

    for (final url in byUrl.keys.toList()..sort()) {
      final packages = byUrl[url]!;

      final byRef = <String, List<DwLockedFrameworkPackage>>{};
      for (final package in packages) {
        byRef.putIfAbsent(package.resolvedRef, () => []).add(package);
      }
      if (byRef.length < 2) continue;

      final groups = byRef.keys.toList()..sort();
      final spelledOut = groups
          .map(
            (ref) =>
                '${byRef[ref]!.first.shortRef} '
                '(${byRef[ref]!.map((package) => package.toString()).join(', ')})',
          )
          .join(', ');

      final locations = {for (final package in packages) package.location};

      _findings.add(
        'the dartway packages from $url are locked to ${byRef.length} '
        'different commits: $spelledOut. A git dependency is pinned at the '
        'moment it is added, so `ref: master` names a moving branch while the '
        'lock holds each package still — and a git dependency shows no version '
        'number, so nothing else makes the gap visible. Bring them together '
        'with `dart pub upgrade <the dartway packages>` in '
        '${(locations.toList()..sort()).join(', ')}, then run this check again',
      );
    }
  }

  /// The project's own lock files: the root's, and one per package beside it.
  /// A workspace keeps a single lock at the root and the per-package files are
  /// absent — both shapes are read the same way.
  List<File> _lockFiles() {
    final files = <File>[];

    void take(Directory dir) {
      final lock = File(p.join(dir.path, 'pubspec.lock'));
      if (lock.existsSync()) files.add(lock);
    }

    take(projectRoot);
    if (!projectRoot.existsSync()) return files;

    final children = projectRoot.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final child in children) {
      if (p.basename(child.path).startsWith('.')) continue;
      take(child);
    }

    return files;
  }
}
