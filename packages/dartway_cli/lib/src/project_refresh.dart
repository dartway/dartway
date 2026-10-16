import 'dart:io';

import 'package:path/path.dart' as p;

import 'commands/dev_command.dart' show flutterCommand;

/// The packages directly in [root], each with whether it builds on Flutter.
///
/// A workspace resolves once, at its root.
List<(Directory, bool)> projectPackages(String root) {
  bool isFlutter(Directory directory) => File(
    p.join(directory.path, 'pubspec.yaml'),
  ).readAsStringSync().contains(RegExp(r'sdk:\s*flutter\b'));
  final rootPubspec = File(p.join(root, 'pubspec.yaml'));
  if (rootPubspec.existsSync() &&
      rootPubspec.readAsStringSync().contains(
        RegExp(r'^workspace:', multiLine: true),
      )) {
    final directory = Directory(root);
    return [(directory, isFlutter(directory))];
  }
  final packages = [
    for (final entity in Directory(
      root,
    ).listSync()..sort((a, b) => a.path.compareTo(b.path)))
      if (entity is Directory &&
          !p.basename(entity.path).startsWith('.') &&
          File(p.join(entity.path, 'pubspec.yaml')).existsSync())
        entity,
  ];
  return [for (final directory in packages) (directory, isFlutter(directory))];
}

/// `pub get` in every package of [root] — `flutter pub get` where the package
/// builds on Flutter, through the SDK the project pins — and `flutter gen-l10n`
/// where a package configures it. Returns the first failing exit code, or 0.
Future<int> resolvePackages(String root) async {
  for (final (directory, flutter) in projectPackages(root)) {
    final (executable, prefix) = flutter
        ? flutterCommand(searched: [Directory(root), directory])
        : ('dart', const <String>[]);
    final steps = [
      ['pub', 'get'],
      if (flutter && File(p.join(directory.path, 'l10n.yaml')).existsSync())
        ['gen-l10n'],
    ];
    for (final step in steps) {
      stdout.writeln(
        '${[executable, ...prefix, ...step].join(' ')} in '
        '${p.relative(directory.path, from: root)}',
      );
      final process = await Process.start(
        executable,
        [...prefix, ...step],
        workingDirectory: directory.path,
        mode: ProcessStartMode.inheritStdio,
        runInShell: Platform.isWindows,
      );
      final code = await process.exitCode;
      if (code != 0) return code;
    }
  }
  return 0;
}
