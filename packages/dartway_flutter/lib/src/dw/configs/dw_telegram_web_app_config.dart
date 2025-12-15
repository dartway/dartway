class DwTelegramWebAppConfig {
  const DwTelegramWebAppConfig({
    this.disableVerticalSwipes = true,
    this.expand = true,
    this.requestFullScreen = false,
  });

  final bool disableVerticalSwipes;
  final bool expand;
  final bool requestFullScreen;
}
