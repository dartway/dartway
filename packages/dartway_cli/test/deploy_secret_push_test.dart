import 'dart:io';

import 'package:dartway_cli/src/commands/secret_commands.dart';
import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// Minimal fakes so a test can read what `runSecretPush` printed, the same
/// way the real CLI reads it — through `dart:io`'s `stdout`/`stderr`, never
/// by changing the function's signature to take a sink of its own.
class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void write(Object? object) => buffer.write(object);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingStdout implements Stdout {
  final _CapturingSink sink = _CapturingSink();

  @override
  void writeln([Object? object = '']) => sink.writeln(object);

  @override
  void write(Object? object) => sink.write(object);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

base class _CapturingIOOverrides extends IOOverrides {
  final _CapturingStdout out = _CapturingStdout();
  final _CapturingStdout err = _CapturingStdout();

  @override
  Stdout get stdout => out;

  @override
  Stdout get stderr => err;
}

/// Runs [runSecretPush] with its stdout/stderr captured instead of printed,
/// so a test can assert on the plan it prints without polluting the test
/// runner's own output.
Future<({int code, String out, String err})> _push({
  required DwStack stack,
  required DwSecretStore store,
  required Map<String, String> section,
  bool prune = false,
  bool allowEmptying = false,
  Set<String> overwrite = const {},
  bool dryRun = false,
}) async {
  final overrides = _CapturingIOOverrides();
  final code = await IOOverrides.runWithIOOverrides(
    () => runSecretPush(
      stack: stack,
      store: store,
      section: section,
      prune: prune,
      allowEmptying: allowEmptying,
      overwrite: overwrite,
      dryRun: dryRun,
    ),
    overrides,
  );
  return (
    code: code,
    out: overrides.out.sink.buffer.toString(),
    err: overrides.err.sink.buffer.toString(),
  );
}

void main() {
  late Directory root;
  late DwSecretStore store;
  final stack = stackVariants()['bundled storage and a site']!;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dw_secret_push_');
    store = DwSecretStore(
      ssh: LocalShell(),
      target: stack.target,
      directory: p.join(root.path, 'store'),
    );
  });
  tearDown(() => root.deleteSync(recursive: true));

  Map<String, String> stored() => File(store.file).existsSync()
      ? DwSecretStore.parse(File(store.file).readAsStringSync())
      : const {};

  group('a first push, nothing on the server yet', () {
    test('adds every key', () async {
      final result = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'first-value', 'OTHER_KEY': 'other-value'},
      );
      expect(result.code, 0);
      expect(result.out, contains('add: OTHER_KEY, SMS_API_TOKEN'));
      expect(stored(), {
        'SMS_API_TOKEN': 'first-value',
        'OTHER_KEY': 'other-value',
      });
      // Values are never printed, not even the one that was just sent.
      expect(result.out, isNot(contains('first-value')));
      expect(result.err, isNot(contains('first-value')));
    });
  });

  group('a key the server already holds', () {
    test('an equal value is kept, and reported as such', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'same-value');
      final result = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'same-value'},
      );
      expect(result.code, 0);
      expect(result.out, contains('keep (same): SMS_API_TOKEN'));
      expect(result.out, isNot(contains('overwrite')));
      expect(stored(), {'SMS_API_TOKEN': 'same-value'});
    });

    test(
      'an empty server value is treated as missing — added, not refused',
      () async {
        await store.ensureDirectory();
        File(store.file).writeAsStringSync("SMS_API_TOKEN=''\n");
        final result = await _push(
          stack: stack,
          store: store,
          section: {'SMS_API_TOKEN': 'new-value'},
        );
        expect(result.code, 0);
        expect(result.out, contains('add: SMS_API_TOKEN'));
        expect(stored(), {'SMS_API_TOKEN': 'new-value'});
      },
    );

    test(
      'a differing value is refused — the whole push, nothing sent, the key named',
      () async {
        await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');
        final before = File(store.file).readAsStringSync();

        final result = await _push(
          stack: stack,
          store: store,
          section: {'SMS_API_TOKEN': 'local-value', 'OTHER_KEY': 'ok'},
        );

        expect(result.code, 1);
        expect(result.out, contains('differs — refused: SMS_API_TOKEN'));
        expect(result.err, contains('SMS_API_TOKEN'));
        // No partial writes: OTHER_KEY (which would have been fine on its
        // own) never reaches the server either.
        expect(File(store.file).readAsStringSync(), before);
        expect(stored().containsKey('OTHER_KEY'), isFalse);
        // Neither value ever appears in what was printed.
        expect(result.out, isNot(contains('server-value')));
        expect(result.out, isNot(contains('local-value')));
        expect(result.err, isNot(contains('server-value')));
        expect(result.err, isNot(contains('local-value')));
      },
    );

    test('--overwrite unlocks only the keys it names', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-a');
      await store.setSecret(key: 'RESEND_API_KEY', value: 'server-b');

      // Naming only one of the two differing keys still refuses the whole
      // push: the other one differs too and was not named.
      final partial = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'local-a', 'RESEND_API_KEY': 'local-b'},
        overwrite: {'SMS_API_TOKEN'},
      );
      expect(partial.code, 1);
      expect(partial.out, contains('overwrite: SMS_API_TOKEN'));
      expect(partial.out, contains('differs — refused: RESEND_API_KEY'));
      expect(stored()['SMS_API_TOKEN'], 'server-a');

      // Naming both goes through.
      final full = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'local-a', 'RESEND_API_KEY': 'local-b'},
        overwrite: {'SMS_API_TOKEN', 'RESEND_API_KEY'},
      );
      expect(full.code, 0);
      expect(stored(), {
        'SMS_API_TOKEN': 'local-a',
        'RESEND_API_KEY': 'local-b',
      });
    });
  });

  group('a generated key', () {
    // The minimal stack (no bundled storage) generates exactly one secret —
    // the database password — so its section names nothing else and the
    // --prune guard never enters into it.
    final minimalStack = stackVariants()['minimal']!;
    late DwSecretStore minimalStore;

    setUp(() {
      minimalStore = DwSecretStore(
        ssh: LocalShell(),
        target: minimalStack.target,
        directory: p.join(root.path, 'minimal-store'),
      );
    });

    Map<String, String> storedIn(DwSecretStore s) => File(s.file).existsSync()
        ? DwSecretStore.parse(File(s.file).readAsStringSync())
        : const {};

    test(
      'differing is refused without naming it, even under a general push',
      () async {
        await minimalStore.ensureDirectory();
        await minimalStore.generateMissing(minimalStack.generatedSecrets);
        final generatedPassword = storedIn(
          minimalStore,
        )[DwStack.databasePasswordKey]!;

        final result = await _push(
          stack: minimalStack,
          store: minimalStore,
          section: {DwStack.databasePasswordKey: 'a-different-password'},
        );

        expect(result.code, 1);
        expect(
          result.out,
          contains('differs — refused: ${DwStack.databasePasswordKey}'),
        );
        expect(result.err, contains('bound to the data'));
        expect(
          storedIn(minimalStore)[DwStack.databasePasswordKey],
          generatedPassword,
        );
      },
    );

    test('named in --overwrite, it can be replaced on purpose', () async {
      await minimalStore.ensureDirectory();
      await minimalStore.generateMissing(minimalStack.generatedSecrets);

      final result = await _push(
        stack: minimalStack,
        store: minimalStore,
        section: {DwStack.databasePasswordKey: 'a-different-password'},
        overwrite: {DwStack.databasePasswordKey},
      );

      expect(result.code, 0);
      expect(
        storedIn(minimalStore)[DwStack.databasePasswordKey],
        'a-different-password',
      );
    });
  });

  group('blanking, the older guard', () {
    test(
      'is refused without --allow-emptying, distinct from --overwrite',
      () async {
        await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');

        final result = await _push(
          stack: stack,
          store: store,
          section: {'SMS_API_TOKEN': ''},
          overwrite: {'SMS_API_TOKEN'},
        );

        expect(result.code, 1);
        expect(result.err, contains('blanked'));
        expect(stored()['SMS_API_TOKEN'], 'server-value');
      },
    );

    test('--allow-emptying alone unlocks it', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');

      final result = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': ''},
        allowEmptying: true,
      );

      expect(result.code, 0);
      expect(stored()['SMS_API_TOKEN'], '');
    });
  });

  group('--dry-run', () {
    test('prints the plan and sends nothing', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');

      final result = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'server-value', 'NEW_KEY': 'x'},
        dryRun: true,
      );

      expect(result.code, 0);
      expect(result.out, contains('keep (same): SMS_API_TOKEN'));
      expect(result.out, contains('add: NEW_KEY'));
      expect(result.out, contains('Dry run'));
      expect(stored(), {'SMS_API_TOKEN': 'server-value'});
    });
  });

  group('orphaned keys — the --prune guard, unchanged', () {
    test('refuses without --prune, leaving the server untouched', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');
      final before = File(store.file).readAsStringSync();

      final result = await _push(
        stack: stack,
        store: store,
        section: {'OTHER_KEY': 'x'},
      );

      expect(result.code, 1);
      expect(result.out, contains('drop: SMS_API_TOKEN'));
      expect(File(store.file).readAsStringSync(), before);
    });

    test('--prune drops it', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');

      final result = await _push(
        stack: stack,
        store: store,
        section: {'OTHER_KEY': 'x'},
        prune: true,
      );

      expect(result.code, 0);
      expect(stored(), {'OTHER_KEY': 'x'});
    });
  });

  group('a reserved key', () {
    test('is refused up front, before the server is even asked', () async {
      final reserved = stack.reservedSecretKeys.first;
      final result = await _push(
        stack: stack,
        store: store,
        section: {reserved: 'x'},
      );
      expect(result.code, 1);
      expect(File(store.file).existsSync(), isFalse);
    });
  });

  group('an unreadable store (M1)', () {
    test(
      'refuses instead of treating every key as new — chmod 000 the store',
      () async {
        await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');
        final before = File(store.file).readAsStringSync();
        final chmod = await Process.run('chmod', ['000', store.file]);
        expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
        addTearDown(() => Process.runSync('chmod', ['600', store.file]));

        final result = await _push(
          stack: stack,
          store: store,
          section: {'SMS_API_TOKEN': 'a-new-value'},
        );

        expect(result.code, 1);
        expect(result.err, contains('could not be compared'));
        // Never claims the push happened.
        expect(result.out, isNot(contains('Pushed')));
        expect(result.out, isNot(contains('add: SMS_API_TOKEN')));
        // The store itself was never touched — restore permissions to read
        // it back and prove that.
        await Process.run('chmod', ['600', store.file]);
        expect(File(store.file).readAsStringSync(), before);
      },
    );
  });

  group('a key the plan does not classify (M2)', () {
    test(
      'is treated as refused, not silently sent as part of the section',
      () async {
        // A canned answer that never emits ADD/SAME/DIFFER for MYSTERY_KEY —
        // standing in for a plan that (by a bug, or a future change to the
        // script) failed to classify a candidate key at all.
        final recording = RecordingSsh([
          ('echo "ADD', const DwSshResult(exitCode: 0, stdout: '', stderr: '')),
        ]);
        final recordingStore = DwSecretStore(
          ssh: recording,
          target: stack.target,
          directory: p.join(root.path, 'recording-store'),
        );

        final result = await _push(
          stack: stack,
          store: recordingStore,
          section: {'MYSTERY_KEY': 'value'},
        );

        expect(result.code, 1);
        expect(result.err, contains('MYSTERY_KEY'));
        expect(result.err, contains('not classified'));
        expect(
          recording.issued.any(
            (c) => c.contains('Written by "dartway deploy secret push"'),
          ),
          isFalse,
          reason: 'an unclassified key must never reach a write',
        );
      },
    );
  });

  group('a generated key — every path, not only --overwrite (M3)', () {
    final minimalStack = stackVariants()['minimal']!;
    late DwSecretStore minimalStore;

    setUp(() {
      minimalStore = DwSecretStore(
        ssh: LocalShell(),
        target: minimalStack.target,
        directory: p.join(root.path, 'minimal-store-m3'),
      );
    });

    Map<String, String> storedIn(DwSecretStore s) => File(s.file).existsSync()
        ? DwSecretStore.parse(File(s.file).readAsStringSync())
        : const {};

    test(
      '--prune alone does not drop it; naming it in --overwrite is also required',
      () async {
        await minimalStore.ensureDirectory();
        await minimalStore.generateMissing(minimalStack.generatedSecrets);
        final generatedPassword = storedIn(
          minimalStore,
        )[DwStack.databasePasswordKey]!;

        // A section that simply does not mention the generated key at all —
        // the shape a maintainer's deploy/secrets.yaml has when it never
        // held the generated values to begin with.
        final pruneOnly = await _push(
          stack: minimalStack,
          store: minimalStore,
          section: const {},
          prune: true,
        );
        expect(pruneOnly.code, 1);
        expect(pruneOnly.err, contains(DwStack.databasePasswordKey));
        expect(pruneOnly.err, contains('bound to the data'));
        expect(
          storedIn(minimalStore)[DwStack.databasePasswordKey],
          generatedPassword,
        );

        final pruneAndNamed = await _push(
          stack: minimalStack,
          store: minimalStore,
          section: const {},
          prune: true,
          overwrite: {DwStack.databasePasswordKey},
        );
        expect(pruneAndNamed.code, 0);
        expect(
          storedIn(minimalStore).containsKey(DwStack.databasePasswordKey),
          isFalse,
        );
      },
    );

    test(
      '--allow-emptying alone does not blank it; naming it in --overwrite is also required',
      () async {
        await minimalStore.ensureDirectory();
        await minimalStore.generateMissing(minimalStack.generatedSecrets);
        final generatedPassword = storedIn(
          minimalStore,
        )[DwStack.databasePasswordKey]!;

        final emptyingOnly = await _push(
          stack: minimalStack,
          store: minimalStore,
          section: {DwStack.databasePasswordKey: ''},
          allowEmptying: true,
        );
        expect(emptyingOnly.code, 1);
        expect(emptyingOnly.err, contains(DwStack.databasePasswordKey));
        expect(emptyingOnly.err, contains('bound to the data'));
        expect(
          storedIn(minimalStore)[DwStack.databasePasswordKey],
          generatedPassword,
        );

        final emptyingAndNamed = await _push(
          stack: minimalStack,
          store: minimalStore,
          section: {DwStack.databasePasswordKey: ''},
          allowEmptying: true,
          overwrite: {DwStack.databasePasswordKey},
        );
        expect(emptyingAndNamed.code, 0);
        expect(storedIn(minimalStore)[DwStack.databasePasswordKey], '');
      },
    );
  });

  group('the plan-then-write race (M4)', () {
    test(
      'a store that changed since it was planned refuses the write, not overwrites it',
      () async {
        await store.setSecret(key: 'SMS_API_TOKEN', value: 'original');

        // The plan a push would have made from the store as it stood a
        // moment ago.
        final stalePlan = await store.plan({'SMS_API_TOKEN': 'original'});
        expect(stalePlan.ok, isTrue, reason: stalePlan.error);

        // Someone else's push (or a hand edit) lands in between.
        await store.setSecret(key: 'SMS_API_TOKEN', value: 'concurrent');

        final written = await store.writeAll({
          'SMS_API_TOKEN': 'original',
        }, expectedFingerprint: stalePlan.fingerprint);

        expect(written.ok, isFalse);
        expect(written.stderr, contains('changed'));
        expect(stored()['SMS_API_TOKEN'], 'concurrent');
      },
    );

    test('a fingerprint that still matches writes normally', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'original');
      final freshPlan = await store.plan({'SMS_API_TOKEN': 'original'});
      expect(freshPlan.ok, isTrue, reason: freshPlan.error);

      final written = await store.writeAll({
        'SMS_API_TOKEN': 'updated',
      }, expectedFingerprint: freshPlan.fingerprint);

      expect(written.ok, isTrue, reason: written.stderr);
      expect(stored()['SMS_API_TOKEN'], 'updated');
    });
  });

  group('--dry-run with a refusal (L2)', () {
    test('prints the plan with the refusal and sends nothing', () async {
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'server-value');

      final result = await _push(
        stack: stack,
        store: store,
        section: {'SMS_API_TOKEN': 'local-value'},
        dryRun: true,
      );

      expect(result.code, 1);
      expect(result.out, contains('differs — refused: SMS_API_TOKEN'));
      expect(result.err, contains('SMS_API_TOKEN'));
      expect(stored()['SMS_API_TOKEN'], 'server-value');
    });
  });
}
