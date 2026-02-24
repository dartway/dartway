import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------------------------------------------------
/// DW SHARED PREFERENCES WRAPPER
/// ------------------------------------------------------------

class DwSharedPreferences {
  DwSharedPreferences(this._prefs);

  final SharedPreferences _prefs;
  SharedPreferences get sharedPreferences => _prefs;

  /// ----------------------------------------------------------
  /// Generic provider factory
  /// ----------------------------------------------------------

  NotifierProvider<_PrefNotifier<T>, T> provider<T>({
    required String key,
    required T defaultValue,
  }) {
    return NotifierProvider<_PrefNotifier<T>, T>(() {
      return _PrefNotifier<T>(_prefs, key, defaultValue);
    });
  }

  /// ----------------------------------------------------------
  /// String-mapped provider (enum, custom types, etc.)
  /// ----------------------------------------------------------

  NotifierProvider<_MappedPrefNotifier<T>, T> mappedProvider<T>({
    required String key,
    required T Function(String?) mapFrom,
    required String Function(T) mapTo,
  }) {
    return NotifierProvider<_MappedPrefNotifier<T>, T>(() {
      return _MappedPrefNotifier<T>(_prefs, key, mapFrom, mapTo);
    });
  }
}

/// ------------------------------------------------------------
/// INTERNAL GENERIC NOTIFIER
/// ------------------------------------------------------------

class _PrefNotifier<T> extends Notifier<T> {
  _PrefNotifier(this._prefs, this._key, this._defaultValue);

  final SharedPreferences _prefs;
  final String _key;
  final T _defaultValue;

  @override
  T build() {
    final value = _prefs.get(_key);
    return value as T? ?? _defaultValue;
  }

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

/// ------------------------------------------------------------
/// INTERNAL MAPPED NOTIFIER (String <-> T)
/// ------------------------------------------------------------

class _MappedPrefNotifier<T> extends Notifier<T> {
  _MappedPrefNotifier(this._prefs, this._key, this._mapFrom, this._mapTo);

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
