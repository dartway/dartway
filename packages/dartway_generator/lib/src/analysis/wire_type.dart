import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'framework.dart';
import 'library_names.dart';

/// The serialisable shape of a field type: what the generator needs to encode,
/// decode, compare and hash it. One classification feeds every emitter, so a
/// type is either supported everywhere or rejected with one message.
sealed class WireType {
  const WireType({required this.nullable});

  final bool nullable;

  /// Whether the Dart value is already its JSON value, which lets the encoder
  /// pass it through untouched. (Decoding may still convert.)
  bool get isIdentity => false;
}

/// `int`, `String`, `bool`.
final class ScalarWire extends WireType {
  const ScalarWire(this.dartName, {required super.nullable});

  final String dartName;

  @override
  bool get isIdentity => true;
}

final class DoubleWire extends WireType {
  const DoubleWire({required super.nullable});

  /// A double encodes as itself; only decoding converts, through
  /// `DwJsonCodec.decodeDouble`, because a whole number arrives as `int`.
  @override
  bool get isIdentity => true;
}

final class DateTimeWire extends WireType {
  const DateTimeWire({required super.nullable});
}

final class DurationWire extends WireType {
  const DurationWire({required super.nullable});
}

final class BytesWire extends WireType {
  const BytesWire({required super.nullable});
}

final class EnumWire extends WireType {
  const EnumWire(this.spelling, {required super.nullable});

  final String spelling;
}

final class DtoWire extends WireType {
  const DtoWire(this.decoder, {required super.nullable});

  /// `$NameFromJson` or `Name.fromJson`, spelled for the owning library.
  final String decoder;
}

final class ListWire extends WireType {
  const ListWire(this.element, {required super.nullable});

  final WireType element;

  @override
  bool get isIdentity => element.isIdentity;
}

final class MapWire extends WireType {
  const MapWire(this.value, {required super.nullable});

  final WireType value;

  @override
  bool get isIdentity => value.isIdentity;
}

final class PatchWire extends WireType {
  const PatchWire(this.inner) : super(nullable: false);

  final WireType inner;
}

/// Why a type cannot be serialised, in words for the author.
final class UnsupportedType implements Exception {
  const UnsupportedType(this.reason);

  final String reason;
}

/// Classifies field types as seen from one library.
final class WireTypeReader {
  WireTypeReader(this.names, {this.forEntity = false});

  final LibraryNames names;

  /// Reads column types (`docs/4-server/database.md`) instead of DTO field types.
  final bool forEntity;

  String get supportedList => forEntity
      ? 'int, double, String, bool, DateTime, Duration, Uint8List, an enum, '
            'List<T> or Map<String, T> of int, double, String or bool (jsonb), '
            'List<E> of an enum (jsonb of names), or a nullable one of these'
      : 'int, double, String, bool, DateTime, Duration, Uint8List, an enum, '
            'a DTO class, List<T>, Map<String, T>, DwFieldPatch<T>, or a nullable '
            'one of these';

  /// Throws [UnsupportedType] with the reason when [type] is not supported.
  WireType read(DartType type) {
    final wire = _read(type, _Position.field);
    if (forEntity) _checkColumn(wire, type);
    return wire;
  }

  void _checkColumn(WireType wire, DartType type) {
    final display = type.getDisplayString();
    switch (wire) {
      case DtoWire():
        throw UnsupportedType(
          '`$display` is a DTO, which is not stored; store its fields as '
          'columns (or ids of other rows) and map it in the handler',
        );
      case PatchWire():
        throw UnsupportedType(
          '`$display` is a command input, not a stored value',
        );
      // A list of an enum is stored as its names (DwEnumListType).
      case ListWire(element: EnumWire(nullable: false)):
        return;
      case ListWire(element: final inner) || MapWire(value: final inner)
          when inner is! ScalarWire && inner is! DoubleWire:
        throw UnsupportedType(
          '`$display` is stored as jsonb, whose elements are read back as '
          'plain JSON: they must be int, double, String or bool — or, in a '
          'list, a non-null enum',
        );
      default:
        return;
    }
  }

