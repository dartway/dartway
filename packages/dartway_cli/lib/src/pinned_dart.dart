import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The Dart of the Flutter a project pins in `.fvmrc` — the one its CI runs.
///
/// Two Darts format the same file differently, so a `dart format` run with
/// whatever `dart` is first on the PATH rewrites files the task never
/// touched, and CI, holding the pinned one, then disagrees with the result.
/// The project's own tools therefore run on the pinned SDK, found where FVM
/// links it, in FVM's cache, or as the `flutter` on the PATH when that one
/// is the pinned version (CI installs exactly that).
class DwPinnedDart {
  const DwPinnedDart._(this.executable, this.flutterVersion, this.source);

  /// The `dart` on the PATH, for a caller that can do with another Dart when
  /// the pinned one is missing; [reason] says why it is not the pinned one.
  const DwPinnedDart.onPath(String reason) : this._('dart', null, reason);

  /// The `dart` to run: a path into the pinned SDK, or `dart` from the PATH
  /// when the project pins no Flutter.
  final String executable;

  /// The Flutter version `.fvmrc` names, or null when there is no `.fvmrc`.
  final String? flutterVersion;

  /// Where [executable] was found, for the one line that says which Dart ran.
  final String source;

  /// What to say about the Dart that is about to run.
  String describe() => flutterVersion == null
      ? 'the dart on PATH ($source)'
      : 'the Dart of Flutter $flutterVersion ($source)';

  /// The Flutter version the `.fvmrc` in one of [directories] names (the
  /// first that has one), or null when none does.
  static String? pinnedFlutterVersion(List<Directory> directories) {
    for (final directory in directories) {
      final fvmrc = File(p.join(directory.path, '.fvmrc'));
      if (!fvmrc.existsSync()) continue;
      final Object? parsed;
      try {
        parsed = jsonDecode(fvmrc.readAsStringSync());
      } on FormatException {
        throw StateError('${fvmrc.path} is not JSON.');
      }
      final version = parsed is Map ? parsed['flutter'] : null;
      if (version is! String || version.isEmpty) {
        throw StateError('${fvmrc.path} names no Flutter version.');
      }
      return version;
    }
    return null;
  }

  /// The Dart for the project whose packages are [directories] — the Flutter
  /// package first, then the project root. Throws a [StateError] naming the
  /// fix when `.fvmrc` pins a Flutter that is installed nowhere it looks.
  ///
  /// [environment] stands in for the process's in tests.
  static DwPinnedDart resolve(
    List<Directory> directories, {
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final pinned = pinnedFlutterVersion(directories);
    if (pinned == null) {
      return const DwPinnedDart._('dart', null, 'no .fvmrc');
    }
    final binary = Platform.isWindows ? 'dart.bat' : 'dart';

    for (final directory in directories) {
      final link = Directory(p.join(directory.path, '.fvm', 'flutter_sdk'));
      if (!link.existsSync()) continue;
      final sdk = Directory(link.resolveSymbolicLinksSync());
      final version =
          flutterVersionOf(sdk) ??
          // FVM keeps each SDK in a directory named by its version.
          p.basename(sdk.path);
      if (version == pinned) {
        return DwPinnedDart._(
          p.join(link.path, 'bin', binary),
          pinned,
          p.relative(link.path, from: directories.last.path),
        );
      }
    }

    final home = env['HOME'] ?? env['USERPROFILE'];
    final cache =
        env['FVM_CACHE_PATH'] ?? (home == null ? null : p.join(home, 'fvm'));
    if (cache != null) {
      final sdk = Directory(p.join(cache, 'versions', pinned));
      if (File(p.join(sdk.path, 'bin', binary)).existsSync()) {
        return DwPinnedDart._(
          p.join(sdk.path, 'bin', binary),
          pinned,
          'FVM cache',
        );
      }
    }

    final onPath = _flutterOnPath(env);
    String? pathVersion;
    if (onPath != null) {
      pathVersion = flutterVersionOf(onPath) ?? _askedVersion(onPath);
      if (pathVersion == pinned) {
        return DwPinnedDart._(
          p.join(onPath.path, 'bin', binary),
          pinned,
          'the flutter on PATH',
        );
      }
    }

    throw StateError(
      '.fvmrc pins Flutter $pinned, and it is not installed: not linked in '
      '.fvm/flutter_sdk, not in the FVM cache, and the flutter on PATH is '
      '${onPath == null ? 'absent' : (pathVersion ?? 'of an unknown version')}.\n'
      'Install it: fvm install $pinned (or put Flutter $pinned first on the '
      'PATH).',
    );
  }

  /// The version of the Flutter SDK at [sdk], read from what the SDK writes
  /// about itself, or null when it says nothing yet (a checkout never run).
  static String? flutterVersionOf(Directory sdk) {
    final json = File(p.join(sdk.path, 'bin', 'cache', 'flutter.version.json'));
    if (json.existsSync()) {
      try {
        final parsed = jsonDecode(json.readAsStringSync());
        final version = parsed is Map ? parsed['frameworkVersion'] : null;
        if (version is String && version.isNotEmpty) return version;
      } on FormatException {
        // Fall through to the older file.
      }
    }
    final plain = File(p.join(sdk.path, 'version'));
    if (plain.existsSync()) {
      final version = plain.readAsStringSync().trim();
      if (version.isNotEmpty) return version;
    }
    return null;
  }

  /// The SDK of the first `flutter` on the PATH, following links.
  static Directory? _flutterOnPath(Map<String, String> env) {
    final binary = Platform.isWindows ? 'flutter.bat' : 'flutter';
    for (final entry in (env['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    )) {
      if (entry.isEmpty) continue;
      final file = File(p.join(entry, binary));
      if (!file.existsSync()) continue;
      return File(file.resolveSymbolicLinksSync()).parent.parent;
    }
    return null;
  }

  /// Asks the SDK at [sdk] for its version, when it has not written it down.
  static String? _askedVersion(Directory sdk) {
    final result = Process.runSync(
      p.join(sdk.path, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter'),
      const ['--version', '--machine'],
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) return null;
    final output = result.stdout as String;
    final start = output.indexOf('{');
    if (start < 0) return null;
    try {
      final parsed = jsonDecode(output.substring(start));
      final version = parsed is Map ? parsed['frameworkVersion'] : null;
      return version is String ? version : null;
    } on FormatException {
      return null;
    }
  }
}
