# dartway_push_rustore

RuStore as a transport for [`dartway_push_flutter`](https://pub.dev/packages/dartway_push_flutter) —
Android only, inert everywhere else.

```dart
DwPush(
  config: DwPushConfig(
    providers: [DwRuStorePush(), DwFirebasePush()],
    // ...
  ),
)
```

Declared first, it takes Android and stands aside on iOS and web; on an Android device without the
RuStore app it stands aside too and the next transport gets its turn.

## What this package carries so your app does not

- **The messaging service.** RuStore delivers to exactly one, and it must do two things the SDK's
  own does not: write the payload down before showing the notification — the tap may come back
  hours later to a process that no longer exists — and draw a notification for a **data-only**
  message, which the SDK leaves invisible.
- **That renderer.** The server sends a message with a picture as data only, because RuStore
  ignores an image in a notification block. The notification appears as text at once and upgrades
  to the picture when it has been fetched — bounded to HTTPS, 1 MB and 1600 px, in the app's own
  process.
- **The tap.** `ActivityAware` + `onNewIntent`, so no `MainActivity` override and no list of
  payload keys duplicated in Kotlin: whatever arrived is stored whole and handed back as one JSON
  extra.
- **The Android 13 permission prompt** — no `permission_handler` dependency for a single call.

## What the app still owns

In `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data android:name="ru.rustore.sdk.pushclient.project_id"
           android:value="${rustorePushProjectId}" />
<meta-data android:name="ru.rustore.sdk.pushclient.default_notification_icon"
           android:resource="@drawable/ic_notification" />
<meta-data android:name="ru.rustore.sdk.pushclient.default_notification_color"
           android:resource="@color/notification" />
```

The project id comes from the RuStore Console and usually differs per flavour. The icon and colour
are reused by this package's own renderer — a plugin cannot reach your resources any other way.
Two optional entries name the channel in your language:

```xml
<meta-data android:name="dev.dartway.push.rustore.channel_id" android:value="my_app_push" />
<meta-data android:name="dev.dartway.push.rustore.channel_name" android:value="Уведомления" />
```

The RuStore SDK is not on Maven Central; this package declares the repository it lives in, so an
app that pins its own repositories (`repositoriesMode.set(FAIL_ON_PROJECT_REPOS)`) has to add
`https://artifactory-external.vkpartner.ru/artifactory/maven` itself.

## Testing it

Only on a **physical Android device with the RuStore app installed and signed in** — there is no
emulator path, and a device without RuStore reports itself unavailable, which is the correct
behaviour rather than a failure.

## Part of DartWay

[DartWay](https://dartway.dev) is a fullstack Dart framework (Flutter + Serverpod). The framework
lives in one [repository](https://github.com/dartway/dartway).
