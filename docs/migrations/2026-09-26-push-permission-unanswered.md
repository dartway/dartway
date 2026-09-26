---
title: "DwPushPermission gained unanswered — an exhaustive switch over it needs a case"
affects:
  dartway_push_flutter: "0.6.0"
---

## Who is affected

A project with an exhaustive `switch` over `DwPushPermission` — most likely around what
`requestPermission()` or `permission()` returns, to decide what to save or show. The compiler
refuses it without a case for the new value.

## What changed

`requestPermission()` and `permission()` used to wait forever for the transport to attach — on
iOS, `attach` awaits an APNs registration a wrong bundle id, or no signal at all, never delivers
(dartway/dartway#338), which left a settings toggle busy and unsaved for good. They now give up
after `DwPush(permissionDeadline:)` (10 s by default) and return `DwPushPermission.unanswered`:
the real state is unknown — not "nobody has asked" (`notDetermined` keeps only that meaning now)
and not a guess at granted or denied. `permission()`'s own call to the transport is bounded the
same way once attached; `requestPermission()`'s call to the platform is not — it may be showing
the user a system dialog, and their own time answering it is not silence.

## What to change

Add a case for `DwPushPermission.unanswered` wherever `requestPermission()` or `permission()` is
switched on exhaustively. Treat it as "try again", not as an answer: the registration that
normally follows `granted` did not happen and will not until asked again, so do not persist a
settings toggle as on because of it — save nothing, or offer the user a retry action instead.
