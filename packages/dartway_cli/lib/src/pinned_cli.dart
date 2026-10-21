import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'pinned_dart.dart';
import 'toolkit_manifest.dart' show dartwayCliVersion;

/// Which `dartway` a project's commands are supposed to be — and, when the
/// one that is running is not it, the way to hand the command over.
///
/// A DartWay project pins the CLI like every other part of the framework: it
/// is a dev dependency of the Flutter package. A globally activated `dartway`
/// is a second copy with a life of its own, and the two drift — a global CLI
/// from before 1.0 has no `generate` at all, while the skills of the project
/// it is standing in name `dartway generate` as the only way to write
/// `*.dw.dart`.
///
/// So a project command asks this first, and a `dartway` of another version
/// does not run it: it runs the pinned one (`dart run dartway_cli:dartway`
/// from the package that pins it, on the Dart of the Flutter `.fvmrc` pins)
/// and passes its exit code on. Every project then types the same
/// `dartway <command>`, whichever copy is on the PATH.
class DwPinnedCli {
  const DwPinnedCli._({
    required this.root,
    required this.runningVersion,
    this.owner,
    this.pinnedVersion,
  });

  /// Commands that read or write an existing project, and so have to be the
  /// CLI that project pins. The rest either make a project (`create`,
  /// `quickstart`), repair its pins (`update`, `setup-ai`) or touch nothing
  /// (`doctor`). The toolkit's command blocks are held to it by
  /// `toolkit_pinned_commands_test.dart`.
  static const Set<String> projectCommands = {
    'generate',
    'check',
    'test',
    'deploy',
    'dev',
    'stats',
    'format',
  };

  /// Set in the environment of the pinned CLI this one starts, so that a
  /// pin which still disagrees once running is refused instead of started
  /// again.
  static const reentryVariable = 'DW_PINNED_CLI';

  /// The project the pin was looked for in.
  final Directory root;

  /// The package whose pubspec declares `dartway_cli`, or null when none
  /// does — a directory that is not a DartWay project, or a project without
  /// the dev dependency.
  final Directory? owner;

  /// The version [owner]'s resolved packages hold, or null when they are not
  /// resolved (no `pub get` yet) or name a CLI that is not there.
  final String? pinnedVersion;

  /// The version of the CLI that is running.
  final String runningVersion;

  /// Whether the running CLI is the one this project pins. True when the
  /// project pins nothing: there is nothing to disagree with.
  bool get isPinnedOne =>
      owner == null ||
      (pinnedVersion != null && pinnedVersion == runningVersion);

  /// Whether the project pins a CLI that cannot be found: [owner]'s packages
  /// are not resolved.
  bool get isUnresolved => owner != null && pinnedVersion == null;

  /// What to say when the pin cannot be found, ending with the command that
  /// resolves it.
  String unresolvedComplaint() {
    final package = p.relative(owner!.path, from: root.path);
    final flutter = File(
      p.join(owner!.path, 'pubspec.yaml'),
    ).readAsStringSync().contains(RegExp(r'sdk:\s*flutter\b'));
    final fvm = DwPinnedDart.pinnedFlutterVersion([owner!, root]) != null;
    final get = flutter
        ? '${fvm ? 'fvm ' : ''}flutter pub get'
        : '${fvm ? 'fvm ' : ''}dart pub get';
    return 'This project pins dartway_cli in $package/pubspec.yaml, and its '
        'packages are not resolved, so there is no pinned CLI to run.\n'
        'Resolve them, then run the command again:\n'
        '  (cd $package && $get)';
  }

  /// What to say when the pinned CLI, once started, still is not this
  /// version.
  String complaintFor(String command) =>
      'This project pins dartway_cli $pinnedVersion and the `dartway` that '
      'ran is $runningVersion, even after handing the command over.\n'
      'Resolve the project again and run the pinned one directly:\n'
      '  (cd ${p.relative(owner!.path, from: root.path)} && '
      'dart run dartway_cli:dartway $command)';

