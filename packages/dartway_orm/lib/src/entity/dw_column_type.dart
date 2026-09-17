import 'dart:convert';
import 'dart:typed_data';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';
import 'package:postgres/postgres.dart' as pg;

import '../db/dw_errors.dart';

/// How one Dart type is stored in one SQL type.
///
/// Every conversion between a row value and a statement parameter or a
/// result cell goes through exactly one of these, so a type is never encoded
/// one way in `insert` and another in `where`.
///
/// [sqlType] is spelled the way `format_type` reports it, so a column created
/// from it and the same column read back by introspection compare equal
/// without a translation table.
abstract final class DwColumnType<T> {
  const DwColumnType(this.sqlType);

  final String sqlType;

  static const DwColumnType<int> bigint = _DwIdentityType<int>(
    'bigint',
    pg.Type.bigInteger,
    pg.Type.bigIntegerArray,
  );

  static const DwColumnType<double> doublePrecision = _DwDoubleType();

  static const DwColumnType<bool> boolean = _DwIdentityType<bool>(
    'boolean',
    pg.Type.boolean,
    pg.Type.booleanArray,
  );

  static const DwColumnType<String> text = _DwIdentityType<String>(
    'text',
    pg.Type.text,
    pg.Type.textArray,
  );

  /// Stored as an instant; always read back in UTC.
  static const DwColumnType<DateTime> timestamptz = _DwDateTimeType();

  /// Stored as `bigint` microseconds: exact, sortable, and free of the
  /// month/day ambiguity of `interval`.
  static const DwColumnType<Duration> duration = _DwDurationType();

  static const DwColumnType<Uint8List> bytea = _DwByteaType();

  @internal
  pg.Type<Object> get parameterType;

  /// The type of an array parameter of these values (`inList`, `insertAll`).
  @internal
  pg.Type<Object> get arrayParameterType;

  /// The SQL type the array elements must be cast to, when the array travels
  /// as another type. `null` when no cast is needed.
  @internal
  String? get arrayElementCast => null;

  /// The parameter value for [value].
  @internal
  Object encode(T value);

  /// The element of an array parameter for [value].
  @internal
  Object encodeArrayElement(T value) => encode(value);

  /// The Dart value of a non-null result cell.
  @internal
  T decode(Object raw);

  @override
  String toString() => 'DwColumnType($sqlType)';
}

final class _DwIdentityType<T> extends DwColumnType<T> {
  const _DwIdentityType(
    super.sqlType,
    this.parameterType,
    this.arrayParameterType,
  );

  @override
  final pg.Type<Object> parameterType;

  @override
  final pg.Type<Object> arrayParameterType;

  @override
  Object encode(T value) => value!;

  @override
  T decode(Object raw) {
    if (raw is T) return raw as T;
    throw DwDecodeException('expected $T for $sqlType, got ${raw.runtimeType}');
  }
}

final class _DwDoubleType extends DwColumnType<double> {
  const _DwDoubleType() : super('double precision');

  @override
  pg.Type<Object> get parameterType => pg.Type.double;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.doubleArray;

  @override
  Object encode(double value) => value;

  @override
  double decode(Object raw) {
    if (raw is num) return raw.toDouble();
    throw DwDecodeException('expected double, got ${raw.runtimeType}');
  }
}

final class _DwDateTimeType extends DwColumnType<DateTime> {
  const _DwDateTimeType() : super('timestamp with time zone');

  @override
  pg.Type<Object> get parameterType => pg.Type.timestampTz;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.timestampTzArray;

  @override
  Object encode(DateTime value) => value.toUtc();

  @override
  DateTime decode(Object raw) {
    if (raw is DateTime) return raw.toUtc();
    throw DwDecodeException('expected DateTime, got ${raw.runtimeType}');
  }
}

final class _DwDurationType extends DwColumnType<Duration> {
  const _DwDurationType() : super('bigint');

  @override
  pg.Type<Object> get parameterType => pg.Type.bigInteger;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.bigIntegerArray;

  @override
  Object encode(Duration value) => value.inMicroseconds;

  @override
  Duration decode(Object raw) {
    if (raw is int) return Duration(microseconds: raw);
    throw DwDecodeException('expected bigint micros, got ${raw.runtimeType}');
  }
}

final class _DwByteaType extends DwColumnType<Uint8List> {
  const _DwByteaType() : super('bytea');

