import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic/mapped_pref_notifier.dart';
import 'logic/pref_notifier.dart';

export 'logic/mapped_pref_notifier.dart';
export 'logic/pref_notifier.dart';

/// Reaches the plugin as `dw.plugins.prefs` — same shape as `dw.plugins.telegram`.
extension DwPrefsAccess on DwPlugins {
  DwSharedPreferences get prefs => of<DwSharedPreferences>();
}

/// The shared-preferences plugin: a reactive wrapper over [SharedPreferences].
/// Declare it at startup, then reach it as `dw.plugins.prefs`:
///
/// ```dart
/// DwFlutter(
///   config: DwConfig(/* ... */),
///   plugins: [DwSharedPreferences()],
/// );
/// ```
///
/// It loads [SharedPreferences] during `dw.init()`, then serves reactive
/// riverpod providers over stored keys. **Define each provider once**, as a
/// top-level `final` — like any riverpod provider. Do not call [provider]
/// inline in `build`: every call builds a *new* provider, so two providers over
/// the same key would not see each other's writes.
///
/// ```dart
/// final darkModeProvider =
///     dw.plugins.prefs.provider(key: 'darkMode', defaultValue: false);
///
/// // one-off imperative read, no provider:
/// final token = dw.plugins.prefs.raw.getString('token');
/// ```
class DwSharedPreferences extends DwPlugin {
  DwSharedPreferences();

  /// The underlying [SharedPreferences], for direct imperative reads/writes.
  /// Available after `dw.init()` has run.
  late final SharedPreferences raw;

  @override
  Future<void> init() async {
    raw = await SharedPreferences.getInstance();
  }

  /// Builds a provider whose value is the stored [key], falling back to
  /// [defaultValue]. Update it through the notifier's `update`.
  ///
  /// Supported types: `String`, `bool`, `int`, `double`, `List<String>` — the
  /// ones `SharedPreferences` stores natively. Any other `T` compiles but throws
  /// [UnsupportedError] on the first write; use [mappedProvider] for enums and
  /// custom types.
  ///
  /// Assign the result to a top-level `final` once — see the class doc.
  NotifierProvider<PrefNotifier<T>, T> provider<T>({
    required String key,
    required T defaultValue,
  }) {
    return NotifierProvider<PrefNotifier<T>, T>(() {
      return PrefNotifier<T>(raw, key, defaultValue);
    });
  }

  /// Builds a provider for a value stored as a `String` but exposed as [T], via
  /// [mapFrom]/[mapTo] — for enums and custom types.
  ///
  /// Assign the result to a top-level `final` once — see the class doc.
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
