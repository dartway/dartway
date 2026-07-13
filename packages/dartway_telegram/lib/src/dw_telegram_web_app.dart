import 'package:flutter/widgets.dart';

import 'dw_telegram_web_app_config.dart';
import 'dw_telegram_web_app_stub.dart'
    if (dart.library.js_interop) 'dw_telegram_web_app_web.dart';

/// The Telegram Mini App bridge.
///
/// [create] returns the real bridge on web and an inert stub everywhere else,
/// so an app can wire Telegram unconditionally and still run on mobile and
/// desktop — and on plain web, outside Telegram, every getter answers as if
/// there were no Telegram, rather than throwing.
///
/// It is deliberately not wired into `DwConfig`: the framework has no business
/// knowing a vendor's name. An app that wants Telegram holds the instance and
/// initializes it through `DwAppRunner.appInitializers`:
///
/// ```dart
/// final telegram = DwTelegramWebApp.create();
///
/// DwAppRunner(
///   appInitializers: [
///     () => telegram.init(const DwTelegramWebAppConfig()),
///   ],
///   child: const MyApp(),
/// ).run();
/// ```
abstract class DwTelegramWebApp {
  const DwTelegramWebApp();

  factory DwTelegramWebApp.create() = DwTelegramWebAppImpl;

  /// Announces the app to Telegram and applies [config]. Safe to call outside
  /// Telegram — it detects that and does nothing.
  Future<void> init(DwTelegramWebAppConfig config);

  /// Whether the app really is running inside a Telegram Mini App. `false` on
  /// mobile, desktop, and on plain web opened in a browser.
  bool get isRunningInTelegram;

  /// Insets reserved by the Telegram chrome. [EdgeInsets.zero] outside Telegram.
  EdgeInsets get safeAreaInset;

  /// The Telegram user id, when Telegram supplied one. `null` outside Telegram.
  ///
  /// This comes from `initDataUnsafe` and is **not** authenticated: treat it as
  /// a hint, never as proof of identity. Verifying the init-data signature is
  /// the server's job.
  int? get telegramUserId;
}
