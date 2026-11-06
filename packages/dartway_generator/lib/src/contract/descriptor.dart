import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';

import '../analysis/framework.dart';
import '../analysis/library_names.dart';
import '../analysis/wire_type.dart';
import '../dto/dto_model.dart';

/// A generator-owned, path-independent description of its project codecs.
Map<String, Object?> describeContract(
  String version,
  List<(ClassElement, DtoClass)> entries,
) {
  final unsupported = <String>[];
  final names = {for (final (_, dto) in entries) dto.name};
  final byName = {for (final (_, dto) in entries) dto.name: dto};
  final defaultEquality = <String>{};
  // DTO equality participates in omission of non-empty constructor defaults,
  // including DTOs nested in default lists/maps or other DTO values.
  void equalityTargets(WireType wire, Object? value) {
    if (value == null) return;
    switch (wire) {
      case DtoWire() when !wire.core:
        defaultEquality.add(wire.wireName);
        final dto = byName[wire.wireName];
        if (dto == null || value is! Map || value['fields'] is! Map) return;
        for (final field in dto.fields) {
          equalityTargets(field.type, (value['fields'] as Map)[field.name]);
        }
      case ListWire():
        if (value is List) {
          for (final item in value) {
            equalityTargets(wire.element, item);
          }
        }
      case MapWire():
        if (value is Map) {
          for (final item in value.values) {
            equalityTargets(wire.value, item);
          }
        }
      default:
        break;
    }
  }

  for (final (_, dto) in entries) {
    for (final field in dto.fields) {
      if (field.defaultValue != null) {
        equalityTargets(field.type, field.defaultValue!.value);
      }
    }
  }
  Object type(WireType wire) {
    final shape = <String, Object?>{'nullable': wire.nullable};
    switch (wire) {
      case ScalarWire():
        shape['kind'] = wire.dartName;
      case DoubleWire():
        shape['kind'] = 'double';
      case DateTimeWire():
        shape['kind'] = 'dateTime';
      case CalendarDayWire():
        shape['kind'] = 'calendarDay';
      case DurationWire():
        shape['kind'] = 'duration';
      case BytesWire():
        shape['kind'] = 'bytes';
      case EnumWire():
        if (wire.customNameEncoding) {
          unsupported.add('custom enum name encoding ${wire.spelling}');
        }
        shape.addAll({
          'kind': 'enum',
          'values': [...wire.values]..sort(),
          'open': wire.open,
          if (wire.deprecatedValues.isNotEmpty)
            'deprecatedValues': wire.deprecatedValues,
        });
      case DtoWire():
        shape.addAll({'kind': 'dto', 'name': wire.wireName, 'core': wire.core});
        if (!wire.core && !names.contains(wire.wireName)) {
          unsupported.add('external/custom DTO codec ${wire.wireName}');
        }
      case ListWire():
        shape.addAll({'kind': 'list', 'element': type(wire.element)});
      case MapWire():
        shape.addAll({'kind': 'map', 'value': type(wire.value)});
      case PatchWire():
        shape.addAll({'kind': 'patch', 'value': type(wire.inner)});
    }
    return shape;
  }

  Object resolved(DartType dart, LibraryNames libraryNames) {
    if (dart is VoidType) return {'kind': 'void', 'nullable': false};
    if (dart.isDartCoreNull) return {'kind': 'Null', 'nullable': true};
    if (dart.isDartCoreNum) {
      return {'kind': 'num', 'nullable': dart.getDisplayString().endsWith('?')};
    }
    try {
      return type(WireTypeReader(libraryNames).read(dart));
    } on UnsupportedType catch (error) {
      unsupported.add(
        'resolved result ${dart.getDisplayString()}: ${error.reason}',
      );
      return {'kind': 'unsupported', 'nullable': false};
    }
  }

  final objects = <String, Object?>{};
  for (final (element, dto) in entries) {
    final libraryNames = LibraryNames(element.library);
    final owners = [element, ...element.allSupertypes.map((t) => t.element)];
    for (final owner in owners) {
      if (DwFrameworkTypes.isFramework(owner) || _isGeneratedDtoMixin(owner)) {
        continue;
      }
      for (final method in owner.methods) {
        if (method.name == '==' &&
            owner.library.uri.scheme != 'dart' &&
            defaultEquality.contains(dto.name)) {
          unsupported.add(
            '${dto.name}: custom default equality (${owner.name}.==)',
          );
        }
        if (const {
          'fromJson',
          'toJson',
          'encodeResult',
          'decodeResult',
        }.contains(method.name)) {
          unsupported.add('${dto.name}: custom ${method.name}');
        }
      }
      for (final getter in owner.getters) {
        if (getter.name == 'dwTypeName') {
          unsupported.add('${dto.name}: custom wire name');
        }
      }
    }
    final shape = <String, Object?>{
      'kind': dto.kind.name,
      'deprecatedSince': ?_deprecatedSince(element),
      'fields': {
        for (final field in dto.fields)
          field.name: {
            'type': type(field.type),
            'deprecatedSince': ?_deprecatedSince(
              element.getGetter(field.name)?.variable,
            ),
            if (field.defaultValue != null)
              'default': field.defaultValue!.value,
          },
      },
    };
    if (dto.kind == DtoKind.data) {
      final identity = owners
          .map((o) => o.getGetter('id'))
          .nonNulls
          .firstOrNull;
      if (identity == null) {
        unsupported.add('${dto.name}: unresolved identity');
      } else {
        shape['identity'] = resolved(identity.returnType, libraryNames);
      }
    } else {
      final kind = element.allSupertypes
          .where(
            (t) =>
                const {
                  'DwSingleRequest',
                  'DwMaybeRequest',
                  'DwListRequest',
                  'DwPageRequest',
                  'DwTableRequest',
                  'DwWindowRequest',
                  'DwActionCommand',
                }.contains(t.element.name) &&
                DwFrameworkTypes.isFrom(
                  t.element,
                  DwFrameworkTypes.corePackage,
                ),
          )
          .firstOrNull;
      if (kind == null) {
        unsupported.add('${dto.name}: unresolved request/result kind');
      } else {
        shape['result'] = {
          'kind': kind.element.name,
          'arguments': [
            for (final argument in kind.typeArguments)
              resolved(argument, libraryNames),
          ],
        };
      }
    }
    objects[dto.name] = shape;
  }
  return {
    'format': 2,
    'codec': 1,
    'contractVersion': version,
    'objects': objects,
    'unverified': unsupported.toSet().toList()..sort(),
  };
}

