import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier backing `DwSharedPreferences.provider`. Public because it is
/// the state type of the returned `NotifierProvider`; you do not construct it.
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

  /// Writes [value] to storage and updates the provider's state. Throws
  /// [UnsupportedError] for a type `SharedPreferences` cannot store.
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
        'Type ${value.runtimeType} is not supported by DwSharedPreferences. '
        'Use mappedProvider for enums and custom types.',
      );
    }

    state = value;
  }
}
