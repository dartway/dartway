---
title: The startup error screen is built from the error
affects:
  dartway_flutter: "0.9.0"
---

## Who is affected

A project that passes its own `errorScreen` to `DwAppLoadingOptions` — in the `DwAppRunner` of its
app file. A project that uses the default screen has nothing to change.

## What to change

`DwAppLoadingOptions.errorScreen` (a widget) is now `errorScreenBuilder` (a function of the error
that failed the start):

    - DwAppLoadingOptions.withNativeSplash(errorScreen: const MyStartupError())
    + DwAppLoadingOptions.withNativeSplash(
    +   errorScreenBuilder: (error, stackTrace) => MyStartupError(error: error),
    + )

Ignoring both arguments is a valid answer — `(_, _) => const MyStartupError()` — but the error is
worth putting on the screen. The person looking at a failed start is usually the one who will be
asked what happened, and "please contact administrator" with nothing else is not something they
can report.

## How to check

`dart analyze` in the Flutter package: `errorScreen` no longer exists, so a missed call site is a
compile error rather than something that surfaces on a launch nobody watched.