String? _deprecatedSince(Element? element) {
  if (element == null) return null;
  for (final annotation in element.metadata.annotations) {
    final value = annotation.computeConstantValue();
    final type = value?.type?.element;
    if (type != null &&
        DwFrameworkTypes.isCoreClass(type, 'DwContractDeprecation')) {
      return value?.getField('since')?.toStringValue();
    }
  }
  return null;
}

// A name prefix is not provenance: project code can declare a `_$...` mixin.
// Only the exact DTO mixin in its owning generated part is generator-owned.
bool _isGeneratedDtoMixin(InterfaceElement owner) {
  final name = owner.name;
  if (owner is! MixinElement || name == null || !name.startsWith(r'_$')) {
    return false;
  }
  final dto = owner.library.getClass(name.substring(2));
  if (dto == null || DwFrameworkTypes.dtoKindOf(dto) == null) return false;
  final source = dto.firstFragment.libraryFragment.source.fullName;
  return source.endsWith('.dart') &&
      owner.firstFragment.libraryFragment.source.fullName ==
          '${source.substring(0, source.length - 5)}.dw.dart';
}

Object? canonical(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: canonical(value[key]),
  },
  List() => value.map(canonical).toList(),
  _ => value,
};

String contractJson(Map<String, Object?> descriptor) =>
    '${const JsonEncoder.withIndent('  ').convert(canonical(descriptor))}\n';

