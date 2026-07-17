/// Keys `DwTelegramAlertsConfig.fromEnv` reads from the server's
/// `passwords.yaml`.
///
/// The values are the literal key names an app writes in that file — renaming
/// one breaks every deployment that already has it.
class DwTelegramAlertsKeys {
  static const dwTelegramAlertsChatIdKey = 'dwTelegramAlertsChatId';
  static const dwTelegramAlertsTokenKey = 'dwTelegramAlertsToken';
  static const dwTelegramAlertsMessageThreadIdKey =
      'dwTelegramAlertsMessageThreadId';
}
