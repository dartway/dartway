import 'package:flutter/widgets.dart';

import 'dw_telegram_platform.dart';
import 'dw_telegram_web_app.dart';
import 'dw_telegram_web_app_config.dart';

/// Non-web implementation: there is no Telegram WebApp here, so everything
/// answers as if Telegram were absent. Lets an app declare the plugin once and
/// still build for mobile and desktop.
class DwTelegramWebAppImpl extends DwTelegramWebApp {
  const DwTelegramWebAppImpl({required this.config});

  final DwTelegramWebAppConfig config;

  @override
  Future<void> init() async {}

  @override
  bool get isRunningInTelegram => false;

  @override
  DwTelegramPlatform? get platform => null;

  @override
  EdgeInsets get safeAreaInset => EdgeInsets.zero;

  @override
  int? get telegramUserId => null;
}
