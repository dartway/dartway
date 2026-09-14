import '../analysis/framework.dart';
import '../analysis/wire_type.dart';
import '../emit/value_class_writer.dart';

/// A serialised field of a DTO.
final class DtoField implements ValueField {
  const DtoField({
    required this.name,
    required this.type,
    required this.spelling,
    this.defaultValue,
  });

  @override
  final String name;
  @override
  final WireType type;
  @override
  final String spelling;

  /// The non-null constructor default (D-041): an absent field decodes to it,
  /// and a value equal to it is left off the wire. `null` for a field without
  /// one and for a patch, whose absence is already `DwFieldPatch.keep()`.
  final DtoDefault? defaultValue;
}

/// A constructor default, written as a Dart expression.
final class DtoDefault {
  const DtoDefault(this.expression, {required this.isEmptyCollection});

  /// Constant wherever the value can be (`const <int>[1, 2]`, `Color.red`).
  final String expression;

  /// `const []` or `const {}`: emptiness is tested without the literal.
  final bool isEmptyCollection;
}

/// A DTO class the generator writes a mixin, a decoder and (for data objects)
/// a `copyWith` for.
final class DtoClass {
  const DtoClass({
    required this.name,
    required this.kind,
    required this.superclass,
    required this.fields,
    required this.constConstructor,
  });

  final String name;
  final DtoKind kind;

  /// The `extends` clause as written, which the mixin is declared `on`.
  final String superclass;
  final List<DtoField> fields;
  final bool constConstructor;
}
