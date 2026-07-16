# DartWay Telegram

Telegram Mini App integration for [DartWay](https://dartway.dev) apps: announce
the app to Telegram, apply the viewport options, and read the safe-area insets,
the client platform and the Telegram user id.

## A plugin, not a framework feature

`dartway_flutter` knows nothing about Telegram — it knows only what a `DwPlugin`
is. The framework's config has no business carrying a vendor's name, and an app
that is not a Mini App should not download a Telegram SDK to get a bootstrap
runner.

Declare the plugin at startup:

```dart
DwFlutter(
  config: DwConfig(/* ... */),
  plugins: [
    DwTelegramWebApp.create(
      config: const DwTelegramWebAppConfig(requestFullScreen: true),
    ),
  ],
);
```

…and reach it anywhere as `dw.plugins.telegram`:

```dart
final insets = dw.plugins.telegram.safeAreaInset;

if (dw.plugins.telegram.isRunningInTelegram) { ... }
```

That accessor is an extension declared **in this package**, not in the
framework. So you get the ergonomics of an ambient service with none of the
coupling: `dw.plugins.telegram` exists only for apps that chose Telegram.

(`dw` itself is the core instance your app declares once at startup — no DartWay package
exports it as a global.)

## Everywhere else it is inert

`DwTelegramWebApp.create()` returns the real bridge on web and a stub on mobile
and desktop, so you declare Telegram once and still ship every platform.

And on plain web — the same build, just opened in a browser instead of in
Telegram — every getter answers as if Telegram were absent rather than throwing.
`isRunningInTelegram` tells you which world you are in.

## Do not ask Telegram about the device

`platform` is *Telegram's* client, not the user's device. Outside Telegram there
is no Telegram to ask, and the answer is `null` — even on an iPhone. Ask Flutter
for the device and Telegram only for Telegram:

```dart
bool get isIOS => dw.plugins.telegram.isRunningInTelegram
    ? dw.plugins.telegram.platform == DwTelegramPlatform.ios
    : defaultTargetPlatform == TargetPlatform.iOS;
```

Getting this backwards is a classic: an app asks Telegram for the platform on
web, gets `false` in Safari on an iPhone, and quietly serves the wrong controls.

## `telegramUserId` is a hint, not a proof

It comes from Telegram's `initDataUnsafe` and is not authenticated. Use it to
personalize; never to authorize. Verifying the init-data signature belongs on
the server.

## Configuration

```dart
const DwTelegramWebAppConfig(
  disableVerticalSwipes: true,   // a vertical drag should not dismiss the app
  expand: true,                  // open at full height
  requestFullScreen: false,      // Telegram 8.0+; older clients ignore it
)
```
