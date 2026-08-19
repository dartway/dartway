import 'dart:io';

import 'package:path/path.dart' as p;

import 'dw_check_type.dart';

/// One finding, kept as a value so the tests can assert what the rule *said*
/// rather than what it printed.
class DwCrudCoverageFinding {
  const DwCrudCoverageFinding(this.type, this.message);

  final DwCheckType type;
  final String message;

  @override
  String toString() => '${type.name}: $message';
}

/// Finds the things a project is **missing** on the server, by name.
///
/// Not a coverage percentage: each finding names one model and one thing to do
/// about it. The three it looks for are the ones nothing else catches, because
/// every one of them fails *closed* — the code compiles, the server starts, the
/// migration applies, and the app quietly cannot do something.
///
/// - [DwCheckType.crudConfigMissing] — a table nobody configured. Generic CRUD
///   is secure by default, so an unconfigured model answers `notConfigured` to
///   every read and write. That is the right default and a silent one.
/// - [DwCheckType.crudConfigUnregistered] — a config that was written and never
///   put in `crudConfigurations`. The worst of the three: the file exists, it
///   reviews as done, and the API answers exactly as if it did not.
/// - [DwCheckType.crudRuleUntested] — a config carrying hand-written save or
///   delete logic that no server test names. The rule lives on the server, so
///   only a server test can hold it; a widget test proving the button is hidden
///   proves nothing about who may save.
///
/// **What it deliberately does not do.** It says nothing about Flutter features
/// or about Event models. A feature's tests are not countable without turning
/// into the percentage this check exists instead of, and *Event model* is a
/// domain reading — a change written on top of a base — with no marker in the
/// YAML to detect it by. A rule that guessed from a `*Event` suffix would miss
/// the one spelled `BalanceEntry` and fire on the one that is a plain lookup.
class DwCrudCoverageInspector {
  DwCrudCoverageInspector({
    required this.serverPackageDir,
    DwCheckType? filterType,
    DwCheckSeverity? filterSeverity,
  }) : _filterType = filterType,
       _filterSeverity = filterSeverity;

  final Directory? serverPackageDir;

  final DwCheckType? _filterType;
  final DwCheckSeverity? _filterSeverity;
  final _findings = <DwCrudCoverageFinding>[];

  /// The findings, in the order they were made.
  List<DwCrudCoverageFinding> get findings => List.unmodifiable(_findings);

  static const _checks = {
    DwCheckType.crudConfigMissing,
    DwCheckType.crudConfigUnregistered,
    DwCheckType.crudRuleUntested,
  };

  /// The save/delete hooks that make a config carry a rule rather than declare
  /// a shape. `accessFilter` and `include` are deliberately absent: they are
  /// the declaration, and a config that only declares needs no test.
  static const _ruleHooks = {
    'allowSave',
    'validateSave',
    'beforeSaveTransaction',
    'afterSaveTransaction',
    'afterSaveTransform',
    'afterSaveSideEffects',
    'allowDelete',
    'beforeDelete',
    'afterDelete',
  };

  bool _runs(DwCheckType type) =>
      (_filterType == null || _filterType == type) &&
      (_filterSeverity == null || _filterSeverity == type.severity);

  /// Runs the checks and prints the section. Returns the number of
  /// error-severity findings.
  int run() {
    final serverDir = serverPackageDir;
    if (serverDir == null) return 0;
    if (!_checks.any(_runs)) return 0;

    final srcDir = Directory(p.join(serverDir.path, 'lib', 'src'));
    if (!srcDir.existsSync()) return 0;

    final models = _declaredTableModels(
      Directory(p.join(srcDir.path, 'models')),
    );
    if (models.isEmpty) return 0;

    final configs = _declaredConfigs(srcDir);
    final registered = _registeredConfigNames(srcDir);
    final testedModels = _modelsNamedInTests(serverDir);

    for (final model in models) {
      final config = configs[model];

      if (config == null) {
        if (_runs(DwCheckType.crudConfigMissing)) {
          _findings.add(
            DwCrudCoverageFinding(
              DwCheckType.crudConfigMissing,
              '$model has a table and no DwCrudConfig, so every read and write '
              'of it answers notConfigured — the app cannot reach it at all. '
              'Add a config in lib/src/crud/, or, if this table is the '
              "server's own and no client should see it, that is what the "
              'absence already means and this line is the reminder to say so '
              'in a doc comment on the model.',
            ),
          );
        }
        continue;
      }

      if (!registered.contains(config.variableName) &&
          _runs(DwCheckType.crudConfigUnregistered)) {
        _findings.add(
          DwCrudCoverageFinding(
            DwCheckType.crudConfigUnregistered,
            '${config.variableName} (${config.relativePath}) is not in the '
            'crudConfigurations list passed to DwCore.init, so $model answers '
            'notConfigured exactly as if the config had never been written.',
          ),
        );
      }

      if (config.ruleHooks.isNotEmpty &&
          !testedModels.contains(model) &&
          _runs(DwCheckType.crudRuleUntested)) {
        _findings.add(
          DwCrudCoverageFinding(
            DwCheckType.crudRuleUntested,
            '$model carries a rule (${config.ruleHooks.join(', ')}) that no '
            'test under test/ names. The rule runs inside a request and touches '
            'the database, so only an integration test can hold it — see the '
            'dartway-testing skill. A widget test showing the button is hidden '
            'says nothing about who may save.',
          ),
        );
      }
    }

    if (_findings.isEmpty) return 0;

    print('\n🗄️ Server CRUD coverage:\n');
    for (final finding in _findings) {
      print('  ${finding.type.reportLabel}: ${finding.message}');
    }

    return _findings
        .where((f) => f.type.severity == DwCheckSeverity.error)
        .length;
  }

