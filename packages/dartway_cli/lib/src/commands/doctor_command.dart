import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../project_layout.dart';
import '../version_check.dart';

/// Checks that this machine can actually create and run a DartWay project.
///
/// It exists because the first failure a newcomer meets is never DartWay's: it
/// is a Docker daemon that is not running, a `serverpod_cli` that drifted from
/// the version the project pins, or a pub cache that is not on PATH. Each of
/// those surfaces much later — as a connection refused during migrations, as
/// generated code that compiles and then misbehaves, as `dartway: not found` —
/// and each is trivially detectable up front.
///
/// Every failure prints the command that fixes it. An agent runs this first and
/// relays what is missing; nothing below it works until this passes.
class DoctorCommand extends Command<int> {
  /// Minimum SDK versions, taken from the template's pubspecs. Bump them there
  /// and here in the same change.
  static const _minDartVersion = '3.11.0';
  static const _minFlutterVersion = '3.41.0';

  /// The Serverpod CLI a project expects when nothing better can be read.
  /// Inside a project the pin is read from the server package instead — the
  /// generator must match the runtime, and only the project knows its runtime.
  static const _defaultServerpodCli = '3.4.11';

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check that this machine can create and run a DartWay project.';

  @override
  String get invocation => 'dartway doctor';

  @override
  Future<int> run() async {
    final expectedServerpodCli = _expectedServerpodCli();
    final checks = [
      _checkDart(),
      _checkFlutter(),
      _checkDocker(),
      _checkServerpodCli(expectedServerpodCli),
      _checkPubGlobalBinOnPath(),
    ];

    stdout.writeln('DartWay doctor\n');
    for (final check in checks) {
      stdout.writeln(
        '  ${check.status.label.padRight(6)}${check.name.padRight(16)}'
        '${check.detail}',
      );
      if (check.fix != null) {
        stdout.writeln('${' ' * 8}fix: ${check.fix}');
      }
    }

    final failures = checks.where((check) => check.status == _Status.fail);
    final warnings = checks.where((check) => check.status == _Status.warn);
    stdout.writeln('');
    if (failures.isEmpty) {
      stdout.writeln(
        warnings.isEmpty
            ? 'Everything this needs is in place.'
            : 'Nothing is blocking you; ${warnings.length} warning(s) above.',
      );
      return 0;
    }
    stdout.writeln(
      '${failures.length} problem(s) block creating or running a project. '
      'Fix them, then run `dartway doctor` again.',
    );
    return 1;
  }

  _Check _checkDart() {
    // The SDK running this command is the one that will run the project, so
    // there is no process to spawn and no PATH ambiguity to resolve.
    final version = Platform.version.split(' ').first;
    return isAtLeastVersion(version, _minDartVersion)
        ? _Check.ok('Dart', '$version  (need >=$_minDartVersion)')
        : _Check.fail(
            'Dart',
            '$version is too old  (need >=$_minDartVersion)',
            fix: 'Update the Dart SDK — https://dart.dev/get-dart',
          );
  }

  _Check _checkFlutter() {
    final result = _run('flutter', ['--version']);
    if (result == null) {
      return _Check.fail(
        'Flutter',
        'not found on PATH',
        fix: 'Install Flutter — https://docs.flutter.dev/get-started/install',
      );
    }
    final version = RegExp(
      r'Flutter (\d+\.\d+\.\d+)',
    ).firstMatch(result.stdout as String)?.group(1);
    if (version == null) {
      return _Check.warn(
        'Flutter',
        'installed, version not recognised in `flutter --version`',
      );
    }
    return isAtLeastVersion(version, _minFlutterVersion)
        ? _Check.ok('Flutter', '$version  (need >=$_minFlutterVersion)')
        : _Check.fail(
            'Flutter',
            '$version is too old  (need >=$_minFlutterVersion)',
            fix: 'flutter upgrade',
          );
  }

  _Check _checkDocker() {
    final result = _run('docker', ['ps']);
    if (result == null) {
      return _Check.fail(
        'Docker',
        'not found on PATH',
        fix:
            'Install Docker Desktop — https://docs.docker.com/get-docker/ '
            '(the database runs in it; there is no second path)',
      );
    }
    if (result.exitCode != 0) {
      return _Check.fail(
        'Docker',
        'installed, but the daemon is not responding',
        fix: 'Start Docker Desktop and wait until it reports "running"',
      );
    }
    return _Check.ok('Docker', 'daemon responding');
  }

