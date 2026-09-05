---
title: "The signed-in session's key needs a DwKeyValueStorePlugin declared"
affects:
  dartway_serverpod_core_flutter: "0.12.0"
  dartway_flutter: "0.8.0"
---

## Who is affected

Every Flutter app on the framework. The core used to reach for `shared_preferences` itself, through
its own copy of the storage contract; it no longer depends on that package at all and asks the
plugins for whoever claims the `DwKeyValueStorePlugin` role.

**Without a plugin claiming it, reaching for the auth key throws** — with a message saying exactly
that, at the moment something needs it. In practice that is the first thing after sign-in, or the
first launch that should have restored a session.

## What to change

Declare a store plugin where `DwCore` is built (`<project>_flutter/lib/core/dw_core.dart` in a
project laid out like the skeleton):

    dw = DwCore<Client, UserProfile>(
    + // The session's key lives here. The core asks the plugins for whoever
    + // claimed the DwKeyValueStorePlugin role.
    + plugins: [DwSharedPreferences()],
      config: DwConfig(...),
      ...
    )

If the project already declares plugins, add it to the list. If it has its own key-value storage,
that class can claim the role instead — the framework asks for the role, not for this package.

Add `dartway_shared_preferences` to the Flutter package's `pubspec.yaml` if it is not there
already; the core no longer brings it in.

**If the project constructed `DwAuthenticationKeyManager` itself:** `Storage` and
`SharedPreferenceStorage` are gone, and the parameter `storage:` is now `store:`, taking the role.

## How to check

Sign in, kill the app, launch it again: the session survives. That is the whole behaviour the key
is there for, and it is not covered by a compile error — the failure is a throw at runtime.
