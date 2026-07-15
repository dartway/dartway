# Changelog

## 0.1.0

First public release — Telegram Mini App integration for DartWay apps.

`DwTelegramWebApp` initializes the Telegram WebApp and exposes what an app actually needs from it:
`isRunningInTelegram`, `platform`, `safeAreaInset` (the Telegram chrome, not the phone's) and
`telegramUserId`. Configured with `DwTelegramWebAppConfig`.

**A plugin, not a framework feature.** The framework's config has no business knowing a vendor's
name, and an app that is not a Mini App should not download a Telegram SDK to get a bootstrap
runner. You declare `DwCore(plugins: [DwTelegramWebApp.create(...)])` and reach the bridge as
`dw.plugins.telegram` — an extension declared *in this package*, so the ambient accessor exists only for the
apps that chose Telegram.

**The same build works in a plain browser.** Outside Telegram the JS bridge is simply absent, which
is where naive integrations throw. Here every access is guarded and answers as if Telegram were not
there; `isRunningInTelegram` says which world the app is in. An unrecognized Telegram client maps to
`DwTelegramPlatform.other` rather than silently becoming something else.
