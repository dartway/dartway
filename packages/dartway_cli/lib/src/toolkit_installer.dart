import 'dart:io';

import 'package:path/path.dart' as p;

/// Installs the DartWay AI toolkit into a project's `.claude/` directory.
///
/// `.claude/` is a generated-but-committed artifact (like the Serverpod
/// client). Only MANAGED files are overwritten: `CLAUDE.md`, skills named
/// `dartway-*` and the `commit` / `dartway-audit` commands. Project-own
/// skills and commands are never touched.
class ToolkitInstaller {
  static const managedCommandFiles = ['commit.md', 'dartway-audit.md'];

  /// Copies the toolkit from [toolkitDir] into `<projectRoot>/.claude/`,
  /// substituting [tokens] in the managed markdown files.
  static Future<void> install({
    required Directory toolkitDir,
    required Directory projectRoot,
    required Map<String, String> tokens,
  }) async {
    final toolkitSkillsDir = Directory(p.join(toolkitDir.path, 'skills'));
    final toolkitCommandsDir = Directory(p.join(toolkitDir.path, 'commands'));
    final toolkitClaudeMd = File(p.join(toolkitDir.path, 'CLAUDE.md'));
    if (!toolkitSkillsDir.existsSync() ||
        !toolkitCommandsDir.existsSync() ||
        !toolkitClaudeMd.existsSync()) {
      throw StateError(
        'Toolkit at ${toolkitDir.path} is incomplete '
        '(expected skills/, commands/ and CLAUDE.md).',
      );
    }

    final claudeDir = Directory(p.join(projectRoot.path, '.claude'));
    final skillsDir = Directory(p.join(claudeDir.path, 'skills'));
    final commandsDir = Directory(p.join(claudeDir.path, 'commands'));

    _removeManagedFiles(claudeDir, skillsDir, commandsDir);
    skillsDir.createSync(recursive: true);
    commandsDir.createSync(recursive: true);

    final managedFiles = <File>[];
    for (final skillDir in toolkitSkillsDir.listSync().whereType<Directory>()) {
      final installedDir = Directory(
        p.join(skillsDir.path, p.basename(skillDir.path)),
      );
      managedFiles.addAll(_copyDirectory(skillDir, installedDir));
    }
    for (final commandFile in toolkitCommandsDir.listSync().whereType<File>()) {
      final installedFile = File(
        p.join(commandsDir.path, p.basename(commandFile.path)),
      );
      commandFile.copySync(installedFile.path);
      managedFiles.add(installedFile);
    }
    final installedClaudeMd = File(p.join(claudeDir.path, 'CLAUDE.md'));
    toolkitClaudeMd.copySync(installedClaudeMd.path);
    managedFiles.add(installedClaudeMd);

    _substituteTokens(managedFiles, tokens);

    _installNotesJournal(toolkitDir, projectRoot, tokens);
    _reportLegacyInstallerTraces(projectRoot);
  }

  /// Puts `dartway_notes.md` at the project root and git-ignores it.
  ///
  /// The one file the installer writes outside `.claude/`, and the only one it
  /// refuses to overwrite: the journal is where a project records what the
  /// framework got wrong, so its content is the project's, not ours. Without
  /// this step the practice exists only where somebody set it up by hand, which
  /// is exactly how the last one was lost.
  static void _installNotesJournal(
    Directory toolkitDir,
    Directory projectRoot,
    Map<String, String> tokens,
  ) {
    final template = File(p.join(toolkitDir.path, 'dartway_notes.md'));
    final journal = File(p.join(projectRoot.path, 'dartway_notes.md'));

    if (template.existsSync() && !journal.existsSync()) {
      template.copySync(journal.path);
      _substituteTokens([journal], tokens);
      stdout.writeln('Created dartway_notes.md (findings for the framework)');
    }

    _ignoreJournal(projectRoot);
  }

  static void _ignoreJournal(Directory projectRoot) {
    final gitignore = File(p.join(projectRoot.path, '.gitignore'));
    if (!gitignore.existsSync()) return;

    final lines = gitignore.readAsLinesSync();
    if (lines.any((line) => line.trim() == 'dartway_notes.md')) return;

    gitignore.writeAsStringSync(
      '\n# Findings to carry back into the DartWay monorepo — a local journal.\n'
      'dartway_notes.md\n',
      mode: FileMode.append,
    );
    stdout.writeln('Added dartway_notes.md to .gitignore');
  }

  /// The toolkit used to be installed by a shell script from a private
  /// repository, which left `tools/dw_claude_setup/` behind — usually as a
  /// gitlink with no `.gitmodules` entry, so `git submodule update` does not see
  /// it and `git status` says nothing while the folder sits there empty.
  ///
  /// Reported, never removed: taking it out means `git rm --cached` in somebody
  /// else's repository, and an installer that edits the git index is a
  /// different kind of tool than one that copies files.
  static void _reportLegacyInstallerTraces(Directory projectRoot) {
    final legacyDir = Directory(p.join(projectRoot.path, 'tools', 'dw_claude_setup'));
    if (!legacyDir.existsSync()) return;

    stdout.writeln(
      '\nLeftovers from the old shell installer are still in this project:\n'
      '  tools/dw_claude_setup/\n'
      'Nothing here needs it any more. To remove it:\n'
      '  git rm -r --cached tools/dw_claude_setup\n'
      '  rm -rf tools/dw_claude_setup\n'
      'and drop any .gitignore comment pointing at that path.',
    );
  }

  static void _removeManagedFiles(
    Directory claudeDir,
    Directory skillsDir,
    Directory commandsDir,
  ) {
    if (skillsDir.existsSync()) {
      for (final skillDir in skillsDir.listSync().whereType<Directory>()) {
        if (p.basename(skillDir.path).startsWith('dartway-')) {
          skillDir.deleteSync(recursive: true);
        }
      }
    }
    for (final commandFileName in managedCommandFiles) {
      final commandFile = File(p.join(commandsDir.path, commandFileName));
      if (commandFile.existsSync()) {
        commandFile.deleteSync();
      }
    }
    final claudeMd = File(p.join(claudeDir.path, 'CLAUDE.md'));
    if (claudeMd.existsSync()) {
      claudeMd.deleteSync();
    }
  }

  static List<File> _copyDirectory(Directory source, Directory target) {
    target.createSync(recursive: true);
    final copiedFiles = <File>[];
    for (final entity in source.listSync(recursive: true)) {
      final relativePath = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relativePath);
      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        File(targetPath).parent.createSync(recursive: true);
        entity.copySync(targetPath);
        copiedFiles.add(File(targetPath));
      }
    }
    return copiedFiles;
  }

  static void _substituteTokens(List<File> files, Map<String, String> tokens) {
    for (final file in files) {
      if (!file.path.endsWith('.md')) {
        continue;
      }
      var content = file.readAsStringSync();
      var changed = false;
      tokens.forEach((token, value) {
        if (content.contains(token)) {
          content = content.replaceAll(token, value);
          changed = true;
        }
      });
      if (changed) {
        file.writeAsStringSync(content);
      }
    }
  }
}
