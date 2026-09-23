import 'dart:io';

import 'package:path/path.dart' as p;

/// The project root: the repository, or the working directory when there is no
/// repository around it.
///
/// Top-level because more than one command needs the same answer, and two
/// commands resolving it apart would install into one directory what they
/// report about another.
Directory findProjectRoot() {
  final gitResult = Process.runSync('git', [
    'rev-parse',
    '--show-toplevel',
  ], runInShell: true);
  if (gitResult.exitCode == 0) {
    final gitRoot = (gitResult.stdout as String).trim();
    if (gitRoot.isNotEmpty) {
      return Directory(gitRoot);
    }
  }
  return Directory.current;
}

/// The DartWay project [start] is in: the nearest directory at or above it
/// that holds `*_server` / `*_shared` packages, or is one of them.
///
/// Separate from [findProjectRoot], which answers the repository. A project
/// is not always the repository — a monorepo holds several — and a command
/// run from inside one of its packages must find the project, not the
/// checkout. `dart run dartway_cli:dartway <command>` is run from the package
/// that pins the CLI, which is exactly that case: `deploy` and `secret` read
/// `Directory.current` and told a person standing in their own Flutter
/// package that there was no DartWay project anywhere.
Directory? findPackageProjectRoot(Directory start) {
  var current = p.normalize(p.absolute(start.path));
  while (true) {
    final name = p.basename(current);
    if (_isRolePackageName(name) &&
        File(p.join(current, 'pubspec.yaml')).existsSync()) {
      final parent = p.dirname(current);
      // Inside a project, the root is the directory holding the packages.
      return Directory(_rolePackagesIn(parent).isNotEmpty ? parent : current);
    }
    if (_rolePackagesIn(current).isNotEmpty) return Directory(current);
    final parent = p.dirname(current);
    if (parent == current) return null;
    current = parent;
  }
}

bool _isRolePackageName(String name) =>
    name.endsWith('_shared') || name.endsWith('_server');

List<String> _rolePackagesIn(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync())
      if (entity is Directory &&
          _isRolePackageName(p.basename(entity.path)) &&
          File(p.join(entity.path, 'pubspec.yaml')).existsSync())
        entity.path,
  ];
}

/// DartWay project layout: three sibling Dart packages in the project root
/// whose role is defined by the directory name suffix — `*_server`,
/// `*_flutter` and `*_shared`, the contract both of them speak.
///
/// All three are required. A project without its shared package has no
/// contract to generate, and every token the agent toolkit names a package by
/// has to name a real one: an empty `__SHARED_PKG__` turned the skills' paths
/// into `/lib/src/`.
class ProjectLayout {
  ProjectLayout({
    required this.root,
    required this.serverPackage,
    required this.flutterPackage,
    required this.sharedPackage,
  });

  final Directory root;
  final String serverPackage;
  final String flutterPackage;
  final String sharedPackage;

  Directory get sharedPackageDir => Directory(p.join(root.path, sharedPackage));

  Directory get flutterPackageDir =>
      Directory(p.join(root.path, flutterPackage));

  Directory get serverPackageDir => Directory(p.join(root.path, serverPackage));

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
      flutterPackage: findBySuffix('flutter', required: true)!,
      sharedPackage: findBySuffix('shared', required: true)!,
    );
  }

  /// The app's wiring file — `main.dart`'s counterpart, holding `DwAppRunner`
  /// and the router. `create` renames the template's copy along with the
  /// package, so the name follows the project rather than being chosen.
  String get flutterAppFile =>
      '${flutterPackage.replaceAll(RegExp(r'_flutter$'), '')}_app.dart';

  /// Where a project's findings about the framework go unless it says
  /// otherwise: the framework's own public tracker.
  ///
  /// A default rather than a prompt, because the alternative was tried and it
  /// is what this whole mechanism exists to fix — a journal nobody had pointed
  /// anywhere is a journal whose entries stay on one laptop. Opting in would
  /// have meant every project deciding a question it has no reason to think
  /// about, and the projects that never decided are precisely the ones whose
  /// findings were lost.
  ///
  /// The literal lives here and not in `toolkit/`: the harness carries the
  /// token, so an installation that wants a different tracker changes one
  /// option instead of editing files it does not own.
  static const defaultNotesTracker = 'dartway/dartway';

  /// The opt-out, and the reason it is a word rather than an empty string.
  ///
  /// The token is substituted by plain text replacement into prose that has to
  /// keep reading correctly either way: "**Tracker:** `` " reads as a bug,
  /// "**Tracker:** `none`" reads as an answer, and the installed `CLAUDE.md`
  /// states what `none` means for the journal.
  static const noNotesTracker = 'none';

  Map<String, String> toolkitTokens({
    required String baseBranch,
    String language = 'English',
    String? notesTracker,
  }) => {
    '__PROJECT_LANGUAGE__': language,
    '__NOTES_TRACKER__': notesTracker ?? defaultNotesTracker,
    '__SERVER_PKG__': serverPackage,
    '__FLUTTER_PKG__': flutterPackage,
    '__FLUTTER_APP_FILE__': flutterAppFile,
    '__SHARED_PKG__': sharedPackage,
    '__BASE_BRANCH__': baseBranch,
  };
}
