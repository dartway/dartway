# DartWay — public API design principles

These are the rules the framework's public surface follows. They exist so the API stays coherent as
it grows — a new symbol has a right place, an old one has a reason to stay, and neither is decided by
taste. When you extend any DartWay package, apply these; when they conflict with a change you want to
make, change the principle on purpose, not the code by accident.

## 1. `dw` is the ambient root — everything the framework offers goes through it

An app declares its core once (`late DwFlutterCore dw;`) and imports it anywhere. So "you'd need `dw`
in scope" is never a real constraint — it always is. Because of that, everything the framework
provides on the app side — reads and commands, actions, notifications, confirmations, error
handling — is reached through `dw.`, not through a scatter of static methods. One namespace, one
autocomplete, one place to discover what the framework can do.

A value the framework hands back (e.g. `DwUiAction`) still lives as a value afterwards: its type is
public, you pass it and store it. But you *create* it through `dw.` (`dw.action(...)`), not through a
static factory on the type.

Corollary: **the current usage count in existing code is not a design argument.** Battle code
inherits whatever the API was when it was written; it migrates. Design for what is right, not for
what there is most of right now.

### The price of this principle, which is not zero

"`dw` is always in scope" is true of an application and **false of a widget test**: a test pumps a
subtree, not an app, so `DwAppRunner` never runs and nobody has built the core unless the test does.
Every symbol reached through `dw.` therefore widens the set of tests that must build one — including
tests that only ever name the symbol, because `dw.request(...)` dereferences `dw` to *produce the
provider object*, before riverpod mounts anything or applies a single `overrides:` entry.

This is a real cost, paid by consumers, and it is invisible from inside the framework. A widget test
about a card that knows nothing of profiles still fails when the card reaches the core through
`router → a guard → the profile request`. The failure reads `LateInitializationError` and names a
variable the test's author never touched.

So, when you put a symbol on `dw.`:

- **say so in the changelog as a test-contract change**, not only as an API addition — and in a
  `docs/migrations/` note when projects have to edit their tests;
- expect consumers to build a core in every widget test that reaches one. The skeleton's test support
  builds a fresh `DwFlutterCore` per test against `DwFakeServer` and disposes it in `tearDown`, and
  that has to stay cheap: the core holds no static state, claims the one live slot when built and
  releases it on `dispose`, and refuses to be built while another is alive — so a test that forgets
  to dispose fails the next test loudly instead of sharing its state;
- prefer not to break the rule — the namespace is worth it — but do not pretend the move is free.

## 2. `dw.` is the core; `dw.plugins.<name>` is the extensions

`dw.` is a **closed, known set** — what the core always provides. The toolbox (`DwFlutter`) gives
`dw.notify`, `dw.action`, `dw.confirm`, `dw.handleError`; the data layer on top of it
(`DwFlutterCore`) adds `dw.request`, `dw.pages`, `dw.table`, `dw.window`, `dw.command`, `dw.files`,
`dw.uploader()`, `dw.signIn` / `dw.signOut`, `dw.accountId`, `dw.liveStatus` and
`dw.incompatibility`. `dw.plugins.` is an **open, growing set** — whatever a project has plugged in
(`dw.plugins.telegram`, `dw.plugins.prefs`).

Keep them apart in the namespace. Merging plugins into the root drowns the stable core in a stream of
optional add-ons and invites name collisions. The boundary "what is always there" vs "what this
project connected" should be visible where you type it. A plugin package declares
`extension on DwPlugins`; the core exports the public `DwPlugins` holder with `of<T>()` for an app
reaching for its own integration and `maybeOf<T>()` for the framework asking whether any plugin took
a role.

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

The same test places the contract's own types: a request or a command is data — `const ListNews()`
— and `dw.request(...)` / `dw.command(...)` are what act on it.

## 4. One way, not two

A better API replaces the old one — they do not coexist "for compatibility". The moment you keep a
weaker hook beside a richer one because something old still calls it, you have two ways to do one
thing and a slow rot. Introduce the new one, write the `docs/migrations/` note, migrate the projects,
remove the old one.

## 5. The core is a minimal contract; optional things are plugins

The core does not carry a dependency that isn't necessary to *every* app. Even something as light as
shared-preferences is a plugin — `DwSharedPreferences`, reached as `dw.plugins.prefs`. Where the core
genuinely needs a capability, it asks for a **role**, not a package: `DwFlutterCore` keeps the session
through whichever plugin claims `DwKeyValueStorePlugin`, or through a token store the app passes
itself, and says at `init` when neither is there. This is the same seam as a vendor SDK (Telegram):
`DwPlugin` is the one mechanism for everything optional, not a special case for one integration.

## 6. Context by default

An error carries a snapshot of the app state at the moment it broke — the route, the mounted
features, the action, the platform, the app version, the signed-in account — not a bare stack trace.
The framework collects and routes the error (`DwErrorReport`); *delivery* — a log, an alert channel,
a message to the user — is the app's, plugged in through `DwConfig.onErrorReport`. A package
collects; it does not decide where reports are sent.

## 7. Every public symbol is justified — checked against battle, and against its origin

"Nobody in the demo uses it" is not evidence: the example and template are a narrow slice of what the
framework must do. Check candidates against the real applications built on the framework —
Molodey and U90 — not against demos. A demo would have missed `followUpIfMountedAction`,
`customNotificationBuilder` and half the notification surface, all heavily used in production.

And "zero usages" is not a verdict on its own — look at where the symbol came from. Dead weight that
was never once called (a stubbed global navigator, a flag nobody flipped) is removed. A young,
deliberate extension point, symmetric with ones that already earn their place (a custom confirmation
dialog builder next to the error-report hook), stays — even if no one has reached for it yet.

## 8. A name has at least two words, and `Dw` is not one

Every public class name is two or more words after the prefix: `DwAppServer`, `DwCallResult`,
`DwFlutterCore` — never the prefix and a bare "Server", "Result" or "Core". A one-word name claims a
whole concept — "the server", "the result" — that the framework will need again in another sense,
and the second meaning then arrives with a worse name than the first. The owner's decision, and it binds projects
too: `<Entity>Row` for table rows, data objects as nouns of two or more words, reads as `Get…` /
`List…`, changes as a verb and its object, `<Project>Channel` and `<Project>Refusal`.

The rule is not yet true everywhere: `DwConfig`, `DwFlutter`, `DwPlugin`, `DwPlugins` and `DwFeature`
in the Flutter core, `DwRoute` in the server and `DwRouter` in the router still have one word. They
are the rule's open debt — renamed under principle 4 with a migration note — and a new name does not
add to the list.
