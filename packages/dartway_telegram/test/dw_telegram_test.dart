import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_telegram/dartway_telegram.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwTelegramPlatform.fromRaw', () {
    test('maps the clients Telegram reports today', () {
      expect(DwTelegramPlatform.fromRaw('ios'), DwTelegramPlatform.ios);
      expect(DwTelegramPlatform.fromRaw('android'), DwTelegramPlatform.android);
      expect(DwTelegramPlatform.fromRaw('macos'), DwTelegramPlatform.macos);
      expect(DwTelegramPlatform.fromRaw('tdesktop'), DwTelegramPlatform.desktop);
      expect(DwTelegramPlatform.fromRaw('weba'), DwTelegramPlatform.web);
    });

    test('a client Telegram adds later becomes `other`, never a guess', () {
      // The whole point: a value we have not seen must not silently land on
      // `ios` and hand the app the wrong layout.
      expect(DwTelegramPlatform.fromRaw('visionos'), DwTelegramPlatform.other);
      expect(DwTelegramPlatform.fromRaw('unknown'), DwTelegramPlatform.other);
      expect(DwTelegramPlatform.fromRaw(''), DwTelegramPlatform.other);
    });
  });

  group('off Telegram', () {
    // The test target is the VM, so `create()` hands back the stub — the same
    // one a mobile or desktop build gets.
    final telegram = DwTelegramWebApp.create();

    test('answers as if there were no Telegram, rather than throwing', () {
      expect(telegram.isRunningInTelegram, isFalse);
      expect(telegram.platform, isNull);
      expect(telegram.telegramUserId, isNull);
      expect(telegram.safeAreaInset, EdgeInsets.zero);
    });

    test('init is a no-op, so an app can declare it on every platform', () {
      expect(telegram.init(), completes);
    });
  });

  group('as a plugin', () {
    final telegram = DwTelegramWebApp.create(
      config: const DwTelegramWebAppConfig(requestFullScreen: true),
    );

    // One DwFlutter per test process — the singleton forbids re-creation.
    final dwInstance = DwFlutter(
      config: const DwConfig(useSharedPreferences: false),
      plugins: [telegram],
    );

    test('is reachable as dw.telegram', () {
      // The bridge the app declares is an interface; the object it gets is a
      // platform impl. `dw.telegram` has to resolve the former to the latter —
      // this is the whole contract behind the extension.
      expect(dwInstance.telegram, same(telegram));
    });

    test('the framework initializes it with the app core', () {
      expect(dwInstance.init(), completes);
    });
  });
}
