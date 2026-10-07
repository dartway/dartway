import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'project_contract_test.dart' show git, generatorCli, itemSource;
import 'support/temp_project.dart';

void main() {
  test(
    'a user codec mixin cannot impersonate generated ownership by name',
    () async {
      final project = TempProject.create(['app_shared']);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      project.writeFile('app_shared/bin/mixin_probe.dart', r'''
import '../lib/src/item.dart';
void main() {
  final json = const ItemRecord(id: 1).toJson();
  print(json['id']);
  try { $ItemRecordFromJson(json); print('decoded'); }
  catch (e) { print(e.runtimeType); }
}
''');
      await project.generateClean();
      final base = baseline(project);
      final before = await project.runScript(
        'app_shared',
        'bin/mixin_probe.dart',
      );
      expect(before.exitCode, 0, reason: output(before));
      expect(before.stdout, '1\ndecoded\n');
      project.writeFile(
        'app_shared/lib/src/item.dart',
        project
                .readFile('app_shared/lib/src/item.dart')
                .replaceFirst(
                  r'with _$ItemRecord {',
                  r'with _$ItemRecord, _$ManualCodec {',
                ) +
            r'''
mixin _$ManualCodec on DwDataObject {
  @override Map<String, Object?> toJson() => {'id': 'changed'};
}
''',
      );
      await project.generateClean();
      final after = await project.runScript(
        'app_shared',
        'bin/mixin_probe.dart',
      );
      expect(after.exitCode, 0, reason: output(after));
      expect(after.stdout, 'changed\n_TypeError\n');
      final snapshot = bytes(project);
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 3, reason: output(result));
      expect(output(result), contains('custom toJson'));
      expect(bytes(project), snapshot);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'native custom enum name encoding cannot silently pass the gate',
    () async {
      for (final custom in [
        "extension ItemStateWireName on ItemState { String get name => 'renamed'; }",
        "enum ItemState { ready; String get name => 'renamed'; }",
      ]) {
        final project = TempProject.create(['app_shared']);
        const source = r'''
import 'package:dartway_core_shared/dartway_core_shared.dart';
part 'item.dw.dart';
enum ItemState { ready }
final class ItemRecord extends DwDataObject with _$ItemRecord {
  const ItemRecord({required this.id, required this.state});
  @override final int id;
  final ItemState state;
}
''';
        project.writeFile('app_shared/lib/src/item.dart', source);
        project.writeFile('app_shared/bin/enum_probe.dart', r'''
import '../lib/src/item.dart';
void main() {
  final json = const ItemRecord(id: 1, state: ItemState.ready).toJson();
  print(json['state']);
  try { $ItemRecordFromJson(json); print('decoded'); }
  catch (e) { print(e.runtimeType); }
}
''');
        await project.generateClean();
        final base = baseline(project);
        final before = await project.runScript(
          'app_shared',
          'bin/enum_probe.dart',
        );
        expect(before.exitCode, 0, reason: output(before));
        expect(before.stdout, 'ready\ndecoded\n');
        project.writeFile(
          'app_shared/lib/src/item.dart',
          custom.startsWith('enum ')
              ? source.replaceFirst('enum ItemState { ready }', custom)
              : '$source\n$custom\n',
        );
        await project.generateClean();
        final after = await project.runScript(
          'app_shared',
          'bin/enum_probe.dart',
        );
        expect(after.exitCode, 0, reason: output(after));
        expect(after.stdout, 'renamed\nDwUnknownEnumValue\n');
        final snapshot = bytes(project);
        final result = await generatorCli(project, [
          '--check',
          '--contract-base',
          base,
        ]);
        expect(result.exitCode, 3, reason: output(result));
        expect(output(result), contains('custom enum name encoding'));
        expect(bytes(project), snapshot);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'descriptor-free adoption permits dependency codec changes with unchanged shared source',
    () async {
      final project = TempProject.create(['app_shared']);
      final external = Directory.systemTemp.createTempSync('dw_external_enum_');
      addTearDown(() => external.deleteSync(recursive: true));
      File(p.join(external.path, 'pubspec.yaml')).writeAsStringSync(
        'name: external_enum\nversion: 1.0.0\nenvironment:\n  sdk: ^3.11.0\n',
      );
      final enumFile = File(p.join(external.path, 'lib/state.dart'));
      enumFile.parent.createSync();
      enumFile.writeAsStringSync('enum ItemState { ready }\n');
      final configFile = File(
        project.path('app_shared/.dart_tool/package_config.json'),
      );
      final config =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      (config['packages'] as List).add({
        'name': 'external_enum',
        'rootUri': external.uri.toString(),
        'packageUri': 'lib/',
        'languageVersion': '3.11',
      });
      configFile.writeAsStringSync(jsonEncode(config));
      project.writeFile(
        'app_shared/pubspec.yaml',
        '${project.readFile('app_shared/pubspec.yaml')}  external_enum:\n    path: ${external.path}\n',
      );
      project.writeFile(
        'app_shared/pubspec.lock',
        File(
          p.join(generatorRoot, 'pubspec.lock'),
        ).readAsStringSync().replaceFirst(
          'packages:\n',
          'packages:\n  external_enum:\n    dependency: direct main\n    description:\n      path: ${external.path}\n      relative: false\n    source: path\n    version: "1.0.0"\n',
        ),
      );
      project.writeFile('app_shared/lib/src/item.dart', r'''
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:external_enum/state.dart';
part 'item.dw.dart';
final class ItemRecord extends DwDataObject with _$ItemRecord {
  const ItemRecord({required this.id, required this.state});
  @override final int id;
  final ItemState state;
}
''');
      project.writeFile('app_shared/bin/enum_probe.dart', r'''
import '../lib/src/item.dart';
void main() {
  try { $ItemRecordFromJson({'id': 1, 'state': 'archived'}); print('decoded'); }
  catch (e) { print(e.runtimeType); }
}
''');
      await project.generateClean();
      final before = await project.runScript(
        'app_shared',
        'bin/enum_probe.dart',
      );
      expect(before.exitCode, 0, reason: output(before));
      expect(before.stdout, 'DwUnknownEnumValue\n');
      File(
        project.path('app_shared/lib/generated/dw_contract.json'),
      ).deleteSync();
      final base = baseline(project);
      enumFile.writeAsStringSync('enum ItemState { ready, archived }\n');
      await project.generateClean();
      final after = await project.runScript(
        'app_shared',
        'bin/enum_probe.dart',
      );
      expect(after.exitCode, 0, reason: output(after));
      expect(after.stdout, 'decoded\n');
      final snapshot = bytes(project);
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 0, reason: output(result));
      expect(output(result), contains('shared contract source unchanged'));
      expect(bytes(project), snapshot);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'custom DTO equality used by default omission is unverified, not silently compatible',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();
      final base = baseline(project);
      project.writeFile('app_shared/bin/equality_probe.dart', r'''
import '../lib/src/defaults.dart';
import '../lib/src/catalog.dart';
void main() { print(Settings(id: 1, createdAt: DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true), ref: const Ref(id: 'live')).toJson().containsKey('ref')); }
''');
      expect(
        (await project.runScript(
          'app_shared',
          'bin/equality_probe.dart',
        )).stdout,
        'true\n',
      );
      final catalog = project.readFile('app_shared/lib/src/catalog.dart');
      project.writeFile(
        'app_shared/lib/src/catalog.dart',
        catalog.replaceFirst(
          r'final class Ref extends DwDataObject with _$Ref {',
          r'final class Ref extends DwDataObject with _$Ref { @override bool operator ==(Object other) => other is Ref; @override int get hashCode => 0;',
        ),
      );
      await project.generateClean();
      expect(
        (await project.runScript(
          'app_shared',
          'bin/equality_probe.dart',
        )).stdout,
        'false\n',
      );
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 3, reason: output(result));
      expect(output(result), contains('custom default equality'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'pin move adopts unchanged shared source through generation and real CLI check',
    () async {
      final project = TempProject.create([
        'app_shared',
        'app_server',
        'app_flutter',
      ]);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      await project.generateClean();
      final pubspec = project.readFile('app_shared/pubspec.yaml');
      project.writeFile(
        'app_shared/pubspec.yaml',
        '$pubspec\ndependency_overrides:\n  dartway_core_shared:\n    git:\n      url: https://example.test/framework.git\n      ref: old-pin\n',
      );
      project.writeFile('app_shared/pubspec.lock', 'old lock bytes\n');
      File(
        project.path('app_shared/lib/generated/dw_contract.json'),
      ).deleteSync();
      // The old generator's output cannot be reproduced by the new one.
      for (final path in [
        'lib/src/item.dw.dart',
        'lib/generated/dw_protocol.dart',
      ]) {
        project.writeFile(
          'app_shared/$path',
          '${project.readFile('app_shared/$path')}\n// old codec rules\n',
        );
      }
      final base = baseline(project);
      project.writeFile(
        'app_shared/pubspec.yaml',
        project
            .readFile('app_shared/pubspec.yaml')
            .replaceFirst('old-pin', 'new-pin'),
      );
      project.writeFile('app_shared/pubspec.lock', 'new lock bytes\n');
      await project.generateClean();
      generatorResolution(project);
      commit(project, 'adopt contract gate with pin move');
      final snapshot = bytes(project);
      for (final arguments in <List<String>>[
        ['generate', '--check'],
        ['generate', '--check', '--contract-base', base],
        ['check', '--type', 'projectContractVersion'],
        ['check', '--type', 'projectContractVersion', '--contract-base', base],
      ]) {
        final result = await cli(project, arguments);
        expect(result.exitCode, 0, reason: output(result));
        expect(
          output(result),
          contains(
            'adopted at $base: shared contract source unchanged; descriptor established by this change',
          ),
        );
        expect(bytes(project), snapshot);
      }
      project.writeFile(
        'app_shared/lib/src/item.dart',
        itemSource(requiredTitle: true),
      );
      await project.generateClean();
      final changed = bytes(project);
      for (final arguments in <List<String>>[
        ['generate', '--check', '--contract-base', base],
        ['check', '--type', 'projectContractVersion', '--contract-base', base],
      ]) {
        final result = await cli(project, arguments);
        expect(
          result.exitCode,
          arguments.first == 'check' ? 1 : 3,
          reason: output(result),
        );
        expect(
          output(result),
          allOf(
            contains('app_shared/lib/src/item.dart'),
            contains('Split the change'),
            contains('pin move'),
            contains('following PR'),
          ),
        );
        expect(bytes(project), changed);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'import/enum order and evaluated map defaults do not change the contract',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();
      final base = baseline(project);
      final descriptor = project.readFile(
        'app_shared/lib/generated/dw_contract.json',
      );
      project.writeFile(
        'app_shared/lib/src/catalog.dart',
        project
            .readFile('app_shared/lib/src/catalog.dart')
            .replaceAll('as units;', 'as measure;')
            .replaceAll('units.', 'measure.')
            .replaceFirst('red, green, blue', 'blue, green, red'),
      );
      project.writeFile(
        'app_shared/lib/src/defaults.dart',
        project
            .readFile('app_shared/lib/src/defaults.dart')
            .replaceFirst("{'max': 10, 'min': 1}", "{'min': 1, 'max': 10}")
            .replaceAll('as units;', 'as measure;')
            .replaceAll('units.', 'measure.'),
      );
      project.writeFile(
        'app_shared/lib/src/measure.dart',
        project
            .readFile('app_shared/lib/src/units.dart')
            .replaceFirst("part 'units.dw.dart';", "part 'measure.dw.dart';"),
      );
      File(project.path('app_shared/lib/src/units.dart')).deleteSync();
      project.writeFile(
        'app_shared/lib/app_shared.dart',
        project
            .readFile('app_shared/lib/app_shared.dart')
            .replaceAll('units.dart', 'measure.dart'),
      );
      project.writeFile(
        'app_shared/bin/round_trip.dart',
        project
            .readFile('app_shared/bin/round_trip.dart')
            .replaceAll('units.dart', 'measure.dart'),
      );
      await project.generateClean();
      final roundTrip = await project.runScript(
        'app_shared',
        'bin/round_trip.dart',
      );
      expect(roundTrip.exitCode, 0, reason: output(roundTrip));
      expect(
        project.readFile('app_shared/lib/generated/dw_contract.json'),
        descriptor,
      );
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 0, reason: output(result));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'real CLI holds the Git baseline through regeneration/feature commits and writes nothing on failure/check',
    () async {
      final project = TempProject.create([
        'app_shared',
        'app_server',
        'app_flutter',
      ]);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      await project.generateClean();
      final base = baseline(project);
      generatorResolution(project);
      project.writeFile(
        'app_shared/lib/src/item.dart',
        itemSource(requiredTitle: true),
      );
      await project.generateClean();
      commit(project, 'feature regeneration');
      project.writeFile(
        'app_shared/pubspec.yaml',
        project
            .readFile('app_shared/pubspec.yaml')
            .replaceFirst('0.1.0', '0.1.1'),
      );
      await project.generateClean();
      final generatedDescriptor = project.readFile(
        'app_shared/lib/generated/dw_contract.json',
      );
      project.writeFile(
        'app_shared/lib/generated/dw_contract.json',
        git(project, [
          'show',
          '$base:app_shared/lib/generated/dw_contract.json',
        ]),
      );
      final before = bytes(project);
      final checked = await cli(project, [
        'check',
        '--type',
        'projectContractVersion',
        '--contract-base',
        base,
      ]);
      expect(checked.exitCode, 1, reason: output(checked));
      expect(
        output(checked),
        allOf(
          contains(base),
          contains('required field added'),
          contains('projectContractVersion'),
        ),
      );
      expect(bytes(project), before);
      final failedGeneration = await cli(project, [
        'generate',
        '--contract-base',
        base,
      ]);
      expect(failedGeneration.exitCode, 3, reason: output(failedGeneration));
      expect(bytes(project), before);
      project.writeFile(
        'app_shared/lib/generated/dw_contract.json',
        generatedDescriptor,
      );
      project.writeFile(
        'app_shared/pubspec.yaml',
        project
            .readFile('app_shared/pubspec.yaml')
            .replaceFirst('0.1.1', '0.2.0'),
      );
      final green = await cli(project, ['generate', '--contract-base', base]);
      expect(green.exitCode, 0, reason: output(green));
      final snapshot = bytes(project);
      final clean = await cli(project, [
        'generate',
        '--check',
        '--contract-base',
        base,
      ]);
      expect(clean.exitCode, 0, reason: output(clean));
      expect(output(clean), contains('isolated by line 0.2'));
      expect(bytes(project), snapshot);
      final inferred = await generatorCli(project, ['--check']);
      expect(inferred.exitCode, 0, reason: output(inferred));
      expect(output(inferred), contains(base));
      git(project, ['branch', '-m', 'main', 'integration']);
      project.writeFile(
        '.agents/dartway-toolkit.json',
        jsonEncode({
          'settings': {'baseBranch': 'integration'},
        }),
      );
      final configured = await generatorCli(project, ['--check']);
      expect(configured.exitCode, 0, reason: output(configured));
      expect(output(configured), contains(base));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'generated codecs prove nullable/default/patch additions and open enum growth safe',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      project.writeFile('app_shared/lib/src/extra.dart', extra);
      await project.generateClean();
      final base = baseline(project);
      expect(
        (await project.runScript('app_shared', 'bin/round_trip.dart')).exitCode,
        0,
      );
      project.writeFile(
        'app_shared/lib/src/extra.dart',
        extra
                .replaceFirst('unknown, ready', 'unknown, ready, archived')
                .replaceFirst(
                  'this.state = OpenState.ready',
                  'this.state = OpenState.ready, this.note, this.count = 2, this.patch = const DwFieldPatch.keep()',
                )
                .replaceFirst(
                  'final OpenState state;',
                  'final OpenState state; final String? note; final int count; final DwFieldPatch<String> patch;',
                ) +
            r'''
final class RemoveState extends DwActionCommand<void> with _$RemoveState { const RemoveState(); }
''',
      );
      await project.generateClean();
      project.writeFile('app_shared/bin/addition_probe.dart', r'''
import 'package:dartway_core_shared/dartway_core_shared.dart';
import '../lib/src/extra.dart';
void main() {
  final missing = $ChangeStateFromJson({});
  if (missing.note != null || missing.count != 2 || missing.patch is! DwKeepField<String>) throw StateError('missing fallback');
  final present = $ChangeStateFromJson({'state':'archived','note':null,'patch':null});
  if (present.state != OpenState.archived || present.patch is! DwClearField<String>) throw StateError('present codec');
  if (DwJsonCodec.decodeEnum('future', OpenState.values) != OpenState.unknown) throw StateError('open fallback');
  print('ok');
}
''');
      final codec = await project.runScript(
        'app_shared',
        'bin/addition_probe.dart',
      );
      expect(codec.exitCode, 0, reason: output(codec));
      expect(codec.stdout, 'ok\n');
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 0, reason: output(result));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'actual missing/default/null codecs expose changed defaults and strict enum additions',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();
      final base = baseline(project);
      project.writeFile('app_shared/bin/default_probe.dart', r'''
import '../lib/src/defaults.dart';
import '../lib/src/catalog.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
void main() {
  final a = $SettingsFromJson({'id':1,'createdAt':0});
  final b = $SettingsFromJson({'id':1,'createdAt':0,'label':null,'count':null});
  print('${a.count}:${a.label}:${b.count}:${b.label}:${a.toJson().containsKey("count")}');
  try { DwJsonCodec.decodeEnum('archived', Color.values); print('enum:accepted'); } on DwUnknownEnumValue { print('enum:rejected'); }
}
''');
      expect(
        (await project.runScript(
          'app_shared',
          'bin/default_probe.dart',
        )).stdout,
        '3:none:3:null:false\nenum:rejected\n',
      );
      project.writeFile(
        'app_shared/lib/src/defaults.dart',
        project
            .readFile('app_shared/lib/src/defaults.dart')
            .replaceFirst('this.count = 3', 'this.count = 4'),
      );
      project.writeFile(
        'app_shared/lib/src/catalog.dart',
        project
            .readFile('app_shared/lib/src/catalog.dart')
            .replaceFirst('red, green, blue', 'red, green, blue, archived'),
      );
      await project.generateClean();
      expect(
        (await project.runScript(
          'app_shared',
          'bin/default_probe.dart',
        )).stdout,
        '4:none:4:null:false\nenum:accepted\n',
      );
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 3, reason: output(result));
      expect(
        output(result),
        allOf(contains('Settings.count'), contains('Item.color')),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'resolved nested/request/result/nullability/removal changes and unknown update groups are breaking',
    () async {
      final project = TempProject.create(['app_shared']);
      project.copyFixture('types');
      await project.generateClean();
      final base = baseline(project);
      final catalog = project.readFile('app_shared/lib/src/catalog.dart');
      project.writeFile('app_shared/bin/result_probe.dart', r'''
import '../lib/src/catalog.dart';
import '../lib/generated/dw_protocol.dart';
void probe(String name, Object? Function() decode) { try { decode(); print('$name:accept'); } catch (_) { print('$name:reject'); } }
void main() {
  probe('get', () => const GetItem(id: 1).decodeResult(null, appProtocol));
  probe('result', () => const EditItem(itemId: 1).decodeResult(7, appProtocol));
  probe('patch', () => $EditItemFromJson({'itemId':1,'discount':2.5}));
  probe('nested', () => $EditItemFromJson({'itemId':1,'dimensions':{'id':'x','width':1.5}}));
}
''');
      final oldCodecs = await project.runScript(
        'app_shared',
        'bin/result_probe.dart',
      );
      expect(oldCodecs.exitCode, 0, reason: output(oldCodecs));
      expect(
        oldCodecs.stdout,
        'get:reject\nresult:reject\npatch:accept\nnested:accept\n',
      );
      project.writeFile(
        'app_shared/lib/src/catalog.dart',
        catalog
            .replaceFirst('DwSingleRequest<Item>', 'DwMaybeRequest<Item>')
            .replaceFirst(
              'const GetItem({required this.id});',
              'const GetItem({required this.id}); @override bool matches(Item item) => item.id == id;',
            )
            .replaceFirst('DwActionCommand<Item>', 'DwActionCommand<int>')
            .replaceFirst('final double? discount;', 'final double discount;')
            .replaceFirst('this.discount,', 'required this.discount,')
            .replaceFirst(
              'final List<double> ratings;',
              'final List<double?> ratings;',
            )
            .replaceFirst(
              'final DwFieldPatch<double> discount;',
              'final DwFieldPatch<int> discount;',
            ),
      );
      final units = project.readFile('app_shared/lib/src/units.dart');
      project.writeFile(
        'app_shared/lib/src/units.dart',
        units.replaceFirst('final double width;', 'final int width;'),
      );
      await project.generateClean();
      final newCodecs = await project.runScript(
        'app_shared',
        'bin/result_probe.dart',
      );
      expect(newCodecs.exitCode, 0, reason: output(newCodecs));
      expect(
        newCodecs.stdout,
        'get:accept\nresult:accept\npatch:reject\nnested:reject\n',
      );
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(result.exitCode, 3, reason: output(result));
      expect(
        output(result),
        allOf(
          contains('GetItem: request/result codec changed'),
          contains('EditItem: request/result codec changed'),
          contains('Item.discount'),
          contains('Item.ratings'),
          contains('EditItem.discount'),
          contains('Dimensions.width'),
        ),
      );
      project.writeFile(
        'app_shared/lib/src/catalog.dart',
        catalog.replaceAll('RemoveItem', 'DeleteItem'),
      );
      project.writeFile('app_shared/lib/src/units.dart', units);
      await project.generateClean();
      final renamed = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(renamed.exitCode, 3, reason: output(renamed));
      expect(
        output(renamed),
        contains('RemoveItem: wire name removed/renamed'),
      );
      project.writeFile('app_shared/lib/src/catalog.dart', catalog);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      await project.generateClean();
      final added = await generatorCli(project, [
        '--check',
        '--contract-base',
        base,
      ]);
      expect(added.exitCode, 3, reason: output(added));
      expect(output(added), contains('unknown to installed clients'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  for (final corruption in [
    'malformed',
    'format',
    'missing-version',
    'unknown-type',
    'null-default',
    'custom',
  ]) {
    test(
      '$corruption baseline/current codec is unverified even after a line bump',
      () async {
        final project = TempProject.create(['app_shared']);
        project.writeFile('app_shared/lib/src/item.dart', itemSource());
        await project.generateClean();
        final relative = 'app_shared/lib/generated/dw_contract.json';
        if (corruption == 'malformed') project.writeFile(relative, '{');
        if (corruption == 'format') {
          project.writeFile(
            relative,
            project
                .readFile(relative)
                .replaceFirst('"format": 1', '"format": 99'),
          );
        }
        if (corruption == 'missing-version') {
          project.writeFile(
            relative,
            project
                .readFile(relative)
                .replaceFirst('"contractVersion": "0.1.0",', ''),
          );
        }
        if (corruption == 'unknown-type') {
          project.writeFile(
            relative,
            project
                .readFile(relative)
                .replaceFirst('"kind": "int"', '"kind": "future"'),
          );
        }
        if (corruption == 'null-default') {
          project.writeFile(
            relative,
            project
                .readFile(relative)
                .replaceFirst('"type": {', '"default": null, "type": {'),
          );
        }
        final base = baseline(project);
        if (corruption == 'custom') {
          project.writeFile(
            'app_shared/lib/src/item.dart',
            itemSource().replaceFirst(
              'final int id;',
              r'final int id; @override Map<String, Object?> toJson() => {"id": "$id"};',
            ),
          );
        }
        project.writeFile(
          'app_shared/pubspec.yaml',
          project
              .readFile('app_shared/pubspec.yaml')
              .replaceFirst('0.1.0', '0.2.0'),
        );
        await project.generateClean();
        final result = await generatorCli(project, [
          '--check',
          '--contract-base',
          base,
        ]);
        expect(result.exitCode, 3, reason: output(result));
        expect(
          output(result),
          allOf(
            contains('contract not verified'),
            isNot(contains('contracts compatible')),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  test(
    'descriptor-free submodule baseline names the unsupported shared source',
    () async {
      final project = TempProject.create(['app_shared']);
      project.writeFile('app_shared/lib/src/item.dart', itemSource());
      await project.generateClean();
      File(
        project.path('app_shared/lib/generated/dw_contract.json'),
      ).deleteSync();
      final base = baseline(project);
      git(project, [
        'update-index',
        '--add',
        '--cacheinfo',
        '160000,$base,app_shared/vendor',
      ]);
      git(project, [
        '-c',
        'user.name=Fixture',
        '-c',
        'user.email=fixture@example.test',
        'commit',
        '-m',
        'shared source submodule',
      ]);
      final submoduleBase = git(project, ['rev-parse', 'HEAD']);
      await project.generateClean();
      final snapshot = bytes(project);
      final result = await generatorCli(project, [
        '--check',
        '--contract-base',
        submoduleBase,
      ]);
      expect(result.exitCode, 3, reason: output(result));
      expect(
        output(result),
        allOf(
          contains(
            'shared contract source submodule is unsupported: app_shared/vendor',
          ),
          contains('tracked files'),
        ),
      );
      expect(bytes(project), snapshot);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final edit in ['modify', 'delete', 'add', 'binary', 'manual-part']) {
    test(
      'descriptor-free adoption blocks $edit of hand-written shared files',
      () async {
        final project = TempProject.create(['app_shared']);
        project.writeFile('app_shared/lib/src/item.dart', itemSource());
        project.writeFile('app_shared/README.md', 'contract documentation\n');
        project.writeFile(
          'app_shared/test/manual.dw.dart',
          '// hand-written fixture\n',
        );
        final binary = File(project.path('app_shared/data.bin'))
          ..writeAsBytesSync([0, 255, 13, 10]);
        await project.generateClean();
        File(
          project.path('app_shared/lib/generated/dw_contract.json'),
        ).deleteSync();
        final base = baseline(project);
        final String changed;
        switch (edit) {
          case 'modify':
            changed = 'app_shared/README.md';
            project.writeFile(changed, 'changed contract documentation\n');
          case 'delete':
            changed = 'app_shared/README.md';
            File(project.path(changed)).deleteSync();
          case 'add':
            changed = 'app_shared/lib/src/new_item.dart';
            project.writeFile(
              changed,
              itemSource()
                  .replaceAll('ItemRecord', 'NewItem')
                  .replaceAll('item.dw.dart', 'new_item.dw.dart'),
            );
          case 'binary':
            changed = 'app_shared/data.bin';
            binary.writeAsBytesSync([0, 254, 13, 10]);
          case 'manual-part':
            changed = 'app_shared/test/manual.dw.dart';
            // A filename, or a header forged at head, cannot turn source into output.
            project.writeFile(
              changed,
              '// GENERATED BY dartway generate. DO NOT EDIT.\n',
            );
          default:
            throw StateError(edit);
        }
        await project.generateClean();
        final snapshot = bytes(project);
        final result = await generatorCli(project, [
          '--check',
          '--contract-base',
          base,
        ]);
        expect(result.exitCode, 3, reason: output(result));
        expect(
          output(result),
          allOf(contains(changed), contains('Split the change')),
        );
        expect(bytes(project), snapshot);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

const extra = r'''
import 'package:dartway_core_shared/dartway_core_shared.dart';
part 'extra.dw.dart';
enum OpenState with DwOpenEnum { unknown, ready }
final class ChangeState extends DwActionCommand<void> with _$ChangeState {
  const ChangeState({this.state = OpenState.ready});
  final OpenState state;
}
''';

String output(ProcessResult result) => '${result.stdout}${result.stderr}';
String baseline(TempProject project) {
  project.writeFile('.gitignore', '.dart_tool/\n');
  git(project, ['init', '-b', 'main']);
  final base = commit(project, 'trusted baseline');
  git(project, ['checkout', '-b', 'feature']);
  return base;
}

String commit(TempProject project, String message) {
  git(project, ['add', '.']);
  git(project, [
    '-c',
    'user.name=Fixture',
    '-c',
    'user.email=fixture@example.test',
    'commit',
    '-m',
    message,
  ]);
  return git(project, ['rev-parse', 'HEAD']);
}

Map<String, String> bytes(TempProject project) => {
  for (final file in Directory(
    project.root,
  ).listSync(recursive: true).whereType<File>())
    if (!p.split(p.relative(file.path, from: project.root)).contains('.git'))
      p.relative(file.path, from: project.root): base64Encode(
        file.readAsBytesSync(),
      ),
};
void generatorResolution(TempProject project) {
  for (final name in ['app_shared', 'app_server', 'app_flutter']) {
    final relative = '$name/.dart_tool/package_config.json';
    final config = jsonDecode(project.readFile(relative)) as Map;
    (config['packages'] as List).add({
      'name': 'dartway_generator',
      'rootUri': p.toUri(generatorRoot).toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.11',
    });
    project.writeFile(relative, jsonEncode(config));
  }
}

Future<ProcessResult> cli(
  TempProject project,
  List<String> arguments,
) => Process.run(dartExecutable, [
  '--packages=${p.join(frameworkPackages, '..', '.dart_tool/package_config.json')}',
  p.join(frameworkPackages, 'dartway_cli/bin/dartway.dart'),
  ...arguments,
], workingDirectory: project.path('app_flutter'));
