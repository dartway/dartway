## 0.1.0

First release: RuStore behind the `DwPushClientProvider` contract, with the Android side an app
used to have to write itself.

- A messaging service that persists each message's payload on arrival and renders data-only
  messages — including the picture ones, which RuStore shows as nothing at all otherwise.
- Notification taps through `ActivityAware`/`onNewIntent`: no `MainActivity` override, and no list
  of payload keys duplicated in Kotlin.
- The Android 13 notification permission, requested natively rather than through an extra package.
- Appearance (icon, colour, channel) read from the app's manifest meta-data.
