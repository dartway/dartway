import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'diagnostic.dart';

/// What a package is for in a DartWay project, read from its name suffix.
enum DwPackageRole { shared, server, flutter }

/// One Dart package of the project.
final class DwPackage {
  const DwPackage({
    required this.root,
    required this.name,
    required this.role,
    required this.languageVersion,
  });

  final String root;
  final String name;
  final DwPackageRole role;

  /// From the package config, the version its libraries are formatted at.
  final Version languageVersion;

  String get lib => p.join(root, 'lib');

  /// The package name without its role suffix: `dartway_example_shared` →
  /// `dartway_example`. Registry and schema names are built from it.
  String get baseName {
    final suffix = '_${role.name}';
    return name.endsWith(suffix)
        ? name.substring(0, name.length - suffix.length)
        : name;
  }
}

/// Finds the packages of the project at [root]: its `*_shared`, `*_server`
/// and `*_flutter` packages, or [root] itself when it is one of them.
///
/// The role is read from the package name in `pubspec.yaml`, not from the
/// directory, because the name is what the registry variable is derived from.
List<DwPackage> detectPackages(String root, List<DwDiagnostic> diagnostics) {
  final candidates = <String>[
    if (File(p.join(root, 'pubspec.yaml')).existsSync())
      root
    else if (Directory(root).existsSync())
      for (final entity in Directory(root).listSync())
        if (entity is Directory &&
            File(p.join(entity.path, 'pubspec.yaml')).existsSync())
          entity.path,
  ]..sort();

  final packages = <DwPackage>[];
  for (final directory in candidates) {
    final pubspecFile = File(p.join(directory, 'pubspec.yaml'));
    final Object? pubspec;
    try {
      pubspec = loadYaml(pubspecFile.readAsStringSync());
    } on YamlException catch (error) {
      diagnostics.add(
        DwDiagnostic(
          'cannot read ${pubspecFile.path}: ${error.message}',
          path: pubspecFile.path,
          line: (error.span?.start.line ?? 0) + 1,
          column: (error.span?.start.column ?? 0) + 1,
        ),
      );
      continue;
    }
    final name = pubspec is YamlMap ? pubspec['name'] : null;
    if (name is! String) continue;
    final role = DwPackageRole.values
        .where((role) => name.endsWith('_${role.name}'))
        .firstOrNull;
    if (role == null) continue;
    final version = _languageVersion(directory, name);
    if (version == null) {
      diagnostics.add(
        DwDiagnostic(
          '$name has no resolved package config; run `dart pub get` in '
          '${p.normalize(directory)} first',
        ),
      );
      continue;
    }
    packages.add(
      DwPackage(
        root: p.normalize(p.absolute(directory)),
        name: name,
        role: role,
        languageVersion: version,
      ),
    );
  }

  if (packages.isEmpty && diagnostics.isEmpty) {
    diagnostics.add(
      DwDiagnostic(
        'no DartWay package in ${p.normalize(p.absolute(root))}: expected a '
        'project root holding *_shared and *_server packages, or one of them',
      ),
    );
  }
  for (final role in DwPackageRole.values) {
    final ofRole = packages.where((package) => package.role == role).toList();
    if (ofRole.length > 1) {
      diagnostics.add(
        DwDiagnostic(
          'several *_${role.name} packages in $root '
          '(${ofRole.map((package) => package.name).join(', ')}); a project '
          'has one',
        ),
      );
    }
  }
  return packages;
}

/// The language version of package [name], from the nearest package config
/// above [directory] (a workspace keeps one at its root).
Version? _languageVersion(String directory, String name) {
  var current = p.normalize(p.absolute(directory));
  while (true) {
    final config = File(p.join(current, '.dart_tool', 'package_config.json'));
    if (config.existsSync()) {
      final Object? json;
      try {
        json = jsonDecode(config.readAsStringSync());
      } on FormatException {
        return null;
      }
      if (json case {'packages': final List<Object?> entries}) {
        for (final entry in entries) {
          if (entry case {
            'name': final String entryName,
            'languageVersion': final String version,
          } when entryName == name) {
            return Version.parse('$version.0');
          }
        }
      }
      return null;
    }
    final parent = p.dirname(current);
    if (parent == current) return null;
    current = parent;
  }
}
