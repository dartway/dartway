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
      if (type is PatchWire) {
        final encode = JsonCodecWriter.encodeValue(type.inner, 'v');
        patches.add(
          'DwJsonCodec.writePatch(json, $key, $self, (v) => $encode);',
        );
      } else if (type.nullable) {
        final value = type.isIdentity
            ? self
            : JsonCodecWriter.encodeValue(type, '$self!');
        entries.add('if ($self != null) $key: $value');
      } else if (field.omitWhenEmpty) {
        entries.add(
          'if ($self.isNotEmpty) $key: ${JsonCodecWriter.encodeValue(type, self)}',
        );
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
    if (field.omitWhenEmpty && !type.nullable) {
      final empty = type is MapWire ? 'const {}' : 'const []';
      return '$json == null ? $empty : ${JsonCodecWriter.decodeValue(type, json)}';
    }
    return JsonCodecWriter.decode(type, json);
  }
}
