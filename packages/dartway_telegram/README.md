# DartWay Telegram

Telegram Mini App integration for [DartWay](https://dartway.dev) apps: announce
the app to Telegram, apply the viewport options, and read the safe-area insets
and the Telegram user id.

## Optional by construction

`dartway_flutter` knows nothing about Telegram — the framework has no business
carrying a vendor's name in its config, and an app that is not a Mini App should
not download a Telegram SDK to get a bootstrap runner.

So this package stands alone: it does not even depend on `dartway_flutter`. The
app owns the bridge and starts it through the bootstrap seam it already has.

```dart
final telegram = DwTelegramWebApp.create();

void main() {
  DwAppRunner(
    appInitializers: [
      () => telegram.init(const DwTelegramWebAppConfig()),
    ],
    child: const MyApp(),
  ).run();
}
```

Expose it to the widget tree the same way you expose anything else — a Riverpod
provider:

```dart
final telegramProvider = Provider((ref) => telegram);
```

## Everywhere else it is inert

`DwTelegramWebApp.create()` returns the real bridge on web and a stub on mobile
and desktop, so you wire Telegram once and still ship every platform.

And on plain web — the same build, just opened in a browser instead of in
Telegram — every getter answers as if Telegram were absent rather than throwing.
`isRunningInTelegram` tells you which world you are in:

```dart
final padding = telegram.isRunningInTelegram
    ? telegram.safeAreaInset
    : EdgeInsets.zero;   // the getter already returns zero, but say what you mean
```

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
