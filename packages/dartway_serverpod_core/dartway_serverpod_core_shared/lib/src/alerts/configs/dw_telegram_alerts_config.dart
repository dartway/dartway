import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';

class DwTelegramAlertsConfig {
  late final String alertsChatId;
  late final String alertsToken;
  late final String? alertsMessageThreadId;

  DwTelegramAlertsConfig({
    required this.alertsChatId,
    required this.alertsToken,
    required this.alertsMessageThreadId,
  });

  static DwTelegramAlertsConfig? fromEnv({required Map<String, String> env}) {
    if (env[DwConfigurationKeys.dwTelegramAlertsChatIdKey] == null ||
        env[DwConfigurationKeys.dwTelegramAlertsChatIdKey]!.isEmpty ||
        env[DwConfigurationKeys.dwTelegramAlertsTokenKey] == null ||
        env[DwConfigurationKeys.dwTelegramAlertsTokenKey]!.isEmpty) {
      // TODO: заменить на log function
      print(
        'DwTelegramAlertsConfig.fromEnv: env doesn\'t contain all required keys',
      );
      return null;
    }

    return DwTelegramAlertsConfig(
      alertsChatId: env[DwConfigurationKeys.dwTelegramAlertsChatIdKey]!,
      alertsToken: env[DwConfigurationKeys.dwTelegramAlertsTokenKey]!,
      alertsMessageThreadId:
          env[DwConfigurationKeys.dwTelegramAlertsMessageThreadIdKey],
    );
  }
}
