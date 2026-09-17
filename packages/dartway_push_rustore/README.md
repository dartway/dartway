# dartway_push_rustore

RuStore as a transport of `dartway_push_flutter` — Android devices with RuStore, inert elsewhere.

```dart
DwPush(transports: [DwRuStorePush(), DwFirebasePush(webVapidKey: key)])
```

Declared first, it takes Android devices that have RuStore; the next transport takes the rest.

## What this package carries

- **The messaging service.** RuStore delivers to one; this one replaces the SDK's, writes each
  message's data down on arrival (a tap may come back to a process that no longer exists), and
  draws a **data-only** message — the server sends a picture that way (`dw_title`, `dw_body`,
  `dw_image`), because RuStore ignores an image in its notification block. The notification shows
  as text at once and gains the picture when fetched (https, 1 MB, 1600 px).
- **The tap**, through `ActivityAware` and `onNewIntent`: no `MainActivity` override.
- **The Android 13 permission prompt.**

## What the app owns

In `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data android:name="ru.rustore.sdk.pushclient.project_id" android:value="${rustorePushProjectId}" />
<meta-data android:name="ru.rustore.sdk.pushclient.default_notification_icon" android:resource="@drawable/ic_notification" />
<meta-data android:name="ru.rustore.sdk.pushclient.default_notification_color" android:resource="@color/notification" />
<!-- optional: the channel of drawn notifications, in the app's language -->
<meta-data android:name="dev.dartway.push.rustore.channel_id" android:value="app_push" />
<meta-data android:name="dev.dartway.push.rustore.channel_name" android:value="Notifications" />
```

The RuStore SDK is not on Maven Central: this package declares its repository, so an app that pins
repositories (`FAIL_ON_PROJECT_REPOS`) adds `https://nexus-external.rustore.ru/repository/maven-rustore-exposed`.
It also removes RuStore's retired repository (`artifactory-external.vkpartner.ru`, off from 01.10.2026),
which `flutter_rustore_push` 7.2.0 still adds to every project; an app that pins repositories itself
must not list that host either.

RuStore push runs only on a physical device with RuStore installed and signed in.
