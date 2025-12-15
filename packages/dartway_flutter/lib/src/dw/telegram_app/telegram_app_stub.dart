import 'package:flutter/widgets.dart';

import '../configs/dw_telegram_web_app_config.dart';
import 'telegram_app.dart';

class TelegramAppImpl implements TelegramApp {
  const TelegramAppImpl();

  @override
  Future<void> init(DwTelegramWebAppConfig telegramWebAppConfig) async {}

  @override
  EdgeInsets get safeAreaInset => EdgeInsets.zero;

  @override
  int? get telegramUserId => null;
}
