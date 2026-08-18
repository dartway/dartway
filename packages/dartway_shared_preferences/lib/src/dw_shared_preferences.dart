import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic/mapped_pref_notifier.dart';
import 'logic/pref_notifier.dart';

export 'logic/mapped_pref_notifier.dart';
export 'logic/pref_notifier.dart';

/// Reaches the plugin as `dw.plugins.prefs` — same shape as `dw.plugins.telegram`.
extension DwPrefsAccess on DwPlugins {
  DwSharedPreferences get prefs => of<DwSharedPreferences>();
}

/// What [DwSharedPreferences.provider] returns.
///
/// Exported so a consumer can name it. Without a name of ours the type is
/// `NotifierProvider<PrefNotifier<T>, T>`, which only a library that imports
/// riverpod can write down — and a file that just wants to remember a setting
/// has no other reason to. Worse, when riverpod is absent the analyzer does not
/// say so: it reports *"the getter 'prefs' isn't defined for the type
/// DwPlugins"*, pointing at a getter that is perfectly fine, while
/// `unused_import` simultaneously suggests removing the import that fixes it.
typedef DwPrefProvider<T> = NotifierProvider<PrefNotifier<T>, T>;

/// What [DwSharedPreferences.mappedProvider] returns — see [DwPrefProvider].
typedef DwMappedPrefProvider<T> = NotifierProvider<MappedPrefNotifier<T>, T>;

/// What [DwSharedPreferences.providerFamily] returns — see [DwPrefProvider] for
/// why the plugin names its own return types. Call it with an [Arg] to get a
/// [DwPrefProvider] over the key that argument maps to.
typedef DwPrefProviderFamily<T, Arg> =
    NotifierProviderFamily<PrefNotifier<T>, T, Arg>;

/// What [DwSharedPreferences.mappedProviderFamily] returns — see
/// [DwPrefProviderFamily].
typedef DwMappedPrefProviderFamily<T, Arg> =
    NotifierProviderFamily<MappedPrefNotifier<T>, T, Arg>;

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
///
/// When the key depends on an entity — one value per project, per chat, per
/// user — reach for [providerFamily] / [mappedProviderFamily] instead of
/// calling [provider] per id. The family is the top-level `final`; riverpod
/// then holds one provider per argument value, which is exactly the guarantee
/// a loop over [provider] cannot give you.
///
/// ```dart
/// final projectSortProvider = dw.plugins.prefs.providerFamily<String, int>(
///   keyFor: (projectId) => 'project.$projectId.sort',
///   defaultValue: 'name',
/// );
///
/// ref.watch(projectSortProvider(project.id));
/// ```
class DwSharedPreferences extends DwPlugin {
  DwSharedPreferences();

  /// The underlying [SharedPreferences], for direct imperative reads/writes.
  /// Available after `dw.init()` has run.
  late final SharedPreferences raw;

  @override
  Future<void> init(DwFlutter core) async {
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
  DwPrefProvider<T> provider<T>({
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
  DwMappedPrefProvider<T> mappedProvider<T>({
    required String key,
    required T Function(String?) mapFrom,
    required String Function(T) mapTo,
  }) {
    return NotifierProvider<MappedPrefNotifier<T>, T>(() {
      return MappedPrefNotifier<T>(raw, key, mapFrom, mapTo);
    });
  }

  /// [provider], but the key is built per argument — for a value that belongs
  /// to an entity rather than to the app: a sort order per project, a collapsed
  /// flag per section, a draft per chat.
  ///
  /// [keyFor] turns the argument into the storage key; everything else matches
  /// [provider], including the natively-stored types and the [UnsupportedError]
  /// any other `T` throws on the first write.
  ///
  /// **This is what makes per-entity state safe.** Calling [provider] once per
  /// id hits the hazard the class doc warns about — two providers over one key,
  /// blind to each other's writes. A family is declared once and riverpod keeps
  /// a single provider per argument value, so every reader of `family(id)` sees
  /// the same state. Declare the *family* as a top-level `final`; calling it
  /// with an argument inside `build` is the intended use.
  ///
  /// ```dart
  /// final projectSortProvider = dw.plugins.prefs.providerFamily<String, int>(
  ///   keyFor: (projectId) => 'project.$projectId.sort',
  ///   defaultValue: 'name',
  /// );
  ///
  /// final sort = ref.watch(projectSortProvider(project.id));
  /// ref.read(projectSortProvider(project.id).notifier).update('createdAt');
  /// ```
  ///
  /// [Arg] must be a value riverpod can compare — a `String`, an `int`, or any
  /// type with `==` and `hashCode`. Two arguments that are `==` share one
  /// provider; two that are not get one each, and their keys must differ too,
  /// which is [keyFor]'s job.
  DwPrefProviderFamily<T, Arg> providerFamily<T, Arg>({
    required String Function(Arg arg) keyFor,
    required T defaultValue,
  }) {
    return NotifierProvider.family<PrefNotifier<T>, T, Arg>((arg) {
      return PrefNotifier<T>(raw, keyFor(arg), defaultValue);
    });
  }

  /// [mappedProvider], but the key is built per argument — the enum-and-custom-
  /// type half of [providerFamily], whose doc explains why a family is the
  /// right tool for per-entity state.
  ///
  /// ```dart
  /// final projectViewProvider =
  ///     dw.plugins.prefs.mappedProviderFamily<ProjectView, int>(
  ///       keyFor: (projectId) => 'project.$projectId.view',
  ///       mapFrom: (raw) => ProjectView.values.byName(raw ?? 'list'),
  ///       mapTo: (view) => view.name,
  ///     );
  /// ```
  DwMappedPrefProviderFamily<T, Arg> mappedProviderFamily<T, Arg>({
    required String Function(Arg arg) keyFor,
    required T Function(String?) mapFrom,
    required String Function(T) mapTo,
  }) {
    return NotifierProvider.family<MappedPrefNotifier<T>, T, Arg>((arg) {
      return MappedPrefNotifier<T>(raw, keyFor(arg), mapFrom, mapTo);
    });
  }
}
