import 'dw_plugin.dart';

/// The plugin that gives the framework somewhere to keep a few small values.
///
/// A **role**, not a vendor: the framework needs an auth key to survive a
/// reload and has no opinion about what stores it. Declared here so both sides
/// can name it without either depending on the other — the same shape as
/// `DwRepoLocalStorePlugin`, which the data layer asks for through
/// [DwPlugins.maybeOf].
///
/// ```dart
/// dw = DwCore(
///   config: ..., client: ...,
///   plugins: [DwSharedPreferences()],
/// );
/// ```
///
/// **Why a role and not a direct call.** The core used to reach for
/// `shared_preferences` itself, in its own copy of this contract, while a
/// plugin existed for exactly that job. Two implementations of one thing: they
/// answered from the same store by coincidence rather than by design, and a
/// decision made on one side — a fallback, a failure mode — could not be seen
/// from the other. One implementation, named through this role, is the whole
/// point of the change.
///
/// Only one plugin may claim the role. Two is a wiring mistake, and
/// [DwPlugins.maybeOf] reports it rather than picking one.
abstract class DwKeyValueStorePlugin extends DwPlugin {
  const DwKeyValueStorePlugin();

  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<void> remove(String key);

  /// Whether what is written here outlives the session.
  ///
  /// False where the store fell back to memory — a browser with no local
  /// storage, say. The app is running and remembering nothing, which is a fact
  /// it has to be able to state: a login that will not stick is worth
  /// explaining, and looks like a bug when it is not explained.
  bool get isPersistent;
}
