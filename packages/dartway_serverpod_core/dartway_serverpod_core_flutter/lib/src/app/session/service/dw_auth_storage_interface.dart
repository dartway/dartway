import 'package:shared_preferences/shared_preferences.dart';

/// Abstract class for storage used by the key manager.
abstract class Storage {
  /// Stores an int value with the specified key.
  Future<void> setInt(String key, int value);

  /// Retrieves an int value with the specified key.
  Future<int?> getInt(String key);

  /// Stores a string value with the specified key.
  Future<void> setString(String key, String value);

  /// Retrieves a string value with the specified key.
  Future<String?> getString(String key);

  /// Removes a value for the specified key.
  Future<void> remove(String key);
}

/// Concrete implementation of the [Storage] used by the key manager.
class SharedPreferenceStorage implements Storage {
  @override
  Future<int?> getInt(String key) async {
    var prefs = await SharedPreferences.getInstance();

    return prefs.getInt(key);
  }

  @override
  Future<String?> getString(String key) async {
    var prefs = await SharedPreferences.getInstance();

    return prefs.getString(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setInt(key, value);
  }

  @override
  Future<void> setString(String key, String value) async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.remove(key);
  }
}
