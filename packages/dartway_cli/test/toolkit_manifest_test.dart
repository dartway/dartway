import 'dart:io';

import 'package:dartway_cli/src/monorepo_source.dart';
import 'package:dartway_cli/src/toolkit_manifest.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the version constant matches the pubspec', () {
    // A compiled or globally activated executable has no reliable way back to
    // its own pubspec, so the version is a constant — and a constant copied
    // from a file is a copy, which is why this compares them.
    var dir = Directory.current.absolute;
    while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      dir = dir.parent;
    }
    final pubspec =
        loadYaml(File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync())
            as YamlMap;

    expect(pubspec['name'], 'dartway_cli', reason: 'wrong pubspec found');
    expect(pubspec['version'], dartwayCliVersion);
  });

  group('ToolkitProvenance', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('dw_manifest');
      Directory(p.join(sandbox.path, '.claude')).createSync();
    });
    tearDown(() => sandbox.deleteSync(recursive: true));

    const fromChannel = ToolkitProvenance(
      source: 'https://github.com/dartway/dartway.git',
      channel: 'master',
      commit: '0123456789abcdef',
      cliVersion: '0.9.0',
      installedAt: '2026-08-30T00:00:00.000Z',
    );

    test('what is written comes back', () {
      fromChannel.write(sandbox);
      final read = ToolkitProvenance.read(sandbox)!;

      expect(read.source, fromChannel.source);
      expect(read.channel, 'master');
      expect(read.commit, '0123456789abcdef');
      expect(read.cliVersion, '0.9.0');
    });

    test('a local checkout records no channel', () {
      // A working directory's branch says nothing about what a project should
      // follow, so recording one would invite a comparison that means nothing.
      const local = ToolkitProvenance(
        source: '/home/dev/dartway',
        channel: null,
        commit: 'abc1234',
        cliVersion: '0.9.0',
        installedAt: '2026-08-30T00:00:00.000Z',
      );
      local.write(sandbox);

      expect(ToolkitProvenance.read(sandbox)!.channel, isNull);
      expect(
        local.describe(),
        '/home/dev/dartway (abc1234), installed by dartway 0.9.0',
      );
    });

    test('a commit shorter than a short hash does not break the line', () {
      const odd = ToolkitProvenance(
        source: 'x',
        channel: 'master',
        commit: 'abc',
        cliVersion: '0.9.0',
        installedAt: '2026-08-30T00:00:00.000Z',
      );

      expect(odd.describe(), 'x@master (abc), installed by dartway 0.9.0');
    });

    test('a project installed before this existed reads as nothing', () {
      expect(ToolkitProvenance.read(sandbox), isNull);
    });

    test('an unreadable manifest reads as nothing, not as a crash', () {
      File(
        p.join(sandbox.path, '.claude', 'dartway-toolkit.json'),
      ).writeAsStringSync('[]');

      expect(ToolkitProvenance.read(sandbox), isNull);
    });

    test('the description names the channel and the short commit', () {
      expect(
        fromChannel.describe(),
        'https://github.com/dartway/dartway.git@master (0123456), '
        'installed by dartway 0.9.0',
      );
    });
  });

  group('channelSwitchRefusal', () {
    const onMaster = ToolkitProvenance(
      source: 'https://github.com/dartway/dartway.git',
      channel: 'master',
      commit: 'abc',
      cliVersion: '0.9.0',
      installedAt: '2026-08-30T00:00:00.000Z',
    );

    String? refusalFor({
      ToolkitProvenance? installed,
      String requested = 'stable',
      bool explicit = false,
      bool local = false,
    }) => channelSwitchRefusal(
      installed: installed,
      requestedChannel: requested,
      channelWasExplicit: explicit,
      fromLocalCheckout: local,
    );

    test('refuses the silent rollback', () {
      // The case that happens: a project deliberately on master, and a plain
      // `dartway setup-ai` whose --channel defaults to stable.
      final refusal = refusalFor(installed: onMaster);

      expect(refusal, isNotNull);
      expect(refusal, contains('master'));
      expect(refusal, contains('stable'));
      expect(refusal, contains('--channel'));
    });

    test('allows it when the channel was asked for by name', () {
      // Naming it leaves the decision written down in the command that ran.
      expect(refusalFor(installed: onMaster, explicit: true), isNull);
    });

    test('allows an update on the same channel', () {
      expect(refusalFor(installed: onMaster, requested: 'master'), isNull);
    });

    test('allows an install from a local checkout', () {
      // `--local-repo` resolves to the directory it was handed and ignores the
      // channel entirely, then records none. Judging it against the `--channel`
      // default would block the framework's own development loop for any
      // project whose harness came from a non-default channel — over a channel
      // the run was never going to touch.
      expect(refusalFor(installed: onMaster, local: true), isNull);
    });

    test('allows a project that has no manifest yet', () {
      // Every project installed before this existed. Refusing them would turn
      // a missing record into a blocked update.
      expect(refusalFor(installed: null), isNull);
    });

    test('allows one installed from a local checkout', () {
      const local = ToolkitProvenance(
        source: '/home/dev/dartway',
        channel: null,
        commit: 'abc',
        cliVersion: '0.9.0',
        installedAt: '2026-08-30T00:00:00.000Z',
      );

      expect(refusalFor(installed: local), isNull);
    });
  });

  group('MonorepoSource.isLocalCheckout', () {
    test('the argument makes it local', () {
      expect(
        MonorepoSource(
          branch: 'stable',
          localDir: '/home/dev/dartway',
          environment: const {},
        ).isLocalCheckout,
        isTrue,
      );
    });

    test('so does the environment variable, with no argument', () {
      // The half that was missed: a caller checking the `--local-repo`
      // argument disagreed with what `resolve()` would actually do, and
      // refused a channel switch over a channel nothing was going to touch.
      expect(
        MonorepoSource(
          branch: 'stable',
          environment: const {'DARTWAY_MONOREPO_DIR': '/home/dev/dartway'},
        ).isLocalCheckout,
        isTrue,
      );
    });

    test('the argument wins over the variable', () {
      expect(
        MonorepoSource(
          branch: 'stable',
          localDir: '/from/argument',
          environment: const {'DARTWAY_MONOREPO_DIR': '/from/env'},
        ).localDir,
        '/from/argument',
      );
    });

    test('an empty argument falls through to the variable', () {
      expect(
        MonorepoSource(
          branch: 'stable',
          localDir: '',
          environment: const {'DARTWAY_MONOREPO_DIR': '/from/env'},
        ).localDir,
        '/from/env',
      );
    });

    test('neither means a channel', () {
      expect(
        MonorepoSource(branch: 'stable', environment: const {}).isLocalCheckout,
        isFalse,
      );
    });
  });
}
