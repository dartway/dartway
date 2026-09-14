import 'dart:collection';

import 'package:meta/meta.dart';

import '../query/dw_column.dart';
import 'dw_errors.dart';

/// One result row: a read-only map from column name to the value the driver
/// decoded, with typed reads that fail loudly.
///
/// Rows of one result share a single name index, built once per result.
final class DwResultRow extends MapBase<String, Object?> {
  @internal
  DwResultRow(this._index, this._values);

  final Map<String, int> _index;
  final List<Object?> _values;

  /// The value of [name] as [T].
  ///
  /// Throws [DwDecodeException] when the row has no such column or the value
  /// is not a [T] — including `null` for a non-nullable [T].
  T get<T>(String name) {
    final position = _index[name];
    if (position == null) {
      throw DwDecodeException(
        'the row has no column "$name" (it has ${_index.keys.join(', ')})',
      );
    }
    final value = _values[position];
    if (value is T) return value;
    throw DwDecodeException(
      'column "$name" holds ${value.runtimeType}, expected $T',
    );
  }

  /// The value of [column], decoded through the column's type.
  T decode<T>(DwColumn<T> column) {
    final position = _index[column.name];
    if (position == null) {
      throw DwDecodeException('the row has no column "${column.name}"');
    }
    final raw = _values[position];
    if (raw == null) {
      if (column.nullable) return null as T;
      throw DwDecodeException(
        'column "${column.name}" is null, but ${column.type.sqlType} '
        'of a non-nullable $T is expected',
      );
    }
    return column.type.decode(raw);
  }

  @override
  Object? operator [](Object? key) {
    final position = _index[key];
    return position == null ? null : _values[position];
  }

  @override
  Iterable<String> get keys => _index.keys;

  @override
  int get length => _index.length;

  @override
  bool containsKey(Object? key) => _index.containsKey(key);

  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('a DwResultRow is read-only');

  @override
  void clear() => throw UnsupportedError('a DwResultRow is read-only');

  @override
  Object? remove(Object? key) =>
      throw UnsupportedError('a DwResultRow is read-only');
}
