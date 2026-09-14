import 'dart:convert';
import 'dart:io';

import 'package:dartway_generator/dartway_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The generator package directory (tests run with it as the working
/// directory).
final generatorRoot = p.normalize(p.absolute('.'));

final frameworkPackages = p.normalize(p.join(generatorRoot, '..'));

/// The `dart` running the tests, for subprocesses.
final dartExecutable = Platform.resolvedExecutable;

/// A throwaway DartWay project on disk: real packages with a real package
/// config, resolved against this tree's `dartway_core_shared` and `dartway_orm`, so
/// the generator and `dart analyze` see exactly what a project would.
final class TempProject {
  TempProject._(this.root);

  final String root;

  /// Creates a project with packages named [packages] (e.g. `app_shared`).
  ///
  /// A `*_server` package depends on `dartway_orm` alone — the ORM's own
  /// reference fixtures, which import it directly — unless [serverOnCore]:
  /// then on `dartway_core_server` alone, as a project's server declares it
  /// (D-030), so its code imports ORM types from there, and
  /// `depend_on_referenced_packages` would flag an import of the ORM.
  static TempProject create(
    List<String> packages, {
    bool serverOnCore = false,
  }) {
    final root = Directory.systemTemp
        .createTempSync('dw_generator_')
        .resolveSymbolicLinksSync();
    final project = TempProject._(p.normalize(root));
    for (final package in packages) {
      project._createPackage(package, serverOnCore: serverOnCore);
    }
    addTearDown(project.delete);
    return project;
  }

  void _createPackage(String name, {required bool serverOnCore}) {
    final dir = p.join(root, name);
    Directory(p.join(dir, 'lib')).createSync(recursive: true);
    final isServer = name.endsWith('_server');
    writeFile(
      p.join(name, 'pubspec.yaml'),
      'name: $name\n'
      'publish_to: none\n'
      'environment:\n'
      '  sdk: ^3.11.0\n'
      'dependencies:\n'
      '  dartway_core_shared: any\n'
      '${isServer ? '  ${serverOnCore ? 'dartway_core_server' : 'dartway_orm'}: any\n' : ''}'
      '${isServer ? '  ${name.replaceAll('_server', '_shared')}: any\n' : ''}'
      'dev_dependencies:\n'
      '  lints: any\n',
    );
    // Strict analysis: generated code has to be clean under the strictest
    // settings a project may choose, not only under the defaults.
    writeFile(
      p.join(name, 'analysis_options.yaml'),
      'include: package:lints/recommended.yaml\n'
      'analyzer:\n'
      '  language:\n'
      '    strict-casts: true\n'
      '    strict-inference: true\n'
      '    strict-raw-types: true\n',
    );
    _writePackageConfig(name);
  }

  /// A package config holding everything the generator itself resolved (the
  /// framework packages from this tree and their dependencies), plus every
  /// package of this project.
  void _writePackageConfig(String name) {
    final own =
        jsonDecode(
              File(
                p.join(generatorRoot, '.dart_tool', 'package_config.json'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final ownConfigDir = p.join(generatorRoot, '.dart_tool');
    final packages = <Map<String, Object?>>[
      for (final entry
          in (own['packages']! as List<Object?>).cast<Map<String, Object?>>())
        if (entry['name'] != 'dartway_generator')
          {
            ...entry,
            'rootUri': _absoluteUri(entry['rootUri']! as String, ownConfigDir),
          },
      for (final sibling in Directory(root).listSync())
        if (sibling is Directory)
          {
            'name': p.basename(sibling.path),
            'rootUri': p.toUri(sibling.path).toString(),
            'packageUri': 'lib/',
            'languageVersion': '3.11',
          },
    ];
    // Every package's config lists all project packages, whichever was
    // created first.
    for (final sibling in Directory(root).listSync()) {
      if (sibling is! Directory) continue;
      writeFile(
        p.join(p.basename(sibling.path), '.dart_tool', 'package_config.json'),
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'configVersion': 2, 'packages': packages}),
      );
    }
  }

  static String _absoluteUri(String rootUri, String configDir) {
    if (rootUri.startsWith('file:')) return rootUri;
    return p.toUri(p.normalize(p.join(configDir, rootUri))).toString();
  }

  String path(String relative) => p.join(root, relative);

  /// Copies the tree `test/fixtures/<scenario>/` into the project.
  void copyFixture(String scenario) {
    final source = Directory(
      p.join(generatorRoot, 'test', 'fixtures', scenario),
    );
    for (final entity in source.listSync(recursive: true)) {
      if (entity is! File) continue;
      writeFile(
        p.relative(entity.path, from: source.path),
        entity.readAsStringSync(),
      );
    }
  }

  void writeFile(String relative, String content) {
    final file = File(path(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String readFile(String relative) => File(path(relative)).readAsStringSync();

  bool exists(String relative) => File(path(relative)).existsSync();

  Future<DwGenerationReport> generate({bool check = false}) =>
      DwCodeGenerator.run(root, check: check);

  /// Generates and fails the test on any diagnostic.
  Future<DwGenerationReport> generateClean() async {
    final report = await generate();
    expect(
      report.diagnostics.map((d) => d.format(root)).toList(),
      isEmpty,
      reason: 'generation must succeed',
    );
    return report;
  }

  /// `dart analyze --fatal-infos` on [package]; returns its output when it
  /// fails, `null` when clean.
  Future<String?> analyze(String package) async {
    final result = await Process.run(dartExecutable, [
      'analyze',
      '--fatal-infos',
      '.',
    ], workingDirectory: path(package));
    if (result.exitCode == 0) return null;
    return '${result.stdout}${result.stderr}';
  }

  /// Runs the Dart script [script] of [package] and returns its exit code and
  /// output.
  Future<ProcessResult> runScript(
    String package,
    String script,
  ) => Process.run(dartExecutable, [
    '--packages=${path(p.join(package, '.dart_tool', 'package_config.json'))}',
    path(p.join(package, script)),
  ], workingDirectory: path(package));

  /// Every file under the project except package configs, as relative path →
  /// content.
  Map<String, String> snapshot() => {
    for (final entity in Directory(
      root,
    ).listSync(recursive: true)..sort((a, b) => a.path.compareTo(b.path)))
      if (entity is File && !entity.path.contains('.dart_tool'))
        p.relative(entity.path, from: root): entity.readAsStringSync(),
  };

  void delete() {
    if (Directory(root).existsSync()) {
      Directory(root).deleteSync(recursive: true);
    }
  }
}

/// Compares [actual] with the golden file [name] under `test/goldens/`.
/// `DW_UPDATE_GOLDENS=1` rewrites the golden instead — review the diff.
void expectGolden(String actual, String name) {
  final file = File(p.join(generatorRoot, 'test', 'goldens', name));
  if (Platform.environment['DW_UPDATE_GOLDENS'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'golden $name is missing; run with DW_UPDATE_GOLDENS=1',
  );
  expect(actual, file.readAsStringSync(), reason: 'golden $name');
}
