import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../monorepo_source.dart';
import '../project_layout.dart';
import '../toolkit_installer.dart';

/// Creates a new DartWay project from the `template/` skeleton of the monorepo:
/// copies it, renames `dartway_starter` to the project name, strips
/// monorepo-only `dependency_overrides` and installs the AI toolkit.
///
/// The skeleton is deliberately domain-free — auth, roles, navigation, the
/// admin panel and the UI kit, and no models of anyone else's business. The
/// full application built on it lives in `example/` of the monorepo, and is a
/// reference to read, not a project to inherit.
class CreateCommand extends Command<int> {
  CreateCommand() {
    argParser
      ..addOption(
        'channel',
        defaultsTo:
            Platform.environment['DARTWAY_BRANCH'] ??
            MonorepoSource.defaultBranch,
        help: 'DartWay monorepo branch to create the project from.',
      )
      ..addOption(
        'local-repo',
        help:
            'Path to a local DartWay monorepo checkout '
            '(skips clone; also read from DARTWAY_MONOREPO_DIR).',
      )
      ..addOption(
        'language',
        defaultsTo: 'English',
        help:
            "Language the new project writes its own texts in (feature specs, "
            "doc comments, dartway_notes.md).",
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
      ..addFlag(
        'git',
        defaultsTo: true,
        help: 'Initialize a git repository with an initial commit.',
      );
  }

  static const _sourceDirectory = 'template';
  static const _sourceProjectName = 'dartway_starter';
  static const _sourceProjectPascalName = 'DartwayStarter';

  static const _skippedDirectories = {
    '.dart_tool',
    'build',
    '.git',
    '.idea',
    '.fvm', // per-machine SDK cache; traversing its junction copies the whole Flutter SDK
    'ephemeral',
    'node_modules',
  };
  static const _skippedFiles = {'pubspec.lock'};

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a new DartWay project from the canonical template.';

  @override
  String get invocation => 'dartway create <project_name> | .';

  @override
  Future<int> run() async {
    final createInPlace = _requireSingleArgument() == '.';
    final projectName = createInPlace
        ? _projectNameFromCurrentDirectory()
        : _requireValidProjectName(_requireSingleArgument());
    final targetDir = createInPlace
        ? _requireEmptyCurrentDirectory()
        : _requireFreeSubdirectory(projectName);

    final monorepoDir = await MonorepoSource(
      branch: argResults!['channel'] as String,
      localDir: argResults!['local-repo'] as String?,
    ).resolve();
    final templateDir = Directory(p.join(monorepoDir.path, _sourceDirectory));
    if (!templateDir.existsSync()) {
      throw StateError(
        'No $_sourceDirectory/ found in monorepo at ${monorepoDir.path}',
      );
    }

    stdout.writeln('Creating $projectName from the DartWay template...');
    _copyProject(templateDir, targetDir, projectName);
    _rewritePubspecs(targetDir);

    final layout = ProjectLayout.detect(targetDir);
    _writeLocalPasswords(layout);
    await ToolkitInstaller.install(
      toolkitDir: Directory(p.join(monorepoDir.path, 'toolkit')),
      projectRoot: targetDir,
      tokens: layout.toolkitTokens(
        baseBranch: 'master',
        language: argResults!['language'] as String,
        notesTracker: argResults!['notes-tracker'] as String,
      ),
    );

    if (argResults!['git'] as bool) {
      _initGit(targetDir);
    }

    stdout
      ..writeln('')
      ..writeln('Project $projectName is ready.')
      ..writeln('');
    if (!createInPlace) {
      stdout.writeln('  cd $projectName');
    }
    stdout
      ..writeln('  dartway doctor        # is this machine ready?')
      ..writeln('  dartway quickstart    # what to do next, in full')
      ..writeln('')
      ..writeln(
        'Open the project in whatever AI assistant you use and ask it to bring '
        'the project',
      )
      ..writeln(
        'up: `dartway quickstart` prints everything it needs to know. Prefer '
        'your own hands?',
      )
      ..writeln('The same commands are in README.md.');
    return 0;
  }

  /// Gives the new project the local secrets it needs to run, from the
  /// committed example.
  ///
  /// The file itself is git-ignored, which is why the template cannot simply
  /// ship it: a project that carried its passwords file in Git would sooner or
  /// later carry a real password in it, and `dartway deploy check` fails on a
  /// tracked copy. Writing it here keeps `dartway create` → `dart run` working
  /// without that.
  void _writeLocalPasswords(ProjectLayout layout) {
    final configDir = Directory(p.join(layout.serverPackageDir.path, 'config'));
    final example = File(p.join(configDir.path, 'passwords.yaml.example'));
    final passwords = File(p.join(configDir.path, 'passwords.yaml'));
    if (!example.existsSync() || passwords.existsSync()) {
      return;
    }
    example.copySync(passwords.path);
    stdout.writeln(
      'Created ${p.relative(passwords.path, from: layout.root.path)} '
      '(local development secrets, not tracked by Git)',
    );
  }

  Directory _requireFreeSubdirectory(String projectName) {
    final targetDir = Directory(p.join(Directory.current.path, projectName));
    if (targetDir.existsSync()) {
      throw StateError('Directory already exists: ${targetDir.path}');
    }
    return targetDir;
  }

  /// `dartway create .` is for the shape people actually start in: an empty
  /// folder already open in an editor or an agent. Creating a subdirectory
  /// inside it buries the project one level below where the session is running.
  ///
  /// An initialized-but-empty git repository is allowed through, since that is
  /// how such a folder often arrives; anything else is refused rather than
  /// merged into — this command writes hundreds of files.
  Directory _requireEmptyCurrentDirectory() {
    final currentDir = Directory.current;
    final occupants = currentDir
        .listSync()
        .map((entity) => p.basename(entity.path))
        .where((name) => name != '.git')
        .toList();
    if (occupants.isNotEmpty) {
      throw StateError(
        'The current directory is not empty (${occupants.take(3).join(', ')}'
        '${occupants.length > 3 ? ', …' : ''}). '
        'Run `dartway create <name>` to create the project in a subdirectory.',
      );
    }
    return currentDir;
  }

  String _requireSingleArgument() {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Provide exactly one project name, or `.`.');
    }
    return rest.single;
  }

