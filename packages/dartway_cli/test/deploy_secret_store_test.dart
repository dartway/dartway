import 'dart:io';

import 'package:dartway_cli/src/deploy/local_secrets_file.dart';
import 'package:dartway_cli/src/deploy/secret_store.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  group('a line of the store', () {
    // Single-quoted: Compose takes the value literally — no `$` interpolation,
    // no `#` comment. Verified against Compose itself by the local stack proof.
    test('keeps an awkward value literal', () {
      const value = r'a$b #c "d" \n ${X} `e` @*';
      final line = DwSecretStore.encodeLine('SMS_API_TOKEN', value);
      expect(line, "SMS_API_TOKEN='$value'");
      expect(DwSecretStore.parse(line), {'SMS_API_TOKEN': value});
    });

    test(
      'refuses a value the format cannot carry, rather than mangling it',
      () {
        expect(
          () => DwSecretStore.encodeLine('TOKEN', "it's"),
          throwsA(isA<DwSecretFormatException>()),
        );
        expect(
          () => DwSecretStore.encodeLine('TOKEN', 'two\nlines'),
          throwsA(isA<DwSecretFormatException>()),
        );
        expect(
          () => DwSecretStore.encodeLine('token', 'x'),
          throwsA(isA<DwSecretFormatException>()),
        );
      },
    );

    test('a malformed store names the line, never its content', () {
      expect(
        () => DwSecretStore.parse("# ok\nA='1'\nB=secret-value\n"),
        throwsA(
          isA<DwSecretFormatException>()
              .having((e) => e.message, 'message', contains('line 3'))
              .having(
                (e) => e.message,
                'message',
                isNot(contains('secret-value')),
              ),
        ),
      );
    });
  });

  // The scripts a deploy sends to a server, run in a local shell: what is
  // tested is the shell, not a description of it.
  group('the store on a server', () {
    late Directory root;
    late DwSecretStore store;
    late String appDir;
    final stack = stackVariants()['minio and a site']!;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dw_store_');
      appDir = p.join(root.path, 'checkout');
      Directory(appDir).createSync();
      store = DwSecretStore(
        ssh: LocalShell(),
        target: stack.target,
        directory: p.join(root.path, 'store'),
      );
    });
    tearDown(() => root.deleteSync(recursive: true));

    Map<String, String> stored() =>
        DwSecretStore.parse(File(store.file).readAsStringSync());

    Future<void> render() async {
      final result = await store.renderEnvironment(
        appDir: appDir,
        required: stack.requiredSecretKeys,
        reserved: stack.reservedSecretKeys,
      );
      expect(result.ok, isTrue, reason: result.stderr);
    }

    test(
      'generates random values of the stated length, and never twice',
      () async {
        expect((await store.ensureDirectory()).ok, isTrue);
        final first = await store.generateMissing(stack.generatedSecrets);
        expect(first.ok, isTrue, reason: first.stderr);
        expect(first.stdout.trim().split('\n'), stack.generatedSecrets.keys);

        final values = stored();
        expect(values[DwStack.databasePasswordKey], hasLength(64));
        expect(values[DwStack.storageAccessKey], hasLength(20));
        expect(values[DwStack.storageSecretKey], hasLength(64));
        expect(File(store.file).statSync().modeString(), 'rw-------');

        final second = await store.generateMissing(stack.generatedSecrets);
        expect(second.stdout.trim(), isEmpty);
        expect(stored(), values);
      },
    );

    test('set replaces one key and keeps the rest', () async {
      await store.ensureDirectory();
      await store.generateMissing(stack.generatedSecrets);
      final password = stored()[DwStack.databasePasswordKey];

      for (final value in [r'first $value', 'second # value']) {
        final result = await store.setSecret(
          key: 'SMS_API_TOKEN',
          value: value,
        );
        expect(result.ok, isTrue, reason: result.stderr);
      }
      expect(stored()['SMS_API_TOKEN'], 'second # value');
      expect(stored()[DwStack.databasePasswordKey], password);
      expect(
        File(store.file).readAsStringSync().split('SMS_API_TOKEN='),
        hasLength(2),
        reason: 'one line per key',
      );
    });

    test('key names travel, values do not', () async {
      await store.ensureDirectory();
      await store.setSecret(key: 'SMS_API_TOKEN', value: 'secret-value');
      File(store.file).writeAsStringSync("EMPTY=''\n", mode: FileMode.append);

      final names = await store.readKeyNames();
      final filled = await store.readNonEmptyKeyNames();
      expect(names.names, {'SMS_API_TOKEN', 'EMPTY'});
      expect(filled.names, {'SMS_API_TOKEN'});
      expect('${names.names}${filled.names}', isNot(contains('secret-value')));
    });

    test('renders .env with every stored key, mode 0600', () async {
      await store.ensureDirectory();
      await store.generateMissing(stack.generatedSecrets);
      await render();

      final env = File(p.join(appDir, '.env'));
      expect(env.statSync().modeString(), 'rw-------');
      expect(DwSecretStore.parse(env.readAsStringSync()), stored());
    });

    Future<String> refusal() async {
      final result = await store.renderEnvironment(
        appDir: appDir,
        required: stack.requiredSecretKeys,
        reserved: stack.reservedSecretKeys,
      );
      expect(result.ok, isFalse);
      expect(File(p.join(appDir, '.env')).existsSync(), isFalse);
      return result.stderr;
    }

    test('refuses without a store', () async {
      expect(await refusal(), contains('secret init'));
    });

    test('refuses a missing or empty required secret, by name', () async {
      await store.ensureDirectory();
      await store.setSecret(key: DwStack.storageAccessKey, value: 'key');
      File(store.file).writeAsStringSync(
        "${DwStack.storageSecretKey}=''\n",
        mode: FileMode.append,
      );
      final message = await refusal();
      expect(message, contains(DwStack.databasePasswordKey));
      expect(message, contains(DwStack.storageSecretKey));
      expect(message, isNot(contains("'key'")));
    });

    test(
      'refuses a line Compose would read differently from what was meant',
      () async {
        await store.ensureDirectory();
        await store.generateMissing(stack.generatedSecrets);
        File(store.file).writeAsStringSync(
          'HAND_EDITED=value with # a comment\n',
          mode: FileMode.append,
        );
        final message = await refusal();
        expect(message, contains('line(s) 4'));
        expect(message, isNot(contains('a comment')));
      },
    );

    test('refuses a key declared twice', () async {
      await store.ensureDirectory();
      await store.generateMissing(stack.generatedSecrets);
      File(
        store.file,
      ).writeAsStringSync("TOKEN='a'\nTOKEN='b'\n", mode: FileMode.append);
      expect(await refusal(), contains('more than once'));
    });

    test('refuses a name the compose file sets itself', () async {
      await store.ensureDirectory();
      await store.generateMissing(stack.generatedSecrets);
      File(store.file).writeAsStringSync(
        "DW_DATABASE_HOST='elsewhere'\n",
        mode: FileMode.append,
      );
      expect(await refusal(), contains('DW_DATABASE_HOST'));
    });

    test(
      'push writes the whole store; the file list excludes the key file',
      () async {
        final written = await store.writeAll({'A': '1', 'B': r'$2'});
        expect(written.ok, isTrue, reason: written.stderr);
        expect(stored(), {'A': '1', 'B': r'$2'});

        File(p.join(store.directory, 'fcm.json')).writeAsStringSync('{}');
        final files = await store.listFiles();
        expect(files.ok, isTrue);
        expect(files.names, ['fcm.json']);
      },
    );

    test(
      'an absent store directory lists as unreadable, not as empty',
      () async {
        expect((await store.listFiles()).ok, isFalse);
      },
    );
  });

  group('deploy/secrets.yaml', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('dw_local_secrets'));
    tearDown(() => root.deleteSync(recursive: true));

    test('writes into one section and keeps what a person wrote', () {
      final local = DwLocalSecretsFile.of(root);
      local.file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''
# where each key comes from
staging:
  # issued by the SMS provider
  SMS_API_TOKEN: ''

production:
  SMS_API_TOKEN: 'prod'
''');

      local.write('staging', {
        'SMS_API_TOKEN': "it's",
        'DW_DATABASE_PASSWORD': 'x',
      });
      local.write('test', {'A': 'b'});

      final text = local.file.readAsStringSync();
      expect(text, contains('# issued by the SMS provider'));
      expect(local.read(), {
        'staging': {'SMS_API_TOKEN': "it's", 'DW_DATABASE_PASSWORD': 'x'},
        'production': {'SMS_API_TOKEN': 'prod'},
        'test': {'A': 'b'},
      });
    });

    test('a value written as a YAML map is refused, not stringified', () {
      final local = DwLocalSecretsFile.of(root);
      local.file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('staging:\n  JSON: {a: 1}\n');
      expect(local.read, throwsStateError);
    });
  });
}
