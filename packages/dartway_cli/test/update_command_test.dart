@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Real CLI over the real template: existing parser/wiring suites do not cover
/// update's note selection or its ordering of resolution and project writes.
void main() {
  var repository = Directory.current.absolute;
  while (!Directory(p.join(repository.path, 'toolkit')).existsSync()) {
    repository = repository.parent;
  }
  final cli = p.join(repository.path, 'packages/dartway_cli/bin/dartway.dart');
  late Directory sandbox, project;
  late String target;
  File file(String path) => File(p.join(project.path, path));
  const first = 'docs/migrations/2026-09-30-imports-tests-spacing.md';
  const second = 'docs/migrations/2026-09-30-router-state-provider.md';
  String output(ProcessResult result) => '${result.stdout}\n${result.stderr}';
  Future<ProcessResult> invoke(
    List<String> args,
    Directory cwd, {
    Map<String, String>? environment,
  }) => Process.run(
    Platform.resolvedExecutable,
    [cli, ...args],
    workingDirectory: cwd.path,
    environment: environment,
  );
  Future<ProcessResult> update(
    List<String> args, {
    Map<String, String>? environment,
  }) => invoke(
    ['update', '--local-repo', repository.path, '--target', target, ...args],
    project,
    environment: environment,
  );
  void succeeds(ProcessResult result) =>
      expect(result.exitCode, 0, reason: output(result));
  Map<String, String> files() => {
    for (final entity in project.listSync(recursive: true).whereType<File>())
      p.relative(entity.path, from: project.path): base64Encode(
        entity.readAsBytesSync(),
      ),
  };

  // Copy the plugin's real Flutter fixture: its intentional diagnostics prove
  // that the native analyzer loaded the plugin and applied the owner's settings.
  Future<ProcessResult> nativeAnalyze(
    String options, {
    Map<String, String>? environment,
  }) async {
    final source = Directory(
      p.join(repository.path, 'packages/dartway_lints/example'),
    );
    final fixture = Directory(p.join(sandbox.path, 'native-fixture'))
      ..createSync();
    for (final entry in ['pubspec.yaml', 'lib', 'test']) {
      final origin = p.join(source.path, entry);
      if (File(origin).existsSync()) {
        File(origin).copySync(p.join(fixture.path, entry));
      } else {
        for (final file in Directory(
          origin,
        ).listSync(recursive: true).whereType<File>()) {
          final destination = File(
            p.join(fixture.path, p.relative(file.path, from: source.path)),
          );
          destination.parent.createSync(recursive: true);
          file.copySync(destination.path);
        }
      }
    }
    File(
      p.join(fixture.path, 'analysis_options.yaml'),
    ).writeAsStringSync(options);
    succeeds(
      await Process.run('flutter', [
        'pub',
        'get',
      ], workingDirectory: fixture.path),
    );
    return Process.run(
      Platform.resolvedExecutable,
      ['analyze', '--format=machine'],
      workingDirectory: fixture.path,
      environment: {
        'ANALYZER_STATE_LOCATION_OVERRIDE': p.join(
          sandbox.path,
          'native-state',
        ),
        ...?environment,
      },
    );
  }

  Future<Directory> rootPluginRepository() async {
    final source = Directory(p.join(repository.path, 'packages/dartway_lints'));
    final plugin = Directory(p.join(sandbox.path, 'root-plugin'))..createSync();
    File(
      p.join(source.path, 'pubspec.yaml'),
    ).copySync(p.join(plugin.path, 'pubspec.yaml'));
    for (final file in Directory(
      p.join(source.path, 'lib'),
    ).listSync(recursive: true).whereType<File>()) {
      final destination = File(
        p.join(plugin.path, p.relative(file.path, from: source.path)),
      );
      destination.parent.createSync(recursive: true);
      file.copySync(destination.path);
    }
    for (final args in [
      ['init', '-b', 'true'],
      ['add', 'pubspec.yaml', 'lib'],
      [
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.com',
        'commit',
        '-qm',
        'Real plugin at repository root',
      ],
    ]) {
      succeeds(await Process.run('git', args, workingDirectory: plugin.path));
    }
    return plugin;
  }

  setUp(() async {
    sandbox = Directory.systemTemp.createTempSync('dw-update-test-');
    target =
        ((await Process.run('git', [
                  'rev-parse',
                  'origin/master',
                ], workingDirectory: repository.path)).stdout
                as String)
            .trim();
    succeeds(
      await invoke([
        'create',
        'shop',
        '--no-git',
        '--framework-path',
        repository.path,
        '--local-repo',
        repository.path,
      ], sandbox),
    );
    project = Directory(p.join(sandbox.path, 'shop'));
    // This real lock is already at target, as after bumping pins/pub get first.
    File(
      p.join(repository.path, 'template/dartway_starter_flutter/pubspec.lock'),
    ).copySync(file('shop_flutter/pubspec.lock').path);
  });
  tearDown(() => sandbox.deleteSync(recursive: true));

  test(
    'target lock and toolkit install leave notes unconfirmed; plan is read-only',
    () async {
      final before = files();
      final planned = await update(['--plan']);
      succeeds(planned);
      expect(output(planned), contains('Migration baseline: unknown'));
      expect(output(planned), contains(first));
      expect(output(planned), contains(second));
      expect(files(), before);
      succeeds(await update([]));
      expect(file('.dartway/migrations.json').existsSync(), isFalse);
      final again = await update(['--plan']);
      succeeds(again);
      expect(output(again), contains(first));
      expect(output(again), contains(second));
    },
  );

  test('partial dispositions survive repeated plans and installs', () async {
    succeeds(
      await update([
        '--complete',
        first,
        '--verified',
        '--verification',
        'Reviewed imports, mirrored tests and spacing; project gates passed.',
      ]),
    );
    final ledger = file('.dartway/migrations.json').readAsStringSync();
    for (var repeat = 0; repeat < 2; repeat++) {
      final before = files();
      final planned = await update(['--plan']);
      succeeds(planned);
      expect(output(planned), isNot(contains(first)));
      expect(output(planned), contains(second));
      expect(files(), before);
    }
    succeeds(await update([]));
    expect(file('.dartway/migrations.json').readAsStringSync(), ledger);
    succeeds(
      await update([
        '--not-applicable',
        second,
        '--verified',
        '--verification',
        'Inspected router wiring; no application-owned router disposal.',
      ]),
    );
    final records =
        (jsonDecode(file('.dartway/migrations.json').readAsStringSync())
                as Map)['notes']
            as Map;
    expect(
      records.values.map((record) => (record as Map)['disposition']),
      containsAll(['applied', 'not-applicable']),
    );
    final planned = await update(['--plan']);
    succeeds(planned);
    expect(output(planned), isNot(contains(first)));
    expect(output(planned), isNot(contains(second)));
    expect(
      output(planned),
      contains('docs/migrations/2026-09-30-feature-import-graph.md'),
    );
  });

  test(
    'unverified, conflicting and invalid completion batches write nothing',
    () async {
      final before = files();
      for (final args in [
        ['--complete', first],
        [
          '--plan',
          '--complete',
          first,
          '--verified',
          '--verification',
          'proof',
        ],
        [
          '--complete',
          first,
          '--not-applicable',
          first,
          '--verified',
          '--verification',
          'proof',
        ],
        [
          '--complete',
          first,
          '--complete',
          'missing.md',
          '--verified',
          '--verification',
          'proof',
        ],
      ]) {
        expect((await update(args)).exitCode, isNot(0));
        expect(files(), before);
      }
    },
  );

  test(
    'no lock still reports declared package notes and unknown baseline',
    () async {
      file('shop_flutter/pubspec.lock').deleteSync();
      final planned = await update(['--plan']);
      succeeds(planned);
      expect(output(planned), contains('Migration baseline: unknown'));
      expect(output(planned), contains(first));
      expect(file('.dartway/migrations.json').existsSync(), isFalse);
    },
  );

  test('unpublished hosted pin is refused before any project edit', () async {
    // Actual pub metadata endpoint with no published versions. Pub, not this
    // fixture, decides whether the requested constraint is resolvable.
    final registry = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => registry.close(force: true));
    registry.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'name': 'dartway_lints', 'versions': []}),
      );
      await request.response.close();
    });
    file('shop_flutter/analysis_options.yaml').writeAsStringSync(
      '# owner rule\nlinter:\n  rules:\n    avoid_print: true\n'
      'plugins:\n  dartway_lints:\n'
      '    hosted: http://127.0.0.1:${registry.port}\n    version: ^0.4.0\n',
    );
    final before = files();
    final result = await update(
      [],
      environment: {'PUB_CACHE': p.join(sandbox.path, 'isolated-cache')},
    );
    expect(result.exitCode, 1, reason: output(result));
    expect(
      output(result),
      contains('Analyzer plugin source is not resolvable'),
    );
    expect(files(), before);
  });

  test('native path diagnostics survive plan and install', () async {
    final options =
        '# Owner settings\nplugins:\n  dartway_lints:\n'
        '    path: ${repository.path}/packages/dartway_lints\n'
        '    diagnostics:\n      forbidden_ui_style_usage: false\n';
    file('shop_flutter/analysis_options.yaml').writeAsStringSync(options);
    final native = await nativeAnalyze(options);
    expect(native.exitCode, 2, reason: output(native));
    expect(output(native), contains('FORBIDDEN_PROVIDER_SCOPE'));
    expect(output(native), isNot(contains('FORBIDDEN_UI_STYLE_USAGE')));
    expect(output(native), isNot(contains('ERROR|')));
    final before = files();
    succeeds(await update(['--plan']));
    expect(files(), before);
    succeeds(await update([]));
    expect(
      file('shop_flutter/analysis_options.yaml').readAsStringSync(),
      options,
    );
    expect(file('.dartway/migrations.json').existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'invalid native source forms fail without changing project choices',
    () async {
      for (final source in [
        '    version: ^0.5.0\n    path: ${repository.path}/packages/dartway_lints\n',
        '    git: ${repository.path}\n    path: ${repository.path}/packages/dartway_lints\n',
        '    version: ^0.5.0\n    hosted:\n      url: https://pub.dev\n',
        '    git:\n      url: ${repository.path}\n      ref: [wrong-shape]\n',
        '    git:\n      url: ${repository.path}\n    hosted: https://pub.dev\n',
      ]) {
        file(
          'shop_flutter/analysis_options.yaml',
        ).writeAsStringSync('plugins:\n  dartway_lints:\n$source');
        final before = files();
        final result = await update([]);
        expect(result.exitCode, 1, reason: output(result));
        expect(output(result), contains('Invalid dartway_lints plugin source'));
        expect(output(result), isNot(contains('Analyzer plugin: resolvable')));
        expect(files(), before);
      }
    },
  );

  test(
    'ambiguous version and git fail before native plugin success is reported',
    () async {
      final options =
          'plugins:\n  dartway_lints:\n    version: ^0.5.0\n    git:\n'
          '      url: ${repository.path}\n      ref: $target\n'
          '      path: packages/dartway_lints\n';
      file('shop_flutter/analysis_options.yaml').writeAsStringSync(options);
      final registry = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => registry.close(force: true));
      registry.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'name': 'dartway_lints', 'versions': []}),
        );
        await request.response.close();
      });
      // An empty hosted registry keeps native source selection observable even
      // after 0.5.0 is published. Git still points at the real committed plugin.
      final native = await nativeAnalyze(
        options,
        environment: {'PUB_HOSTED_URL': 'http://127.0.0.1:${registry.port}'},
      );
      expect(native.exitCode, isNot(0), reason: output(native));
      expect(output(native), contains('depends on dartway_lints ^0.5.0'));
      expect(output(native), contains('version solving failed'));
      final before = files();
      for (final flags in [
        <String>['--plan'],
        <String>[],
      ]) {
        final result = await update(flags);
        expect(result.exitCode, 1, reason: output(result));
        expect(output(result), contains('exactly one of version, git or path'));
        expect(output(result), isNot(contains('Analyzer plugin: resolvable')));
        expect(files(), before);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'git choice, installer choices and owner rules survive reinstall',
    () async {
      file('shop_flutter/analysis_options.yaml').writeAsStringSync(
        '# owner rule\nlinter:\n  rules:\n    avoid_print: true\n'
        'plugins:\n  dartway_lints:\n    git:\n'
        '      url: ${repository.path}\n      ref: $target\n'
        '      path: packages/dartway_lints\n'
        '    diagnostics:\n      forbidden_ui_style_usage: false\n',
      );
      file('AGENTS.md').writeAsStringSync('Owner conventions\n');
      final options = file(
        'shop_flutter/analysis_options.yaml',
      ).readAsStringSync();
      succeeds(
        await update([
          '--agent',
          'codex',
          '--base-branch',
          'develop',
          '--language',
          'Russian',
          '--notes-tracker',
          'none',
        ]),
      );
      succeeds(await update([]));
      expect(
        file('shop_flutter/analysis_options.yaml').readAsStringSync(),
        options,
      );
      expect(
        file('AGENTS.md').readAsStringSync(),
        startsWith('Owner conventions\n'),
      );
      final manifest =
          jsonDecode(file('.agents/dartway-toolkit.json').readAsStringSync())
              as Map;
      expect(manifest['settings'], {
        'agent': 'codex',
        'baseBranch': 'develop',
        'language': 'Russian',
        'notesTracker': 'none',
      });
      expect(manifest['commit'], target);
      expect(
        file('.claude/skills/dartway-update/SKILL.md').existsSync(),
        isFalse,
      );
      expect(
        file('.agents/skills/dartway-update/SKILL.md').existsSync(),
        isTrue,
      );
    },
  );

  test('native empty git path selects the repository root unchanged', () async {
    final plugin = await rootPluginRepository();
    final options =
        'plugins:\n  dartway_lints:\n    git:\n'
        '      url: ${plugin.path}\n      path: ""\n'
        '    diagnostics:\n      forbidden_ui_style_usage: false\n';
    file('shop_flutter/analysis_options.yaml').writeAsStringSync(options);
    final native = await nativeAnalyze(options);
    expect(native.exitCode, 2, reason: output(native));
    expect(output(native), contains('FORBIDDEN_PROVIDER_SCOPE'));
    expect(output(native), isNot(contains('FORBIDDEN_UI_STYLE_USAGE')));
    expect(output(native), isNot(contains('ERROR|')));
    final before = files();
    final planned = await update(['--plan']);
    succeeds(planned);
    expect(output(planned), contains('(git)'));
    expect(files(), before);
    succeeds(await update([]));
    expect(
      file('shop_flutter/analysis_options.yaml').readAsStringSync(),
      options,
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('native YAML git ref coercion is refused without edits', () async {
    final plugin = await rootPluginRepository();
    // This branch exists and JSON pub preflight resolves it. The native
    // analyzer emits ref: true into YAML, which pub rejects as a boolean.
    final options =
        'plugins:\n  dartway_lints:\n    git:\n'
        '      url: ${plugin.path}\n      ref: "true"\n';
    file('shop_flutter/analysis_options.yaml').writeAsStringSync(options);
    final native = await nativeAnalyze(options);
    expect(native.exitCode, isNot(0), reason: output(native));
    expect(output(native), contains("The 'ref' field"));
    expect(output(native), contains('must be a string'));
    final before = files();
    for (final flags in [
      <String>['--plan'],
      <String>[],
    ]) {
      final result = await update(flags);
      expect(result.exitCode, 1, reason: output(result));
      expect(
        output(result),
        contains('Analyzer plugin source is not resolvable'),
      );
      expect(output(result), contains("The 'ref' field"));
      expect(output(result), isNot(contains('Analyzer plugin: resolvable')));
      expect(files(), before);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('missing path and git ref explicitly fail without edits', () async {
    for (final source in [
      '    path: ../missing-plugin\n',
      '    git:\n      url: ${repository.path}\n      ref: missing-update-ref\n      path: packages/dartway_lints\n',
    ]) {
      file(
        'shop_flutter/analysis_options.yaml',
      ).writeAsStringSync('plugins:\n  dartway_lints:\n$source');
      final before = files();
      final result = await update([]);
      expect(result.exitCode, 1, reason: output(result));
      expect(
        output(result),
        contains('Analyzer plugin source is not resolvable'),
      );
      expect(files(), before);
    }
  });

  test('a published hosted source resolves before its pin is raised', () async {
    final plugin = Directory(p.join(repository.path, 'packages/dartway_lints'));
    final archive = File(p.join(sandbox.path, 'plugin.tar.gz'));
    final packed = await Process.run('tar', [
      '-czf',
      archive.path,
      '-C',
      plugin.path,
      'pubspec.yaml',
      'lib',
    ]);
    expect(packed.exitCode, 0, reason: '${packed.stderr}');
    final bytes = archive.readAsBytesSync();
    final pubspec =
        jsonDecode(
              jsonEncode(
                loadYaml(
                  File(p.join(plugin.path, 'pubspec.yaml')).readAsStringSync(),
                ),
              ),
            )
            as Map;
    final version = pubspec['version'] as String;
    final registry = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => registry.close(force: true));
    final host = 'http://127.0.0.1:${registry.port}';
    registry.listen((request) async {
      if (request.uri.path == '/archive.tar.gz') {
        request.response.add(bytes);
      } else {
        final release = {
          'version': version,
          'pubspec': pubspec,
          'archive_url': '$host/archive.tar.gz',
          'archive_sha256': sha256.convert(bytes).toString(),
        };
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'name': 'dartway_lints',
            'latest': release,
            'versions': [release],
          }),
        );
      }
      await request.response.close();
    });
    file('shop_flutter/analysis_options.yaml').writeAsStringSync(
      '# owned rule\nplugins:\n  dartway_lints:\n'
      '    hosted: $host\n    version: ^0.4.0\n'
      '    diagnostics:\n      forbidden_ui_style_usage: false\n',
    );
    final before = files();
    final planned = await update(['--plan']);
    succeeds(planned);
    expect(output(planned), contains('(hosted)'));
    expect(files(), before);
    succeeds(await update([]));
    expect(
      file('shop_flutter/analysis_options.yaml').readAsStringSync(),
      '# owned rule\nplugins:\n  dartway_lints:\n'
      '    hosted: $host\n    version: ^$version\n'
      '    diagnostics:\n      forbidden_ui_style_usage: false\n',
    );
  });

  test(
    'exact targets ignore a moving source and completion keeps version metadata',
    () async {
      succeeds(
        await update([
          '--complete',
          first,
          '--verified',
          '--verification',
          'Project verification passed.',
        ]),
      );
      final ledger = file('.dartway/migrations.json').readAsStringSync();
      final source = Directory(p.join(sandbox.path, 'source'))..createSync();
      final archive = p.join(sandbox.path, 'source.tar');
      final packed = await Process.run('git', [
        'archive',
        '--output=$archive',
        target,
      ], workingDirectory: repository.path);
      expect(packed.exitCode, 0, reason: '${packed.stderr}');
      expect(
        (await Process.run('tar', [
          '-xf',
          archive,
          '-C',
          source.path,
        ])).exitCode,
        0,
      );
      Future<String> git(List<String> args) async {
        final result = await Process.run(
          'git',
          args,
          workingDirectory: source.path,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return (result.stdout as String).trim();
      }

      await git(['init']);
      await git(['add', '.']);
      await git([
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.com',
        'commit',
        '-qm',
        'Committed framework fixture',
      ]);
      final initial = await git(['rev-parse', 'HEAD']);
      final note = File(p.join(source.path, first));
      note.writeAsStringSync(
        note.readAsStringSync().replaceFirst(
          'dartway_cli: "0.22.0"',
          'dartway_cli: "0.24.0"',
        ),
      );
      await git(['add', first]);
      await git([
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.com',
        'commit',
        '-qm',
        'Changed fixture note version',
      ]);
      final moved = await git(['rev-parse', 'HEAD']);
      note.deleteSync(); // Local uncommitted deletion must not affect the plan.
      final pinned = await update([
        '--plan',
        '--local-repo',
        source.path,
        '--target',
        initial,
      ]);
      succeeds(pinned);
      expect(output(pinned), contains(initial));
      expect(output(pinned), isNot(contains(first)));
      final changed = await update([
        '--plan',
        '--local-repo',
        source.path,
        '--target',
        moved,
      ]);
      succeeds(changed);
      expect(output(changed), contains(moved));
      expect(output(changed), contains(first));
      final committedNote = await git(['show', '$moved:$first']);
      note.writeAsStringSync(
        committedNote
            .replaceFirst('dartway_cli: "0.24.0"', 'dartway_cli: "99.0.0"')
            .replaceFirst(
              'dartway_core_flutter: "0.21.0-dev.16"',
              'dartway_core_flutter: "99.0.0"',
            ),
      );
      await git(['add', first]);
      await git([
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.com',
        'commit',
        '-qm',
        'Fixture note beyond package target',
      ]);
      final future = await git(['rev-parse', 'HEAD']);
      final bounded = await update([
        '--plan',
        '--local-repo',
        source.path,
        '--target',
        future,
      ]);
      succeeds(bounded);
      expect(output(bounded), isNot(contains(first)));
      expect(file('.dartway/migrations.json').readAsStringSync(), ledger);
    },
  );

  test(
    'malformed ledger is refused without discarding any project files',
    () async {
      final ledger = file('.dartway/migrations.json');
      ledger.parent.createSync(recursive: true);
      ledger.writeAsStringSync('{"schema":99,"notes":{}}');
      final before = files();
      final result = await update(['--plan']);
      expect(result.exitCode, 1, reason: output(result));
      expect(output(result), contains('Cannot read'));
      expect(files(), before);
    },
  );
}
