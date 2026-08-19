import 'dart:io';

import 'package:dartway_cli/src/checker/dw_check_type.dart';
import 'package:dartway_cli/src/checker/dw_crud_coverage.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The three gaps on the server that fail *closed*: the code compiles, the
/// server starts, the migration applies, and the app quietly cannot do
/// something. Nothing else in the toolchain says a word about any of them —
/// which is the whole reason they are worth a check rather than a convention.
void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('dw_crud_coverage');
  });

  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });

  /// Writes a server package and returns what the rule said.
  ///
  /// [models] maps a class name to whether it has a table; [configs] maps a
  /// model to the source of the config file declaring it; [registered] is what
  /// the `crudConfigurations` list names; [tests] is the source of the files
  /// under `test/`.
  List<DwCrudCoverageFinding> findingsFor({
    required Map<String, bool> models,
    Map<String, String> configs = const {},
    List<String> registered = const [],
    Map<String, String> tests = const {},
  }) {
    final serverDir = Directory(p.join(sandbox.path, 'my_server'))
      ..createSync(recursive: true);
    final srcDir = Directory(p.join(serverDir.path, 'lib', 'src'));

    models.forEach((className, hasTable) {
      File(p.join(srcDir.path, 'models', '$className.spy.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'class: $className\n'
          '${hasTable ? 'table: ${className.toLowerCase()}\n' : ''}'
          'fields:\n  title: String\n',
        );
    });

    configs.forEach((model, source) {
      File(p.join(srcDir.path, 'crud', '${model.toLowerCase()}_config.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(source);
    });

    File(p.join(srcDir.path, 'dartway', 'dartway_core.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        'void initDartwayCore() {\n'
        '  dw = DwCore.init<UserProfile>(\n'
        '    crudConfigurations: [${registered.join(', ')}],\n'
        '  );\n'
        '}\n',
      );

    tests.forEach((name, source) {
      File(p.join(serverDir.path, 'test', 'integration', '$name.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(source);
    });

    final inspector = DwCrudCoverageInspector(serverPackageDir: serverDir);
    inspector.run();
    return inspector.findings;
  }

  String configSource(String model, {String hooks = ''}) =>
      'final ${model.toLowerCase()}CrudConfig = DwCrudConfig<$model>(\n'
      '  table: $model.t,\n'
      '  getListConfig: DwGetModelListConfig(accessFilter: (s) async => null),\n'
      '$hooks'
      ');\n';

  test('a table nobody configured is reported by name', () {
    final findings = findingsFor(models: const {'Invoice': true});

    expect(findings, hasLength(1));
    expect(findings.single.type, DwCheckType.crudConfigMissing);
    expect(findings.single.message, contains('Invoice'));
    expect(findings.single.message, contains('notConfigured'));
  });

  test('an enum and a table-less model are not asked for a config', () {
    // The two shapes that legitimately have no rows: `UserRole` is an enum
    // (no `class:` at all) and `SearchQuery` is a DTO. Demanding access
    // configuration for either would be noise, and noise is how a check gets
    // switched off.
    final findings = findingsFor(models: const {'SearchQuery': false});

    expect(findings, isEmpty);
  });

  test('a configured and registered model says nothing', () {
    final findings = findingsFor(
      models: const {'Invoice': true},
      configs: {'Invoice': configSource('Invoice')},
      registered: const ['invoiceCrudConfig'],
    );

    expect(findings, isEmpty);
  });

  test('a config that was written and never registered is an error', () {
    // The one with no second reading: the file exists, it reviews as finished,
    // and the API answers exactly as if it had never been written.
    final findings = findingsFor(
      models: const {'Invoice': true},
      configs: {'Invoice': configSource('Invoice')},
      registered: const [],
    );

    expect(findings, hasLength(1));
    expect(findings.single.type, DwCheckType.crudConfigUnregistered);
    expect(findings.single.type.severity, DwCheckSeverity.error);
    expect(findings.single.message, contains('invoiceCrudConfig'));
  });

  test('a config that only declares a shape is not asked for a test', () {
    // `accessFilter` and `include` are the declaration. A config that carries
    // no hand-written save logic has no rule to hold, and asking it for a test
    // would be counting coverage rather than naming a gap.
    final findings = findingsFor(
      models: const {'Invoice': true},
      configs: {'Invoice': configSource('Invoice')},
      registered: const ['invoiceCrudConfig'],
      tests: const {},
    );

    expect(findings, isEmpty);
  });

  test('a save rule no server test names is reported, with the hooks', () {
    final findings = findingsFor(
      models: const {'Invoice': true},
      configs: {
        'Invoice': configSource(
          'Invoice',
          hooks:
              '  saveConfig: DwSaveConfig<Invoice>(\n'
              '    allowSave: (session, ctx) async => session.isAdmin,\n'
              '  ),\n',
        ),
      },
      registered: const ['invoiceCrudConfig'],
    );

    expect(findings, hasLength(1));
    expect(findings.single.type, DwCheckType.crudRuleUntested);
    expect(findings.single.type.severity, DwCheckSeverity.warning);
    expect(findings.single.message, contains('allowSave'));
  });

  test('a rule a test names is covered', () {
    final findings = findingsFor(
      models: const {'Invoice': true},
      configs: {
        'Invoice': configSource(
          'Invoice',
          hooks:
              '  saveConfig: DwSaveConfig<Invoice>(\n'
              '    allowSave: (session, ctx) async => session.isAdmin,\n'
              '  ),\n',
        ),
      },
      registered: const ['invoiceCrudConfig'],
      tests: const {
        'invoice_access_test': "void main() { Invoice(title: 'x'); }\n",
      },
    );

    expect(findings, isEmpty);
  });

  test('the generated test tools do not count as covering anything', () {
    // They name every model of the project, so counting them would mark the
    // whole schema as tested and the check would never fire again.
    final serverDir = Directory(p.join(sandbox.path, 'tools_server'))
      ..createSync(recursive: true);
    File(p.join(serverDir.path, 'lib', 'src', 'models', 'Invoice.spy.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class: Invoice\ntable: invoice\n');
    File(p.join(serverDir.path, 'lib', 'src', 'crud', 'invoice.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        configSource(
          'Invoice',
          hooks:
              '  saveConfig: DwSaveConfig<Invoice>(allowSave: (s, c) => x),\n',
        ),
      );
    File(p.join(serverDir.path, 'lib', 'src', 'dartway', 'dartway_core.dart'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('crudConfigurations: [invoiceCrudConfig],');
    File(
        p.join(
          serverDir.path,
          'test',
          'integration',
          'test_tools',
          'serverpod_test_tools.dart',
        ),
      )
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('// Invoice is named here by the generator.\n');

    final inspector = DwCrudCoverageInspector(serverPackageDir: serverDir);
    inspector.run();

    expect(inspector.findings, hasLength(1));
    expect(inspector.findings.single.type, DwCheckType.crudRuleUntested);
  });

  test('--type narrows the run to one of the three', () {
    final serverDir = Directory(p.join(sandbox.path, 'narrow_server'))
      ..createSync(recursive: true);
    File(p.join(serverDir.path, 'lib', 'src', 'models', 'Invoice.spy.yaml'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class: Invoice\ntable: invoice\n');

    final inspector = DwCrudCoverageInspector(
      serverPackageDir: serverDir,
      filterType: DwCheckType.crudConfigUnregistered,
    );
    inspector.run();

    expect(inspector.findings, isEmpty);
  });

  test('a project with no server package is passed over', () {
    final inspector = DwCrudCoverageInspector(serverPackageDir: null);

    expect(inspector.run(), 0);
    expect(inspector.findings, isEmpty);
  });
}
