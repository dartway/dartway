import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'dw_check_type.dart';
import 'dw_framework_lock.dart';
import 'dw_check_tally.dart';

/// Reports a `dependency_overrides` pin on a framework package that the
/// framework has caught up with (D-032).
///
/// Satellites version on their own, and the core raises its caret on one only
/// in its own next minor. A project that needs a satellite sooner overrides
/// it — and the override stays after the core's raise, silently overruling
/// every later one: the next satellite release the core asks for is held back
/// by a line nobody remembers writing.
///
/// For each package of the project, an override that is a version constraint
/// on a `dartway_*` package is compared with the constraints that the resolved
/// `dartway_*` packages depending on it declare. When one of them already allows
/// the version the lock resolved, the override is doing nothing the framework
/// would not do, and it is reported. Path and git overrides are left alone: they
/// point at a checkout — building against a local framework, vendoring — and say
/// nothing about versions.
class DwFrameworkOverridesInspector {
  DwFrameworkOverridesInspector({
    required this.projectRoot,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _enabled =
           (filterType == null ||
               filterType == DwCheckType.frameworkOverrideOutlived) &&
           (filterSeverity == null ||
               filterSeverity ==
                   DwCheckType.frameworkOverrideOutlived.severity);

  final Directory projectRoot;
  final bool _enabled;
  final _findings = <String>[];

  List<String> get findings => List.unmodifiable(_findings);

  int run({DwCheckTally? tally}) {
    if (!_enabled) return 0;
    _collectFindings();
    if (_findings.isEmpty) return 0;
    print('\n📌 Framework overrides:\n');
    for (final finding in _findings) {
      print('  ${DwCheckType.frameworkOverrideOutlived.reportLabel}: $finding');
    }
    tally?.add(DwCheckType.frameworkOverrideOutlived, _findings.length);
    return DwCheckType.frameworkOverrideOutlived.severity ==
            DwCheckSeverity.error
        ? _findings.length
        : 0;
  }

  void _collectFindings() {
    for (final lock in projectLockFiles(projectRoot)) {
      final packageDir = lock.parent;
      final location = p.basename(packageDir.path);
      final overrides = _versionOverrides(packageDir);
      if (overrides.isEmpty) continue;
      final resolved = {
        for (final package in readLockedFrameworkPackages(
          lockContents: lock.readAsStringSync(),
          location: location,
        ))
          package.name: package.version,
      };
      final installed = _installedPubspecs(packageDir);
      for (final MapEntry(key: name, value: constraint) in overrides.entries) {
        final version = _parseVersion(resolved[name]);
        if (version == null) continue;
        final allowedBy = <String>[];
        for (final MapEntry(key: dependent, value: pubspec)
            in installed.entries) {
          if (dependent == name) continue;
          final declared = _constraintOn(pubspec, name);
          if (declared != null && declared.allows(version)) {
            allowedBy.add('$dependent (`$name: $declared`)');
          }
        }
        if (allowedBy.isEmpty) continue;
        allowedBy.sort();
        _findings.add(
          '$location overrides `$name: $constraint`, and the resolved '
          '$version is already allowed by ${allowedBy.join(', ')}. The '
          'framework has caught up: remove the override from '
          '$location/pubspec.yaml and run `dart pub get`, or the next release '
          'the framework asks for will be held back by it',
        );
      }
    }
  }

  /// `dartway_*` overrides of [packageDir] that are version constraints.
  static Map<String, VersionConstraint> _versionOverrides(
    Directory packageDir,
  ) {
    final file = File(p.join(packageDir.path, 'pubspec.yaml'));
    if (!file.existsSync()) return const {};
    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException {
      return const {};
    }
    final overrides = document is YamlMap
        ? document['dependency_overrides']
        : null;
    if (overrides is! YamlMap) return const {};
    return {
      for (final MapEntry(:key, :value) in overrides.entries)
        if (key is String && key.startsWith('dartway_') && value is String)
          if (_parseConstraint(value) case final constraint?) key: constraint,
    };
  }

  /// The pubspecs of the resolved `dartway_*` packages, from the package
  /// config nearest [packageDir] (a workspace keeps one at its root).
  static Map<String, YamlMap> _installedPubspecs(Directory packageDir) {
    var dir = packageDir.absolute;
    File? config;
    while (true) {
      final candidate = File(
        p.join(dir.path, '.dart_tool', 'package_config.json'),
      );
      if (candidate.existsSync()) {
        config = candidate;
        break;
      }
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
    if (config == null) return const {};
    final Object? json;
    try {
      json = jsonDecode(config.readAsStringSync());
    } on FormatException {
      return const {};
    }
    final packages = json is Map ? json['packages'] : null;
    if (packages is! List) return const {};
    final pubspecs = <String, YamlMap>{};
    for (final entry in packages) {
      if (entry is! Map) continue;
      final name = entry['name'];
      final rootUri = entry['rootUri'];
      if (name is! String ||
          !name.startsWith('dartway_') ||
          rootUri is! String) {
        continue;
      }
      final root = Uri.parse(rootUri);
      final path = root.hasScheme
          ? root.toFilePath()
          : p.normalize(p.join(config.parent.path, root.toFilePath()));
      final pubspec = File(p.join(path, 'pubspec.yaml'));
      if (!pubspec.existsSync()) continue;
      try {
        final document = loadYaml(pubspec.readAsStringSync());
        if (document is YamlMap) pubspecs[name] = document;
      } on YamlException {
        continue;
      }
    }
    return pubspecs;
  }

  static VersionConstraint? _constraintOn(YamlMap pubspec, String name) {
    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap) return null;
    final value = dependencies[name];
    return value is String ? _parseConstraint(value) : null;
  }

  static VersionConstraint? _parseConstraint(String text) {
    try {
      return VersionConstraint.parse(text);
    } on FormatException {
      return null;
    }
  }

  static Version? _parseVersion(String? text) {
    if (text == null) return null;
    try {
      return Version.parse(text);
    } on FormatException {
      return null;
    }
  }
}
