// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final repo = Directory(p.normalize(p.join(Directory.current.path, '../..')));
  final config = File(p.join(repo.path, '.dart_tool/package_config.json'));
  late Directory root;
  late Directory server;
  late File dockerCalled;
  late String compiledCli;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('dw463_');
    server = Directory(p.join(root.path, 'proof_server'))..createSync();
    for (final role in ['shared', 'flutter']) {
      Directory(p.join(root.path, 'proof_$role')).createSync();
    }
    final packages = jsonDecode(config.readAsStringSync()) as Map;
    for (final entry in packages['packages'] as List) {
      entry['rootUri'] = config.uri
          .resolve(entry['rootUri'] as String)
          .toString();
    }
    final overrides = StringBuffer();
    for (final entry in packages['packages'] as List) {
      if ((entry['name'] as String).startsWith('dartway_')) {
        overrides.writeln(
          '  ${entry['name']}:\n    path: ${Uri.parse(entry['rootUri'] as String).toFilePath()}',
        );
      }
    }
    File(p.join(server.path, 'pubspec.yaml')).writeAsStringSync(
      'name: proof_server\nenvironment:\n  sdk: ^3.11.0\n'
      'dependencies:\n  dartway_core_server: any\n  test: any\n'
      'dependency_overrides:\n$overrides',
    );
    (packages['packages'] as List).add({
      'name': 'proof_server',
      'rootUri': server.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.11',
    });
    final copied = File(p.join(server.path, '.dart_tool/package_config.json'));
    copied.createSync(recursive: true);
    copied.writeAsStringSync(jsonEncode(packages));
    Directory(p.join(server.path, 'test')).createSync();
    final bin = Directory(p.join(root.path, 'bin'))..createSync();
    dockerCalled = File(p.join(root.path, 'docker_called'));
    final docker = File(p.join(bin.path, 'docker'));
    docker.writeAsStringSync(
      '#!/bin/sh\necho called >> "${dockerCalled.path}"\nexit 1\n',
    );
    await Process.run('chmod', ['+x', docker.path]);
  });
  tearDown(() async => root.delete(recursive: true));

  Future<Process> launch(
    List<String> arguments, {
    Map<String, String> environment = const {},
    bool compiled = false,
    bool processGroup = false,
  }) => Process.start(
    processGroup
        ? '/bin/bash'
        : compiled
        ? compiledCli
        : Platform.resolvedExecutable,
    [
      if (processGroup) ...[
        '-c',
        // Job control gives the CLI and its descendants a separate group, while
        // the wrapper stays outside it to report the CLI's exit status.
        r'''
set -m
group_file=$1
shift
"$@" &
child=$!
printf '%s\n' "$child" > "$group_file"
wait "$child"
''',
        'dartway-test-group',
        p.join(root.path, 'process-group'),
        compiled ? compiledCli : Platform.resolvedExecutable,
      ],
      if (!compiled) ...[
        '--packages=${config.path}',
        p.join(repo.path, 'packages/dartway_cli/bin/dartway.dart'),
      ],
      'test',
      ...arguments,
    ],
    workingDirectory: root.path,
    environment: {
      ...Platform.environment,
      'PATH': '${p.join(root.path, 'bin')}:${Platform.environment['PATH']}',
      ...environment,
    },
  );
  Future<(int, String)> run(
    List<String> arguments, {
    Map<String, String> environment = const {},
  }) async {
    final process = await launch(arguments, environment: environment);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    return (code, '${await output}${await errors}');
  }

  Future<ProcessResult> signalGroup(int groupId, String signal) => Process.run(
    '/bin/bash',
    ['-c', r'kill -s "$1" -- "-$2"', 'dartway-test-group', signal, '$groupId'],
  );

  test(
    'remote database is refused before services start, without leaking credentials',
    () async {
      final (code, output) = await run([
        '--database-url',
        'postgres://user:private@192.0.2.1/postgres',
      ]);
      expect(code, 1);
      expect(output, contains('loopback'));
      expect(output, isNot(contains('private')));
      expect(dockerCalled.existsSync(), isFalse);
    },
  );
  test(
    'a mismatched CLI pin does not print explicit server credentials',
    () async {
      final heldCli = Directory(p.join(root.path, 'held_cli'))..createSync();
      File(
        p.join(heldCli.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: dartway_cli\nversion: 0.0.1\n');
      final pinned = File(
        p.join(root.path, 'proof_flutter/.dart_tool/package_config.json'),
      );
      pinned.createSync(recursive: true);
      pinned.writeAsStringSync(
        jsonEncode({
          'packages': [
            {'name': 'dartway_cli', 'rootUri': heldCli.uri.toString()},
          ],
        }),
      );
      final (code, output) = await run([
        '--database-url',
        'postgres://user:private-value@127.0.0.1/postgres',
      ]);
      expect(code, 1);
      expect(output, contains('This project pins'));
      expect(output, isNot(contains('private-value')));
    },
  );

  test('inherited database coordinates still select containers', () async {
    final (code, output) = await run(
      ['--no-storage'],
      environment: {
        'DW_DATABASE_HOST': '192.0.2.1',
        'DW_DATABASE_PASSWORD': 'stage-secret',
      },
    );
    expect(code, 1);
    expect(dockerCalled.readAsStringSync(), contains('called'));
    expect(output, contains('Docker daemon'));
    expect(output, isNot(contains('stage-secret')));
  });
  test('remote storage is refused before a local database connects', () async {
    final (code, output) = await run([
      '--database-url',
      'postgres://user:private@127.0.0.1:1/postgres',
      '--storage-url',
      'http://key:private@192.0.2.1:9000',
    ]);
    expect(code, 1);
    expect(output, contains('loopback'));
    expect(output, isNot(contains('Servers ready')));
    expect(dockerCalled.existsSync(), isFalse);
  });

  Future<void> waitFor(File marker) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!marker.existsSync()) {
      if (DateTime.now().isAfter(deadline))
        fail('Never reached ${marker.path}');
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  void containerDocker({String phase = '', int storagePort = 9000}) {
    File(p.join(root.path, 'bin/docker')).writeAsStringSync('''
#!/bin/sh
case "\$1" in
  run)
    id=database-id
    for arg in "\$@"; do
      [ "\$arg" = '127.0.0.1::9000' ] && id=storage-id
    done
    echo "run \$id" >> '${dockerCalled.path}'
    if [ '$phase' = "\$id-start" ]; then
      touch '${root.path}/entered'
      while [ ! -f '${root.path}/release' ]; do sleep 0.05; done
    fi
    echo "\$id"
    ;;
  port)
    if [ "\$2" = storage-id ]; then echo '127.0.0.1:$storagePort';
    else echo '127.0.0.1:54321'; fi
    ;;
  exec)
    if [ '$phase' = database-ready ]; then
      touch '${root.path}/entered'
      exit 1
    fi
    ;;
  rm) echo "rm \$3" >> '${dockerCalled.path}' ;;
  *) exit 1 ;;
esac
''');
  }

  for (final phase in [
    'database-id-start',
    'storage-id-start',
    'database-ready',
    'storage-ready',
  ]) {
    test(
      'SIGINT during $phase exits promptly and removes acquired containers',
      () async {
        final marker = File(p.join(root.path, 'entered'));
        HttpServer? health;
        if (phase == 'storage-ready') {
          health = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => health!.close(force: true));
          health.listen((request) {
            marker.writeAsStringSync('health requested');
            // A listening storage that never answers must not hold cancellation.
          });
        }
        containerDocker(phase: phase, storagePort: health?.port ?? 9000);
        final withStorage = phase.startsWith('storage');
        final process = await launch([if (!withStorage) '--no-storage']);
        addTearDown(() => process.kill(ProcessSignal.sigkill));
        addTearDown(() {
          File(p.join(root.path, 'release')).writeAsStringSync('release');
        });
        final output = process.stdout.transform(utf8.decoder).join();
        final errors = process.stderr.transform(utf8.decoder).join();
        await waitFor(marker);
        final elapsed = Stopwatch()..start();
        expect(process.kill(ProcessSignal.sigint), isTrue);
        if (phase.endsWith('start')) {
          // Keep Docker pending until the command has handled the signal.
          await Future<void>.delayed(const Duration(milliseconds: 150));
          File(p.join(root.path, 'release')).writeAsStringSync('release');
        }
        final code = await process.exitCode.timeout(const Duration(seconds: 8));
        expect(code, 130, reason: '${await output}${await errors}');
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 8)));
        final calls = dockerCalled.readAsStringSync();
        expect(calls, contains('rm database-id'));
        if (withStorage) expect(calls, contains('rm storage-id'));
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );
  }

  test(
    'compiled CLI uses Dart for both the suite and service workers',
    () async {
      compiledCli = p.join(root.path, 'dartway');
      final compiled = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        '--packages=${config.path}',
        p.join(repo.path, 'packages/dartway_cli/bin/dartway.dart'),
        '-o',
        compiledCli,
      ]);
      expect(
        compiled.exitCode,
        0,
        reason: '${compiled.stdout}${compiled.stderr}',
      );
      final storage = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => storage.close(force: true));
      storage.listen((request) async {
        request.response.write(
          '<ListAllMyBucketsResult><Buckets/></ListAllMyBucketsResult>',
        );
        await request.response.close();
      });
      containerDocker();
      File(p.join(server.path, 'test/compiled_test.dart')).writeAsStringSync('''
import 'package:test/test.dart';
void main() { test('suite ran', () => expect(2 + 2, 4)); }
''');
      final dartCalled = File(p.join(root.path, 'dart_called'));
      final dart = File(p.join(root.path, 'bin/dart'));
      dart.writeAsStringSync('''
#!/bin/sh
echo "\$1" >> '${dartCalled.path}'
exec '${Platform.resolvedExecutable}' "\$@"
''');
      await Process.run('chmod', ['+x', dart.path]);
      final process = await launch([
        '--storage-url',
        'http://key:secret@127.0.0.1:${storage.port}',
      ], compiled: true);
      addTearDown(() => process.kill(ProcessSignal.sigkill));
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode.timeout(const Duration(seconds: 40));
      expect(code, 0, reason: '${await output}${await errors}');
      final calls = dartCalled.readAsLinesSync();
      expect(calls, hasLength(3));
      expect(calls[0], startsWith('--packages='));
      expect(calls[1], 'test');
      expect(calls[2], startsWith('--packages='));
      expect(dockerCalled.readAsStringSync(), contains('rm database-id'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'real containers run the suite and are removed afterwards',
    () async {
      File(p.join(server.path, 'test/containers_test.dart')).writeAsStringSync(
        '''
import 'dart:convert';
import 'dart:io';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';
void main() {
  test('isolated database and storage', () async {
    final database = await DwTestDatabase.create();
    addTearDown(database.drop);
    final storage = await DwTestStorage.create();
    addTearDown(storage.drop);
    File('${root.path}/services.json').writeAsStringSync(jsonEncode([
      database.config.port, storage.config.endpoint.port,
    ]));
  });
}
''',
      );
      // Bypass the Docker double only for this opt-in daemon proof.
      final process = await launch(
        [],
        environment: {
          'PATH':
              '${p.dirname(Platform.resolvedExecutable)}:${Platform.environment['PATH']}',
        },
      );
      addTearDown(() => process.kill(ProcessSignal.sigint));
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode.timeout(const Duration(minutes: 2));
      expect(code, 0, reason: '${await output}${await errors}');
      expect(dockerCalled.existsSync(), isFalse);
      final ports =
          jsonDecode(
                File(p.join(root.path, 'services.json')).readAsStringSync(),
              )
              as List;
      for (final port in ports.cast<int>()) {
        await expectLater(
          Socket.connect(
            InternetAddress.loopbackIPv4,
            port,
            timeout: const Duration(seconds: 1),
          ).then((socket) {
            socket.destroy();
          }),
          throwsA(isA<SocketException>()),
        );
      }
    },
    tags: ['docker'],
    timeout: const Timeout(Duration(minutes: 3)),
  );

  final env = Platform.environment;
  group('explicit real services', () {
    late DwPostgresDatabase admin;
    late DwObjectStore store;
    late String databaseUrl, storageUrl;
    setUp(() async {
      admin = await DwPostgresDatabase.open(
        DwDatabaseConfig.fromEnvironment(env),
      );
      store = DwObjectStore(
        DwFileStorageConfig.fromEnvironment(env),
        requestTimeout: const Duration(seconds: 10),
      );
      databaseUrl = Uri(
        scheme: 'postgres',
        host: env['DW_DATABASE_HOST'],
        port: int.parse(env['DW_DATABASE_PORT']!),
        path: '/${env['DW_DATABASE_NAME']}',
        userInfo:
            '${Uri.encodeComponent(env['DW_DATABASE_USER']!)}:${Uri.encodeComponent(env['DW_DATABASE_PASSWORD']!)}',
      ).toString();
      storageUrl = Uri.parse(env['DW_STORAGE_ENDPOINT']!)
          .replace(
            userInfo:
                '${Uri.encodeComponent(env['DW_STORAGE_ACCESS_KEY']!)}:${Uri.encodeComponent(env['DW_STORAGE_SECRET_KEY']!)}',
          )
          .toString();
    });
    tearDown(() async {
      await admin.close();
      store.close();
    });
    Future<List<String>> databases() async => [
      for (final row in await admin.db.query('SELECT datname FROM pg_database'))
        row['datname']! as String,
    ];
    Future<String> buckets() async =>
        utf8.decodeStream(await store.send('GET', bucket: ''));
    void fixture(
      String name, {
      bool hold = false,
      bool storage = false,
      bool fail = false,
    }) {
      File(p.join(server.path, 'test/${name}_test.dart')).writeAsStringSync('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';
void main() {
  test('creates isolated resources', () async {
    final database = await DwTestDatabase.create(prefix: 'custom_test');
    ${storage ? 'final storage = await DwTestStorage.create(prefix: "custom-test");' : ''}
    final ready = File('${root.path}/$name.json.tmp');
    ready.writeAsStringSync(jsonEncode({
      'run': Platform.environment['DW_TEST_RUN_ID'], 'database': database.config.name,
      'pid': pid,
      ${storage ? "'public': storage.publicBucket, 'private': storage.privateBucket," : ''}
      'inheritedStorage': Platform.environment['DW_STORAGE_PUBLIC_BUCKET'],
    }));
    ready.renameSync('${root.path}/$name.json');
    ${hold
          ? 'await Completer<void>().future;'
          : fail
          ? 'fail("intentional suite failure");'
          : ''}
    // Deliberately omit teardown: CLI cleanup must recover abandoned resources.
  });
}
''');
    }

    Future<Map> created(String name) async {
      final file = File(p.join(root.path, '$name.json'));
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!file.existsSync()) {
        if (DateTime.now().isAfter(deadline))
          fail('suite never wrote $name.json');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return jsonDecode(file.readAsStringSync()) as Map;
    }

    test(
      'two files use distinct databases without Docker; success and failure sweep the run',
      () async {
        fixture('first');
        fixture('second');
        final (code, output) = await run(
          ['--database-url', databaseUrl],
          environment: {
            'DW_STORAGE_ENDPOINT': 'http://192.0.2.1:9000',
            'DW_STORAGE_PUBLIC_BUCKET': 'stage-bucket',
          },
        );
        expect(code, 0, reason: output);
        expect(output, contains('storage disabled'));
        final first = await created('first'), second = await created('second');
        expect(first['run'], second['run']);
        expect(first['database'], isNot(second['database']));
        expect(first['inheritedStorage'], isNull);
        expect(await databases(), isNot(contains(first['database'])));
        expect(await databases(), isNot(contains(second['database'])));
        expect(dockerCalled.existsSync(), isFalse);
        fixture('failure', fail: true);
        final (failed, failureOutput) = await run([
          '--database-url',
          databaseUrl,
          '--',
          'test/failure_test.dart',
        ]);
        expect(failed, isNot(0), reason: failureOutput);
        expect(
          await databases(),
          isNot(contains((await created('failure'))['database'])),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
    for (final processGroup in [false, true]) {
      test(
        '${processGroup ? 'group' : 'pid-only'} SIGINT sweeps databases and nonempty buckets, leaving a concurrent run intact',
        () async {
          fixture('other', hold: true, storage: true);
          fixture('interrupted', hold: true, storage: true);
          final other = await launch([
            '--database-url',
            databaseUrl,
            '--storage-url',
            storageUrl,
            '--',
            'test/other_test.dart',
          ]);
          final otherOutput = other.stdout.transform(utf8.decoder).join();
          final otherErrors = other.stderr.transform(utf8.decoder).join();
          addTearDown(() async {
            other.kill(ProcessSignal.sigint);
            try {
              await other.exitCode.timeout(const Duration(seconds: 30));
            } on TimeoutException {
              other.kill(ProcessSignal.sigkill);
              await other.exitCode;
            }
            await otherOutput;
            await otherErrors;
          });
          final concurrent = await created('other');
          final process = await launch([
            '--database-url',
            databaseUrl,
            '--storage-url',
            storageUrl,
            '--',
            'test/interrupted_test.dart',
          ], processGroup: processGroup);
          final output = process.stdout.transform(utf8.decoder).join();
          final errors = process.stderr.transform(utf8.decoder).join();
          final groupFile = File(p.join(root.path, 'process-group'));
          int readGroupId() => int.parse(groupFile.readAsStringSync().trim());
          addTearDown(() async {
            if (processGroup && groupFile.existsSync()) {
              await signalGroup(readGroupId(), 'INT');
            } else {
              process.kill(ProcessSignal.sigint);
            }
            try {
              await process.exitCode.timeout(const Duration(seconds: 30));
            } on TimeoutException {
              if (processGroup && groupFile.existsSync()) {
                await signalGroup(readGroupId(), 'KILL');
              }
              process.kill(ProcessSignal.sigkill);
              await process.exitCode;
            }
            await output;
            await errors;
          });
          final owned = await created('interrupted');
          final groupId = processGroup ? readGroupId() : null;
          if (groupId != null) {
            final suiteGroup = await Process.run('ps', [
              '-o',
              'pgid=',
              '-p',
              '${owned['pid']}',
            ]);
            expect(suiteGroup.exitCode, 0, reason: '${suiteGroup.stderr}');
            expect(int.parse((suiteGroup.stdout as String).trim()), groupId);
          }
          await store.put(
            owned['private'] as String,
            'a + <&/雪.txt',
            bytes: utf8.encode('test'),
            contentType: 'text/plain',
          );
          if (groupId == null) {
            expect(process.kill(ProcessSignal.sigint), isTrue);
          } else {
            final signalled = await signalGroup(groupId, 'INT');
            expect(signalled.exitCode, 0, reason: '${signalled.stderr}');
          }
          final code = await process.exitCode.timeout(
            const Duration(seconds: 30),
          );
          expect(code, 130, reason: '${await output}${await errors}');
          final names = await databases();
          expect(names, isNot(anyElement(contains(owned['run'] as String))));
          expect(names, isNot(contains(owned['database'])));
          expect(names, contains(concurrent['database']));
          final listing = await buckets();
          expect(listing, isNot(contains(owned['run'] as String)));
          expect(listing, isNot(contains(owned['public'])));
          expect(listing, isNot(contains(owned['private'])));
          expect(listing, contains(concurrent['public']));
          expect(listing, contains(concurrent['private']));
          expect(dockerCalled.existsSync(), isFalse);
        },
        timeout: const Timeout(Duration(minutes: 2)),
        skip: processGroup && !Platform.isLinux && !Platform.isMacOS
            ? 'requires POSIX process groups and Bash job control'
            : false,
      );
    }
  }, tags: ['services']);
}
