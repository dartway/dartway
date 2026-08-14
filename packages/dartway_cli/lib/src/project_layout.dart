import 'dart:io';

import 'package:path/path.dart' as p;

/// DartWay project layout: sibling Dart packages in the project root whose
/// role is defined by the directory name suffix (`*_server`, `*_client`,
/// `*_flutter`, optional `*_shared`).
class ProjectLayout {
  ProjectLayout({
    required this.root,
    required this.serverPackage,
    required this.clientPackage,
    required this.flutterPackage,
    this.sharedPackage,
  });

  final Directory root;
  final String serverPackage;
  final String clientPackage;
  final String flutterPackage;
  final String? sharedPackage;

  Directory get flutterPackageDir =>
      Directory(p.join(root.path, flutterPackage));

  Directory get serverPackageDir => Directory(p.join(root.path, serverPackage));

  Directory get clientPackageDir => Directory(p.join(root.path, clientPackage));

  static ProjectLayout detect(Directory root) {
    String? findBySuffix(String suffix, {required bool required}) {
      final matches = root
          .listSync()
          .whereType<Directory>()
          .map((directory) => p.basename(directory.path))
          .where((directoryName) => directoryName.endsWith('_$suffix'))
          .toList();
      if (matches.length == 1) {
        return matches.single;
      }
      if (matches.isEmpty) {
        if (required) {
          throw StateError(
            'No *_$suffix package found in ${root.path}. '
            'Run this command from a DartWay project root.',
          );
        }
        return null;
      }
      throw StateError(
        'Ambiguous layout: several *_$suffix packages in ${root.path}.',
      );
    }

    return ProjectLayout(
      root: root,
      serverPackage: findBySuffix('server', required: true)!,
      clientPackage: findBySuffix('client', required: true)!,
      flutterPackage: findBySuffix('flutter', required: true)!,
      sharedPackage: findBySuffix('shared', required: false),
    );
  }

  /// The app's wiring file — `main.dart`'s counterpart, holding `DwAppRunner`
  /// and the router. `create` renames the template's copy along with the
  /// package, so the name follows the project rather than being chosen.
  String get flutterAppFile =>
      '${flutterPackage.replaceAll(RegExp(r'_flutter$'), '')}_app.dart';

  Map<String, String> toolkitTokens({
    required String baseBranch,
    String language = 'English',
  }) => {
    '__PROJECT_LANGUAGE__': language,
    '__SERVER_PKG__': serverPackage,
    '__FLUTTER_PKG__': flutterPackage,
    '__FLUTTER_APP_FILE__': flutterAppFile,
    '__CLIENT_PKG__': clientPackage,
    '__SHARED_PKG__': sharedPackage ?? '',
    '__BASE_BRANCH__': baseBranch,
  };
}
