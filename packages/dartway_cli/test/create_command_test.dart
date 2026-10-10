import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// `dartway create` over this repository's own template: what a stranger's
/// project is named after, and what it resolves against.
///
/// Whether the result builds, tests and runs is a question for a real
/// toolchain and is answered outside this suite; this one holds the renames
/// and the pubspecs, which are the part `create` itself writes.
///
/// The CLI runs as a process of its own, in a folder of its own: `create`
/// works in the current directory, and the current directory of this process
/// is shared by every suite running beside this one.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!Directory(p.join(dir.path, 'template')).existsSync() ||
        !Directory(p.join(dir.path, 'packages')).existsSync()) {
      final up = dir.parent;
      if (up.path == dir.path) {
        throw StateError('not inside the monorepo');
      }
      dir = up;
    }
    return dir;
  }();

  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_create');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  final cli = p.join(
    repository.path,
    'packages',
    'dartway_cli',
    'bin',
    'dartway.dart',
  );

  Future<ProcessResult> dartway(List<String> arguments) => Process.run(
    Platform.resolvedExecutable,
    [cli, ...arguments],
    workingDirectory: sandbox.path,
  );

  Future<Directory> create(List<String> arguments) async {
    final result = await dartway(['create', ...arguments, '--no-git']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return Directory(p.join(sandbox.path, arguments.first));
  }

  String read(Directory project, String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  test('does not give the project a licence or notice', () async {
    final project = await create(['shop', '--local-repo', repository.path]);

    expect(File(p.join(project.path, 'LICENSE')).existsSync(), isFalse);
    expect(File(p.join(project.path, 'NOTICE')).existsSync(), isFalse);
  });

  test('everything is named after the project, and nothing after the '
      'template', () async {
    final project = await create([
      'shop_floor',
      '--local-repo',
      repository.path,
    ]);

    for (final package in ['shared', 'server', 'flutter']) {
      expect(
        File(
          p.join(project.path, 'shop_floor_$package', 'pubspec.yaml'),
        ).existsSync(),
        isTrue,
        reason: package,
      );
    }
    expect(
      read(project, 'shop_floor_shared/lib/generated/dw_protocol.dart'),
      contains('final DwWireProtocol shopFloorProtocol'),
    );
    expect(
      read(project, 'shop_floor_server/lib/generated/dw_schema.dart'),
      allOf(
        contains('final DwDatabaseSchema shopFloorSchema'),
        contains('extension ShopFloorDb'),
      ),
    );
    expect(
      read(project, 'shop_floor_server/lib/src/core/files.dart'),
      allOf(
        contains("defaultPublicBucket = 'shop-floor-public'"),
        contains("defaultPrivateBucket = 'shop-floor-private'"),
      ),
    );
    expect(
      read(project, 'shop_floor_shared/lib/src/shop_floor_refusal.dart'),
      contains('enum ShopFloorRefusal'),
    );

    final leftovers = [
      for (final entity in project.listSync(recursive: true))
        if (entity is File &&
            !entity.path.contains('${p.separator}.claude${p.separator}') &&
            _isText(entity) &&
            RegExp(
              'dartway_starter|DartwayStarter|dartwayStarter|dartway-starter',
            ).hasMatch(entity.readAsStringSync()))
          p.relative(entity.path, from: project.path),
    ];
    expect(leftovers, isEmpty);
  });

  test(
    'without --framework-path the pubspecs resolve from pub.dev: no '
    'overrides, the framework family and the tools as dev dependencies',
    () async {
      final project = await create(['shop', '--local-repo', repository.path]);
      for (final package in ['shop_shared', 'shop_server', 'shop_flutter']) {
        expect(
          read(project, '$package/pubspec.yaml'),
          isNot(contains('dependency_overrides')),
          reason: package,
        );
      }
      // Read rather than written down: the family's version moves whenever a
      // change owes the projects a migration note (D-080), and an expectation
      // spelled out here would have to be edited every time — which is how it
      // ends up asserting last month's number.
      final family = _familyVersion(repository);
      expect(
        read(project, 'shop_server/pubspec.yaml'),
        allOf(
          contains('dartway_core_server: ^$family'),
          contains('dartway_generator: ^$family'),
        ),
      );
      expect(
        read(project, 'shop_flutter/pubspec.yaml'),
        allOf(
          contains('dartway_core_flutter: ^$family'),
          contains('dartway_cli:'),
        ),
      );
      // The analyzer plugin is not a pub dependency: the template's path into
      // this repository becomes the version the template was taken from.
      final lints = RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(
            File(
              p.join(
                repository.path,
                'packages',
                'dartway_lints',
                'pubspec.yaml',
              ),
            ).readAsStringSync(),
          )!
          .group(1);
      expect(
        read(project, 'shop_flutter/analysis_options.yaml'),
        allOf(
          contains('  dartway_lints: ^$lints'),
          isNot(contains('packages/dartway_lints')),
        ),
      );
    },
  );

  test('--framework-path overrides exactly the framework packages each '
      'package reaches, onto the checkout', () async {
    final project = await create(['shop', '--framework-path', repository.path]);
    Set<String> overridden(String package) {
      final lines = read(project, '$package/pubspec.yaml').split('\n');
      final start = lines.indexOf('dependency_overrides:');
      if (start < 0) return {};
      return {
        for (final line in lines.skip(start + 1))
          if (RegExp(r'^  ([a-z_]+):$').firstMatch(line) case final match?)
            match.group(1)!,
      };
    }

    expect(overridden('shop_shared'), {
      'dartway_analytics_shared',
      'dartway_core_shared',
    });
    expect(overridden('shop_server'), {
      'dartway_analytics_server',
      'dartway_analytics_shared',
      'dartway_client',
      'dartway_core_server',
      'dartway_core_shared',
      'dartway_generator',
      'dartway_orm',
    });
    expect(overridden('shop_flutter'), {
      'dartway_analytics_flutter',
      'dartway_analytics_shared',
      'dartway_cli',
      'dartway_client',
      'dartway_core_flutter',
      'dartway_core_shared',
      'dartway_router',
      'dartway_shared_preferences',
    });
    expect(
      read(project, 'shop_server/pubspec.yaml'),
      contains("path: '${p.join(repository.path, 'packages', 'dartway_orm')}'"),
    );
    expect(
      read(project, 'shop_flutter/analysis_options.yaml'),
      contains(
        "    path: '${p.join(repository.path, 'packages', 'dartway_lints')}'",
      ),
    );
  });

  test('without a channel or a checkout named, the project comes from the '
      'checkout the CLI runs from — its own revision, not a channel', () async {
    // A home with no clone cache and a repository URL that leads nowhere: a
    // run that reached for a channel fails instead of quietly using one.
    final environment = {
      for (final MapEntry(:key, :value) in Platform.environment.entries)
        if (key != 'DARTWAY_BRANCH' && key != 'DARTWAY_MONOREPO_DIR')
          key: value,
      'HOME': sandbox.path,
      'DARTWAY_REPO_URL': p.join(sandbox.path, 'nowhere.git'),
    };
    Future<ProcessResult> run(List<String> arguments) => Process.run(
      Platform.resolvedExecutable,
      [cli, 'create', ...arguments, '--no-git'],
      workingDirectory: sandbox.path,
      environment: environment,
      includeParentEnvironment: false,
    );

    final created = await run(['shop']);
    expect(created.exitCode, 0, reason: '${created.stdout}\n${created.stderr}');
    final manifest = read(
      Directory(p.join(sandbox.path, 'shop')),
      '.agents/dartway-toolkit.json',
    );
    expect(manifest, contains('"source": "${repository.path}"'));
    expect(manifest, isNot(contains('"channel"')));

    final onChannel = await run(['other', '--channel', 'stable']);
    expect(onChannel.exitCode, isNot(0));
    expect('${onChannel.stderr}', contains('nowhere.git'));
  });

  test('the review workflow cannot push: the workflow token, agent mode, and '
      'the commit tools taken away (#494)', () async {
    final project = await create(['shop', '--local-repo', repository.path]);
    final workflow = read(project, '.github/workflows/claude-review.yml');

    // The Claude App's token can write contents whatever `permissions:` says;
    // only the workflow's own token is held to `contents: read`.
    expect(workflow, contains(r'github_token: ${{ secrets.GITHUB_TOKEN }}'));
    // Tracking forces tag mode on pull requests, whose tools edit and commit.
    // The key, not the word: the comment above the step names it to explain
    // why it is absent.
    expect(
      RegExp(r'^\s*track_progress\s*:', multiLine: true).hasMatch(workflow),
      isFalse,
      reason: workflow,
    );
    expect(
      RegExp(r'--disallowedTools "[^"]*Bash\(git push:\*\)').hasMatch(workflow),
      isTrue,
      reason: workflow,
    );
  });

  test('CI is one job named ci, every gate a guarded step of its own, on the '
      'pinned toolchain and the committed locks (#495)', () async {
    final project = await create(['shop', '--local-repo', repository.path]);
    final workflow =
        loadYaml(read(project, '.github/workflows/ci.yml')) as YamlMap;

    // One check with a stable name is what can be made required, and a
    // filtered trigger leaves a required check pending forever.
    final jobs = workflow['jobs'] as YamlMap;
    expect(jobs.keys, ['ci']);
    final job = jobs['ci'] as YamlMap;
    expect(job['name'], 'ci');
    // Hosted runners when nothing says otherwise; a repository or
    // organisation variable moves every project onto its own runners.
    expect(
      job['runs-on'],
      r'''${{ fromJSON(vars.DW_CI_RUNS_ON || '"ubuntu-latest"') }}''',
    );
    final on = workflow['on'] as YamlMap;
    expect(on.containsKey('pull_request'), isTrue);
    expect(on['pull_request'], isNull, reason: 'no paths or branches filter');

    final steps = (job['steps'] as YamlList).cast<YamlMap>();
    final gates = steps.where((step) => step['if'] != null).toList();
    const base = r'--contract-base "$CONTRACT_BASE"';
    expect(
      [
        for (final gate in gates)
          (gate['name'], gate['working-directory'], gate['run']),
      ],
      [
        (
          'generate --check',
          'shop_flutter',
          'dart run dartway_cli:dartway generate --check $base',
        ),
        (
          'server / migrations',
          'shop_server',
          'dart run bin/migrate.dart check',
        ),
        ('shared / analyze', 'shop_shared', 'dart analyze'),
        ('server / analyze', 'shop_server', 'dart analyze'),
        ('flutter / analyze', 'shop_flutter', 'dart analyze --fatal-infos'),
        ('shared / test', 'shop_shared', 'dart test'),
        (
          'server / acceptance',
          'shop_flutter',
          'dart run dartway_cli:dartway test',
        ),
        ('flutter / test', 'shop_flutter', 'flutter test'),
        (
          'dartway check',
          'shop_flutter',
          'dart run dartway_cli:dartway check $base',
        ),
      ],
    );
    for (final gate in gates) {
      // Every gate runs after an earlier one failed, and none after a cancel.
      expect(
        gate['if'],
        r"${{ !cancelled() && steps.deps.outcome == 'success' }}",
        reason: '${gate['name']}',
      );
      expect(
        Directory(
          p.join(project.path, gate['working-directory'] as String),
        ).existsSync(),
        isTrue,
        reason: '${gate['name']}',
      );
    }

    // The toolchain is the one `.fvmrc` pins, not a second copy of it.
    final fvm = steps.singleWhere((step) => step['id'] == 'fvm');
    expect(fvm['run'], contains('jq -r .flutter shop_flutter/.fvmrc'));
    final flutter = steps.singleWhere(
      (step) => '${step['uses']}'.startsWith('subosito/flutter-action@'),
    );
    expect(
      (flutter['with'] as YamlMap)['flutter-version'],
      r'${{ steps.fvm.outputs.version }}',
    );
    expect(
      read(project, '.github/workflows/ci.yml'),
      isNot(contains(RegExp(r'\b3\.\d+\.\d+\b'))),
    );

    // CI proves the versions the locks name, as the deploy images do.
    final deps = steps.singleWhere((step) => step['id'] == 'deps');
    for (final package in ['shop_shared', 'shop_server', 'shop_flutter']) {
      expect(
        deps['run'],
        contains(RegExp('cd $package && \\S+ pub get --enforce-lockfile')),
        reason: package,
      );
    }
  });

  test('the language and the tracker chosen at creation are recorded, because '
      'update runs with no arguments and reads them back', () async {
    final project = await create([
      'shop',
      '--language',
      'ru',
      '--notes-tracker',
      'github',
    ]);
    final manifest = read(project, '.agents/dartway-toolkit.json');

    expect(manifest, contains('"language": "ru"'));
    expect(manifest, contains('"notesTracker": "github"'));
    expect(manifest, contains('"baseBranch": "master"'));
  });

  group('the app speaks the language the project was created in', () {
    List<String> arbs(Directory project) => [
      for (final file in Directory(
        p.join(project.path, 'shop_flutter', 'lib', 'l10n'),
      ).listSync().whereType<File>())
        if (file.path.endsWith('.arb')) p.basename(file.path),
    ];

    test(
      '--language ru keeps one translation, stated, and regenerated',
      () async {
        final project = await create(['shop', '--language', 'ru']);
        expect(arbs(project), ['app_ru.arb']);
        expect(
          read(project, 'shop_flutter/l10n.yaml'),
          contains('template-arb-file: app_ru.arb'),
        );
        expect(
          read(project, 'shop_flutter/lib/core/app_l10n.dart'),
          contains("static const Locale productLocale = Locale('ru');"),
        );
        final generated = read(
          project,
          'shop_flutter/lib/l10n/gen/app_localizations.dart',
        );
        expect(generated, contains("Locale('ru')"));
        expect(generated, isNot(contains("Locale('en')")));
        expect(
          File(
            p.join(
              project.path,
              'shop_flutter/lib/l10n/gen/app_localizations_en.dart',
            ),
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('by default the app speaks English, and only English', () async {
      final project = await create(['shop']);
      expect(arbs(project), ['app_en.arb']);
      expect(
        read(project, 'shop_flutter/lib/core/app_l10n.dart'),
        contains("static const Locale productLocale = Locale('en');"),
      );
    });

    test(
      'a language the skeleton has no translation for is said out loud',
      () async {
        final result = await dartway([
          'create',
          'shop',
          '--language',
          'German',
          '--no-git',
        ]);
        expect(result.exitCode, 0);
        expect('${result.stderr}', contains('no "German" translation'));
      },
    );

    test('the device does not choose the language', () {
      final controller = File(
        p.join(
          repository.path,
          'template/dartway_starter_flutter/lib/core/app_l10n.dart',
        ),
      ).readAsStringSync();
      expect(controller, isNot(contains('PlatformDispatcher')));
    });
  });

  test('a name that cannot become a bucket name is refused', () async {
    for (final name in ['shop__floor', 'shop_', 'a' * 56]) {
      final result = await dartway(['create', name, '--no-git']);
      expect(result.exitCode, 64, reason: name);
      expect(Directory(p.join(sandbox.path, name)).existsSync(), isFalse);
    }
  });
}

bool _isText(File file) {
  const binary = {'.png', '.jpg', '.ico', '.jar', '.webp', '.ttf'};
  return !binary.contains(p.extension(file.path));
}

/// The one version the core family carries, read from the checkout under test.
String _familyVersion(Directory repository) =>
    RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(
          File(
            p.join(
              repository.path,
              'packages',
              'dartway_core_server',
              'pubspec.yaml',
            ),
          ).readAsStringSync(),
        )!
        .group(1)!;
