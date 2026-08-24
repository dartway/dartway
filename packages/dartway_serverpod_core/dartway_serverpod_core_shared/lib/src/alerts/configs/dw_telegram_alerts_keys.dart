/// Keys the Telegram alerts sink reads from the server's `passwords.yaml`.
///
/// The values are the literal key names an app writes in that file — renaming
/// one breaks every deployment that already has it.
class DwTelegramAlertsKeys {
  static const dwTelegramAlertsChatIdKey = 'dwTelegramAlertsChatId';
  static const dwTelegramAlertsTokenKey = 'dwTelegramAlertsToken';
  static const dwTelegramAlertsMessageThreadIdKey =
      'dwTelegramAlertsMessageThreadId';

  /// The outbound proxy alerts are sent through, as
  /// `http://user:pass@host:port` (credentials optional).
  ///
  /// Read by `DwProxyHttpClient.fromEnv` on the server. Absent — the normal
  /// case — alerts go to Telegram directly. It lives here, beside the keys the
  /// config itself reads, because the proxy is part of the same `passwords.yaml`
  /// block and the two drift apart the moment they are named in two places.
  static const dwTelegramAlertsProxyUrlKey = 'dwTelegramAlertsProxyUrl';
}
