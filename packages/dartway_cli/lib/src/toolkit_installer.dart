import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Installs the DartWay AI toolkit into a project's `.claude/` directory.
///
/// `.claude/` is a generated-but-committed artifact (like the Serverpod
/// client). Only MANAGED files are overwritten: `CLAUDE.md`, skills named
/// `dartway-*` and the `commit` / `dartway-checkup` commands. Project-own
/// skills and commands are never touched. `settings.json` is a third kind —
/// a toolkit default the project extends — and is merged rather than
/// overwritten or skipped; see [_installSettings].
class ToolkitInstaller {
  /// Removed before every install, then re-copied from the toolkit — so a
  /// command that has been retired disappears from a project instead of
  /// lingering as a stale `/slash` nobody maintains.
  ///
  /// `dartway-audit.md` stays on the list for exactly that reason: the toolkit
  /// no longer contains it, and this entry is what clears it out of the
  /// projects that still have it. A retired name is removed from here only once
  /// no project can still be carrying it.
  static const managedCommandFiles = [
    'commit.md',
    'dartway-checkup.md',
    'dartway-audit.md',
  ];

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

    _installSettings(toolkitDir, claudeDir);
    _installDevNotes(toolkitDir, projectRoot, tokens);
    _reportRetiredJournals(projectRoot);
    _reportLegacyInstallerTraces(projectRoot);
  }

  /// Brings `.claude/settings.json` up to date, keeping whatever the project
  /// added to it.
  ///
  /// It pre-approves the build commands of this stack — `dart pub get`,
  /// `docker compose up`, `serverpod generate`, the test runners — so that
  /// bringing a fresh project up is not a queue of permission prompts, and it
  /// denies reading `config/passwords.yaml`, turning a rule the skills merely
  /// state into one the harness enforces. Nothing destructive is on the list:
  /// `docker compose down`, commits and pushes still ask.
  ///
  /// **The third kind of file, and the reason this is a merge.** The installer
  /// otherwise deals in two: a *managed* file is the toolkit's and is
  /// overwritten (`CLAUDE.md`, the skills — the project has nothing in them to
  /// lose), and a *project* file is the project's and is never touched
  /// (`docs/dev_notes/_coverage.md` — the toolkit has no opinion on its
  /// contents). This one is neither: it is a toolkit default that the project
  /// *extends*. Treating it as a project file, which is what it used to be,
  /// picks one half of that and drops the other — a changed default reached
  /// existing projects only if somebody deleted the file first, and a new
  /// `deny` rule reached none of them at all, which is the half the harness is
  /// supposed to enforce rather than merely state.
  ///
  /// So: entries the template has and the project lacks are added, everything
  /// the project added stays, and **every added entry is printed**. That last
  /// part is not decoration. The one real cost of merging is a project that
  /// removed an entry *on purpose* — dropping `Bash(curl:*)`, say — and would
  /// have it quietly returned. Printing turns that into something visible in
  /// the same run rather than a discovery months later.
  ///
  /// A file that is not valid JSON is left exactly as it is and reported: an
  /// installer that rewrites something it could not read is worse than one that
  /// skips it.
  static void _installSettings(Directory toolkitDir, Directory claudeDir) {
    final template = File(p.join(toolkitDir.path, 'settings.json'));
    if (!template.existsSync()) return;

    final settings = File(p.join(claudeDir.path, 'settings.json'));
    if (!settings.existsSync()) {
      template.copySync(settings.path);
      stdout.writeln(
        'Created .claude/settings.json (pre-approved dev commands)',
      );
      return;
    }

    // Read as an object or not at all. `jsonDecode` answers `[]` and `42`
    // without complaint, and casting those would throw a `TypeError` past the
    // `FormatException` guard — a crash, which is the one outcome this whole
    // branch exists to avoid.
    final templateJson = _settingsObject(template);
    final projectJson = _settingsObject(settings);
    if (templateJson == null) return;
    if (projectJson == null) {
      stdout.writeln(
        '.claude/settings.json is not a JSON object and was left untouched.',
      );
      return;
    }

    final added = _mergeSettings(templateJson, projectJson);
    if (added.isEmpty) return;

    settings.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(projectJson)}\n',
    );
    stdout.writeln('Updated .claude/settings.json:');
    for (final entry in added) {
      stdout.writeln('  + $entry');
    }
  }

  /// The file's contents as a JSON object, or null when it is anything else —
  /// unparseable, or parseable but a list, a number or a string.
  static Map<String, dynamic>? _settingsObject(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Adds what [template] has and [project] lacks, in place, and answers with
  /// what was added — `permissions.allow: Bash(...)` and the like.
  ///
  /// Lists are merged as sets while keeping the project's order first, so an
  /// update reads as an addition rather than as a reshuffle. A value the
  /// project already holds under a key is never replaced: the template seeds
  /// defaults, it does not overrule decisions.
  static List<String> _mergeSettings(
    Map<String, dynamic> template,
    Map<String, dynamic> project,
  ) {
    final added = <String>[];

    void mergeInto(
      Map<String, dynamic> from,
      Map<String, dynamic> into,
      String path,
    ) {
      for (final key in from.keys) {
        final incoming = from[key];
        final existing = into[key];
        final where = path.isEmpty ? key : '$path.$key';

        if (incoming is Map<String, dynamic>) {
          if (existing is! Map<String, dynamic>) {
            if (existing == null) {
              into[key] = incoming;
              added.add(where);
            }
            continue;
          }
          mergeInto(incoming, existing, where);
        } else if (incoming is List) {
          if (existing is! List) {
            if (existing == null) {
              into[key] = incoming;
              added.add(where);
            }
            continue;
          }
          for (final value in incoming) {
            if (existing.contains(value)) continue;
            existing.add(value);
            added.add('$where: $value');
          }
        } else if (existing == null) {
          into[key] = incoming;
          added.add('$where: $incoming');
        }
      }
    }

    mergeInto(template, project, '');
    return added;
  }

  /// Creates `docs/dev_notes/` — the project's own findings, one file per
  /// entry, tracked like any other file in the repository.
  ///
  /// The only place the installer writes outside `.claude/`. It used to put two
  /// git-ignored journals at the project root, and being ignored is what broke
  /// them: a finding written into one never travelled out through a pull
  /// request, never appeared in review, and `git worktree remove` deleted it
  /// without a word, because `git status` says nothing about ignored files.
  ///
  /// Two files, because they answer to different owners. [_devNotesForm] is the
  /// toolkit's — what the directory is and how an entry is written — so it is
  /// overwritten on every install, like the skills; there is no project content
  /// in it to lose. [_devNotesCoverage] is the project's own record of which
  /// features `/dartway-checkup` has read, so it is created once and never
  /// touched again.
  ///
  /// A finding about the *framework* goes in neither: it is filed straight as an
  /// issue in the tracker named by `__NOTES_TRACKER__`. One that belongs to a
  /// single feature is a line in that feature's `knownIssues`, next to the code.
  static const _devNotesForm = 'README.md';
  static const _devNotesCoverage = '_coverage.md';

  static void _installDevNotes(
    Directory toolkitDir,
    Directory projectRoot,
    Map<String, String> tokens,
  ) {
    final templateDir = Directory(p.join(toolkitDir.path, 'dev_notes'));
    if (!templateDir.existsSync()) return;

    final devNotesDir = Directory(p.join(projectRoot.path, 'docs', 'dev_notes'))
      ..createSync(recursive: true);

    for (final fileName in const [_devNotesForm, _devNotesCoverage]) {
      final template = File(p.join(templateDir.path, fileName));
      final installed = File(p.join(devNotesDir.path, fileName));
      if (!template.existsSync()) continue;
      if (fileName == _devNotesCoverage && installed.existsSync()) continue;

      final existed = installed.existsSync();
      template.copySync(installed.path);
      _substituteTokens([installed], tokens);
      if (!existed) {
        stdout.writeln('Created docs/dev_notes/$fileName');
      }
    }
  }

  /// Reports the two journals the `docs/dev_notes/` directory replaced.
  ///
  /// Reported, never removed, and for the same reason as the journals were
  /// worth replacing: they hold findings nobody else has a copy of. Deleting
  /// them would take that content with it, and leaving them unmentioned is the
  /// failure this change ends — a file that looks like the project's journal,
  /// which nothing reads any more.
  static void _reportRetiredJournals(Directory projectRoot) {
    final retired = ['dartway_notes.md', 'dev_notes.md']
        .where((name) => File(p.join(projectRoot.path, name)).existsSync())
        .toList();
    if (retired.isEmpty) return;

    stdout.writeln(
      '\nRetired root journals are still in this project:\n'
      '  ${retired.join('\n  ')}\n'
      'Nothing reads them any more. Framework findings are filed as issues in '
      'the notes tracker;\nthe project\'s own findings are one file each under '
      'docs/dev_notes/. Carry the open\nentries over, then delete the files and '
      'their .gitignore lines — the migration entry\nin .claude/CLAUDE.md says '
      'how.',
    );
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
    final legacyDir = Directory(
      p.join(projectRoot.path, 'tools', 'dw_claude_setup'),
    );
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
