---
name: dartway-data-layer
description: >-
  The Flutter data layer (__FLUTTER_PKG__): reads as Riverpod providers over the contract (dw.request,
  dw.pages, dw.table, dw.window) keyed by the request value; showing them with DwReadBuilder,
  DwPagedListView and DwWindowListView; chrome from logic/ providers; refresh with refetch;
  commands from the feature's logic/ inside dw.action; refusal texts; form validation; the session,
  live status and incompatibility; hand-written providers; persisted screen state through
  dw.plugins.prefs; notifications. Use when a Flutter feature reads, changes or reacts to server
  data, shows a refusal, or keeps local state.
---

# DartWay — the data layer (Flutter)

The contract **is** the API: a screen watches a request, a button sends a command, the core keeps every
watched request live. No `lib/data/`, repositories, service wrappers or caches — each would be a second
copy of state the core holds. `dw` is the app's `DwFlutterCore`, built once in `lib/core/dw_core.dart`.

## 1. Reads

| Request kind | Read | `AsyncValue` of |
|---|---|---|
| `DwSingleRequest<T>` / `DwMaybeRequest<T>` / `DwListRequest<T>` | `dw.request(r)` | `T` / `T?` / `List<T>` |
| `DwPageRequest<T>` | `dw.pages(r)` | `DwPagedData<T>`; `loadMore()` on its notifier |
| `DwTableRequest<T>` | `dw.table(r)` | `DwTablePage<T>` (`total`, `pageCount`); another page is another request |
| `DwWindowRequest<T, S, I>` | `dw.window(r, anchor:)` | `DwWindowData<T>` |

- **The request value is the key**: equal requests share one provider, one fetch, one subscription;
  building the request in `build` is fine, splitting a screen into small features costs nothing.
- State is kept per signed-in account; a command's changes reach every watched request before
  `dw.command` completes — **never refetch after a command**.
- A screen never stitches several reads together by id: the data object arrives with what the screen
  shows, built by the server.
- A one-off read outside a widget: `await dw.client.fetch(request)` → `DwCallResult`.

## 2. Showing a read

A screen shows a read through **`DwReadBuilder`**, a feed through **`DwPagedListView`**, a chat or log
through **`DwWindowListView`** — never by taking the `AsyncValue` apart (`forbiddenRequestRead`).

```dart
DwReadBuilder(
  dw.request(GetInvoice(invoiceId: invoiceId)),
  placeholder: placeholderInvoice,   // loading is the builder over it, as a skeleton
  onRefused: {
    DwCoreRefusal.notFound: (context, _) => AppText.body(context.l10n.invoiceNotFound),
  },
  builder: (context, invoice) => InvoiceDetails(invoice: invoice),
)
```

