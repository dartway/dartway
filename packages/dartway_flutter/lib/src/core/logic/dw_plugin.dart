import '../dw_flutter.dart';

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
///
/// [init] hands the plugin the core it was plugged into, because until that
/// moment there is nothing for it to reach: the ambient `dw` is the app's own
/// `late final` variable, and a plugin is constructed as an argument to the
/// constructor that assigns it. Reading `dw` from inside a `plugins: [...]`
/// list compiles and throws `LateInitializationError` at startup.
///
/// The argument is a [DwFlutter]. An app built on the data layer passes a
/// `DwCore`, which is one — a plugin that needs the data layer names it and
/// casts, and thereby says out loud that it does not work on the plain
/// toolbox.
abstract class DwPlugin {
  const DwPlugin();

  /// Runs once during `dw.init()`, in declaration order, with the core this
  /// plugin was plugged into. A plugin is built *before* `dw` exists — that is
  /// what `plugins:` being a constructor argument means — so this is the first
  /// moment it may look at anything.
  Future<void> init(DwFlutter core);

  /// Whether a failure in [init] must stop the application from starting.
  ///
  /// True by default, and deliberately: a plugin an app declared is one it
  /// expects to have, and an app running without it is an app whose features
  /// fail one by one, later and further from the cause. Starting anyway is a
  /// decision, and it is made here, by the plugin that knows whether it is
  /// load-bearing.
  ///
  /// Set it to false where the integration is genuinely optional — analytics,
  /// a chat widget, anything whose absence costs its own feature and nothing
  /// else. The failure is then reported once through the error pipeline,
  /// naming the plugin, and the app starts without it.
  ///
  /// The name says what happens rather than how important the plugin feels:
  /// "required" invites an argument about importance, and the only question
  /// that has an answer here is whether the app may start.
  bool get blocksStartup => true;
}

/// A plugin's `init` threw, with the plugin named.
///
/// The raw exception out of an integration says nothing about plugins: it is a
/// null check inside a third-party package, and neither the plugin, nor its
/// position in the list, nor initialization appears anywhere in it. That is
/// what a whole app start cost once, and the report was as unhelpful as the
/// outcome.
class DwPluginInitException implements Exception {
  const DwPluginInitException(this.plugin, this.cause);

  /// The plugin whose [DwPlugin.init] threw.
  final Type plugin;

  /// What it threw.
  final Object cause;

  @override
  String toString() => '$plugin failed to initialize: $cause';
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

  /// Plugins whose [DwPlugin.init] threw, by identity, with what it threw.
  ///
  /// Kept because a failed plugin is not an absent one, and its `late final`
  /// fields are unset: reaching for it must say what happened, not die on a
  /// `LateInitializationError` from inside it — further from the cause than
  /// the crash it replaced.
  final Map<DwPlugin, Object> _failures = {};

  /// The registered plugin of type [T], or `null` when the app connected none.
  ///
  /// For a *role* the framework can ask about but must not require — a local
  /// store for the data layer, say. [of] is for an app reaching for its own
  /// integration, where absence is a wiring mistake; this is for the framework
  /// asking whether anybody took a job, where absence is an ordinary answer.
  ///
  /// Two plugins claiming one role is not an ordinary answer, and picking the
  /// first quietly would decide something the app did not: it throws.
  /// A plugin that failed to start is **not** a claimant here. It was declared,
  /// it did not survive, and its failure was already reported at init — so the
  /// framework gets the honest answer that nobody holds the role, and the app
  /// that allowed the failure ([DwPlugin.blocksStartup] false) gets the
  /// degradation it asked for rather than a second crash later.
  T? maybeOf<T extends DwPlugin>() {
    T? claimant;
    for (final plugin in _plugins) {
      if (plugin is! T) continue;
      if (_failures.containsKey(plugin)) continue;
      if (claimant != null) {
        throw StateError(
          'Two plugins claim the $T role: $claimant and $plugin. '
          'Declare exactly one at startup.',
        );
      }
      claimant = plugin;
    }
    return claimant;
  }

  /// The registered plugin of type [T]. Throws if none is registered.
  ///
  /// A plugin that failed to start throws too, naming the plugin and the
  /// failure. This is an app reaching for its own integration: absence is a
  /// wiring mistake and a corpse is worse, because its fields are unset and
  /// the first touch would raise a `LateInitializationError` from inside the
  /// package, with nothing naming startup.
  T of<T extends DwPlugin>() {
    for (final plugin in _plugins) {
      if (plugin is! T) continue;
      final failure = _failures[plugin];
      if (failure != null) {
        throw StateError(
          '$T failed to initialize: $failure. It declared '
          'blocksStartup = false, so the app started without it — this '
          'feature cannot run until the failure is fixed or handled.',
        );
      }
      return plugin;
    }
    throw StateError(
      'No $T is registered. Declare it at startup: '
      'DwFlutter(plugins: [...]) — or DwCore with the data layer.',
    );
  }

  /// Initializes every plugin once, in declaration order, handing each the
  /// [core] it was declared on. Called by `dw.init()`, which passes itself.
  ///
  /// **One plugin's failure is contained to that plugin.** Before, nothing
  /// separated them: a single `init` that threw aborted `dw.init()`, so every
  /// plugin declared after it never ran and the application did not start at
  /// all. Declaration order silently decided the blast radius, which is not
  /// something an app author weighs while writing `plugins: [...]`.
  ///
  /// What a failure costs is now the plugin's own answer
  /// ([DwPlugin.blocksStartup]), and either way the report names it: a blocking
  /// failure travels on as [DwPluginInitException] and is reported once, by
  /// whoever catches an uncaught error; a non-blocking one goes through the
  /// error pipeline here and the loop carries on.
  Future<void> initAll(DwFlutter core) async {
    for (final plugin in _plugins) {
      try {
        await plugin.init(core);
      } catch (error, stackTrace) {
        _failures[plugin] = error;
        final named = DwPluginInitException(plugin.runtimeType, error);
        if (plugin.blocksStartup) {
          // Rethrown rather than reported here: reporting *and* rethrowing
          // puts the same failure in the log twice, once from us and once
          // from the zone handler that will see it a moment later.
          Error.throwWithStackTrace(named, stackTrace);
        }
        // Reported with the default source. A dedicated `DwErrorSource`
        // value would label it better, and it is left out on purpose: the
        // enum is switched over exhaustively in the core package, so adding
        // one is a lockstep version move of four packages — a release
        // decision, not part of this fix.
        core.handleError(named, stackTrace);
      }
    }
  }
}