  WireType _read(DartType type, _Position position) {
    final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    if (type is InvalidType) {
      throw const UnsupportedType(
        'its type does not resolve; fix the analyzer errors in this file first',
      );
    }
    if (type is! InterfaceType) {
      throw UnsupportedType(
        '`${type.getDisplayString()}` cannot be ${forEntity ? 'stored' : 'serialised'}; supported: '
        '$supportedList',
      );
    }
    final element = type.element;
    final display = type.getDisplayString();

    if (type.isDartCoreInt) return ScalarWire('int', nullable: nullable);
    if (type.isDartCoreString) return ScalarWire('String', nullable: nullable);
    if (type.isDartCoreBool) return ScalarWire('bool', nullable: nullable);
    if (type.isDartCoreDouble) return DoubleWire(nullable: nullable);
    if (_isSdk(element, 'dart:core', 'DateTime')) {
      return DateTimeWire(nullable: nullable);
    }
    if (_isSdk(element, 'dart:core', 'Duration')) {
      return DurationWire(nullable: nullable);
    }
    if (_isSdk(element, 'dart:typed_data', 'Uint8List')) {
      if (position != _Position.field) {
        throw UnsupportedType(
          '`$display` cannot be ${position.description}: equality would '
          'compare the bytes by identity',
        );
      }
      _requireVisible(type);
      return BytesWire(nullable: nullable);
    }
    if (element is EnumElement) {
      final open = element.mixins.any(
        (mixin) => DwFrameworkTypes.isCoreClass(mixin.element, 'DwOpenEnum'),
      );
      if (open &&
          !element.fields.any(
            (field) => field.isEnumConstant && field.name == 'unknown',
          )) {
        throw UnsupportedType(
          '`$display` is a DwOpenEnum and declares no value `unknown` to read '
          'the names of a newer build as',
        );
      }
      return EnumWire(_requireVisible(type), nullable: nullable);
    }
    if (type.isDartCoreList || type.isDartCoreMap) {
      if (position != _Position.field) {
        throw UnsupportedType(
          '`$display` cannot be ${position.description}: equality would '
          'compare the inner collection by identity',
        );
      }
      if (type.isDartCoreList) {
        return ListWire(
          _read(type.typeArguments.single, _Position.collectionElement),
          nullable: nullable,
        );
      }
      final key = type.typeArguments.first;
      if (!key.isDartCoreString ||
          key.nullabilitySuffix == NullabilitySuffix.question) {
        throw UnsupportedType(
          '`$display` has keys of type `${key.getDisplayString()}`; JSON '
          'object keys are strings, so a map must be Map<String, T>',
        );
      }
      return MapWire(
        _read(type.typeArguments.last, _Position.collectionElement),
        nullable: nullable,
      );
    }
    if (DwFrameworkTypes.isPatch(type)) {
      if (position != _Position.field) {
        throw UnsupportedType(
          '`$display` cannot be ${position.description}: a patch is a whole '
          'field',
        );
      }
      if (nullable) {
        throw UnsupportedType(
          '`$display` cannot be nullable: an absent patch is already '
          '`DwFieldPatch.keep()`',
        );
      }
      final inner = type.typeArguments.single;
      if (inner.nullabilitySuffix == NullabilitySuffix.question) {
        throw UnsupportedType(
          '`$display` patches a nullable type; clearing is `DwFieldPatch.clear()`, '
          'so write `DwFieldPatch<${inner.getDisplayString().replaceAll('?', '')}>`',
        );
      }
      return PatchWire(_read(inner, _Position.patchValue));
    }
    if (element is ClassElement &&
        DwFrameworkTypes.dtoKindOf(element) != null) {
      if (element.isAbstract || element.isSealed) {
        throw UnsupportedType(
          '`$display` is abstract; a field must name a concrete DTO class '
          'so it can be decoded',
        );
      }
      if (element.typeParameters.isNotEmpty) {
        throw UnsupportedType(
          '`$display` is generic, and generic DTO classes are not supported',
        );
      }
      _requireVisible(type);
      final decoder = names.decoderOf(element);
      if (decoder == null) {
        throw UnsupportedType(
          '`\$${element.name}FromJson` is not visible in this library: the '
          'import that brings in `${element.name}` hides it — add it to the '
          '`show` list',
        );
      }
      return DtoWire(decoder, nullable: nullable);
    }
    throw UnsupportedType(
      '`$display` cannot be ${forEntity ? 'stored' : 'serialised'}; supported: '
      '$supportedList',
    );
  }

  String _requireVisible(InterfaceType type) {
    final spelled = names.nameOf(type.element);
    if (spelled == null) {
      throw UnsupportedType(
        '`${type.element.name}` is not imported by this library, and the '
        'generated part can only use the library\'s imports',
      );
    }
    return spelled;
  }

  static bool _isSdk(InterfaceElement element, String library, String name) =>
      element.name == name && element.library.uri.toString() == library;
}

enum _Position {
  field(''),
  collectionElement('a list element or map value'),
  patchValue('the value of a DwFieldPatch');

  const _Position(this.description);

  final String description;
}
