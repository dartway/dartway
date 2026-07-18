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
  String get invocation => 'dartway create <project_name>';

  @override
  Future<int> run() async {
    final projectName = _requireProjectName();
    final targetDir = Directory(
      p.join(Directory.current.path, projectName),
    );
    if (targetDir.existsSync()) {
      throw StateError('Directory already exists: ${targetDir.path}');
    }

    final monorepoDir =
        await MonorepoSource(
          branch: argResults!['channel'] as String,
          localDir: argResults!['local-repo'] as String?,
        ).resolve();
    final templateDir = Directory(
      p.join(monorepoDir.path, _sourceDirectory),
    );
    if (!templateDir.existsSync()) {
      throw StateError(
        'No $_sourceDirectory/ found in monorepo at ${monorepoDir.path}',
      );
    }

    stdout.writeln('Creating $projectName from the DartWay template...');
    _copyProject(templateDir, targetDir, projectName);
    _rewritePubspecs(targetDir);

    final layout = ProjectLayout.detect(targetDir);
    await ToolkitInstaller.install(
      toolkitDir: Directory(p.join(monorepoDir.path, 'toolkit')),
      projectRoot: targetDir,
      tokens: layout.toolkitTokens(baseBranch: 'master'),
    );

    if (argResults!['git'] as bool) {
      _initGit(targetDir);
    }

    stdout
      ..writeln('')
      ..writeln('Project $projectName is ready.')
      ..writeln('')
      ..writeln('Open it in VS Code and press F5 (Server, then Seed dev data, '
          'then Flutter), or run it from the terminal:')
      ..writeln('  cd $projectName/${layout.serverPackage}')
      ..writeln('  dart pub get')
      ..writeln('  docker compose up -d')
      ..writeln('  dart bin/main.dart --apply-migrations --role maintenance')
      ..writeln('  dart bin/seed_dev.dart --mode development')
      ..writeln('  dart bin/main.dart')
      ..writeln('then in another terminal:')
      ..writeln('  cd $projectName/${layout.flutterPackage}')
      ..writeln('  flutter pub get && flutter run')
      ..writeln('')
      ..writeln('Sign in as the seeded user 79990000003 (the OTP code is '
          'printed in the server console).');
    return 0;
  }

  String _requireProjectName() {
    final rest = argResults!.rest;
    if (rest.length != 1) {
      usageException('Provide exactly one project name.');
    }
    final projectName = rest.single;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(projectName)) {
      usageException(
        'Project name must be a lower_snake_case Dart identifier '
        '(got "$projectName").',
      );
    }
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

  /// In every package pubspec: drop the monorepo-only `dependency_overrides`
  /// block (with its leading comments) and retarget git dependencies from
  /// `ref: master` to `ref: stable` — standalone projects follow the verified
  /// channel, not the development trunk.
  void _rewritePubspecs(Directory projectRoot) {
    for (final packageDir in projectRoot.listSync().whereType<Directory>()) {
      final pubspecFile = File(p.join(packageDir.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        continue;
      }
      final lines = pubspecFile.readAsLinesSync();
      final rewritten = _stripDependencyOverrides(lines)
          .map((line) => line.replaceAll('ref: master', 'ref: stable'))
          .toList();
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
    final commands = [
      ['init', '-q'],
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
