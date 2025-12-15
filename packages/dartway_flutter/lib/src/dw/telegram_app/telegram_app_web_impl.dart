import 'package:flutter/widgets.dart';
import 'package:telegram_web_app/telegram_web_app.dart';

import '../configs/dw_telegram_web_app_config.dart';
import 'telegram_app.dart';

// import 'dart:js_util' as js_util;
// import 'package:web/web.dart' as web;

// bool get _isTelegramJsLoaded {
//   try {
//     final tg = js_util.getProperty(web.window, 'Telegram');
//     if (tg == null) return false;

//     final webApp = js_util.getProperty(tg, 'WebApp');
//     return webApp != null;
//   } catch (_) {
//     return false;
//   }
// }

class TelegramAppImpl implements TelegramApp {
  const TelegramAppImpl();

  @override
  Future<void> init(DwTelegramWebAppConfig telegramWebAppConfig) async {
    print('starting TelegramAppImpl init');

    try {
      if (!TelegramWebApp.instance.isSupported) return;
    } catch (_) {
      return; // при ошибке — значит не в Telegram
    }

    // Try to initialize Telegram WebApp with retries in case it is not ready yet
    for (var i = 0; i < 3; i++) {
      try {
        TelegramWebApp.instance.ready();
        await Future.delayed(Duration(milliseconds: 100 * i));
        if (telegramWebAppConfig.disableVerticalSwipes) {
          TelegramWebApp.instance.disableVerticalSwipes();
        }
        if (telegramWebAppConfig.expand) {
          TelegramWebApp.instance.expand();
        }
        if (telegramWebAppConfig.requestFullScreen) {
          TelegramWebApp.instance.requestFullscreen();
        }

        return;
      } catch (e) {
        debugPrint("Telegram WebApp init error: $e");
      }
    }
  }

  @override
  EdgeInsets get safeAreaInset {
    final insets = TelegramWebApp.instance.safeAreaInset;
    return EdgeInsets.fromLTRB(
      insets.left.toDouble(),
      insets.top.toDouble(),
      insets.right.toDouble(),
      insets.bottom.toDouble(),
    );
  }

  @override
  int? get telegramUserId => TelegramWebApp.instance.initDataUnsafe?.user?.id;
}
