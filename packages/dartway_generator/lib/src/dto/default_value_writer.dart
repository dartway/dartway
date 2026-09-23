import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../analysis/fields.dart';
import '../analysis/framework.dart';
import '../analysis/library_names.dart';
import '../diagnostic.dart';
import 'dto_model.dart';

/// Why a constructor default cannot be written back as source, in words for
/// the author.
final class UnsupportedDefault implements Exception {
  const UnsupportedDefault(this.reason);

  final String reason;
}

/// Writes the evaluated constructor default of a DTO field back as a Dart
/// expression the generated part can use (D-041).
///
/// The default is rebuilt from its *value*, not copied from its source text:
/// the text may name a static of the class, a constant of another library
/// through a name the part cannot see, or a parameter-scope identifier, while
/// the value is always a tree of literals, enum constants and constructor
/// calls. Equality of DTOs is by value, so an equal value is the same default.
final class DefaultValueWriter {
  DefaultValueWriter(this.names);

  final LibraryNames names;

  /// The default of a field whose constructor parameter declares one, or
  /// `null` when the default is `null` (an absent nullable field is already
  /// `null`). Throws [UnsupportedDefault].
  DtoDefault? write(DartObject value) {
    if (value.isNull) return null;
    final list = value.toListValue();
    final map = value.toMapValue();
    return DtoDefault(
      _write(value).standalone,
      isEmptyCollection:
          (list != null && list.isEmpty) || (map != null && map.isEmpty),
    );
  }

  _Source _write(DartObject value) {
    if (value.isNull) return const _Source.literal('null');
    final type = value.type;
    if (type is! InterfaceType) {
      throw UnsupportedDefault(
        '`${type?.getDisplayString() ?? value}` is not a value a field can hold',
      );
    }
    if (type.isDartCoreBool) {
      return _Source.literal('${value.toBoolValue()}');
    }
    if (type.isDartCoreInt) return _Source.literal('${value.toIntValue()}');
    if (type.isDartCoreDouble) return _Source.literal(_double(value));
    if (type.isDartCoreString) {
      return _Source.literal(_string(value.toStringValue()!));
    }
    final element = type.element;
    if (element is EnumElement) {
      final spelled = _visible(element);
      final constant = _field(value, '_name')?.toStringValue();
      if (constant == null) {
        throw UnsupportedDefault('`$spelled` constant could not be read');
      }
      return _Source.literal('$spelled.$constant');
    }
    if (element.name == 'Duration' &&
        element.library.uri.toString() == 'dart:core') {
      // The field holding the length is private to the SDK and has moved:
      // `_duration` up to Dart 3.12, `inMicroseconds` from 3.13.
      final microseconds =
          (_field(value, 'inMicroseconds') ?? _field(value, '_duration'))
              ?.toIntValue();
      if (microseconds == null) {
        throw const UnsupportedDefault('the Duration could not be read');
      }
      return _Source.call('Duration(microseconds: $microseconds)');
    }
    if (type.isDartCoreList) {
      final elementType = _spell(type.typeArguments.single);
      return _Source.collection('<$elementType>', '[', [
        for (final item in value.toListValue()!) _write(item),
      ], ']');
    }
    if (type.isDartCoreMap) {
      final arguments = type.typeArguments.map(_spell).join(', ');
      final entries = [
        for (final MapEntry(:key, value: item) in value.toMapValue()!.entries)
          _Entry('${_write(key!).inConst}: ', _write(item!)),
      ];
      return _Source.entries('<$arguments>', '{', entries, '}');
    }
    if (element is ClassElement &&
        DwFrameworkTypes.dtoKindOf(element) != null) {
      return _dto(element, value);
    }
    throw UnsupportedDefault(
      '`${type.getDisplayString()}` has no constant form on the wire',
    );
  }

