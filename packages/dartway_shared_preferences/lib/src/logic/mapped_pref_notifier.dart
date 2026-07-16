import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifier backing `DwSharedPreferences.mappedProvider` (String <-> T).
/// Public because it is the state type of the returned `NotifierProvider`; you
/// do not construct it.
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

  /// Maps [value] to its `String` form, writes it to storage, and updates the
  /// provider's state.
  Future<void> update(T value) async {
    await _prefs.setString(_key, _mapTo(value));
    state = value;
  }
}
