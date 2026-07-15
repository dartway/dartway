import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dw_shared_preferences.dart';

/// The shared-preferences plugin. Declare it at startup:
///
/// ```dart
/// DwCore(plugins: [DwSharedPreferencesPlugin()]);
/// ```
///
/// It loads [SharedPreferences] during `dw.init()` and exposes the reactive
/// [DwSharedPreferences] wrapper as `dw.plugins.prefs`.
class DwSharedPreferencesPlugin extends DwPlugin {
  DwSharedPreferencesPlugin();

  late final DwSharedPreferences _prefs;

  DwSharedPreferences get prefs => _prefs;

  @override
  Future<void> init() async {
    _prefs = DwSharedPreferences(await SharedPreferences.getInstance());
  }
}

/// Reaches the shared-preferences wrapper as `dw.plugins.prefs`.
///
/// `dw.plugins.prefs.provider(key: ..., defaultValue: ...)` for a reactive
/// value; `dw.plugins.prefs.raw` for direct [SharedPreferences] access.
extension DwPrefsAccess on DwPlugins {
  DwSharedPreferences get prefs => of<DwSharedPreferencesPlugin>().prefs;
}
