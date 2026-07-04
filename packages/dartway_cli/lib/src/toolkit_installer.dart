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
    for (final commandFile in toolkitCommandsDir
        .listSync()
        .whereType<File>()) {
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
