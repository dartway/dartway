# dartway_flutter — package design notes

This package follows the framework-wide principles in [`docs/DESIGN.md`](../../docs/DESIGN.md). Below
is what is specific to *this* package: what it is for, and where its edges are.

## What this package is

The Flutter skeleton of a DartWay app — everything an app needs *before and around* its data layer:
app bootstrap, the async-UI contract, guarded actions, notifications, error reporting, feature
declarations, the plugin seam. It knows nothing about a server; the data layer
(`dartway_serverpod_core_flutter`) is built on top of it and re-exports it.

## Package principles

**A skeleton, not a design system.** There is no `DwButton`, no `DwText`, no theme. A design system
is the one thing every serious app ends up owning; shipping it as a dependency only starts an
argument about the corner radius of a button. `dartway create` scaffolds a UI kit *into* the app as
source. This package keeps the mechanism (the action guard, the async contract), never the look.

**A contract, not a library.** The line that split this package off the UI kit: a contract — the
part without which a DartWay app doesn't exist — must be boring and stable; a kit must move. Fusing
them makes the boring thing version at the speed of the moving thing. What lives here is the stable
contract.

**It collects, it does not deliver.** The error pipeline gathers an error and its context snapshot
and routes it (`dw.handleError` → `dw.dispatchReport` → the configured hook). It does not deliver:
Telegram/alert delivery is plugged in by the data layer (`DwCore` overrides `dispatchReport`). The
package has no business knowing the channels an error is sent to.

**The core is minimal; optional things are plugins.** This package does not depend on
`shared_preferences`, Telegram, or any other thing an app might not need. Those are plugins, reached
through `dw.plugins.<name>`. `DwPlugin` / `DwPlugins` is the seam.

## Known debt

- **The notification pipeline is over-layered.** `dw.notify.*` → a static `DwNotificationsController`
  bridge (riverpod ↔ `dw`) → a `dynamic`-typed stream → the listener → a handler map. It works and
  is untouched for the first release, but the static bridge and the `dynamic` event type are the
  obvious targets for a later pass. Do not add to that pattern; simplify it when you touch it.
