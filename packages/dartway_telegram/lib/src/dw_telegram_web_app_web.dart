import 'package:flutter/widgets.dart';
import 'package:telegram_web_app/telegram_web_app.dart';

import 'dw_telegram_web_app.dart';
import 'dw_telegram_web_app_config.dart';

/// Web implementation, talking to the Telegram WebApp JS bridge.
///
/// Every access is guarded. On plain web — the same build, just opened in a
/// browser rather than in Telegram — the bridge is absent and touching it
/// throws instead of answering "no". An app should not have to know that.
class DwTelegramWebAppImpl implements DwTelegramWebApp {
  const DwTelegramWebAppImpl();

  @override
  bool get isRunningInTelegram {
    try {
      return TelegramWebApp.instance.isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> init(DwTelegramWebAppConfig config) async {
    if (!isRunningInTelegram) return;

    // The WebApp object can exist before Telegram has handed over the viewport,
    // and the calls below throw until it has — so give it a few chances.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        TelegramWebApp.instance.ready();
        await Future<void>.delayed(Duration(milliseconds: 100 * attempt));

        if (config.disableVerticalSwipes) {
          TelegramWebApp.instance.disableVerticalSwipes();
        }
        if (config.expand) {
          TelegramWebApp.instance.expand();
        }
        if (config.requestFullScreen) {
          TelegramWebApp.instance.requestFullscreen();
        }

        return;
      } catch (error) {
        debugPrint(
          'Telegram WebApp init attempt ${attempt + 1} failed: $error',
        );
      }
    }
  }

  @override
  EdgeInsets get safeAreaInset {
    if (!isRunningInTelegram) return EdgeInsets.zero;

    try {
      final insets = TelegramWebApp.instance.safeAreaInset;
      return EdgeInsets.fromLTRB(
        insets.left.toDouble(),
        insets.top.toDouble(),
        insets.right.toDouble(),
        insets.bottom.toDouble(),
      );
    } catch (_) {
      return EdgeInsets.zero;
    }
  }

  @override
  int? get telegramUserId {
    if (!isRunningInTelegram) return null;

    try {
      return TelegramWebApp.instance.initDataUnsafe?.user?.id;
    } catch (_) {
      return null;
    }
  }
}
