import 'package:flutter/widgets.dart';

import '../configs/dw_telegram_web_app_config.dart';

export 'telegram_app_stub.dart'
    if (dart.library.js_interop) 'telegram_app_web_impl.dart';

/// Unified entry point for Telegram WebApp integration.
abstract class TelegramApp {
  const TelegramApp();

  Future<void> init(DwTelegramWebAppConfig telegramWebAppConfig);

  EdgeInsets get safeAreaInset;

  int? get telegramUserId;
}
