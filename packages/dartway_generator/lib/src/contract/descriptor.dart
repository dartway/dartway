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
      'fields': {
        for (final field in dto.fields)
          field.name: {
            'type': type(field.type),
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
    'format': 1,
    'codec': 1,
    'contractVersion': version,
    'objects': objects,
    'unverified': unsupported.toSet().toList()..sort(),
  };
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
          {'kind', 'nullable', 'values', 'open'},
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
    {'format', 'codec', 'contractVersion', 'objects', 'unverified'},
    {'format', 'codec', 'contractVersion', 'objects', 'unverified'},
  );
  if (root['format'] is! int ||
      root['codec'] is! int ||
      root['format'] != 1 ||
      root['codec'] != 1) {
    invalid('unsupported descriptor/codec format');
  }
  if (root['contractVersion'] is! String) invalid('missing contract version');
  DwContractVersion.parse(root['contractVersion'] as String);
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
      {'kind', 'fields', 'identity', 'result'},
      {'kind', 'fields'},
    );
    if (!const {'data', 'request', 'command'}.contains(shape['kind']) ||
        shape['fields'] is! Map<String, dynamic>) {
      invalid('unsupported DTO kind/fields');
    }
    for (final field in (shape['fields'] as Map<String, dynamic>).values) {
      final f = object(field, {'type', 'default'}, {'type'});
      type(f['type']);
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
}

/// Conservative bidirectional codec compatibility. Domain semantics are out
/// of scope; even an optional removal discards installed-client input.
List<String> compareContracts(
  Map<String, dynamic> old,
  Map<String, dynamic> current,
) {
  final changes = <String>[];
  bool equal(Object? a, Object? b) =>
      jsonEncode(canonical(a)) == jsonEncode(canonical(b));
  bool compatibleType(Map a, Map b) {
    if (a['kind'] != b['kind'] || a['nullable'] != b['nullable']) return false;
    if (a['kind'] == 'enum') {
      final previous = (a['values'] as List).toSet();
      final next = (b['values'] as List).toSet();
      return a['open'] == b['open'] &&
          next.containsAll(previous) &&
          (a['open'] == true || previous.containsAll(next));
    }
    if (a['kind'] == 'list') {
      return compatibleType(a['element'] as Map, b['element'] as Map);
    }
    if (a['kind'] == 'map' || a['kind'] == 'patch') {
      return compatibleType(a['value'] as Map, b['value'] as Map);
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
      changes.add('$name: wire name removed/renamed');
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
        changes.add('$name.$field: field removed/renamed');
        continue;
      }
      if (!compatibleType(af[field]['type'] as Map, bf[field]['type'] as Map) ||
          !equal(af[field]['default'], bf[field]['default']) ||
          (af[field] as Map).containsKey('default') !=
              (bf[field] as Map).containsKey('default')) {
        changes.add('$name.$field: type/nullability/patch/default changed');
      }
    }
    for (final field in bf.keys.where((f) => !af.containsKey(f))) {
      final f = bf[field] as Map;
      final t = f['type'] as Map;
      if (t['nullable'] != true &&
          t['kind'] != 'patch' &&
          !f.containsKey('default')) {
        changes.add('$name.$field: required field added');
      }
    }
  }
  for (final name in after.keys.where((n) => !before.containsKey(n))) {
    if (after[name]['kind'] == 'data') {
      changes.add(
        '$name: new data-object update group is unknown to installed clients',
      );
    }
  }
  return changes..sort();
}
