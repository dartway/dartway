part of '../dw.dart';

class _DwServices {
  _DwServices._();

  // static final _DwServices _instance = _DwServices._();

  // static _DwServices get i => _instance;

  late SharedPreferences _prefs;
  SharedPreferences get sharedPreferences => _prefs;

  late final TelegramApp _telegramWebApp;
  TelegramApp get telegramWebApp => _telegramWebApp;

  // DotEnv get dotEnv => dotenv;

  _init({required DwConfig config}) async {
    if (config.useSharedPreferences) {
      _prefs = await SharedPreferences.getInstance();
    }

    if (config.telegramWebAppConfig != null) {
      _telegramWebApp = const TelegramAppImpl();
      await _telegramWebApp.init(config.telegramWebAppConfig!);
    }

    // if (config.flutterDotEnvFile != null) {
    //   await dotenv.load(fileName: config.flutterDotEnvFile!);
    // }
  }
}
