import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Which `dartway` a project's commands are supposed to be — and whether the
/// one that is running is it.
///
/// A DartWay project pins the CLI like every other part of the framework: it
/// is a dev dependency of the Flutter package, invoked as
/// `dart run dartway_cli:dartway`. A globally activated `dartway` is a second
/// copy with a life of its own, and the two drift — a global CLI from before
/// 1.0 has no `generate` at all, while the skills of the project it is
/// standing in name `dartway generate` as the only way to write `*.dw.dart`.
/// What the person sees then is not "your CLI is old" but "unknown command",
/// three steps from the cause.
///
/// So a command that reads or writes a project asks this first.
class DwPinnedCli {
  const DwPinnedCli._(this.pinnedVersion, this.runningVersion);

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
  };

  /// The version the project pins, or null when it pins none (a directory
  /// that is not a DartWay project, or a project without the dev dependency).
  final String? pinnedVersion;

  /// The version of the CLI that is running.
  final String? runningVersion;

  /// Whether the running CLI is the one this project pins. True when the
  /// project pins nothing: there is nothing to disagree with.
  bool get isPinnedOne =>
      pinnedVersion == null ||
      runningVersion == null ||
      pinnedVersion == runningVersion;

  /// What to say when it is not, ending with the command that always is.
  String complaintFor(String command) =>
      'This project pins dartway_cli $pinnedVersion and the `dartway` that '
      'ran is $runningVersion.\n'
      'A CLI older than its project writes the wrong files or lacks the '
      'command outright.\n'
      'Run the one the project pins:\n'
      '  dart run dartway_cli:dartway $command';

  /// Reads both versions around [root] (the project) and [script] (this
  /// program's own entry point, `Platform.script`).
  static DwPinnedCli of(Directory root, {Uri? script}) => DwPinnedCli._(
    _versionOf(_pinnedPackageRoot(root)),
    _versionOf(_runningPackageRoot(script ?? Platform.script)),
  );

  /// Where the project's own `dartway_cli` lives, by its package config —
  /// which resolves a path, a git and a hosted pin alike.
  static Directory? _pinnedPackageRoot(Directory root) {
    for (final directory in [
      root,
      ...root.listSync().whereType<Directory>().where(
        (entry) => p.basename(entry.path).endsWith('_flutter'),
      ),
    ]) {
      final config = File(
        p.join(directory.path, '.dart_tool', 'package_config.json'),
      );
      if (!config.existsSync()) continue;
      final Object? parsed;
      try {
        parsed = jsonDecode(config.readAsStringSync());
      } on FormatException {
        continue;
      }
      if (parsed is! Map<String, Object?>) continue;
      final packages = parsed['packages'];
      if (packages is! List) continue;
      for (final package in packages) {
        if (package is! Map<String, Object?>) continue;
        if (package['name'] != 'dartway_cli') continue;
        final rootUri = package['rootUri'];
        if (rootUri is! String) continue;
        final resolved = rootUri.startsWith('file:')
            ? Directory.fromUri(Uri.parse(rootUri))
            : Directory(p.normalize(p.join(config.parent.path, rootUri)));
        if (resolved.existsSync()) return resolved;
      }
    }
    return null;
  }

  /// Where the running CLI lives: `…/dartway_cli/bin/dartway.dart` for a
  /// snapshot run from a checkout, `…/dartway_cli-<version>/bin/…` for a
  /// global activation.
  static Directory? _runningPackageRoot(Uri script) {
    if (!script.isScheme('file')) return null;
    var directory = File.fromUri(script).parent;
    for (var depth = 0; depth < 4; depth++) {
      if (File(p.join(directory.path, 'pubspec.yaml')).existsSync()) {
        return directory;
      }
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
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
