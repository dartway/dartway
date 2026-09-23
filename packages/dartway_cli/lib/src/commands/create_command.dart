import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../framework_overrides.dart';
import '../monorepo_source.dart';
import '../project_layout.dart';
import '../project_locale.dart';
import '../toolkit_installer.dart';
import '../toolkit_manifest.dart';

/// Creates a new DartWay project from the `template/` skeleton of the monorepo:
/// copies it, names everything after the project — packages, types, the
/// generated registry and schema, the storage buckets — strips the monorepo's
/// `dependency_overrides` and installs the AI toolkit.
///
/// The skeleton is deliberately domain-free — sign-in, profiles, roles,
/// navigation, the admin panel and the UI kit, and no models of anyone else's
/// business. The full application built on it lives in `example/` of the
/// monorepo, and is a reference to read, not a project to inherit.
class CreateCommand extends Command<int> {
  CreateCommand() {
    argParser
      ..addOption(
        'channel',
        defaultsTo:
            Platform.environment['DARTWAY_BRANCH'] ??
            MonorepoSource.defaultBranch,
        help:
            'DartWay monorepo branch to create the project from. Without it '
            '(or DARTWAY_BRANCH), a CLI activated from a monorepo checkout '
            'creates the project from that checkout — the template of its own '
            'revision.',
      )
      ..addOption(
        'local-repo',
        help:
            'Path to a local DartWay monorepo checkout '
            '(skips clone; also read from DARTWAY_MONOREPO_DIR).',
      )
      ..addOption(
        'framework-path',
        valueHelp: 'monorepo',
        help:
            'Build the project against the framework packages of a local '
            'monorepo checkout, by path: its pubspecs get dependency_overrides '
            'onto <monorepo>/packages instead of resolving from pub.dev. For '
            'developing the framework, and for versions not published yet. '
            'The template and the toolkit come from the same checkout unless '
            '--local-repo names another.',
      )
      ..addOption(
        'language',
        defaultsTo: 'English',
        help:
            "Language of the new project: the app's one UI language (en, ru, "
            "or English, Russian), and the language it writes its own texts "
            "in (feature specs, doc comments, docs/dev_notes/).",
      )
      ..addOption(
        'notes-tracker',
        valueHelp: 'owner/repo',
        defaultsTo: ProjectLayout.defaultNotesTracker,
        help:
            'GitHub repository where findings about the framework are filed as '
            'issues. Pass "${ProjectLayout.noNotesTracker}" to file nothing '
            'outside this project — findings then go to docs/dev_notes/.',
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
  static const _sourceProjectCamelName = 'dartwayStarter';

  /// The template's bucket names are `dartway-starter-public` and
  /// `dartway-starter-private` — the names `dartway deploy` gives the buckets
  /// of its MinIO, after the project with dashes (S3 allows no underscore).
  static const _sourceProjectKebabName = 'dartway-starter';

  /// The longest bucket name S3 accepts, and the longest suffix the template
  /// puts after the project's name.
  static const _maxBucketName = 63;
  static const _longestBucketSuffix = '-private';

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

    final frameworkPath = switch (argResults!['framework-path'] as String?) {
      final path? when path.isNotEmpty => p.normalize(p.absolute(path)),
      _ => null,
    };
    final frameworkPackages = frameworkPath == null
        ? null
        : frameworkPackageDirectories(Directory(frameworkPath));

    final source = MonorepoSource(
      branch: argResults!['channel'] as String,
      localDir: (argResults!['local-repo'] as String?) ?? frameworkPath,
      channelChosen:
          argResults!.wasParsed('channel') ||
          Platform.environment.containsKey('DARTWAY_BRANCH'),
    );
    final monorepoDir = await source.resolve();
    final templateDir = Directory(p.join(monorepoDir.path, _sourceDirectory));
    if (!templateDir.existsSync()) {
      throw StateError(
        'No $_sourceDirectory/ found in monorepo at ${monorepoDir.path}',
      );
    }

    stdout.writeln('Creating $projectName from the DartWay template...');
    _copyProject(templateDir, targetDir, projectName);
    for (final notice in ProjectLocale.apply(
      ProjectLayout.detect(targetDir).flutterPackageDir,
      argResults!['language'] as String,
    )) {
      stderr.writeln('Note: $notice');
    }
    _formatRenamedCode(targetDir);
    _rewritePubspecs(targetDir, frameworkPackages);
    _pinLintsPlugin(
      targetDir,
      monorepoDir: monorepoDir,
      frameworkPackages: frameworkPackages,
    );
    if (frameworkPath != null) {
      stdout.writeln(
        'The framework packages resolve from $frameworkPath/packages '
        '(dependency_overrides).',
      );
    }

    final layout = ProjectLayout.detect(targetDir);
    // The three settings are recorded as well as substituted: `dartway update`
    // runs without arguments and takes them from the manifest, so a project
    // created `--language ru` with a tracker would otherwise be rewritten in
    // the defaults by its first update — silently, since a missing setting and
    // a defaulted one look alike.
    final settings = ToolkitProvenance.settingsOf(
      baseBranch: 'master',
      language: argResults!['language'] as String,
      notesTracker: argResults!['notes-tracker'] as String,
    );
    await ToolkitInstaller.install(
      toolkitDir: Directory(p.join(monorepoDir.path, 'toolkit')),
      projectRoot: targetDir,
      tokens: layout.toolkitTokens(
        baseBranch: settings[ToolkitProvenance.baseBranchSetting]!,
        language: settings[ToolkitProvenance.languageSetting]!,
        notesTracker: settings[ToolkitProvenance.notesTrackerSetting]!,
      ),
      provenance: await source.provenance(monorepoDir, settings: settings),
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
        'Project name must be a lower_snake_case Dart identifier of at most '
        '${_maxBucketName - _longestBucketSuffix.length} characters, without '
        'a leading, trailing or doubled underscore (got "$projectName").',
      );
    }
    return _rejectTemplateName(projectName);
  }