  /// With `.` the folder names the project, the way `flutter create .` does.
  /// A folder is allowed to be called `my-app` while a Dart package is not, so
  /// the obvious separators are converted rather than rejected.
  String _projectNameFromCurrentDirectory() {
    final directoryName = p.basename(Directory.current.absolute.path);
    final candidate = directoryName.toLowerCase().replaceAll(
      RegExp(r'[\s\-.]+'),
      '_',
    );
    if (!_isValidProjectName(candidate)) {
      usageException(
        'Cannot use "$directoryName" as a project name: it has to become three '
        'Dart package names, which must be lower_snake_case identifiers. '
        'Rename the folder, or run `dartway create <name>` from its parent.',
      );
    }
    return _rejectTemplateName(candidate);
  }

  String _requireValidProjectName(String projectName) {
    if (!_isValidProjectName(projectName)) {
      usageException(
        'Project name must be a lower_snake_case Dart identifier '
        '(got "$projectName").',
      );
    }
    return _rejectTemplateName(projectName);
  }

  bool _isValidProjectName(String candidate) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(candidate);

  String _rejectTemplateName(String projectName) {
    if (projectName == _sourceProjectName) {
      usageException('Pick a name other than "$_sourceProjectName".');
    }
    return projectName;
  }

  void _copyProject(Directory source, Directory target, String projectName) {
    final pascalName = _toPascalCase(projectName);
    target.createSync(recursive: true);

    for (final entity in source.listSync(recursive: true)) {
      final relativePath = p.relative(entity.path, from: source.path);
      final pathSegments = p.split(relativePath);
      if (pathSegments.any(_skippedDirectories.contains)) {
        continue;
      }
      if (entity is File && _skippedFiles.contains(p.basename(entity.path))) {
        continue;
      }

      final renamedRelativePath = pathSegments
          .map((segment) => segment.replaceAll(_sourceProjectName, projectName))
          .join(p.separator);
      final targetPath = p.join(target.path, renamedRelativePath);

      if (entity is Directory) {
        Directory(targetPath).createSync(recursive: true);
      } else if (entity is File) {
        File(targetPath).parent.createSync(recursive: true);
        _copyFileWithRenames(entity, File(targetPath), projectName, pascalName);
      }
    }
  }

  void _copyFileWithRenames(
    File source,
    File target,
    String projectName,
    String pascalName,
  ) {
    String content;
    try {
      content = source.readAsStringSync();
    } on FileSystemException {
      // Binary file (image, font, ...) — copy verbatim.
      source.copySync(target.path);
      return;
    }
    target.writeAsStringSync(
      content
          .replaceAll(_sourceProjectName, projectName)
          .replaceAll(_sourceProjectPascalName, pascalName),
    );
  }

  /// Drops the monorepo-only `dependency_overrides` block (with its leading
  /// comments) from every package pubspec: inside the monorepo those overrides
  /// point at sibling folders, and in a standalone project the same paths lead
  /// nowhere. What is left resolves from pub.dev, like any other dependency.
  void _rewritePubspecs(Directory projectRoot) {
    for (final packageDir in projectRoot.listSync().whereType<Directory>()) {
      final pubspecFile = File(p.join(packageDir.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        continue;
      }
      final rewritten = _stripDependencyOverrides(
        pubspecFile.readAsLinesSync(),
      );
      pubspecFile.writeAsStringSync('${rewritten.join('\n')}\n');
    }
  }

  List<String> _stripDependencyOverrides(List<String> lines) {
    final blockStart = lines.indexWhere(
      (line) => line.trimRight() == 'dependency_overrides:',
    );
    if (blockStart == -1) {
      return lines;
    }

    // Drop contiguous top-level comment lines directly above the block.
    var start = blockStart;
    while (start > 0 &&
        (lines[start - 1].startsWith('#') || lines[start - 1].trim().isEmpty)) {
      start--;
    }

    // The block ends at the next top-level line (key or comment).
    var end = blockStart + 1;
    while (end < lines.length &&
        (lines[end].trim().isEmpty || lines[end].startsWith(' '))) {
      end++;
    }

    return [...lines.sublist(0, start), ...lines.sublist(end)];
  }

  String _toPascalCase(String snakeCaseName) => snakeCaseName
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();

  void _initGit(Directory projectRoot) {
    // With `create .` the folder may already be a repository — initializing it
    // again is harmless but noisy, and reinitializing somebody's repo is worse.
    final alreadyARepository = Directory(
      p.join(projectRoot.path, '.git'),
    ).existsSync();
    final commands = [
      if (!alreadyARepository) ['init', '-q'],
      ['add', '-A'],
      ['commit', '-q', '-m', 'chore: initial commit from DartWay template'],
    ];
    for (final gitArgs in commands) {
      final result = Process.runSync(
        'git',
        gitArgs,
        workingDirectory: projectRoot.path,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        stderr.writeln(
          'Warning: git ${gitArgs.first} failed — initialize the repository '
          'manually.\n${result.stderr}',
        );
        return;
      }
    }
    stdout.writeln('Initialized git repository with an initial commit.');
  }
}
