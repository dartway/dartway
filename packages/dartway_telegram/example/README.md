# Example — a Telegram Mini App, and the same build in a browser

Declare the plugin once, at startup:

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

…and reach it anywhere:

```dart
if (dw.plugins.telegram.isRunningInTelegram) {
  final userId = dw.plugins.telegram.telegramUserId;
  final insets = dw.plugins.telegram.safeAreaInset; // the Telegram chrome, not the phone's
}
```

`dw.plugins.telegram` is an extension declared **in this package**, not in the framework. So you get the
ergonomics of an ambient service with none of the coupling: an app that is not a Mini App never
depends on this package, and never downloads a Telegram SDK.

## The same web build, opened in a normal browser

This is the case that breaks naive integrations: the JS bridge simply is not there, and every call
into it throws. Here it does not — `isRunningInTelegram` is false, `safeAreaInset` is zero,
`telegramUserId` is null, and the app runs.

```dart
// Works in Telegram and in Chrome, without an `if` at every call site.
Padding(
  padding: EdgeInsets.only(top: dw.plugins.telegram.safeAreaInset.top),
  child: content,
)
```

## Platform

```dart
// null outside Telegram; an unknown client is `other`, never silently "ios".
final platform = dw.plugins.telegram.platform; // DwTelegramPlatform?
```

(`dw` is the core instance your app declares once at startup — no DartWay package exports it as a
global.)
