/// An integration plugged into the app core at bootstrap.
///
/// The framework knows what a plugin *is* — never what any particular one
/// *does*. That is the whole point: `DwConfig` must not grow a field named
/// after a vendor, and an app that does not use an integration must not carry
/// its dependency.
///
/// A plugin is declared once, initialized with the app, and reached from
/// anywhere through [DwFlutter.plugin]. Integration packages build their own
/// accessor on top of that, so the app writes `dw.telegram` rather than a
/// lookup — the ergonomics of an ambient service, with none of the coupling:
///
/// ```dart
/// // in the integration package, not in the framework
/// extension DwTelegramAccess on DwFlutter {
///   DwTelegramWebApp get telegram => plugin<DwTelegramWebApp>();
/// }
/// ```
abstract class DwPlugin {
  const DwPlugin();

  /// Runs once during `dw.init()`, in the order the plugins were declared.
  Future<void> init();
}
