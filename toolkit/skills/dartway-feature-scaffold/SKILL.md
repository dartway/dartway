---
name: dartway-feature-scaffold
description: >-
  Building a DartWay feature end to end, in order — contract, server, Flutter, tests — and the
  Flutter feature law: the app's top-level layout, what a feature, a group and a building block are,
  one public file with its DwFeatureSpec, widgets/ and logic/, where logic and state live (hooks, a
  <Thing>Controller Notifier), a feature constructible from its address, and the DwFeatureSpec
  fields. Use when adding functionality, a screen, a flow or a new kind of data.
---

# DartWay — building a feature, end to end

Contract first — the server and the screen are both written against it — then the server, then the
app. **An existing feature: read its public file first**; its `DwFeatureSpec` and `knownIssues` are the
current description, and a change of behaviour fixes them in the same diff. The skeleton's admin members
table and user card (`lib/admin/users/`, `lib/admin/user_card/`, the server's `admin/` feature) are the
worked reference across all three packages.

## Step 1 — the contract (`dartway-contract`)

The data object the screen shows (a two-word noun, what the reader sees, not the table); the requests
by the screen's shape, with channels (`dartway-realtime`); the commands (the user's input only,
`DwFieldPatch` for clearable fields, `validate()`); refusal codes with doc comments. Put them in the
file of their server feature, generate, extend the contract test. A change installed builds already
call: the table in `dartway-contract` §8.

## Step 2 — the server (`dartway-server`)