  _Source _dto(ClassElement element, DartObject value) {
    final spelled = _visible(element);
    if (DwFrameworkTypes.isFramework(element)) {
      throw UnsupportedDefault(
        '`$spelled` is a framework DTO, whose fields the generator does not '
        'read',
      );
    }
    final fields = readConstructorFields(element, <DwGenerationDiagnostic>[]);
    if (fields == null) {
      throw UnsupportedDefault('`$spelled` cannot be rebuilt from its fields');
    }
    final arguments = <_Entry>[];
    for (final field in fields) {
      final fieldValue =
          _field(value, field.name) ??
          (throw UnsupportedDefault(
            'field `${field.name}` of the `$spelled` default could not be read',
          ));
      // An argument equal to what its parameter defaults to is left out.
      final parameter = field.parameter;
      if (!parameter.isRequired &&
          (parameter.hasDefaultValue
              ? parameter.computeConstantValue() == fieldValue
              : fieldValue.isNull)) {
        continue;
      }
      arguments.add(_Entry('${field.name}: ', _write(fieldValue)));
    }
    return _Source.entries(
      '',
      '$spelled(',
      arguments,
      ')',
      canBeConst: element.unnamedConstructor?.isConst ?? false,
    );
  }

  String _visible(InterfaceElement element) =>
      names.nameOf(element) ??
      (throw UnsupportedDefault(
        '`${element.name}` is not imported by this library',
      ));

  String _spell(DartType type) =>
      names.spell(type) ??
      (throw UnsupportedDefault(
        '`${type.getDisplayString()}` is not imported by this library',
      ));

  /// A field of a constant object, looked up through its superclasses.
  static DartObject? _field(DartObject object, String name) {
    for (DartObject? current = object; current != null;) {
      final field = current.getField(name);
      if (field != null) return field;
      current = current.getField('(super)');
    }
    return null;
  }

  static String _double(DartObject value) {
    final number = value.toDoubleValue()!;
    if (number.isNaN) return 'double.nan';
    if (number == double.infinity) return 'double.infinity';
    if (number == double.negativeInfinity) return 'double.negativeInfinity';
    final text = number.toString();
    return text.contains('.') || text.contains('e') ? text : '$text.0';
  }

  /// A single-quoted literal that reads back as exactly [value].
  static String _string(String value) {
    final out = StringBuffer("'");
    for (final rune in value.runes) {
      switch (rune) {
        case 0x5C:
          out.write(r'\\');
        case 0x27:
          out.write(r"\'");
        case 0x24:
          out.write(r'\$');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        case < 0x20 || 0x7F:
          out.write('\\u{${rune.toRadixString(16)}}');
        default:
          out.writeCharCode(rune);
      }
    }
    out.write("'");
    return out.toString();
  }
}

/// A written expression and whether it is constant.
final class _Source {
  const _Source.literal(this.bare) : constant = true, needsConst = false;

  const _Source.call(this.bare) : constant = true, needsConst = true;

  const _Source._(
    this.bare, {
    required this.constant,
    required this.needsConst,
  });

  factory _Source.collection(
    String typeArguments,
    String open,
    List<_Source> items,
    String close,
  ) => _Source.entries(typeArguments, open, [
    for (final item in items) _Entry('', item),
  ], close);

  factory _Source.entries(
    String typeArguments,
    String open,
    List<_Entry> entries,
    String close, {
    bool canBeConst = true,
  }) {
    final constant = canBeConst && entries.every((e) => e.value.constant);
    final written = [
      for (final entry in entries)
        '${entry.prefix}'
            '${constant ? entry.value.inConst : entry.value.standalone}',
    ];
    return _Source._(
      '$typeArguments$open${written.join(', ')}$close',
      constant: constant,
      needsConst: constant,
    );
  }

  /// The expression without a `const` keyword.
  final String bare;
  final bool constant;

  /// Whether the expression is a collection literal or a constructor call,
  /// which is constant only under a `const` keyword.
  final bool needsConst;

  /// Inside a constant context, where `const` is implied.
  String get inConst => bare;

  /// Anywhere else.
  String get standalone => needsConst ? 'const $bare' : bare;
}

final class _Entry {
  const _Entry(this.prefix, this.value);

  final String prefix;
  final _Source value;
}
