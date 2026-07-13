# Changelog

## 0.1.0

- First release. Telegram Mini App integration extracted from `dartway_flutter`:
  `DwTelegramWebApp` (init, `isRunningInTelegram`, `safeAreaInset`,
  `telegramUserId`) and `DwTelegramWebAppConfig`.
- **Optional by construction.** `dartway_flutter` no longer carries
  `telegram_web_app` as a dependency, nor `DwConfig.telegramWebAppConfig`, nor
  `dw.services.telegramWebApp`: the framework's config has no business knowing a
  vendor's name, and an app that is not a Mini App should not download a Telegram
  SDK to get a bootstrap runner. This package does not depend on
  `dartway_flutter` either — the app wires the two together through
  `DwAppRunner.appInitializers`.
- Fixed on the way out: outside Telegram — on plain web, the same build opened in
  a browser — `safeAreaInset` and `telegramUserId` reached into an absent JS
  bridge and threw. Every access is now guarded and answers as if Telegram were
  absent; `isRunningInTelegram` says which world the app is in.