/// Reject unknown formats and shapes before making a compatibility claim.
void validateContract(Object? descriptor) {
  Never invalid(String reason) => throw FormatException(reason);
  Map<String, dynamic> object(
    Object? value,
    Set<String> keys,
    Set<String> required,
  ) {
    if (value is! Map<String, dynamic> ||
        !value.keys.toSet().containsAll(required) ||
        !keys.containsAll(value.keys)) {
      invalid('unknown/malformed descriptor object');
    }
    return value;
  }

  void type(Object? value, {bool result = false}) {
    if (value is! Map<String, dynamic> ||
        value['nullable'] is! bool ||
        value['kind'] is! String) {
      invalid('malformed wire type');
    }
    switch (value['kind']) {
      case 'int' ||
          'String' ||
          'bool' ||
          'double' ||
          'dateTime' ||
          'calendarDay' ||
          'duration' ||
          'bytes' ||
          'void' ||
          'Null' ||
          'num':
        object(value, {'kind', 'nullable'}, {'kind', 'nullable'});
        if (const {'void', 'Null', 'num'}.contains(value['kind']) && !result) {
          invalid('unsupported field codec ${value['kind']}');
        }
        if (value['kind'] == 'void' && value['nullable'] != false ||
            value['kind'] == 'Null' && value['nullable'] != true) {
          invalid('malformed result nullability');
        }
      case 'dto':
        object(
          value,
          {'kind', 'nullable', 'name', 'core'},
          {'kind', 'nullable', 'name', 'core'},
        );
        if (value['name'] is! String || value['core'] is! bool) {
          invalid('malformed DTO reference');
        }
        if (value['core'] == true &&
            DwWireProtocol.core.entryNamed(value['name'] as String) == null) {
          invalid('unsupported core DTO codec ${value['name']}');
        }
      case 'enum':
        object(
          value,
          {'kind', 'nullable', 'values', 'open', 'deprecatedValues'},
          {'kind', 'nullable', 'values', 'open'},
        );
        final values = value['values'];
        if (values is! List ||
            values.isEmpty ||
            values.any((v) => v is! String) ||
            values.toSet().length != values.length ||
            value['open'] is! bool ||
            (value['open'] == true && !values.contains('unknown'))) {
          invalid('malformed enum');
        }
        if (value['deprecatedValues'] case final Map deprecated) {
          if (deprecated.keys.any((key) => !values.contains(key)) ||
              deprecated.values.any((since) {
                try {
                  DwContractVersion.parse(since as String);
                  return false;
                } catch (_) {
                  return true;
                }
              })) {
            invalid('malformed deprecated enum values');
          }
        }
      case 'list':
        object(
          value,
          {'kind', 'nullable', 'element'},
          {'kind', 'nullable', 'element'},
        );
        type(value['element']);
        if (const {
          'list',
          'map',
          'patch',
          'bytes',
        }.contains((value['element'] as Map)['kind'])) {
          invalid('unsupported collection element');
        }
      case 'map' || 'patch':
        object(
          value,
          {'kind', 'nullable', 'value'},
          {'kind', 'nullable', 'value'},
        );
        type(value['value']);
        final inner = value['value'] as Map;
        if (value['kind'] == 'patch' &&
            (value['nullable'] != false ||
                inner['nullable'] != false ||
                const {
                  'list',
                  'map',
                  'patch',
                  'bytes',
                }.contains(inner['kind']))) {
          invalid('unsupported patch shape');
        }
        if (value['kind'] == 'map' &&
            const {'list', 'map', 'patch', 'bytes'}.contains(inner['kind'])) {
          invalid('unsupported map value');
        }
      default:
        invalid('unsupported wire type ${value['kind']}');
    }
  }

  final root = object(
    descriptor,
    {
      'format',
      'codec',
      'contractVersion',
      'objects',
      'unverified',
      'baselineCommit',
    },
    {'format', 'codec', 'contractVersion', 'objects', 'unverified'},
  );
  if (root['format'] is! int ||
      root['codec'] is! int ||
      !const {1, 2}.contains(root['format']) ||
      root['codec'] != 1) {
    invalid('unsupported descriptor/codec format');
  }
  if (root['contractVersion'] is! String) invalid('missing contract version');
  DwContractVersion.parse(root['contractVersion'] as String);
  if (root.containsKey('baselineCommit') &&
      (root['baselineCommit'] is! String ||
          (root['baselineCommit'] as String).isEmpty)) {
    invalid('malformed baseline commit');
  }
  if (root['unverified'] is! List || (root['unverified'] as List).isNotEmpty) {
    invalid('unsupported/custom codecs: ${root['unverified']}');
  }
  if (root['objects'] is! Map<String, dynamic>) invalid('malformed registry');
  final objects = root['objects'] as Map<String, dynamic>;
  void defaultValue(Object? value, Map type) {
    if (value == null) {
      if (type['nullable'] != true) invalid('invalid null default');
      return;
    }
    switch (type['kind']) {
      case 'int':
        if (value is! int) invalid('invalid integer default');
      case 'String':
        if (value is! String) invalid('invalid string default');
      case 'bool':
        if (value is! bool) invalid('invalid boolean default');
      case 'double':
        final v = object(value, {'double'}, {'double'});
        if (v['double'] is! String ||
            (!const {
                  'double.nan',
                  'double.infinity',
                  'double.negativeInfinity',
                }.contains(v['double']) &&
                double.tryParse(v['double'] as String) == null)) {
          invalid('unsupported double default');
        }
      case 'duration':
        if (object(value, {'duration'}, {'duration'})['duration'] is! int) {
          invalid('invalid duration default');
        }
      case 'enum':
        if (!(type['values'] as List).contains(
          object(value, {'enum'}, {'enum'})['enum'],
        )) {
          invalid('invalid enum default');
        }
      case 'list':
        if (value is! List) invalid('invalid list default');
        for (final item in value) {
          defaultValue(item, type['element'] as Map);
        }
      case 'map':
        if (value is! Map<String, dynamic>) invalid('invalid map default');
        for (final item in value.values) {
          defaultValue(item, type['value'] as Map);
        }
      case 'dto':
        final v = object(value, {'dto', 'fields'}, {'dto', 'fields'});
        if (v['dto'] != type['name'] ||
            type['core'] == true ||
            objects[type['name']] is! Map ||
            v['fields'] is! Map<String, dynamic>) {
          invalid('unsupported DTO default');
        }
        final fields = (objects[type['name']] as Map)['fields'];
        if (fields is! Map ||
            !(v['fields'] as Map).keys.toSet().containsAll(fields.keys) ||
            !fields.keys.toSet().containsAll((v['fields'] as Map).keys)) {
          invalid('malformed DTO default fields');
        }
        for (final entry in (v['fields'] as Map).entries) {
          defaultValue(entry.value, fields[entry.key]['type'] as Map);
        }
      default:
        invalid('unsupported default codec ${type['kind']}');
    }
  }

  for (final entry in objects.entries) {
    final shape = object(
      entry.value,
      {
        'kind',
        'fields',
        'identity',
        'result',
        'deprecatedSince',
        if (root['format'] == 2) 'since',
      },
      {'kind', 'fields'},
    );
    if (!const {'data', 'request', 'command'}.contains(shape['kind']) ||
        shape['fields'] is! Map<String, dynamic>) {
      invalid('unsupported DTO kind/fields');
    }
    for (final fieldEntry
        in (shape['fields'] as Map<String, dynamic>).entries) {
      final f = object(
        fieldEntry.value,
        {'type', 'default', 'deprecatedSince'},
        {'type'},
      );
      type(f['type']);
      if (f.containsKey('deprecatedSince')) {
        final since = DwContractVersion.parse(f['deprecatedSince'] as String);
        if (DwContractVersion.parse(root['contractVersion'] as String) <
            since) {
          invalid('field deprecation version exceeds contract version');
        }
        if ((f['type'] as Map)['nullable'] != true &&
            !f.containsKey('default')) {
          invalid(
            '${entry.key}.${fieldEntry.key}: deprecated field requires a nullable type or a default so its codec can decode a payload without the field',
          );
        }
      }
    }
    if (shape.containsKey('since')) {
      if (shape['kind'] != 'data' || shape['since'] is! String) {
        invalid('malformed data introduction version');
      }
      final since = DwContractVersion.parse(shape['since'] as String);
      if (DwContractVersion.parse(root['contractVersion'] as String) < since) {
        invalid('data introduction version exceeds contract version');
      }
    }
    if (shape.containsKey('deprecatedSince')) {
      final since = DwContractVersion.parse(shape['deprecatedSince'] as String);
      if (DwContractVersion.parse(root['contractVersion'] as String) < since) {
        invalid('object deprecation version exceeds contract version');
      }
    }
    if (shape['kind'] == 'data') {
      if (shape.containsKey('result') || !shape.containsKey('identity')) {
        invalid('malformed data shape');
      }
      type(shape['identity']);
      final identity = shape['identity'] as Map;
      if (!const {'int', 'String'}.contains(identity['kind']) ||
          identity['nullable'] != false) {
        invalid('unsupported data identity');
      }
    } else {
      if (shape.containsKey('identity')) invalid('malformed call shape');
      final result = object(
        shape['result'],
        {'kind', 'arguments'},
        {'kind', 'arguments'},
      );
      final kind = result['kind'];
      final arguments = result['arguments'];
      if (!const {
            'DwSingleRequest',
            'DwMaybeRequest',
            'DwListRequest',
            'DwPageRequest',
            'DwTableRequest',
            'DwWindowRequest',
            'DwActionCommand',
          }.contains(kind) ||
          arguments is! List ||
          arguments.length != (kind == 'DwWindowRequest' ? 3 : 1) ||
          (shape['kind'] == 'command') != (kind == 'DwActionCommand')) {
        invalid('unsupported resolved result');
      }
      for (final argument in arguments) {
        type(argument, result: kind == 'DwActionCommand');
      }
      if (kind != 'DwActionCommand' &&
          ((arguments.first as Map)['kind'] != 'dto' ||
              (arguments.first as Map)['nullable'] != false)) {
        invalid('unsupported request data result');
      }
      if (kind != 'DwActionCommand') {
        final data = arguments.first as Map;
        if (data['core'] == true
            ? DwWireProtocol.core.entryNamed(data['name'] as String)!.kind !=
                  DwWireObjectKind.dataObject
            : objects[data['name']] is! Map ||
                  (objects[data['name']] as Map)['kind'] != 'data') {
          invalid('unverified request data-object result');
        }
      }
      if (kind == 'DwActionCommand' &&
          !const {
            'void',
            'Null',
            'int',
            'double',
            'num',
            'String',
            'bool',
            'dto',
          }.contains((arguments.single as Map)['kind'])) {
        invalid('unsupported command result');
      }
    }
  }
  for (final shape in objects.values.cast<Map<String, dynamic>>()) {
    for (final field
        in (shape['fields'] as Map<String, dynamic>).values
            .cast<Map<String, dynamic>>()) {
      if (field.containsKey('default')) {
        if (field['default'] == null) {
          invalid('unsupported explicit null default descriptor');
        }
        defaultValue(field['default'], field['type'] as Map);
      }
    }
  }
  void references(Object? value) {
    if (value is Map) {
      if (value['kind'] == 'dto' &&
          value['core'] == false &&
          !objects.containsKey(value['name'])) {
        invalid('unverified external DTO ${value['name']}');
      }
      for (final item in value.values) {
        references(item);
      }
    } else if (value is List) {
      for (final item in value) {
        references(item);
      }
    }
  }

  references(objects);

  void validateEnumMarks(Object? value) {
    if (value is Map) {
      if (value['deprecatedValues'] case final Map marks) {
        final current = DwContractVersion.parse(
          root['contractVersion'] as String,
        );
        for (final since in marks.values) {
          if (current < DwContractVersion.parse(since as String)) {
            invalid('enum-value deprecation version exceeds contract version');
          }
        }
      }
      for (final child in value.values) {
        validateEnumMarks(child);
      }
    } else if (value is List) {
      for (final child in value) {
        validateEnumMarks(child);
      }
    }
  }

  validateEnumMarks(objects);
}

