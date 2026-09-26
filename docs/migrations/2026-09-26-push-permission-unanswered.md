---
title: "DwPushPermission gained unanswered — code reading requestPermission()/permission() needs a case for it"
affects:
  dartway_push_flutter: "0.6.0"
---

## Who is affected

Any code that reads, or ignores, what `requestPermission()` or `permission()` returns:

- **An exhaustive `switch` over `DwPushPermission`.** The compiler refuses it without a case for
  the new value.
- **Code that persists a settings toggle regardless of the result** — a call that used to always
  either grant or refuse now has a third outcome that is neither, and saving the toggle as on
  because of it records a permission that was never actually asked for.
- **Code that compares the result to `granted` and treats anything else as denied** (an `if`/`else`
  instead of a switch, or a check like `== DwPushPermission.denied`). `unanswered` would fall into
  the `else` or fail that check the same way a real refusal does, which can send a user to their
  system settings to "turn notifications back on" when nobody has actually asked them yet.
- **A home-made timeout wrapped around either call**, to work around the wait that used to have no
  bound of its own. It is no longer needed and would now hide the honest `unanswered` behind
  whatever fallback the wrapper answers instead.

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
switched, compared or persisted. Treat it as "try again", not as an answer: the registration that
normally follows `granted` did not happen and will not until asked again, so do not persist a
settings toggle as on because of it, and do not treat it as `denied` — save nothing, or offer the
user a retry action instead. Remove any timeout wrapped around either call to work around the
former unbounded wait: the framework now gives up on its own, honestly, and a wrapper on top of it
only hides that behind whatever it falls back to.
