import '../analysis/framework.dart';
import '../analysis/wire_type.dart';
import '../emit/source_text.dart';
import '../emit/value_class_writer.dart';
import 'dto_model.dart';
import 'json_codec_writer.dart';

/// Writes the generated code of one DTO class. Output is unformatted but
/// syntactically final; the formatter only lays it out, so blank lines here
/// are the blank lines of the result.
abstract final class DtoEmitter {
  static String emit(DtoClass dto) {
    final copyWith = dto.kind == DtoKind.data
        ? ValueClassWriter.copyWith(dto.name, dto.fields)
        : null;
    return [_mixin(dto), _fromJson(dto), ?copyWith].join('\n\n');
  }

  static String _mixin(DtoClass dto) {
    final name = dto.name;
    final members = <String>[
      ?ValueClassWriter.self(name, dto.fields),
      '@override\nString get dwTypeName => ${dartString(name)};',
      _toJson(dto),
      ValueClassWriter.equalsMember(name, dto.fields),
      ValueClassWriter.hashCodeMember(
        name,
        dto.fields,
        seedWithType: dto.kind != DtoKind.data,
      ),
      // A command is an input and may carry a code or a password: a toString
      // that prints its fields would put them into any log that interpolates
      // the command. Data objects and requests are safe to print and worth it.
      if (dto.kind != DtoKind.command)
        ValueClassWriter.toStringMember(name, dto.fields),
    ];
    return 'mixin _\$$name on ${dto.superclass} {\n'
        '${members.join('\n\n')}\n'
        '}';
  }

  static String _toJson(DtoClass dto) {
    final entries = <String>[];
    final patches = <String>[];
    for (final field in dto.fields) {
      final key = dartString(field.name);
      final self = '_self.${field.name}';
      final type = field.type;
      final defaultValue = field.defaultValue;
      if (type is PatchWire) {
        final encode = JsonCodecWriter.encodeValue(type.inner, 'v');
        patches.add(
          'DwJsonCodec.writePatch(json, $key, $self, (v) => $encode);',
        );
      } else if (defaultValue != null) {
        // Left off the wire when equal to its default, which the decoder
        // restores (D-041). A nullable field with a non-null default writes
        // its null out: absent would mean the default.
        final value = type.nullable
            ? _encodeNullable(type, self)
            : JsonCodecWriter.encodeValue(type, self);
        entries.add('if (${_differs(field, defaultValue)}) $key: $value');
      } else if (type.nullable) {
        final value = type.isIdentity
            ? self
            : JsonCodecWriter.encodeValue(type, '$self!');
        entries.add('if ($self != null) $key: $value');
      } else {
        entries.add('$key: ${JsonCodecWriter.encodeValue(type, self)}');
      }
    }
    const signature = '@override\nMap<String, Object?> toJson()';
    if (patches.isEmpty) {
      if (entries.isEmpty) return '$signature => const {};';
      return '$signature => {${entries.join(', ')}};';
    }
    return '$signature {\n'
        'final json = <String, Object?>{${entries.join(', ')}};\n'
        '${patches.join('\n')}\n'
        'return json;\n'
        '}';
  }

  /// Whether the field's value differs from its [defaultValue].
  static String _differs(DtoField field, DtoDefault defaultValue) {
    final self = '_self.${field.name}';
    if (defaultValue.isEmptyCollection && !field.type.nullable) {
      return '$self.isNotEmpty';
    }
    final expression = defaultValue.expression;
    return switch (field.type) {
      ScalarWire(dartName: 'bool', nullable: false) =>
        expression == 'true' ? '!$self' : self,
      ListWire() => '!dwListEquals($self, $expression)',
      MapWire() => '!dwMapEquals($self, $expression)',
      _ => '$self != $expression',
    };
  }

  /// Encodes [self], a getter of the nullable [type], null included.
  static String _encodeNullable(WireType type, String self) {
    if (type.isIdentity) return self;
    return switch (type) {
      EnumWire() => '$self?.name',
      DtoWire() => '$self?.toJson()',
      _ =>
        '$self == null ? null : ${JsonCodecWriter.encodeValue(type, '$self!')}',
    };
  }

  static String _fromJson(DtoClass dto) {
    final name = dto.name;
    final arguments = [
      for (final field in dto.fields) '${field.name}: ${_decodeField(field)}',
    ];
    final construct = arguments.isEmpty
        ? '${dto.constConstructor ? 'const ' : ''}$name()'
        : '$name(${arguments.join(', ')})';
    return '$name \$${name}FromJson(Map<String, Object?> json) => $construct;';
  }

  static String _decodeField(DtoField field) {
    final key = dartString(field.name);
    final json = 'json[$key]';
    final type = field.type;
    if (type is PatchWire) {
      final decode = JsonCodecWriter.decodeValue(type.inner, 'v');
      return 'DwJsonCodec.readPatch(json, $key, (v) => $decode)';
    }
    final defaultValue = field.defaultValue;
    if (defaultValue == null) return JsonCodecWriter.decode(type, json);
    if (type.nullable) {
      // Present null is null; only an absent key means the default.
      final decoded = JsonCodecWriter.decode(type, json);
      return 'json.containsKey($key) ? ($decoded) : ${defaultValue.expression}';
    }
    final fallback = defaultValue.isEmptyCollection
        ? (type is MapWire ? 'const {}' : 'const []')
        : defaultValue.expression;
    return '$json == null ? $fallback : ${JsonCodecWriter.decodeValue(type, json)}';
  }
}
