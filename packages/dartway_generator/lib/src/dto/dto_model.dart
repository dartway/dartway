import '../analysis/framework.dart';
import '../analysis/wire_type.dart';
import '../emit/value_class_writer.dart';

/// A serialised field of a DTO.
final class DtoField implements ValueField {
  const DtoField({
    required this.name,
    required this.type,
    required this.spelling,
    required this.omitWhenEmpty,
  });

  @override
  final String name;
  @override
  final WireType type;
  @override
  final String spelling;

  /// A collection whose constructor default is empty: an empty value is left
  /// off the wire, because the decoder restores the same default.
  final bool omitWhenEmpty;
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
