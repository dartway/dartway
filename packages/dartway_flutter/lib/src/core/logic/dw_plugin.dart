/// An integration plugged into the app core at bootstrap.
///
/// The framework knows what a plugin *is* — never what any particular one
/// *does*. That is the whole point: `DwConfig` must not grow a field named
/// after a vendor, and an app that does not use an integration must not carry
/// its dependency.
///
/// A plugin is declared once (`DwFlutter(plugins: [...])`), initialized with the
/// app, and reached through [DwPlugins] (`dw.plugins`). Integration packages
/// build their own accessor on top, so the app writes `dw.plugins.telegram`
/// rather than a lookup — the ergonomics of an ambient service, with none of
/// the coupling:
///
/// ```dart
/// // in the integration package, not in the framework
/// extension DwTelegramAccess on DwPlugins {
///   DwTelegramWebApp get telegram => of<DwTelegramWebApp>();
/// }
/// ```
abstract class DwPlugin {
  const DwPlugin();

  /// Runs once during `dw.init()`, in the order the plugins were declared.
  Future<void> init();
}

/// The plugins a project has connected, reached as `dw.plugins`.
///
/// This is the namespace for extensions — kept apart from the core's own
/// services (`dw.notify`, `dw.action`, `dw.confirm`). `dw.` is the closed,
/// known core; `dw.plugins.` is the open set a project plugs in. An integration
/// package adds a named accessor here (`dw.plugins.telegram`, `dw.plugins.prefs`)
/// via `extension on DwPlugins`.
class DwPlugins {
  DwPlugins(this._plugins);

  final List<DwPlugin> _plugins;

  /// The registered plugin of type [T]. Throws if none is registered.
  T of<T extends DwPlugin>() {
    for (final plugin in _plugins) {
      if (plugin is T) return plugin;
    }
    throw StateError(
      'No $T is registered. Declare it at startup: '
      'DwFlutter(plugins: [...]) — or DwCore with the data layer.',
    );
  }

  /// Initializes every plugin once, in declaration order. Called by `dw.init()`.
  Future<void> initAll() async {
    for (final plugin in _plugins) {
      await plugin.init();
    }
  }
}
