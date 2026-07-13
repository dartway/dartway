import 'package:flutter/widgets.dart';

import 'dw_telegram_web_app.dart';
import 'dw_telegram_web_app_config.dart';

/// Non-web implementation: there is no Telegram WebApp here, so everything
/// answers as if Telegram were absent. Lets an app wire Telegram once and still
/// build for mobile and desktop.
class DwTelegramWebAppImpl implements DwTelegramWebApp {
  const DwTelegramWebAppImpl();

  @override
  Future<void> init(DwTelegramWebAppConfig config) async {}

  @override
  bool get isRunningInTelegram => false;

  @override
  EdgeInsets get safeAreaInset => EdgeInsets.zero;

  @override
  int? get telegramUserId => null;
}
