import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Runs `dartway_generator` over the project: DTO codecs and the protocol
/// registry in `*_shared`, entity tables and the schema in `*_server`.
///
/// The CLI does not link the generator in. The generator pins `analyzer`, and
/// a CLI activated globally would force one analyzer on every project it ever
/// touches; the generator must instead match the `dartway_core_shared` and
/// `dartway_orm` the project builds against. So the command finds the
/// generator the project resolved — a dev dependency of one of its packages —
/// and runs that one, falling back to a globally activated generator only when
/// the project declares none.
class GenerateCommand extends Command<int> {
  GenerateCommand() {
    argParser.addFlag(
      'check',
      negatable: false,
      help:
          'Write nothing; fail when a generated file is out of date or stale. '
          'For CI.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'List every file written or removed.',
    );
  }

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate DTO codecs, the protocol registry, entity tables and the '
      'schema of this project.';

  @override
  String get invocation => 'dartway generate [--check]';

  static const _generator = 'dartway_generator';

  @override
  Future<int> run() async {
    final root = _findProjectRoot(Directory.current.path);
    if (root == null) {
      throw StateError(
        'No DartWay project here: expected a directory holding *_shared and '
        '*_server packages (or one of them) at or above '
        '${Directory.current.path}.',
      );
    }

    final forwarded = [
      '--project',
      root,
      if (argResults!.flag('check')) '--check',
      if (argResults!.flag('verbose')) '--verbose',
    ];

    final host = _packagesOf(root).where(_resolvesGenerator).firstOrNull;
    final List<String> command;
    final String workingDirectory;
    if (host != null) {
      command = ['run', _generator, ...forwarded];
      workingDirectory = host;
    } else if (await _isGloballyActivated()) {
      command = ['pub', 'global', 'run', _generator, ...forwarded];
      workingDirectory = root;
    } else {
      throw StateError(
        'dartway_generator is not available to this project. Add it to the '
        'dev_dependencies of the *_server package (and run `dart pub get`), '
        'or activate it with `dart pub global activate dartway_generator`.',
      );
    }

    final process = await Process.start(
      _dart,
      command,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }

  /// The project root: the nearest directory at or above [start] that holds a
  /// `*_shared` or `*_server` package, or is one.
  static String? _findProjectRoot(String start) {
    var current = p.normalize(p.absolute(start));
    while (true) {
      final name = p.basename(current);
      if (_isRolePackageName(name) &&
          File(p.join(current, 'pubspec.yaml')).existsSync()) {
        final parent = p.dirname(current);
        // Inside a project, the root is the directory holding the packages.
        return _packagesOf(parent).isNotEmpty ? parent : current;
      }
      if (_packagesOf(current).isNotEmpty) return current;
      final parent = p.dirname(current);
      if (parent == current) return null;
      current = parent;
    }
  }

  static bool _isRolePackageName(String name) =>
      name.endsWith('_shared') || name.endsWith('_server');

  /// The `*_server` then `*_shared` package directories directly in [root]:
  /// the server first, because that is where the template declares the
  /// generator.
  static List<String> _packagesOf(String root) {
    final directory = Directory(root);
    if (!directory.existsSync()) return const [];
    final packages = [
      for (final entity in directory.listSync())
        if (entity is Directory &&
            _isRolePackageName(p.basename(entity.path)) &&
            File(p.join(entity.path, 'pubspec.yaml')).existsSync())
          entity.path,
    ];
    packages.sort((a, b) {
      final byRole = (a.endsWith('_server') ? 0 : 1).compareTo(
        b.endsWith('_server') ? 0 : 1,
      );
      return byRole != 0 ? byRole : a.compareTo(b);
    });
    return packages;
  }

  /// Whether the package at [directory] has resolved `dartway_generator`,
  /// reading the nearest package config (a workspace keeps one at its root).
  static bool _resolvesGenerator(String directory) {
    var current = directory;
    while (true) {
      final config = File(p.join(current, '.dart_tool', 'package_config.json'));
      if (config.existsSync()) {
        try {
          final json = jsonDecode(config.readAsStringSync());
          if (json case {'packages': final List<Object?> packages}) {
            return packages.any(
              (entry) => entry is Map && entry['name'] == _generator,
            );
          }
        } on FormatException {
          return false;
        }
        return false;
      }
      final parent = p.dirname(current);
      if (parent == current) return false;
      current = parent;
    }
  }

  /// The `dart` executable: the one running this CLI when it runs as a Dart
  /// script or snapshot, otherwise the one on `PATH` (a compiled CLI is its
  /// own executable).
  static String get _dart {
    final running = p.basenameWithoutExtension(Platform.resolvedExecutable);
    return running == 'dart' ? Platform.resolvedExecutable : 'dart';
  }

  static Future<bool> _isGloballyActivated() async {
    final result = await Process.run(_dart, ['pub', 'global', 'list']);
    return result.exitCode == 0 &&
        LineSplitter.split(
          result.stdout as String,
        ).any((line) => line.startsWith('$_generator '));
  }
}
