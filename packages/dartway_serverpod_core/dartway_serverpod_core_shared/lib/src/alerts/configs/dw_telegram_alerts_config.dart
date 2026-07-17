import 'dw_telegram_alerts_keys.dart';

class DwTelegramAlertsConfig {
  final String alertsChatId;
  final String alertsToken;
  final String? alertsMessageThreadId;

  DwTelegramAlertsConfig({
    required this.alertsChatId,
    required this.alertsToken,
    this.alertsMessageThreadId,
  });

  /// Builds the config from [env] (typically the app's `passwords.yaml`).
  ///
  /// Returns null when the chat id or the token is missing — alerts then
  /// degrade to logging instead of failing the boot. Pass [logFunction] to hear
  /// about it; the library never writes to stdout on its own.
  static DwTelegramAlertsConfig? fromEnv({
    required Map<String, String> env,
    void Function(String message)? logFunction,
  }) {
    if (env[DwTelegramAlertsKeys.dwTelegramAlertsChatIdKey] == null ||
        env[DwTelegramAlertsKeys.dwTelegramAlertsChatIdKey]!.isEmpty ||
        env[DwTelegramAlertsKeys.dwTelegramAlertsTokenKey] == null ||
        env[DwTelegramAlertsKeys.dwTelegramAlertsTokenKey]!.isEmpty) {
      logFunction?.call(
        'DwTelegramAlertsConfig.fromEnv: '
        '${DwTelegramAlertsKeys.dwTelegramAlertsChatIdKey} and '
        '${DwTelegramAlertsKeys.dwTelegramAlertsTokenKey} are required — '
        'Telegram alerts stay off.',
      );
      return null;
    }

    return DwTelegramAlertsConfig(
      alertsChatId: env[DwTelegramAlertsKeys.dwTelegramAlertsChatIdKey]!,
      alertsToken: env[DwTelegramAlertsKeys.dwTelegramAlertsTokenKey]!,
      alertsMessageThreadId:
          env[DwTelegramAlertsKeys.dwTelegramAlertsMessageThreadIdKey],
    );
  }
}