  /// Runs [args] on the pinned CLI and returns its exit code: from [owner],
  /// on the Dart of the pinned Flutter, with this process's stdio. One line
  /// on stderr says so.
  Future<int> runPinned(
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Platform.environment;
    if (env[reentryVariable] != null) {
      stderr.writeln(complaintFor(args.join(' ')));
      return 1;
    }
    DwPinnedDart dart;
    try {
      dart = DwPinnedDart.resolve([owner!, root], environment: env);
    } on StateError catch (error) {
      // The pinned CLI still runs on another Dart; the command it was handed
      // decides whether that matters (`format` refuses).
      dart = DwPinnedDart.onPath(error.message.split('\n').first);
    }
    stderr.writeln(
      'dartway $runningVersion: running the dartway_cli $pinnedVersion this '
      'project pins, on ${dart.describe()}.',
    );
    final Process process;
    try {
      process = await Process.start(
        dart.executable,
        ['run', 'dartway_cli:dartway', ...args],
        workingDirectory: owner!.path,
        environment: {reentryVariable: pinnedVersion!},
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
    } on ProcessException catch (error) {
      throw StateError('Could not start ${dart.executable}: ${error.message}.');
    }
    // The terminal interrupts the whole foreground group, the pinned CLI
    // included; this one waits for it to finish rather than leave it behind.
    // A termination sent to this process alone is passed on.
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) {}),
      if (!Platform.isWindows)
        ProcessSignal.sigterm.watch().listen(
          (_) => process.kill(ProcessSignal.sigterm),
        ),
    ];
    try {
      return await process.exitCode;
    } finally {
      for (final signal in signals) {
        await signal.cancel();
      }
    }
  }

  /// Reads the pin of the project at [root]; [runningVersion] is this CLI's
  /// own unless a test names another.
  static DwPinnedCli of(
    Directory root, {
    String runningVersion = dartwayCliVersion,
  }) {
    final owner = _owner(root);
    return DwPinnedCli._(
      root: root,
      runningVersion: runningVersion,
      owner: owner,
      pinnedVersion: owner == null ? null : _versionOf(_resolved(owner)),
    );
  }

  /// The package of the project that declares `dartway_cli` as a dependency:
  /// the root, or one of its `*_flutter` packages, where a project keeps it.
  static Directory? _owner(Directory root) {
    if (!root.existsSync()) return null;
    for (final directory in [
      root,
      ...root.listSync().whereType<Directory>().where(
        (entry) => p.basename(entry.path).endsWith('_flutter'),
      ),
    ]) {
      final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
      if (!pubspec.existsSync()) continue;
      final Object? parsed;
      try {
        parsed = loadYaml(pubspec.readAsStringSync());
      } on YamlException {
        continue;
      }
      if (parsed is! YamlMap) continue;
      for (final section in ['dependencies', 'dev_dependencies']) {
        final dependencies = parsed[section];
        if (dependencies is YamlMap &&
            dependencies.containsKey('dartway_cli')) {
          return directory;
        }
      }
    }
    return null;
  }

  /// Where [owner]'s own `dartway_cli` lives, by the nearest package config
  /// at or above it (a workspace keeps one at its root) — which resolves a
  /// path, a git and a hosted pin alike.
  static Directory? _resolved(Directory owner) {
    var directory = owner.absolute;
    while (true) {
      final config = File(
        p.join(directory.path, '.dart_tool', 'package_config.json'),
      );
      if (config.existsSync()) return _cliIn(config);
      final parent = directory.parent;
      if (parent.path == directory.path) return null;
      directory = parent;
    }
  }

  static Directory? _cliIn(File config) {
    final Object? parsed;
    try {
      parsed = jsonDecode(config.readAsStringSync());
    } on FormatException {
      return null;
    }
    if (parsed is! Map<String, Object?>) return null;
    final packages = parsed['packages'];
    if (packages is! List) return null;
    for (final package in packages) {
      if (package is! Map<String, Object?>) continue;
      if (package['name'] != 'dartway_cli') continue;
      final rootUri = package['rootUri'];
      if (rootUri is! String) continue;
      final resolved = rootUri.startsWith('file:')
          ? Directory.fromUri(Uri.parse(rootUri))
          : Directory(p.normalize(p.join(config.parent.path, rootUri)));
      return resolved.existsSync() ? resolved : null;
    }
    return null;
  }

  /// The `version:` of a package, read from its pubspec without a YAML
  /// parser: the line is the first `version:` at the top level.
  static String? _versionOf(Directory? packageRoot) {
    if (packageRoot == null) return null;
    final pubspec = File(p.join(packageRoot.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    for (final line in pubspec.readAsLinesSync()) {
      final match = RegExp(r'^version:\s*(\S+)').firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
