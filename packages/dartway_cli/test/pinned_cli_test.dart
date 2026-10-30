import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/pinned_cli.dart';
import 'package:dartway_cli/src/toolkit_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/cli_kernel.dart';
import 'support/test_process.dart';

/// A project pins its CLI like everything else of the framework. A `dartway`
/// of another version does not refuse a project command: it hands it to the
/// pinned one, and only a pin that cannot be found is refused.
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('dw_pinned_cli_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// A `dartway_cli` package of [version] at [path], whose executable prints
  /// what it was asked, where, and exits with 7.
  void cliPackage(String path, String version) {
    final root = Directory(p.join(temp.path, path))
      ..createSync(recursive: true);
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(
      'name: dartway_cli\nversion: $version\n'
      'environment:\n  sdk: ^3.0.0\n',
    );
    Directory(p.join(root.path, 'bin')).createSync();
    File(p.join(root.path, 'bin', 'dartway.dart')).writeAsStringSync(r'''
import 'dart:io';

void main(List<String> args) {
  stdout.writeln('pinned ran: ${args.join(' ')}');
  stdout.writeln('in: ${Directory.current.path}');
  stdout.writeln('reentry: ${Platform.environment['DW_PINNED_CLI']}');
  exitCode = 7;
}
''');
  }

  /// A project `shop` whose Flutter package declares dartway_cli at
  /// [cliRoot]; with [resolved], its package config resolves it there.
  Directory project(String cliRoot, {bool resolved = true}) {
    final root = Directory(p.join(temp.path, 'shop'))..createSync();
    for (final role in ['shop_shared', 'shop_server']) {
      Directory(p.join(root.path, role)).createSync();
      File(
        p.join(root.path, role, 'pubspec.yaml'),
      ).writeAsStringSync('name: $role\n');
    }
    final flutter = Directory(p.join(root.path, 'shop_flutter'))..createSync();
    File(p.join(flutter.path, 'pubspec.yaml')).writeAsStringSync(
      'name: shop_flutter\n'
      'environment:\n  sdk: ^3.0.0\n'
      'dev_dependencies:\n'
      '  dartway_cli:\n    path: ${p.join(temp.path, cliRoot)}\n',
    );
    if (resolved) {
      final tool = Directory(p.join(flutter.path, '.dart_tool'))..createSync();
      File(p.join(tool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'shop_flutter', 'rootUri': '../'},
            {'name': 'dartway_cli', 'rootUri': p.join(temp.path, cliRoot)},
          ],
        }),
      );
    }
    return root;
  }

  group('reading the pin', () {
    test('the CLI a project pins and the one that is running are the same, '
        'and it runs here', () {
      cliPackage('cli', '0.10.1');
      final pinned = DwPinnedCli.of(project('cli'), runningVersion: '0.10.1');
      expect(pinned.pinnedVersion, '0.10.1');
      expect(pinned.isPinnedOne, isTrue);
      expect(pinned.isUnresolved, isFalse);
    });

    test('a CLI of another version is not the pinned one, and the pin is '
        'found in the Flutter package, where a project keeps it', () {
      cliPackage('cli', '0.11.0');
      final pinned = DwPinnedCli.of(project('cli'), runningVersion: '0.10.0');
      expect(pinned.pinnedVersion, '0.11.0');
      expect(p.basename(pinned.owner!.path), 'shop_flutter');
      expect(pinned.isPinnedOne, isFalse);
    });

    test('a directory that pins nothing disagrees with nothing: create and '
        'quickstart run where there is no project yet', () {
      final root = Directory(p.join(temp.path, 'empty'))..createSync();
      final pinned = DwPinnedCli.of(root, runningVersion: '0.10.1');
      expect(pinned.owner, isNull);
      expect(pinned.isPinnedOne, isTrue);
      expect(pinned.isUnresolved, isFalse);
    });

    test('a pin whose packages are not resolved is refused, with the command '
        'that resolves them', () {
      cliPackage('cli', '0.10.1');
      final pinned = DwPinnedCli.of(
        project('cli', resolved: false),
        runningVersion: '0.10.1',
      );
      expect(pinned.isUnresolved, isTrue);
      expect(
        pinned.unresolvedComplaint(),
        contains('(cd shop_flutter && dart pub get)'),
      );
    });

    test('a package config naming a CLI that is not there is no pin to '
        'run either', () {
      final pinned = DwPinnedCli.of(project('gone'), runningVersion: '0.10.1');
      expect(pinned.isUnresolved, isTrue);
    });
  });

  group('a bare dartway of another version', () {
    var repository = Directory.current.absolute;
    while (!Directory(p.join(repository.path, 'toolkit')).existsSync()) {
      repository = repository.parent;
    }
    final packages = p.join(repository.path, '.dart_tool/package_config.json');
    late String cli;
    setUpAll(() async => cli = await cliKernel(repository.path));

    Future<ProcessResult> dartway(
      List<String> args,
      Directory from, {
      Map<String, String>? environment,
    }) => runTestProcess(
      Platform.resolvedExecutable,
      ['--packages=$packages', cli, ...args],
      workingDirectory: from.path,
      environment: environment,
    );

    Future<void> pubGet(Directory package) async {
      final result = await runTestProcess(Platform.resolvedExecutable, [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: package.path);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    }

    test('runs the pinned one from the Flutter package, with the arguments, '
        'and passes its exit code on', () async {
      // Two versions: the CLI under test is dartwayCliVersion, the project
      // pins another.
      cliPackage('pinned_cli', '0.1.0-pinned');
      expect(dartwayCliVersion, isNot('0.1.0-pinned'));
      final root = project('pinned_cli', resolved: false);
      final flutter = Directory(p.join(root.path, 'shop_flutter'));
      await pubGet(flutter);

      final result = await dartway(['generate', '--check', 'x y'], root);
      expect(result.exitCode, 7, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('pinned ran: generate --check x y'));
      // Where it was typed, not in the package that pins the CLI.
      expect(result.stdout, contains('in: ${root.resolveSymbolicLinksSync()}'));
      expect(result.stdout, contains('reentry: 0.1.0-pinned'));
      expect(
        result.stderr,
        allOf(
          contains(
            'dartway $dartwayCliVersion: running the dartway_cli '
            '0.1.0-pinned this project pins',
          ),
          contains('the dart on PATH (no .fvmrc)'),
        ),
      );
    });

    test('runs it where it was typed, so a relative path means the same as '
        'to a direct run', () async {
      cliPackage('pinned_cli', '0.1.0-pinned');
      final root = project('pinned_cli', resolved: false);
      await pubGet(Directory(p.join(root.path, 'shop_flutter')));
      final server = Directory(p.join(root.path, 'shop_server'))
        ..createSync(recursive: true);

      final result = await dartway([
        'dev',
        'proxy',
        '--web-dir',
        'build/web',
      ], server);
      expect(
        result.stdout,
        contains('pinned ran: dev proxy --web-dir build/web'),
      );
      expect(
        result.stdout,
        contains('in: ${server.resolveSymbolicLinksSync()}'),
      );
    });

    test('runs it on the Dart of the Flutter .fvmrc pins', () async {
      cliPackage('pinned_cli', '0.1.0-pinned');
      final root = project('pinned_cli', resolved: false);
      final flutter = Directory(p.join(root.path, 'shop_flutter'));
      await pubGet(flutter);
      File(
        p.join(flutter.path, '.fvmrc'),
      ).writeAsStringSync('{"flutter": "9.9.9"}');
      final log = File(p.join(temp.path, 'sdk.log'));
      _fakeFlutterSdk(
        Directory(p.join(flutter.path, '.fvm', 'flutter_sdk')),
        '9.9.9',
        log,
      );

      final result = await dartway(['check'], root);
      expect(result.exitCode, 7, reason: '${result.stdout}${result.stderr}');
      expect(result.stdout, contains('pinned ran: check'));
      expect(
        result.stderr,
        contains('the Dart of Flutter 9.9.9 (shop_flutter/.fvm/flutter_sdk)'),
      );
      expect(log.readAsStringSync(), contains('bin/dartway.dart check'));
    }, skip: Platform.isWindows ? 'the fake SDK is a shell script' : null);

    test('refuses when the pin is not resolved, naming the fix', () async {
      cliPackage('pinned_cli', '0.1.0-pinned');
      final root = project('pinned_cli', resolved: false);
      final result = await dartway(['check'], root);
      expect(result.exitCode, 1);
      expect(result.stdout, isNot(contains('pinned ran')));
      expect(result.stderr, contains('(cd shop_flutter && dart pub get)'));
    });

    test(
      'an already-pinned deployer runs from an unresolved checkout',
      () async {
        cliPackage('pinned_cli', dartwayCliVersion);
        final root = project('pinned_cli', resolved: false);
        final result = await dartway(
          ['check', '--help'],
          root,
          environment: {DwPinnedCli.reentryVariable: dartwayCliVersion},
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(result.stdout, contains('Run DartWay convention checks'));
        expect(result.stderr, isNot(contains('packages are not resolved')));
      },
    );

    test('a pinned CLI that still disagrees once running is refused, not '
        'started again', () async {
      cliPackage('pinned_cli', '0.1.0-pinned');
      final root = project('pinned_cli', resolved: false);
      await pubGet(Directory(p.join(root.path, 'shop_flutter')));
      final result = await dartway(
        ['check'],
        root,
        environment: {DwPinnedCli.reentryVariable: '0.1.0-pinned'},
      );
      expect(result.exitCode, 1);
      expect(result.stdout, isNot(contains('pinned ran')));
      expect(result.stderr, contains('dart run dartway_cli:dartway check'));
    });

    test(
      'the refusal names the subcommand and nothing of its arguments',
      () async {
        cliPackage('pinned_cli', '0.1.0-pinned');
        final root = project('pinned_cli', resolved: false);
        await pubGet(Directory(p.join(root.path, 'shop_flutter')));
        final result = await dartway(
          ['test', '--database-url', 'postgres://user:hunter2@db/app'],
          root,
          environment: {DwPinnedCli.reentryVariable: '0.1.0-pinned'},
        );
        expect(result.exitCode, 1);
        expect(result.stderr, contains('dart run dartway_cli:dartway test)'));
        expect(
          '${result.stdout}${result.stderr}',
          allOf(isNot(contains('hunter2')), isNot(contains('--database-url'))),
        );
      },
    );
  });

  group('the exit code of a child killed by a signal', () {
    test('is 128 plus the signal on POSIX, as a shell reports it', () {
      expect(DwPinnedCli.exitCodeOf(-2, windows: false), 130);
      expect(DwPinnedCli.exitCodeOf(-15, windows: false), 143);
    });

    test('an ordinary exit code is passed on as it is', () {
      expect(DwPinnedCli.exitCodeOf(0, windows: false), 0);
      expect(DwPinnedCli.exitCodeOf(7, windows: false), 7);
      expect(DwPinnedCli.exitCodeOf(-1073741510, windows: true), -1073741510);
    });
  });
}

/// A Flutter SDK of [version] at [sdk] whose `bin/dart` notes every call in
/// [log] and runs the Dart running this test.
void _fakeFlutterSdk(Directory sdk, String version, File log) {
  Directory(p.join(sdk.path, 'bin', 'cache')).createSync(recursive: true);
  File(
    p.join(sdk.path, 'bin', 'cache', 'flutter.version.json'),
  ).writeAsStringSync(jsonEncode({'frameworkVersion': version}));
  final dart = File(p.join(sdk.path, 'bin', 'dart'))
    ..writeAsStringSync(
      '#!/bin/sh\n'
      'echo "\$*" >> "${log.path}"\n'
      'exec "${Platform.resolvedExecutable}" "\$@"\n',
    );
  Process.runSync('chmod', ['+x', dart.path]);
}