- Without a `placeholder` the app's loading view shows — leave it out where drawing over stand-in data
  would mislead (someone else's details for a moment). A failure shows the app's failed view with a
  retry — both configured once in `lib/core/dw_core.dart` (`readLoadingBuilder`, `readFailedBuilder`).
- A provider of the project's own that returns a read whole is still a read: show it through
  `DwReadBuilder` too — the check only sees `dw.request(…)` where it is spelled.
- A refusal that means a screen of its own (gone, not yours) is an `onRefused` branch keyed by the code;
  without one, the failed view. `DwNotAuthenticatedException` shows nothing: the router moves to sign-in.
- Several reads nest, each `DwReadBuilder` answering for its own failure.
- **The body comes from a builder, the chrome from `logic/`.** A title, an enabled button, a badge is a
  provider in the feature's `logic/` answering a plain value with a fallback — the skeleton's
  `lib/admin/user_card/logic/user_card_name.dart` — never a `DwReadBuilder` in an app bar.
- A value derived from reads as an `AsyncValue` renders through
  `DwReadBuilder.derived(provider, retry: (ref) => …)`.
- A feed: `DwPagedListView<FeedPost>(request:, placeholder:, header:, emptyBuilder:, itemBuilder:)`
  loads the next page as its end nears and retries a failed page in place; inside a page that scrolls as
  a whole it is `DwPagedListView.sliver`, never a list inside a `Column`.
- A newest-first sequence: `DwWindowListView<T>(request:, initialAnchor:, controller:,
  onVisibleItemsChanged:, emptyBuilder:, itemBuilder: (context, row) …)` — `initialAnchor` is
  `request.cursorOf(item)` or `null` for the newest; `DwWindowListController` scrolls (`scrollToCursor`,
  `jumpToNewest`, `newerCount`); `row.older`/`row.newer` for grouping, `row.isHighlighted`; it keeps
  position on loads and stays at the newest row. Worked example, in the framework repository's example (on GitHub, not in this project):
  [`chat_channel_view.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_flutter/lib/app/chat/widgets/chat_channel_view.dart).
  Sort values may be `int`, `String`, `DateTime` or `DwCalendarDay`; a date cursor keeps the
  canonical `YYYY-MM-DD` value and compares by civil date.

## 3. Refreshing

Live data needs no refresh: a stale screen is a missing channel or publication (`dartway-realtime`).
Retry and pull-to-refresh are `ref.read(dw.request(r).notifier).refetch()` (the same on `pages`,
`table`, `window`) — **not `ref.invalidate`**, which reattaches to the same failed state. A table's page
number is a field of the request; keep it tied to the filter it was chosen under.

## 4. Commands and actions

**`dw.command` is called in the feature's `logic/`** (`<feature>_commands.dart`, or a flow's
controller) and **runs inside the `dw.action` of the widget that owns the button**; `lib/core/` is the
one other place, for wiring no button starts (`forbiddenCommandCall` holds the rest).

```dart
// logic/invoice_card_commands.dart — senders only, results untouched
abstract final class InvoiceCardCommands {
  static Future<DwCallResult<CustomerInvoice>> pay(CustomerInvoice invoice) =>
      dw.command(PayInvoice(invoiceId: invoice.id));
}

// the card
AppButton.primary(
  context.l10n.payInvoice,
  onTap: dw.action(
    (_) => InvoiceCardCommands.pay(invoice),
    confirmation: DwUiConfirmation(context.l10n.confirmPayInvoice),
    onSuccessNotification: context.l10n.invoicePaid,
  ),
),
```

`dw.action` reads the result: ok → the success notification and `followUpIfMountedAction(context,
value)`; refused → `DwFlutterConfig.refusalText` as an error notification (write nothing for it);
signed out → signs out; failed or timed out → `onErrorNotification` and the error report. A value the
widget needs is unwrapped in the logic function (`(await dw.command(…)).valueOrThrow`).

- A `DwUiAction` goes to the kit's buttons or, for any other tap (a tile, an icon, a card),
  `DwActionBuilder(action:, builder: (context, onPressed, busy) …)`, which blocks a repeated tap — never a
  hand-made busy flag, never a callback handed down from a parent.
- It wraps work, not waiting for a person: open a sheet from a plain handler and wrap what happens
  after the choice.
- A command is retried with the same idempotency key; a timeout's outcome is unknown.
- A command two features send is one more feature, not a copy in each.
- "Already paid" is the invoice's status in the watched list, not a local set the widget keeps.

## 5. Refusal texts

`DwFlutterConfig.refusalText` turns a code into words: the skeleton's `lib/core/refusal_text.dart`, an
exhaustive `switch` per enum — `<Package>Refusal`, `DwCoreRefusal`, `DwAuthRefusal`,
`DwUploadRefusal`, and each module's the app uses (`DwAnalyticsRefusal`, `DwPushRefusal`,
`DwProviderRefusal`) — plus a generic sentence for an unknown code. **A new refusal code** is a string
(`dartway-ui-kit`, "Localization") and a case there (it does not compile without one), with `refusal.params` and
`refusal.field` where they matter. `onErrorReport` skips `DwRefusalException` and
`DwNotAuthenticatedException` by type. A client-only rule throws
`DwRefusalException(DwCallRefusal(code, field: …))`, rendered the same way.

## 6. Forms

The command's `validate()` is the rule (`dartway-contract`); the client runs it before sending. For
feedback under a field, wrap the fields in a `Form` and give the button `requireValidation` (it needs a
`Form` above it); a field validator may build the command and show its refusal for its own `field`. An
edit sends only what changed: `DwFieldPatch.keep()` / `set(v)` / `clear()`.

## 7. Session, live status, incompatibility

- `ref.watch(dw.accountId)` → `int?`. The signed-in gate loads the member's profile once
  (`lib/core/profile/`); read it from there.
- Sign-in is `DwRequestCode` then `DwVerifyCode` → `dw.signIn(session)` — the skeleton's `auth/` zone is
  the flow. Sign-out: `dw.action((_) => dw.signOut())`; nothing to reset by hand.
- `ref.watch(dw.liveStatus)` → `DwConnectionStatus`: an offline hint, never a reason to block a button.
- An older contract line or protocol sets `dw.incompatibility`; `DwAppRunner` shows
  `DwFlutterConfig.updateRequiredScreen`.

## 8. Providers are written by hand

Most features need none — server data is already a provider (`dw.request(…)`). One goes into the
feature's `logic/` when state is derived from several sources or carries a rule — **one question each**,
keyed by a value with meaningful equality (a request, an id, a record: a new object per build is a new
provider per build), its decision a factory on the state type with time passed in. A family's argument
arrives in the factory, and a notifier takes it through its constructor. Derived from one object
→ an extension on the data object in `lib/shared/`. No shims over `dw` (a repository, a
`ref.payInvoice` extension); a `<feature>_commands.dart` is not one. A provider never reaches into
another feature's internals.

**`ProviderScope` is written by `DwAppRunner` and tests only** (`forbidden_provider_scope`, a lint): a
nested override is invisible to providers reading through `Ref`. A value that differs per subtree is a
family key or a constructor argument.

## 9. Local state that survives a restart, notifications

Not surviving a restart: a hook or a controller (`dartway-feature-scaffold`). Surviving:
`dw.plugins.prefs` (import `package:dartway_shared_preferences` for the getter; never read `raw` for
screen state) — `provider(key:, defaultValue:)`, or per entity a
top-level `providerFamily<String, int>(keyFor: (id) => 'invoices.$id.sort', defaultValue: …)`,
`mappedProviderFamily` for enums; read with `ref.watch`, write with `.notifier).update(…)`.

Notifications are `dw.notify.success / info / warning / error(text)`, the text localized
(`dartway-ui-kit`) — never `ScaffoldMessenger` or a `SnackBar`.