  @override
  pg.Type<Object> get parameterType => pg.Type.byteArray;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.byteArrayArray;

  @override
  Object encode(Uint8List value) => value;

  @override
  Uint8List decode(Object raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    throw DwDecodeException('expected bytes, got ${raw.runtimeType}');
  }
}

/// An enum stored as `text` holding its `name` (D-008): adding a value needs
/// no migration, and the driver decodes native enum types only as raw bytes.
final class DwEnumType<E extends Enum> extends DwColumnType<E> {
  const DwEnumType(this.values) : super('text');

  final List<E> values;

  @override
  pg.Type<Object> get parameterType => pg.Type.text;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.textArray;

  /// The `unknown` value of a [DwOpenEnum] cannot be written: it stands for
  /// a name this build did not know, and writing it would replace that name.
  @override
  Object encode(E value) => DwJsonCodec.encodeEnum(value);

  /// A name no value has fails the read — unless [E] is a [DwOpenEnum],
  /// whose `unknown` it is read as.
  @override
  E decode(Object raw) {
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
      if (DwJsonCodec.openFallback(values) case final fallback?) {
        return fallback;
      }
      throw DwDecodeException('"$raw" is not a value of $E');
    }
    throw DwDecodeException('expected text for $E, got ${raw.runtimeType}');
  }
}

/// A `jsonb` value.
///
/// Arrays of these travel as `text[]` of JSON documents cast back to `jsonb`:
/// the driver encodes a null element of a `jsonb[]` parameter as the JSON
/// value `null`, which is not SQL `NULL` — a nullable column filled by
/// `insertAll` would answer `IS NULL` with false.
abstract final class _DwJsonType<T> extends DwColumnType<T> {
  const _DwJsonType() : super('jsonb');

  @override
  pg.Type<Object> get parameterType => pg.Type.jsonb;

  @override
  pg.Type<Object> get arrayParameterType => pg.Type.textArray;

  @override
  String? get arrayElementCast => 'jsonb';

  @override
  Object encode(T value) => value!;

  @override
  Object encodeArrayElement(T value) => jsonEncode(value);
}

/// A `List<E>` stored as a `jsonb` array. Elements are JSON values: `int`,
/// `double`, `String`, `bool`, or `Map<String, Object?>` / `List<Object?>`
/// read back untyped.
final class DwJsonListType<E> extends _DwJsonType<List<E>> {
  const DwJsonListType();

  @override
  List<E> decode(Object raw) {
    if (raw is! List) {
      throw DwDecodeException('expected a jsonb array, got ${raw.runtimeType}');
    }
    try {
      return List<E>.unmodifiable(raw);
    } on TypeError {
      throw DwDecodeException('jsonb array does not hold only $E: $raw');
    }
  }
}

/// A `List<E>` of an enum stored as a `jsonb` array of the values' names —
/// the list form of [DwEnumType] (D-008): adding a value needs no migration,
/// and a name no value has any more fails the read rather than guessing.
final class DwEnumListType<E extends Enum> extends _DwJsonType<List<E>> {
  const DwEnumListType(this.values);

  final List<E> values;

  @override
  Object encode(List<E> value) => [
    for (final item in value) DwJsonCodec.encodeEnum(item),
  ];

  @override
  Object encodeArrayElement(List<E> value) => jsonEncode(encode(value));

  @override
  List<E> decode(Object raw) {
    if (raw is! List) {
      throw DwDecodeException('expected a jsonb array, got ${raw.runtimeType}');
    }
    return List<E>.unmodifiable([
      for (final name in raw)
        values.firstWhere(
          (value) => value.name == name,
          orElse: () =>
              DwJsonCodec.openFallback(values) ??
              (throw DwDecodeException('"$name" is not a value of $E')),
        ),
    ]);
  }
}

/// A `Map<String, V>` stored as a `jsonb` object.
final class DwJsonMapType<V> extends _DwJsonType<Map<String, V>> {
  const DwJsonMapType();

  @override
  Map<String, V> decode(Object raw) {
    if (raw is! Map) {
      throw DwDecodeException(
        'expected a jsonb object, got ${raw.runtimeType}',
      );
    }
    try {
      return Map<String, V>.unmodifiable(raw);
    } on TypeError {
      throw DwDecodeException('jsonb object does not hold only $V: $raw');
    }
  }
}
