import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reactive wrapper over [SharedPreferences]: build a riverpod provider whose
/// value is backed by a stored key, so the UI watches a preference the same way
/// it watches anything else. Reach it as `dw.plugins.prefs`.
///
/// For one-off imperative access, use [raw] — the underlying [SharedPreferences].
class DwSharedPreferences {
  DwSharedPreferences(this.raw);

  /// The underlying [SharedPreferences], for direct imperative reads/writes.
  final SharedPreferences raw;

  /// A provider whose value is the stored [key], falling back to [defaultValue].
  /// Update it through the notifier's `update`. Supported types: `String`,
  /// `bool`, `int`, `double`, `List<String>`.
  NotifierProvider<PrefNotifier<T>, T> provider<T>({
    required String key,
    required T defaultValue,
  }) {
    return NotifierProvider<PrefNotifier<T>, T>(() {
      return PrefNotifier<T>(raw, key, defaultValue);
    });
  }

  /// A provider for a value stored as a `String` but exposed as [T], via
  /// [mapFrom]/[mapTo] — for enums and custom types.
  NotifierProvider<MappedPrefNotifier<T>, T> mappedProvider<T>({
    required String key,
    required T Function(String?) mapFrom,
    required String Function(T) mapTo,
  }) {
    return NotifierProvider<MappedPrefNotifier<T>, T>(() {
      return MappedPrefNotifier<T>(raw, key, mapFrom, mapTo);
    });
  }
}

/// Notifier backing [DwSharedPreferences.provider].
class PrefNotifier<T> extends Notifier<T> {
  PrefNotifier(this._prefs, this._key, this._defaultValue);

  final SharedPreferences _prefs;
  final String _key;
  final T _defaultValue;

  @override
  T build() {
    final value = _prefs.get(_key);
    return value as T? ?? _defaultValue;
  }

  /// Writes [value] to storage and updates the provider's state. Supported
  /// types: `String`, `bool`, `int`, `double`, `List<String>`.
  Future<void> update(T value) async {
    if (value is String) {
      await _prefs.setString(_key, value);
    } else if (value is bool) {
      await _prefs.setBool(_key, value);
    } else if (value is int) {
      await _prefs.setInt(_key, value);
    } else if (value is double) {
      await _prefs.setDouble(_key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(_key, value);
    } else {
      throw UnsupportedError(
        'Type ${value.runtimeType} is not supported by DwSharedPreferences',
      );
    }

    state = value;
  }
}

/// Notifier backing [DwSharedPreferences.mappedProvider] (String <-> T).
class MappedPrefNotifier<T> extends Notifier<T> {
  MappedPrefNotifier(this._prefs, this._key, this._mapFrom, this._mapTo);

  final SharedPreferences _prefs;
  final String _key;
  final T Function(String?) _mapFrom;
  final String Function(T) _mapTo;

  @override
  T build() {
    final raw = _prefs.getString(_key);
    return _mapFrom(raw);
  }

  Future<void> update(T value) async {
    await _prefs.setString(_key, _mapTo(value));
    state = value;
  }
}
