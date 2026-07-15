# DartWay — public API design principles

These are the rules the framework's public surface follows. They exist so the API stays coherent as
it grows — a new symbol has a right place, an old one has a reason to stay, and neither is decided by
taste. When you extend any DartWay package, apply these; when they conflict with a change you want to
make, change the principle on purpose, not the code by accident.

## 1. `dw` is the ambient root — everything the framework offers goes through it

An app declares its core once (`late final DwCore dw;`) and imports it anywhere. So "you'd need `dw`
in scope" is never a real constraint — it always is. Because of that, everything the framework
provides — actions, notifications, confirmations, error handling — is reached through `dw.`, not
through a scatter of static methods. One namespace, one autocomplete, one place to discover what the
framework can do.

A value the framework hands back (e.g. `DwUiAction`) still lives as a value afterwards: its type is
public, you pass it and store it. But you *create* it through `dw.` (`dw.action(...)`), not through a
static factory on the type.

Corollary: **the current usage count in existing code is not a design argument.** Battle code
inherits whatever the API was when it was written; it migrates. Design for what is right, not for
what there is most of right now.

## 2. `dw.` is the core; `dw.plugins.<name>` is the extensions

`dw.` is a **closed, known set** — the services and actions the core always provides (`dw.notify`,
`dw.action`, `dw.confirm`, `dw.handleError`). `dw.plugins.` is an **open, growing set** — whatever a
project has plugged in (`dw.plugins.telegram`, `dw.plugins.prefs`).

Keep them apart in the namespace. Merging plugins into the root drowns the stable core in a stream of
optional add-ons and invites name collisions. The boundary "what is always there" vs "what this
project connected" should be visible where you type it. A plugin package declares
`extension on DwPlugins`; the core exports the public `DwPlugins` holder and `dw.plugins.of<T>()`.

## 3. Where a factory goes — `dw.` vs the type's constructor

Three questions, in order. They give one answer for any symbol:

1. **Is it self-contained data/config** (exists and compares without the app; especially if it is
   ever `const`)? → **the type's constructor.** `const` is only possible this way — a `dw.` method
   can't be a const expression.
2. **Does it need `dw`/services to do its job** (the way `DwUiAction` internally calls
   `dw.confirm`/`dw.notify`/`dw.handleError`)? → **`dw.`**.
3. **Is it an action or a service** (deliver, confirm, handle)? → **`dw.`**.

So `DwUiNotification` / `DwUiConfirmation` are data → their own constructors; `DwUiAction` is
behaviour woven into services → `dw.action`; `dw.notify` / `dw.confirm` / `dw.handleError` are
services → `dw.`. Note that `dw.notify.success(msg)` *delivers* (a service) while
`DwUiNotification.success(msg)` *creates a value* (for a builder to return) — both exist, different
jobs, no contradiction.

## 4. One way, not two

A better API replaces the old one — they do not coexist "for compatibility". The moment you keep a
weaker hook beside a richer one because something old still calls it, you have two ways to do one
thing and a slow rot. Introduce the new one, migrate the projects, remove the old one.

## 5. The core is a minimal contract; optional things are plugins

The core does not carry a dependency that isn't necessary to *every* app. Even something as light as
shared-preferences is a plugin, reached through `dw.plugins.<name>` — an app that doesn't need local
storage doesn't pay for it. This is the same seam as a vendor SDK (Telegram): `DwPlugin` is the one
mechanism for everything optional, not a special case for one integration.

## 6. Context by default

An error carries a snapshot of the app state at the moment it broke — route, mounted features, the
action, platform, version, user — not a bare stack trace. The framework collects and routes the
error; *delivery* (alerting to a channel) is plugged in by the data layer, which overrides the
dispatch point. A package collects; it does not decide where reports are sent.

## 7. Every public symbol is justified — checked against battle, and against its origin

"Nobody in the demo uses it" is not evidence: the example and template are a narrow slice of what the
framework must do. Check candidates against real applications, not demos — the demo missed
`followUpIfMountedAction`, `customNotificationBuilder` and half the notification surface, all heavily
used in production.

And "zero usages" is not a verdict on its own — look at where the symbol came from. Dead weight from
an early code dump that was never once called (a stubbed global navigator, a flag nobody flipped) is
removed. A young, deliberate extension point, symmetric with ones that already earn their place (a
custom-dialog builder next to the error-report override), stays — even if no one has reached for it
yet.
