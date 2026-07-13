# Changelog

## 0.1.0

- First release. Telegram Mini App integration extracted from `dartway_flutter`:
  `DwTelegramWebApp` (`init`, `isRunningInTelegram`, `platform`, `safeAreaInset`,
  `telegramUserId`), `DwTelegramWebAppConfig` and `DwTelegramPlatform`.
- **A plugin, not a framework feature.** `dartway_flutter` no longer carries
  `telegram_web_app` as a dependency, nor `DwConfig.telegramWebAppConfig`, nor
  `dw.services.telegramWebApp`. It knows only what a `DwPlugin` is. The app
  declares `DwCore(plugins: [DwTelegramWebApp.create(...)])` and reaches the
  bridge as `dw.telegram` — an extension declared *in this package*, so the
  ambient accessor exists only for apps that chose Telegram.
- `platform` reports the Telegram client, and an unrecognized one maps to
  `DwTelegramPlatform.other` rather than silently becoming something else.
- Fixed on the way out of the framework: outside Telegram — on plain web, the
  same build opened in a browser — `safeAreaInset` and `telegramUserId` reached
  into an absent JS bridge and threw. Every access is now guarded and answers as
  if Telegram were absent; `isRunningInTelegram` says which world the app is in.