In `lib/src/<feature>/`: the row class (indexes for the handlers' queries) → generate → a migration
draft, reviewed (`dartway-migrations`) → one handler per call with its rule (`dartway-access`), locking
what a command decides by, a `///` comment above each → rows mapped in batch in `_objects` → what a
command changed published through `_publications`, and the channel rule for a new kind → the feature
declared in `<feature>_feature.dart` and listed in `DwAppServer(features: [...])`.

## Step 3 — the Flutter feature

### The top level of `lib/`

Two files — `main.dart` (the environment: backend URL, version) and `__FLUTTER_APP_FILE__` (the
wiring). Four zones, which hold features only — `app/`, `admin/`, `auth/`, `common/` (features more
than one zone draws). Four layers — `core/` (router and the zones' shells, the `dw` core, the signed-in
profile, settings, refusal texts, `core/platform/` for a conditional-import trio), `shared/` (non-visual
helpers several features use: an extension on a data object, a formatter), `ui_kit/`, `l10n/`. Nothing
else, and none of these names lower down (`invalidTopLevelLayout`). No `data/`, no `domain/`.

### Feature, group, building block

```
lib/app/invoices/invoice_card/
  invoice_card.dart            the only public file: a widget, the only DwFeatureSpec
  widgets/                     its private layout — no spec, no command
  logic/invoice_card_commands.dart   every dw.command it sends
```

- **A feature decides something by the data** — shows different things per state, picks a label, hides
  a button, sends a command. However small (a card in a list), it is a feature, with a spec.
- **A building block arranges what it is handed** — a row, a form field, a badge: `lib/ui_kit/`
  (`2_frequent/`, `3_special/`) or the feature's `widgets/`, described by a doc comment.
- **A group** is a folder with no root `.dart` file; it only groups and does not affect visibility (the
  router imports `app/billing/invoice/invoice_page.dart`). A feature that gains a second public entity
  — a page plus an embeddable block, a three-screen flow — becomes a group of features. Behaviour two
  features share is one more feature. **Split small**: every feature carries its own description.
- Not a feature: state several features watch → `core/`; a helper → `shared/`; a visual one →
  `ui_kit/`. The tell: its `purpose` and `behaviors` could only restate the type name (`notAFeature`
  when a zone folder's entry declares no widget).
- A file in `widgets/` or `logic/` that nothing in the feature uses is `unusedFeatureFile` (a warning); a
  file that only re-exports others is `barrelFile` — import the file itself.

### Where logic and state live — bottom up

1. **In the widget**: a couple of reads, local state in hooks, a `.where` over a loaded list.
2. **A provider in `logic/`** when state derives from several sources or carries a rule; the decision
   is a factory on the state type (`dartway-data-layer`, §8).
3. **A `Notifier` named `<Thing>Controller` in `logic/`** when widgets share state or a flow has logic
   — a draft two widgets edit, a multi-step sign-in (the skeleton's `auth/logic/auth_controller.dart`).
   First check the server does not already hold it.

A widget's own state is a hook in a `HookWidget`/`HookConsumerWidget` (`forbiddenStateHolder`):

| What a `State` held | The hook |
|---|---|
| a text, scroll, tab controller, a `FocusNode` | `useTextEditingController`, `useScrollController`, `useTabController`, `useFocusNode` |
| an `AnimationController` | `useAnimationController` |
| a flag, a selection, a draft | `useState` |
| a timer, a subscription, a lifecycle observer | `useEffect` returning its cleanup; `useOnAppLifecycleStateChange` |
| `didUpdateWidget` resyncing from a prop | `useEffect(…, [prop])`, `useValueChanged` |
| an object built once and disposed | `useMemoized` plus a `useEffect` cleanup |
| a `StatefulBuilder` | `HookBuilder` (`HookConsumer` with a `ref`) |
| a mixin or extension on `State` calling `setState` | a `use…` function of your own that calls hooks |

A callback registered once reads the latest props through `final latest = useRef(this)..value = this;`.
A controller the provider owns lives while watched (`NotifierProvider.autoDispose`, `.family`). The one
way out — a third-party API that needs a `State` subclass or its own `Listenable` — is
`// dw:allow-stateful <reason>` on the class, listed by every check run. State two features use is a
feature whose public surface is a provider (the provider in the root file, the notifier in `logic/`);
state one feature uses may keep notifier and provider in one file, provider first.

### A feature is constructible from its address

Write the call: can the widget be built in the router, in a kit dialog, in a `ListView.builder`, from
identifiers and data objects alone? No → it is its parent's layout; fold it back, or take the assembled
data out of its constructor. A `Function`, a `Map` or a computed `List` in a constructor is the tell; a
list of data objects is fine.

A sheet or dialog that is a feature shows itself through a static method taking `BuildContext` first —
`static Future<void> show(BuildContext context, {required int invoiceId}) =>
context.showAppBottomSheet(child: InvoiceEditSheet(invoiceId: invoiceId));` — never an extension on
`BuildContext`.

### Build it

The route (`dartway-navigation`) → the public widget `implements DwFeatureWidget` with its spec → reads
and commands (`dartway-data-layer`) → the kit (`dartway-ui-kit`) → the texts (`dartway-ui-kit`,
"Localization") and a refusal text for every new code (`dartway-data-layer` §5). Sample: the skeleton's `lib/admin/user_card/admin_user_card_page.dart`.

## The feature spec — `DwFeatureSpec`

The feature's only description, on its public widget (`dwFeature`); without one, `featureSpecMissing`
(a warning). Written from what the code does.

- **`id`** — `<feature-folder>/<name>`, a contract Studio and tickets refer to: it survives a move; a
  new name is a new id.
- **`title`**; **`purpose`** — why the user needs it, often unnecessary.
- **`behaviors`** — what it observably does, each checkable by looking at the running app.
- **`requirements`** — what it must honour, imposed from outside (who may see it); one phrased as
  something observable belongs in `behaviors`.
- **`implementationNotes`** — what the code cannot say about itself and survives a rewrite ("not paged
  — dozens of rows, not thousands"), never a map of the code.
- **`knownIssues`** — what is wrong and worth picking up, one sentence with its cost; noticed here,
  recorded here.

## Step 4 — tests, then finish

Use the six risk classes in `dartway-testing` §4. Do not scaffold test files for behaviour outside
them. Extend the owner test's list or table:

- New DTOs in the contract test's list (class 5).
- One refused call per access rule, with its code, from a caller only that rule stops (class 1).
  If creating a per-feature acceptance test file, start with this refusal and nothing else by
  default. Where a channel narrows its audience — a member's own data or a team's channel — also
  prove that an outsider attempting to subscribe receives nothing from that channel (class 1).
- A test for any other risk class the feature has: 2, 3 or 6; a bugfix follows class 4 and §5.
- A widget test only where the screen has logic of its own and the risk calls for it.

A second client hearing the publication is not mandatory; it must answer the §4 gate.
Then `dartway-finish`.
