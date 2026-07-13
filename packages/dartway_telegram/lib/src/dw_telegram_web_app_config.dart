/// What to ask the Telegram WebApp for once it is ready.
class DwTelegramWebAppConfig {
  const DwTelegramWebAppConfig({
    this.disableVerticalSwipes = true,
    this.expand = true,
    this.requestFullScreen = false,
  });

  /// Stops a vertical drag inside the app from dismissing the Mini App.
  final bool disableVerticalSwipes;

  /// Expands the Mini App to the full available height on open.
  final bool expand;

  /// Requests fullscreen (Telegram 8.0+); ignored by older clients.
  final bool requestFullScreen;
}
