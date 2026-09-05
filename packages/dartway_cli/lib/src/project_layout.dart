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
    '__CLIENT_PKG__': clientPackage,
    '__SHARED_PKG__': sharedPackage ?? '',
    '__BASE_BRANCH__': baseBranch,
  };
}
