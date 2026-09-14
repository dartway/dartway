import '../analysis/wire_type.dart';
import 'source_text.dart';

/// A field of a generated value class (a DTO or an entity).
abstract interface class ValueField {
  String get name;
  WireType get type;

  /// The Dart type as the owning library spells it, nullability included.
  String get spelling;
}

/// Writes the members DTOs and entities share: `_self`, `==`, `hashCode`,
/// `toString` and `copyWith`. One writer, so a DTO and an entity with the same
/// fields compare, hash and copy the same way.
abstract final class ValueClassWriter {
  /// `Name get _self => this as Name;`, or nothing when no member reads it
  /// (an unused private member is an analyzer warning in the project).
  static String? self(String className, List<ValueField> fields) =>
      fields.isEmpty ? null : '$className get _self => this as $className;';

  static String equalsMember(String className, List<ValueField> fields) {
    final comparisons = [
      'other is $className',
      for (final field in fields)
        switch (field.type) {
          ListWire() || BytesWire() =>
            'dwListEquals(other.${field.name}, _self.${field.name})',
          MapWire() => 'dwMapEquals(other.${field.name}, _self.${field.name})',
          _ => 'other.${field.name} == _self.${field.name}',
        },
    ];
    return '@override\nbool operator ==(Object other) =>\n'
        'identical(this, other) || ${comparisons.join(' && ')};';
  }

  /// [seedWithType] mixes the class into the hash: requests and commands key
  /// caches shared across classes, where two classes with equal fields (or
  /// none) must not collide. A data object or an entity is only compared with
  /// objects of its own class.
  static String hashCodeMember(
    String className,
    List<ValueField> fields, {
    required bool seedWithType,
  }) {
    final components = [
      if (seedWithType) className,
      for (final field in fields) _hashComponent(field),
    ];
    final String expression;
    if (components.isEmpty) {
      expression = '($className).hashCode';
    } else if (components.length == 1) {
      final only = components.single;
      if (only == className) {
        expression = '($only).hashCode';
      } else if (only.startsWith('Object.')) {
        expression = only;
      } else if (only.contains(' ')) {
        expression = '($only).hashCode';
      } else {
        expression = '$only.hashCode';
      }
    } else if (components.length <= 20) {
      expression = 'Object.hash(${components.join(', ')})';
    } else {
      expression = 'Object.hashAll([${components.join(', ')}])';
    }
    return '@override\nint get hashCode => $expression;';
  }

  static String _hashComponent(ValueField field) {
    final self = '_self.${field.name}';
    final type = field.type;
    final String collectionHash;
    switch (type) {
      case ListWire() || BytesWire():
        collectionHash = 'Object.hashAll(${type.nullable ? '$self!' : self})';
      case MapWire():
        collectionHash =
            'Object.hashAllUnordered(${type.nullable ? '$self!' : self}'
            '.entries.map((e) => Object.hash(e.key, e.value)))';
      default:
        return self;
    }
    // Consistent with element-wise equality; null stays distinct from empty.
    return type.nullable
        ? '$self == null ? null : $collectionHash'
        : collectionHash;
  }

  static String toStringMember(String className, List<ValueField> fields) {
    final shown = [
      for (final field in fields)
        '${escapeInString(field.name)}: \${_self.${field.name}}',
    ].join(', ');
    return '@override\nString toString() => '
        "'${escapeInString(className)}($shown)';";
  }

  /// `extension NameCopyWith on Name { Name copyWith(...) }`, or `null` when
  /// there is nothing to copy.
  static String? copyWith(String className, List<ValueField> fields) {
    if (fields.isEmpty) return null;
    final parameters = <String>[];
    final arguments = <String>[];
    for (final field in fields) {
      final name = field.name;
      if (field.type.nullable) {
        // A nullable parameter cannot tell "keep" from "set to null"; a patch
        // can.
        final nonNull = field.spelling.substring(0, field.spelling.length - 1);
        parameters.add(
          'DwFieldPatch<$nonNull> $name = const DwFieldPatch.keep()',
        );
        arguments.add('$name: $name.apply(this.$name)');
      } else {
        parameters.add('${field.spelling}? $name');
        arguments.add('$name: $name ?? this.$name');
      }
    }
    return 'extension ${className}CopyWith on $className {\n'
        '$className copyWith({${parameters.join(', ')}}) => '
        '$className(${arguments.join(', ')});\n'
        '}';
  }
}
