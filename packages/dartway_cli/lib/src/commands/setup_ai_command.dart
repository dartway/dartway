import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../monorepo_source.dart';
import '../project_layout.dart';
import '../toolkit_installer.dart';

/// Installs or updates the DartWay AI toolkit (`.claude/`) in the current
/// project. Replaces the legacy `setup-claude.sh` / `.ps1` scripts.
class SetupAiCommand extends Command<int> {
  SetupAiCommand() {
    argParser
      ..addOption(
        'base-branch',
        defaultsTo: 'master',
        help: 'Base branch of THIS project (used by PR/commit skills).',
      )
      ..addOption(
        'language',
        defaultsTo: 'English',
        help:
            "Language this project writes its own texts in (feature specs, doc "
            "comments, dartway_notes.md). Package APIs and error strings stay "
            "English regardless.",
      )
      ..addOption(
        'notes-tracker',
        valueHelp: 'owner/repo',
        defaultsTo: ProjectLayout.defaultNotesTracker,
        help:
            'GitHub repository where findings about the framework are filed as '
            'issues. Pass "${ProjectLayout.noNotesTracker}" to keep the '
            'journal local instead.',
      )
      ..addOption(
        'channel',
        defaultsTo:
            Platform.environment['DARTWAY_BRANCH'] ??
            MonorepoSource.defaultBranch,
        help: 'DartWay monorepo branch to take the toolkit from.',
      )
      ..addOption(
        'local-repo',
        help:
            'Path to a local DartWay monorepo checkout '
            '(skips clone; also read from DARTWAY_MONOREPO_DIR).',
      );
  }

  @override
  String get name => 'setup-ai';

  @override
  String get description =>
      'Install or update the DartWay AI toolkit (.claude/) in the current project.';

  @override
  Future<int> run() async {
    final projectRoot = _findProjectRoot();
    final layout = ProjectLayout.detect(projectRoot);
    final baseBranch = argResults!['base-branch'] as String;
    final language = argResults!['language'] as String;
    final notesTracker = argResults!['notes-tracker'] as String;

    stdout.writeln(
      'Packages: server=${layout.serverPackage} '
      'flutter=${layout.flutterPackage} '
      'client=${layout.clientPackage} '
      'shared=${layout.sharedPackage ?? '<none>'}',
    );
    stdout.writeln('Base branch: $baseBranch');
    stdout.writeln('Project language: $language');
    stdout.writeln(
      notesTracker == ProjectLayout.noNotesTracker
          ? 'Notes tracker: none — the journal stays local'
          : 'Notes tracker: $notesTracker',
    );

    final monorepoDir = await MonorepoSource(
      branch: argResults!['channel'] as String,
      localDir: argResults!['local-repo'] as String?,
    ).resolve();

    await ToolkitInstaller.install(
      toolkitDir: Directory(p.join(monorepoDir.path, 'toolkit')),
      projectRoot: projectRoot,
      tokens: layout.toolkitTokens(
        baseBranch: baseBranch,
        language: language,
        notesTracker: notesTracker,
      ),
    );

    stdout.writeln(
      'Done: .claude/CLAUDE.md, skills and commands installed. '
      'Commit .claude/ to your repository.',
    );
    return 0;
  }

  Directory _findProjectRoot() {
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
}