/// Conservative bidirectional codec compatibility. Domain semantics are out
/// of scope; even an optional removal discards installed-client input.
List<String> compareContracts(
  Map<String, dynamic> old,
  Map<String, dynamic> current, {
  required Map<String, dynamic>? removalBaseline,
  required String comparison,
}) {
  final changes = <String>[];
  final removalMarks = removalBaseline == null
      ? const <String>{}
      : _deprecationMarks(removalBaseline);
  bool equal(Object? a, Object? b) =>
      jsonEncode(canonical(a)) == jsonEncode(canonical(b));
  bool compatibleType(String path, Map a, Map b) {
    if (a['kind'] != b['kind'] || a['nullable'] != b['nullable']) return false;
    if (a['kind'] == 'enum') {
      final previous = (a['values'] as List).toSet();
      final next = (b['values'] as List).toSet();
      final retired = previous
          .where((value) => removalMarks.contains('$path.$value'))
          .toSet();
      final openedForMigration =
          removalBaseline != null &&
          a['open'] == false &&
          b['open'] == true &&
          next.difference(previous).every((value) => value == 'unknown');
      if (a['open'] == true && b['open'] != true) return false;
      if (!openedForMigration && a['open'] != b['open']) return false;
      return next.containsAll(previous.difference(retired)) &&
          (a['open'] == true ||
              openedForMigration ||
              previous.containsAll(next));
    }
    if (a['kind'] == 'list') {
      return compatibleType(path, a['element'] as Map, b['element'] as Map);
    }
    if (a['kind'] == 'map' || a['kind'] == 'patch') {
      return compatibleType(path, a['value'] as Map, b['value'] as Map);
    }
    return equal(a, b);
  }

  final before = old['objects'] as Map<String, dynamic>;
  final after = current['objects'] as Map<String, dynamic>;
  for (final entry in before.entries) {
    final name = entry.key;
    final a = entry.value as Map;
    final b = after[name];
    if (b is! Map) {
      if (!removalMarks.contains(name)) {
        changes.add(
          '$comparison: $name wire name removed/renamed without @DwContractDeprecation in the store baseline',
        );
      }
      continue;
    }
    if (a['kind'] != b['kind'] || !equal(a['identity'], b['identity'])) {
      changes.add('$name: kind/identity changed');
    }
    if (!equal(a['result'], b['result'])) {
      final ar = a['result'];
      final br = b['result'];
      if (ar is! Map ||
          br is! Map ||
          ar['kind'] != br['kind'] ||
          !(ar['arguments'] as List).indexed.every(
            (pair) => compatibleType(
              '$name.result.${pair.$1}',
              pair.$2 as Map,
              (br['arguments'] as List)[pair.$1] as Map,
            ),
          )) {
        changes.add('$name: request/result codec changed');
      }
    }
    final af = a['fields'] as Map;
    final bf = b['fields'] as Map;
    for (final field in af.keys) {
      if (!bf.containsKey(field)) {
        if (!removalMarks.contains('$name.$field')) {
          changes.add(
            '$comparison: $name.$field field removed/renamed without @DwContractDeprecation in the store baseline',
          );
        }
        continue;
      }
      final oldField = af[field] as Map;
      final newField = bf[field] as Map;
      final addsSurvivalDefault =
          oldField['deprecatedSince'] == null &&
          newField['deprecatedSince'] != null &&
          !oldField.containsKey('default') &&
          newField.containsKey('default') &&
          (oldField['type'] as Map)['nullable'] == false;
      if (!compatibleType(
            '$name.$field',
            oldField['type'] as Map,
            newField['type'] as Map,
          ) ||
          (!addsSurvivalDefault &&
              (!equal(oldField['default'], newField['default']) ||
                  oldField.containsKey('default') !=
                      newField.containsKey('default')))) {
        changes.add('$name.$field: type/nullability/patch/default changed');
      }
    }
    for (final field in bf.keys.where((f) => !af.containsKey(f))) {
      final f = bf[field] as Map;
      final t = f['type'] as Map;
      if (t['nullable'] != true &&
          t['kind'] != 'patch' &&
          !f.containsKey('default')) {
        changes.add(
          '$comparison: $name.$field required field added; old builds ignore extra keys, but the new codec must still decode the old payload, so make the field nullable or give it a default',
        );
      }
    }
  }
  for (final name in after.keys.where((n) => !before.containsKey(n))) {
    if (after[name]['kind'] == 'data' &&
        !(DwContractVersion.parse(old['contractVersion'] as String) <
            DwContractVersion.parse(current['contractVersion'] as String))) {
      changes.add(
        'raise `version:` above ${old['contractVersion']}: $name is new, and clients at ${old['contractVersion']} must not be sent it',
      );
    }
  }
  return changes..sort();
}