  /// A Dart package name once `_server` is appended, and a storage bucket
  /// name once dashed and suffixed: lower-case letters, digits and single
  /// underscores between them, short enough for the longest bucket.
  bool _isValidProjectName(String candidate) =>
      RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$').hasMatch(candidate) &&
      candidate.length + _longestBucketSuffix.length <= _maxBucketName;

  String _rejectTemplateName(String projectName) {
    if (projectName == _sourceProjectName) {
      usageException('Pick a name other than "$_sourceProjectName".');
    }
    return projectName;
  }

  void _copyProject(Directory source, Directory target, String projectName) {
    final renames = {
      _sourceProjectName: projectName,
      _sourceProjectPascalName: _toPascalCase(projectName),
      _sourceProjectCamelName: _toCamelCase(projectName),
      _sourceProjectKebabName: projectName.replaceAll('_', '-'),
    };
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
        _copyFileWithRenames(entity, File(targetPath), renames);
      }
    }
  }

  void _copyFileWithRenames(
    File source,
    File target,
    Map<String, String> renames,
  ) {
    String content;
    try {
      content = source.readAsStringSync();
    } on FileSystemException {
      // Binary file (image, font, ...) — copy verbatim.
      source.copySync(target.path);
      return;
    }
    for (final MapEntry(key: from, value: to) in renames.entries) {
      content = content.replaceAll(from, to);
    }
    target.writeAsStringSync(content);
  }

  /// Formats the Dart code of the new project.
  ///
  /// The renames change the length of names — `DartwayStarterRefusal` is not
  /// as long as the project's own — so lines the template had formatted no
  /// longer are, and `dart format` over the fresh project would rewrite them:
  /// a first commit that is not formatted, and a generator `--check` that
  /// depends on where the lines happened to break. Formatting here once makes
  /// the project the formatter's from its first commit.
  void _formatRenamedCode(Directory projectRoot) {
    final paths = [
      for (final package in projectRoot.listSync().whereType<Directory>())
        if (File(p.join(package.path, 'pubspec.yaml')).existsSync())
          for (final folder in const ['bin', 'lib', 'test'])
            if (Directory(p.join(package.path, folder)).existsSync())
              p.join(package.path, folder),
    ];
    if (paths.isEmpty) return;
    final ProcessResult result;
    try {
      result = Process.runSync(_dart, [
        'format',
        '--output=write',
        ...paths,
      ], runInShell: Platform.isWindows);
    } on ProcessException catch (error) {
      stderr.writeln(
        'Warning: `dart format` could not run (${error.message}); run it over '
        'the new project before the first commit.',
      );
      return;
    }
    if (result.exitCode != 0) {
      stderr.writeln(
        'Warning: `dart format` failed — run it over the new project before '
        'the first commit.\n${result.stderr}',
      );
    }
  }

  /// The `dart` executable: the one running this CLI when it runs as a Dart
  /// script or snapshot, otherwise the one on `PATH`.
  static String get _dart {
    final running = p.basenameWithoutExtension(Platform.resolvedExecutable);
    return running == 'dart' ? Platform.resolvedExecutable : 'dart';
  }

  /// Drops the monorepo-only `dependency_overrides` block (with its leading
  /// comments) from every package pubspec: inside the monorepo those overrides
  /// point at sibling folders, and in a standalone project the same paths lead
  /// nowhere. What is left resolves from pub.dev, like any other dependency.
  ///
  /// With [frameworkPackages] (`--framework-path`) each pubspec gets overrides
  /// onto those packages instead — for exactly the framework packages it
  /// reaches.
  void _rewritePubspecs(
    Directory projectRoot,
    Map<String, String>? frameworkPackages,
  ) {
    for (final packageDir in projectRoot.listSync().whereType<Directory>()) {
      final pubspecFile = File(p.join(packageDir.path, 'pubspec.yaml'));
      if (!pubspecFile.existsSync()) {
        continue;
      }
      final lines = pubspecFile.readAsLinesSync();
      final rewritten = frameworkPackages == null
          ? withoutDependencyOverrides(lines)
          : withFrameworkOverrides(
              lines,
              frameworkOverridesFor(
                withoutDependencyOverrides(lines).join('\n'),
                frameworkPackages,
              ),
            );
      pubspecFile.writeAsStringSync('${rewritten.join('\n')}\n');
    }
  }

  /// Points the Flutter package's `plugins: dartway_lints:` at the published
  /// plugin, or at the checkout's with `--framework-path`.
  ///
  /// The template names it by a path into this repository, which leads
  /// nowhere in a project; an analyzer plugin is not a pub dependency, so
  /// `dependency_overrides` never reached it. The version is the one the
  /// template was taken from.
  void _pinLintsPlugin(
    Directory projectRoot, {
    required Directory monorepoDir,
    required Map<String, String>? frameworkPackages,
  }) {
    final options = File(
      p.join(
        ProjectLayout.detect(projectRoot).flutterPackageDir.path,
        'analysis_options.yaml',
      ),
    );
    if (!options.existsSync()) return;
    final pattern = RegExp(
      r'^(  dartway_lints:)\n    path: [^\n]+$',
      multiLine: true,
    );
    final source = options.readAsStringSync();
    if (!pattern.hasMatch(source)) return;
    final String pin;
    if (frameworkPackages?['dartway_lints'] case final path?) {
      pin = "\n    path: '$path'";
    } else {
      final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(
            File(
              p.join(
                monorepoDir.path,
                'packages',
                'dartway_lints',
                'pubspec.yaml',
              ),
            ).readAsStringSync(),
          )
          ?.group(1);
      if (version == null) return;
      pin = ' ^$version';
    }
    options.writeAsStringSync(
      source.replaceFirstMapped(pattern, (match) => '${match[1]}$pin'),
    );
  }

  String _toPascalCase(String snakeCaseName) => snakeCaseName
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join();

  String _toCamelCase(String snakeCaseName) {
    final pascal = _toPascalCase(snakeCaseName);
    return pascal[0].toLowerCase() + pascal.substring(1);
  }

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
