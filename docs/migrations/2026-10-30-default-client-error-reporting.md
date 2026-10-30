---
title: Adopt default Flutter error delivery
affects:
  dartway_core_flutter: "0.25.0-dev.1"
---

## Who is affected

Flutter projects whose `lib/core/dw_core.dart` sets `DwFlutterConfig.onErrorReport` only to implement the former skeleton policy.

## What to change

Remove that `onErrorReport` wrapper so the framework's persistent reporter can deliver unexpected failures to the server. Set the localized button-failure message separately:

```dart
DwFlutterConfig(
  uiActionFailedText: appL10n.actionFailed,
  // no onErrorReport: the framework default delivers incidents
)
```

The default already excludes `DwRefusalException` and `DwNotAuthenticatedException`. Keep `onErrorReport` only when the project intentionally replaces server delivery (a no-op opts out).

## How to check

Trigger an unexpected error from a button handler. Confirm that the localized
failure text appears and exactly one client incident reaches the server alert
sink with the current route and app version.
