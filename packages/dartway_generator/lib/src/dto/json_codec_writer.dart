import '../analysis/wire_type.dart';

/// Writes the expressions that convert values between Dart and JSON.
///
/// Every conversion goes through `DwJson` (dartway_core), so how a type looks
/// on the wire is decided in one place and the generated code only calls it.
abstract final class JsonCodecWriter {
  /// Encodes [value], an expression of the non-nullable form of [type].
  static String encodeValue(WireType type, String value) => switch (type) {
    ScalarWire() || DoubleWire() => value,
    DateTimeWire() => 'DwJson.encodeDateTime($value)',
    DurationWire() => 'DwJson.encodeDuration($value)',
    BytesWire() => 'DwJson.encodeBytes($value)',
    EnumWire() => '$value.name',
    DtoWire() => '$value.toJson()',
    ListWire(:final element) =>
      element.isIdentity
          ? value
          : '[for (final e in $value) ${encodeLocal(element, 'e')}]',
    MapWire(value: final valueType) =>
      valueType.isIdentity
          ? value
          : '$value.map((k, v) => MapEntry(k, ${encodeLocal(valueType, 'v')}))',
    PatchWire() => throw StateError('A patch is encoded by writePatch.'),
  };

  /// Encodes [local], a promotable variable of [type] (nullable or not).
  static String encodeLocal(WireType type, String local) {
    if (!type.nullable || type.isIdentity) return encodeValue(type, local);
    return switch (type) {
      EnumWire() => '$local?.name',
      DtoWire() => '$local?.toJson()',
      _ => '$local == null ? null : ${encodeValue(type, local)}',
    };
  }

  /// Decodes [json], an `Object?` expression, into [type].
  ///
  /// [local] says [json] is a local variable: after a null check it is
  /// promoted, so no `!` is written in front of a cast. A map lookup is not.
  static String decode(WireType type, String json, {bool local = false}) {
    if (!type.nullable) return decodeValue(type, json);
    if (type is ScalarWire) return '$json as ${type.dartName}?';
    return '$json == null ? null : '
        '${decodeValue(type, json, promoted: local)}';
  }

  /// Decodes [json] into the non-nullable form of [type]; [promoted] says it
  /// is statically non-null already.
  static String decodeValue(
    WireType type,
    String json, {
    bool promoted = false,
  }) {
    final nonNull = promoted ? json : '$json!';
    return switch (type) {
      ScalarWire(:final dartName) => '$nonNull as $dartName',
      DoubleWire() => 'DwJson.decodeDouble($json)',
      DateTimeWire() => 'DwJson.decodeDateTime($json)',
      DurationWire() => 'DwJson.decodeDuration($json)',
      BytesWire() => 'DwJson.decodeBytes($json)',
      EnumWire(:final spelling) => 'DwJson.decodeEnum($json, $spelling.values)',
      DtoWire(:final decoder) => '$decoder($nonNull as Map<String, Object?>)',
      ListWire(:final element) =>
        'DwJson.decodeList($json, (e) => ${decode(element, 'e', local: true)})',
      MapWire(:final value) =>
        'DwJson.decodeMap($json, (v) => ${decode(value, 'v', local: true)})',
      PatchWire() => throw StateError('A patch is decoded by readPatch.'),
    };
  }
}
