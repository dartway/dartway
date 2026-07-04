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

  static ProjectLayout detect(Directory root) {
    String? findBySuffix(String suffix, {required bool required}) {
      final matches =
          root
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

  Map<String, String> toolkitTokens({required String baseBranch}) => {
    '__SERVER_PKG__': serverPackage,
    '__FLUTTER_PKG__': flutterPackage,
    '__CLIENT_PKG__': clientPackage,
    '__SHARED_PKG__': sharedPackage ?? '',
    '__BASE_BRANCH__': baseBranch,
  };
}
