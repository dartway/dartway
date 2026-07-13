/// Which Telegram client the Mini App is running in.
enum DwTelegramPlatform {
  android,
  ios,
  macos,
  desktop,
  web,

  /// A client Telegram introduced after this package was written. Mapped here
  /// rather than guessed at — a new value must not silently become `ios` and
  /// hand the app the wrong layout.
  other;

  static DwTelegramPlatform fromRaw(String raw) => switch (raw.toLowerCase()) {
    'android' => android,
    'ios' => ios,
    'macos' => macos,
    'tdesktop' => desktop,
    'web' || 'weba' || 'webk' => web,
    _ => other,
  };
}