Set<String> _deprecationMarks(Map<String, dynamic> descriptor) {
  final marks = <String>{};
  void type(String path, Map value) {
    if (value['deprecatedValues'] case final Map deprecated) {
      marks.addAll(deprecated.keys.map((name) => '$path.$name'));
    }
    if (value['kind'] == 'list' && value['element'] is Map) {
      type(path, value['element'] as Map);
    } else if ((value['kind'] == 'map' || value['kind'] == 'patch') &&
        value['value'] is Map) {
      type(path, value['value'] as Map);
    }
  }

  final objects = descriptor['objects'] as Map;
  for (final entry in objects.entries) {
    final object = entry.value as Map;
    if (object['deprecatedSince'] != null) marks.add(entry.key as String);
    for (final field in (object['fields'] as Map).entries) {
      final path = '${entry.key}.${field.key}';
      final value = field.value as Map;
      if (value['deprecatedSince'] != null) marks.add(path);
      type(path, value['type'] as Map);
    }
    if (object['result'] case final Map result) {
      for (final argument in (result['arguments'] as List).indexed) {
        type('${entry.key}.result.${argument.$1}', argument.$2 as Map);
      }
    }
  }
  return marks;
}

/// Members whose retirement mark has reached the store baseline but which
/// still remain in source. Release CI requires the promised cleanup.
List<String> staleDeprecations(
  Map<String, dynamic> baseline,
  Map<String, dynamic> current,
) {
  final baselineMarks = _deprecationMarks(baseline);
  final currentMembers = _contractMembers(current);
  return baselineMarks.where(currentMembers.contains).toList()..sort();
}

