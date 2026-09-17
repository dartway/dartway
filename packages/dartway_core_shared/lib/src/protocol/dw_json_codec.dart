import 'dart:convert';
import 'dart:typed_data';

import '../wire/dw_field_patch.dart';
import 'dw_open_enum.dart';

/// Conversions the generated codecs call. One place decides how each Dart type
/// looks on the wire, so a generator change never has to agree with a second
/// copy of the rule.
abstract final class DwJsonCodec {
  /// `DateTime` travels as UTC microseconds since the epoch: exact, compact and
  /// free of time-zone text.
  static int encodeDateTime(DateTime value) =>
      value.toUtc().microsecondsSinceEpoch;

  static DateTime decodeDateTime(Object? json) =>
      DateTime.fromMicrosecondsSinceEpoch(json! as int, isUtc: true);

  static int encodeDuration(Duration value) => value.inMicroseconds;

  static Duration decodeDuration(Object? json) =>
      Duration(microseconds: json! as int);

  static String encodeBytes(Uint8List value) => base64Encode(value);

  static Uint8List decodeBytes(Object? json) => base64Decode(json! as String);

  /// JSON numbers without a fraction arrive as `int` on some platforms.
  static double decodeDouble(Object? json) => (json! as num).toDouble();

  /// The value named [json]. A name no value has is [DwUnknownEnumValue] —
  /// the data is newer than this build — unless the enum is a [DwOpenEnum],
  /// whose `unknown` value it is read as.
  static T decodeEnum<T extends Enum>(Object? json, List<T> values) {
    final name = json! as String;
    for (final value in values) {
      if (value.name == name) return value;
    }
    if (openFallback(values) case final fallback?) return fallback;
    throw DwUnknownEnumValue(T, name);
  }

  /// The `unknown` value of an open enum, or null for a strict one. Throws
  /// [StateError] for an open enum that declares no `unknown`.
  static T? openFallback<T extends Enum>(List<T> values) {
    if (values.isEmpty || values.first is! DwOpenEnum) return null;
    for (final value in values) {
      if (value.name == DwOpenEnum.fallbackName) return value;
    }
    throw StateError(
      '$T is a DwOpenEnum and declares no value named '
      '"${DwOpenEnum.fallbackName}" to read unknown names as',
    );
  }

  /// The name [value] is written as. Throws [StateError] for the `unknown`
  /// value of an open enum: it stands for a name this build did not know,
  /// and writing it would replace that name.
  static String encodeEnum(Enum value) {
    if (value is DwOpenEnum && value.isUnknown) {
      throw StateError(
        '${value.runtimeType}.unknown stands for a value this build does not '
        'know and cannot be written; update the app',
      );
    }
    return value.name;
  }

  static List<T> decodeList<T>(Object? json, T Function(Object? item) decode) =>
      [for (final item in json! as List<Object?>) decode(item)];

  static Map<String, T> decodeMap<T>(
    Object? json,
    T Function(Object? value) decode,
  ) => (json! as Map<String, Object?>).map(
    (key, value) => MapEntry(key, decode(value)),
  );

  /// Writes a patch field into [json]: absent when kept, `null` when cleared.
  static void writePatch<T>(
    Map<String, Object?> json,
    String key,
    DwFieldPatch<T> patch,
    Object? Function(T value) encode,
  ) {
    switch (patch) {
      case DwKeepField():
        return;
      case DwSetField(:final value):
        json[key] = encode(value);
      case DwClearField():
        json[key] = null;
    }
  }

  static DwFieldPatch<T> readPatch<T>(
    Map<String, Object?> json,
    String key,
    T Function(Object? value) decode,
  ) {
    if (!json.containsKey(key)) return DwFieldPatch<T>.keep();
    final value = json[key];
    return value == null
        ? DwFieldPatch<T>.clear()
        : DwFieldPatch<T>.set(decode(value));
  }
}

/// Element-wise list equality, for generated `==`.
bool dwListEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Entry-wise map equality, for generated `==`.
bool dwMapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}
