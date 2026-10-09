import 'dart:io';

import 'package:dartway_cli/src/commands/secret_commands.dart';
import 'package:dartway_cli/src/deploy/local_secrets_file.dart';
import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

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

void main() {
  late Directory root;
  late DwSecretStore store;
  late DwLocalSecretsFile local;
  final stack = stackVariants()['bundled storage and a site']!;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('dw_secret_pull_');
    store = DwSecretStore(
      ssh: LocalShell(),
      target: stack.target,
      directory: p.join(root.path, 'store'),
    );
    await store.ensureDirectory();
    local = DwLocalSecretsFile(
      File(p.join(root.path, 'deploy', 'secrets.yaml')),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  void writeLocal(String body) {
    local.file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(body);
  }

  Future<({int code, String out, String err})> pull({
    Set<String> overwrite = const {},
    bool dryRun = false,
  }) async {
    final overrides = _CapturingIOOverrides();
    final code = await IOOverrides.runWithIOOverrides(
      () => runSecretPull(
        stack: stack,
        store: store,
        local: local,
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

  void expectValuesHidden(
    ({int code, String out, String err}) result,
    Iterable<String> sentinels,
  ) {
    for (final sentinel in sentinels) {
      expect(result.out, isNot(contains(sentinel)));
      expect(result.err, isNot(contains(sentinel)));
    }
  }

  test('overwrites a named key and preserves the file', () async {
    const oldA = 'local-a-sentinel';
    const newA = 'server-a-sentinel';
    const added = 'server-added-sentinel';
    writeLocal('''
# owner note
staging:
  A: '$oldA'

production:
  KEEP: 'production-sentinel'
''');
    await store.setSecret(key: 'A', value: newA);
    await store.setSecret(key: 'ADDED', value: added);

    final result = await pull(overwrite: {'A'});

    expect(result.code, 0);
    expect(result.out, contains('add: ADDED'));
    expect(result.out, contains('overwrite: A'));
    expect(local.read()!['staging'], {'A': newA, 'ADDED': added});
    final text = local.file.readAsStringSync();
    expect(text, contains('# owner note'));
    expect(text, contains("production:\n  KEEP: 'production-sentinel'"));
    expectValuesHidden(result, [oldA, newA, added, 'production-sentinel']);
  });

  test('reports a ready command without changing bytes', () async {
    const oldA = 'local-report-sentinel';
    const newA = 'server-report-sentinel';
    writeLocal("staging:\n  A: '$oldA'\n");
    await store.setSecret(key: 'A', value: newA);
    final before = local.file.readAsBytesSync();

    final result = await pull();

    expect(result.code, 0);
    expect(result.out, contains('--env staging --overwrite A'));
    expect(local.file.readAsBytesSync(), before);
    expectValuesHidden(result, [oldA, newA]);
  });

  test('dry run prints the overwrite plan and changes no bytes', () async {
    const oldA = 'local-dry-sentinel';
    const newA = 'server-dry-sentinel';
    writeLocal("staging:\n  A: '$oldA'\n");
    await store.setSecret(key: 'A', value: newA);
    final before = local.file.readAsBytesSync();

    final result = await pull(overwrite: {'A'}, dryRun: true);

    expect(result.code, 0);
    expect(result.out, contains('overwrite: A'));
    expect(result.out, contains('Dry run'));
    expect(local.file.readAsBytesSync(), before);
    expectValuesHidden(result, [oldA, newA]);
  });

  test('overwrites a named key while only reporting another', () async {
    const localA = 'local-partial-a-sentinel';
    const serverA = 'server-partial-a-sentinel';
    const localB = 'local-partial-b-sentinel';
    const serverB = 'server-partial-b-sentinel';
    writeLocal("staging:\n  A: '$localA'\n  B: '$localB'\n");
    await store.setSecret(key: 'A', value: serverA);
    await store.setSecret(key: 'B', value: serverB);

    final result = await pull(overwrite: {'A'});

    expect(result.code, 0);
    expect(result.out, contains('overwrite: A'));
    expect(result.out, contains('values differ: B'));
    expect(local.read()!['staging'], {'A': serverA, 'B': localB});
    expectValuesHidden(result, [localA, serverA, localB, serverB]);
  });

  test('overwrites a named generated database password', () async {
    const localPassword = 'local-generated-sentinel';
    const serverPassword = 'server-generated-sentinel';
    writeLocal(
      "staging:\n  ${DwStack.databasePasswordKey}: '$localPassword'\n",
    );
    await store.setSecret(
      key: DwStack.databasePasswordKey,
      value: serverPassword,
    );

    final result = await pull(overwrite: {DwStack.databasePasswordKey});

    expect(result.code, 0);
    expect(
      local.read()!['staging']![DwStack.databasePasswordKey],
      serverPassword,
    );
    expectValuesHidden(result, [localPassword, serverPassword]);
  });

  test('refuses a named empty server value without any write', () async {
    const localA = 'local-empty-guard-sentinel';
    writeLocal("staging:\n  A: '$localA'\n");
    File(store.file).writeAsStringSync("A=''\n");
    final before = local.file.readAsBytesSync();

    final result = await pull(overwrite: {'A'});

    expect(result.code, 1);
    expect(result.err, contains('A'));
    expect(local.file.readAsBytesSync(), before);
    expectValuesHidden(result, [localA]);
  });

  test('restores a block scalar when read-back cannot verify it', () async {
    const serverA = 'server-block-sentinel';
    const oldPart = 'local-block-sentinel';
    writeLocal('''
staging:
  A: |-
    $oldPart
''');
    await store.setSecret(key: 'A', value: serverA);
    final before = local.file.readAsBytesSync();

    final result = await pull(overwrite: {'A'});

    expect(result.code, 1);
    expect(result.err, contains('A'));
    expect(local.file.readAsBytesSync(), before);
    expectValuesHidden(result, [oldPart, serverA]);
  });
}