Set<String> _contractMembers(Map<String, dynamic> descriptor) {
  final members = <String>{};
  void type(String path, Map value) {
    if (value['kind'] == 'enum') {
      members.addAll((value['values'] as List).map((name) => '$path.$name'));
    }
    if (value['kind'] == 'list' && value['element'] is Map) {
      type(path, value['element'] as Map);
    } else if ((value['kind'] == 'map' || value['kind'] == 'patch') &&
        value['value'] is Map) {
      type(path, value['value'] as Map);
    }
  }

  for (final entry in (descriptor['objects'] as Map).entries) {
    members.add(entry.key as String);
    final object = entry.value as Map;
    for (final field in (object['fields'] as Map).entries) {
      final path = '${entry.key}.${field.key}';
      members.add(path);
      type(path, (field.value as Map)['type'] as Map);
    }
    if (object['result'] case final Map result) {
      for (final argument in (result['arguments'] as List).indexed) {
        type('${entry.key}.result.${argument.$1}', argument.$2 as Map);
      }
    }
  }
  return members;
}

/// Introduction metadata comes only from the trusted descriptor. An object
/// absent there is introduced by this version; legacy objects keep no since.
Map<String, String> contractIntroductions(
  Map<String, dynamic> base,
  Map<String, dynamic> current,
) {
  final before = base['objects'] as Map;
  final after = current['objects'] as Map;
  return {
    for (final name in after.keys)
      if (after[name]['kind'] == 'data')
        if (!before.containsKey(name))
          name as String: current['contractVersion'] as String
        else if (before[name]['since'] case final String since)
          name as String: since,
  };
}

/// The shared package version that settles [changes] against a baseline at
/// [previous] (D-158): a new breaking line for any incompatible change, else
/// the next compatible version — a minor above 1.0, a patch on a `0.x` line,
/// where the minor is the line.
String contractRaiseOf(String previous, List<String> changes) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(previous);
  if (match == null) throw FormatException('not a semantic version', previous);
  final [major, minor, patch] = [
    for (final group in [1, 2, 3]) int.parse(match[group]!),
  ];
  final breaking = changes.any(
    (change) => !change.startsWith('raise `version:`'),
  );
  if (major > 0) {
    return breaking ? '${major + 1}.0.0' : '$major.${minor + 1}.0';
  }
  return breaking ? '0.${minor + 1}.0' : '0.$minor.${patch + 1}';
}