  _Check _checkServerpodCli(String expected) {
    final result = _run('dart', ['pub', 'global', 'list']);
    if (result == null) {
      return _Check.warn(
        'serverpod_cli',
        'could not run `dart pub global list`',
      );
    }
    final installed = RegExp(
      r'^serverpod_cli (\S+)',
      multiLine: true,
    ).firstMatch(result.stdout as String)?.group(1);
    if (installed == null) {
      return _Check.fail(
        'serverpod_cli',
        'not installed  (need exactly $expected)',
        fix: 'dart pub global activate serverpod_cli $expected',
      );
    }
    if (installed != expected) {
      return _Check.fail(
        'serverpod_cli',
        '$installed does not match the project pin $expected',
        fix:
            'dart pub global activate serverpod_cli $expected  '
            '(the generator writes code for its own version; a drifted CLI '
            'produces a protocol that compiles and then misbehaves)',
      );
    }
    return _Check.ok('serverpod_cli', '$installed  (matches the project pin)');
  }

  /// `dart pub global activate` puts executables in a directory that is not on
  /// PATH by default on a fresh machine — the first symptom being
  /// `dartway: command not found` right after a successful install.
  _Check _checkPubGlobalBinOnPath() {
    final binDir = _pubCacheBinDir();
    if (binDir == null) {
      return _Check.warn('PATH', 'could not locate the pub cache');
    }
    final entries = (Platform.environment['PATH'] ?? '').split(
      Platform.isWindows ? ';' : ':',
    );
    final onPath = entries.any(
      (entry) => p.equals(p.normalize(entry.trim()), binDir),
    );
    return onPath
        ? _Check.ok('PATH', 'pub global executables are reachable')
        : _Check.warn(
            'PATH',
            'globally activated executables are not on PATH',
            fix:
                'Add $binDir to PATH, or call the CLI as '
                '`dart pub global run dartway_cli:dartway <command>`',
          );
  }

  String? _pubCacheBinDir() {
    final explicitCache = Platform.environment['PUB_CACHE'];
    if (explicitCache != null && explicitCache.isNotEmpty) {
      return p.normalize(p.join(explicitCache, 'bin'));
    }
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData == null) return null;
      return p.normalize(p.join(localAppData, 'Pub', 'Cache', 'bin'));
    }
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return p.normalize(p.join(home, '.pub-cache', 'bin'));
  }

  /// The Serverpod version the current project pins, when run inside one.
  String _expectedServerpodCli() {
    try {
      final layout = ProjectLayout.detect(Directory.current);
      final pubspec = File(
        p.join(Directory.current.path, layout.serverPackage, 'pubspec.yaml'),
      );
      if (!pubspec.existsSync()) return _defaultServerpodCli;
      final pinned = RegExp(
        r'^\s+serverpod:\s*(\d+\.\d+\.\d+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync())?.group(1);
      return pinned ?? _defaultServerpodCli;
    } on StateError {
      // Not inside a project — the default pin is the best answer available.
      return _defaultServerpodCli;
    }
  }

  /// Runs a command, returning null when the executable is not on PATH.
  ProcessResult? _run(String executable, List<String> arguments) {
    try {
      return Process.runSync(executable, arguments, runInShell: true);
    } on ProcessException {
      return null;
    }
  }
}

enum _Status {
  ok('ok'),
  warn('warn'),
  fail('FAIL');

  const _Status(this.label);

  final String label;
}

class _Check {
  _Check(this.status, this.name, this.detail, {this.fix});

  _Check.ok(String name, String detail) : this(_Status.ok, name, detail);

  _Check.warn(String name, String detail, {String? fix})
    : this(_Status.warn, name, detail, fix: fix);

  _Check.fail(String name, String detail, {required String fix})
    : this(_Status.fail, name, detail, fix: fix);

  final _Status status;
  final String name;
  final String detail;
  final String? fix;
}
