import 'dart:convert';

import 'package:dartway_client/dartway_client.dart';

import '../core/logic/dw_key_value_store.dart';

/// Keeps the session through whichever plugin claimed the
/// [DwKeyValueStorePlugin] role, so a signed-in app stays signed in across
/// restarts.
///
/// The plugin is resolved on first use, not when the core is built: plugins
/// are constructed before the core and initialized in `dw.init()`, which runs
/// before the client first reads the session.
final class DwKeyValueTokenStore implements DwTokenStore {
  DwKeyValueTokenStore(this._resolve, {this.key = 'dw.session'});

  final DwKeyValueStorePlugin? Function() _resolve;

  /// The key the session is stored under. One key per server: an app that
  /// talks to two servers keeps two sessions.
  final String key;

  DwKeyValueStorePlugin get _store {
    final store = _resolve();
    if (store == null) {
      throw StateError(
        'No DwKeyValueStorePlugin is declared, so there is nowhere to keep the '
        'session and a sign-in cannot survive a restart. Declare one — '
        'DwCore(plugins: [DwSharedPreferences()]) — or pass DwCore a '
        'tokenStore of its own.',
      );
    }
    return store;
  }

  @override
  Future<DwSession?> read() async {
    final stored = await _store.getString(key);
    if (stored == null) return null;
    try {
      return DwSession.fromJson(jsonDecode(stored) as Map<String, Object?>);
    } on Object {
      // Unreadable: nobody is signed in, and the key is freed for the next
      // session rather than failing every start.
      await _store.remove(key);
      return null;
    }
  }

  @override
  Future<void> write(DwSession session) =>
      _store.setString(key, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _store.remove(key);
}
