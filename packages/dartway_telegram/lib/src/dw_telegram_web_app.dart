import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/widgets.dart';

import 'dw_telegram_platform.dart';
import 'dw_telegram_web_app_config.dart';
import 'dw_telegram_web_app_stub.dart'
    if (dart.library.js_interop) 'dw_telegram_web_app_web.dart';

/// The Telegram Mini App bridge, plugged into the app core.
///
/// [create] returns the real bridge on web and an inert stub everywhere else,
/// so an app wires Telegram once and still builds for mobile and desktop — and
/// on plain web, outside Telegram, every getter answers as if there were no
/// Telegram rather than throwing.
///
/// Declare it at startup and reach it anywhere as `dw.plugins.telegram`:
///
/// ```dart
/// DwCore(
///   config: DwConfig(...),
///   plugins: [
///     DwTelegramWebApp.create(
///       config: const DwTelegramWebAppConfig(requestFullScreen: true),
///     ),
///   ],
///   ...
/// );
///
/// // anywhere
/// final insets = dw.plugins.telegram.safeAreaInset;
/// ```
///
/// `dartway_flutter` knows nothing of Telegram: it knows only what a [DwPlugin]
/// is. The `dw.plugins.telegram` accessor is an extension declared *here*, so it
/// exists only for apps that chose this package.
abstract class DwTelegramWebApp implements DwPlugin {
  const DwTelegramWebApp();

  /// The platform implementation: the real bridge on web, an inert stub on
  /// mobile and desktop.
  ///
  /// A factory with a body rather than a redirecting one (`= Impl`) — Dart
  /// forbids default values on redirecting factories, and the default config is
  /// worth more than the brevity.
  factory DwTelegramWebApp.create({
    DwTelegramWebAppConfig config = const DwTelegramWebAppConfig(),
  }) => DwTelegramWebAppImpl(config: config);

  /// Announces the app to Telegram and applies the config. Called by the app
  /// core during bootstrap; safe outside Telegram, where it does nothing.
  @override
  Future<void> init();

  /// Whether the app really is running inside a Telegram Mini App — `false` on
  /// mobile, on desktop, and on plain web opened in a browser.
  bool get isRunningInTelegram;

  /// Which Telegram client the app runs in. `null` outside Telegram.
  ///
  /// Do not use this to detect the device: on plain web there is no Telegram to
  /// ask, and the answer is `null` even on an iPhone. Ask Flutter for the
  /// device and Telegram only for Telegram.
  DwTelegramPlatform? get platform;

  /// Insets reserved by the Telegram chrome. [EdgeInsets.zero] outside Telegram.
  EdgeInsets get safeAreaInset;

  /// The Telegram user id, when Telegram supplied one. `null` outside Telegram.
  ///
  /// It comes from `initDataUnsafe` and is **not** authenticated: a hint, never
  /// a proof of identity. Verifying the init-data signature is the server's job.
  int? get telegramUserId;
}

/// Reaches the bridge from anywhere: `dw.plugins.telegram.safeAreaInset`.
///
/// Declared in this package rather than in the framework — that is what keeps
/// `DwConfig` free of vendor names while the app still gets an ambient
/// accessor.
extension DwTelegramAccess on DwPlugins {
  DwTelegramWebApp get telegram => of<DwTelegramWebApp>();
}
