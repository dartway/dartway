import 'dart:convert';
import 'dart:typed_data';

import '../dto/dw_patch.dart';

/// Conversions the generated codecs call. One place decides how each Dart type
/// looks on the wire, so a generator change never has to agree with a second
/// copy of the rule.
abstract final class DwJson {
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

  static T decodeEnum<T extends Enum>(Object? json, List<T> values) =>
      values.byName(json! as String);

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
    DwPatch<T> patch,
    Object? Function(T value) encode,
  ) {
    switch (patch) {
      case DwKeep():
        return;
      case DwSet(:final value):
        json[key] = encode(value);
      case DwClear():
        json[key] = null;
    }
  }

  static DwPatch<T> readPatch<T>(
    Map<String, Object?> json,
    String key,
    T Function(Object? value) decode,
  ) {
    if (!json.containsKey(key)) return DwPatch<T>.keep();
    final value = json[key];
    return value == null ? DwPatch<T>.clear() : DwPatch<T>.set(decode(value));
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