  /// Every model this project declares with a table, by class name.
  ///
  /// Only the ones with a `table:` — an enum, and a class used purely as a DTO,
  /// have no rows and nothing to configure access to.
  Set<String> _declaredTableModels(Directory modelsDir) {
    if (!modelsDir.existsSync()) return const {};

    final models = <String>{};
    for (final file in modelsDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.yaml') && !file.path.endsWith('.yml')) continue;

      final source = file.readAsStringSync();
      final className = RegExp(
        r'^class:\s*(\w+)',
        multiLine: true,
      ).firstMatch(source)?.group(1);
      if (className == null) continue;
      if (!RegExp(r'^table:\s*\S', multiLine: true).hasMatch(source)) continue;

      models.add(className);
    }
    return models;
  }

  /// Every `DwCrudConfig<Model>` the server declares, by the model it is for.
  Map<String, _DeclaredConfig> _declaredConfigs(Directory srcDir) {
    final configs = <String, _DeclaredConfig>{};
    final declaration = RegExp(
      r'(?:final|const)\s+(\w+)\s*=\s*DwCrudConfig<(\w+)>\s*\(',
    );

    for (final file in _dartFilesOf(srcDir)) {
      final source = file.readAsStringSync();
      for (final match in declaration.allMatches(source)) {
        final variableName = match.group(1)!;
        final model = match.group(2)!;
        configs[model] = _DeclaredConfig(
          variableName: variableName,
          relativePath: p
              .relative(file.path, from: srcDir.parent.parent.path)
              .replaceAll(r'\', '/'),
          ruleHooks: _ruleHooks.where((hook) {
            return RegExp('\\b$hook\\s*:').hasMatch(source);
          }).toList(),
        );
      }
    }
    return configs;
  }

  /// The identifiers listed in the `crudConfigurations:` argument.
  ///
  /// Read as text rather than parsed: the list is one argument in one call, and
  /// an analyzer pass would cost seconds on every run to learn the same names.
  Set<String> _registeredConfigNames(Directory srcDir) {
    final names = <String>{};
    for (final file in _dartFilesOf(srcDir)) {
      final source = file.readAsStringSync();
      final start = source.indexOf('crudConfigurations:');
      if (start < 0) continue;

      final open = source.indexOf('[', start);
      final close = open < 0 ? -1 : source.indexOf(']', open);
      if (open < 0 || close < 0) continue;

      for (final identifier in RegExp(
        r'\b[a-z]\w*\b',
      ).allMatches(source.substring(open, close))) {
        names.add(identifier.group(0)!);
      }
    }
    return names;
  }

  /// The model class names any server test mentions.
  ///
  /// A Serverpod integration test names the model to build a row with it, so a
  /// mention is a reliable enough signal — and the failure mode of being wrong
  /// is a rule silently counted as covered, which is why this check is a
  /// warning and not an error.
  Set<String> _modelsNamedInTests(Directory serverDir) {
    final testDir = Directory(p.join(serverDir.path, 'test'));
    if (!testDir.existsSync()) return const {};

    final mentioned = <String>{};
    for (final file in _dartFilesOf(testDir)) {
      // The generated test tools name every model of the project, so counting
      // them would mark the whole schema as tested.
      if (p.basename(file.path) == 'serverpod_test_tools.dart') continue;

      for (final word in RegExp(
        r'\b[A-Z]\w*\b',
      ).allMatches(file.readAsStringSync())) {
        mentioned.add(word.group(0)!);
      }
    }
    return mentioned;
  }

  Iterable<File> _dartFilesOf(Directory dir) sync* {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = p.relative(entity.path, from: dir.path);
      // Generated code declares no configs and tests nothing.
      if (relative.split(p.separator).contains('generated')) continue;
      yield entity;
    }
  }
}

class _DeclaredConfig {
  const _DeclaredConfig({
    required this.variableName,
    required this.relativePath,
    required this.ruleHooks,
  });

  final String variableName;
  final String relativePath;
  final List<String> ruleHooks;
}
