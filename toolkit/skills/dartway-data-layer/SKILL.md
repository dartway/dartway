---
name: dartway-data-layer
description: >-
  The Flutter data layer of a DartWay project (__FLUTTER_PKG__): reads are Riverpod providers over
  the shared contract — ref.watch(dw.request(...)) for single/maybe/list requests, dw.pages (feeds,
  loadMore), dw.table (numbered pages), dw.window (chats, DwWindowListView) — keyed by the request
  value itself; a screen shows a read only through DwReadBuilder (skeleton placeholder, onRefused
  branches per refusal code, the app's failed view with retry) or DwPagedListView (a feed that loads
  its next page as the end comes near), never by taking the AsyncValue apart; refreshing
  with the notifier's refetch (never ref.invalidate); commands sent from the feature's logic/
  (dw.command in <feature>_commands.dart) inside dw.action, with refusals shown by DwFlutterConfig.refusalText; form validation with DwSelfValidating;
  the session (dw.accountId, dw.signIn, dw.signOut), dw.liveStatus and dw.incompatibility;
  hand-written providers (no riverpod_generator) that answer one question each; notifications via
  dw.notify; local screen state via dw.plugins.prefs. No data/ layer, no repository classes. Use when
  a Flutter feature reads, changes or reacts to server data, shows a refusal, or keeps local state.
---

# DartWay — the data layer (Flutter)

The app has no data layer of its own. The contract in `__SHARED_PKG__` **is** the API: a screen
watches a request, a button sends a command, and the core keeps every watched request live. So there
is **no `lib/data/`, no repository class, no service wrapper, no hand-made cache** in
`__FLUTTER_PKG__` — each of those would be a second copy of state the core already holds, and it
can only drift from it.

`dw` is the app's `DwFlutterCore`, built once in `lib/core/` (the skeleton's core file: `late
DwFlutterCore dw;` and the function that builds it with the protocol, the base URL, `DwFlutterConfig` and
the plugins). Everything below reaches it as `dw`.

Related skills: `dartway-contract` (the DTOs), `dartway-realtime` (why screens update by themselves),
`dartway-feature-scaffold` (where this code lives), `dartway-ui-kit`, `dartway-testing`.

## 1. Reads

A screen shows a read through **`DwReadBuilder(dw.request(…), builder: …)`** (any kind below but a
feed and a window), **`DwPagedListView(request: …)`** for a feed and **`DwWindowListView`** for a
chat (section 8). The table says what each read holds underneath.

| Request kind | Read | `AsyncValue` of | More |
|---|---|---|---|
| `DwSingleRequest<T>` | `ref.watch(dw.request(GetInvoice(invoiceId: id)))` | `T` | absent → error `DwRefusalException` with `dw.notFound` |
| `DwMaybeRequest<T>` | `ref.watch(dw.request(const GetMyDraft()))` | `T?` | |
| `DwListRequest<T>` | `ref.watch(dw.request(const ListMyInvoices()))` | `List<T>` | |
| `DwPageRequest<T>` | `ref.watch(dw.pages(const ListFeedPosts()))` | `DwPagedData<T>` | `ref.read(dw.pages(r).notifier).loadMore()` |
| `DwTableRequest<T>` | `ref.watch(dw.table(ListInvoicesPage(page: page)))` | `DwTablePage<T>` | `total`, `pageCount`; another page is another request |
| `DwWindowRequest<T, S, I>` | `ref.watch(dw.window(request, anchor: cursor))` | `DwWindowData<T>` | `loadOlder()`, `loadNewer()`; use `DwWindowListView` (section 8) |

- **The request value is the key.** Requests have generated value equality, so every widget watching
  an equal request shares one provider, one fetch and one channel subscription. Splitting a screen
  into small features costs nothing on the wire; building the request in `build` is fine.
- **State is kept per signed-in account.** After an account switch every watched request goes through
  loading for the new account; another account's data is never shown.
- A request that declares channels stays live while watched (`dartway-realtime`). A command's
  changes are applied to every watched request before `dw.command` completes — **never refetch after a
  command**.
- For a one-off read outside any widget: `await dw.client.fetch(request)` answers a `DwCallResult`.

## 2. Showing a read: `DwReadBuilder`

Every way a read ends short of data is an **error of the `AsyncValue`, typed**:

| Error | Means | `DwReadBuilder` shows |
|---|---|---|
| `DwRefusalException` (`.refusal`) | the server answered "no" — `dw.notFound`, `dw.forbidden`, a project code | the `onRefused` branch for that code; without one, the app's failed view |
| `DwFailedException` (`.incidentId`) | the server failed | the app's failed view, with a retry; reported once |
| `DwTimeoutException` | no answer yet; the client keeps trying | the app's failed view, with a retry |
| `DwNotAuthenticatedException` | the session is over; the client has already signed out | nothing — the sign-in screen is the message |

**A widget never takes that `AsyncValue` apart itself** — no `.value`, `.when(`, `.hasError`,
`switch`/`case AsyncError(…)` over `ref.watch(dw.request(…))`: `dart run dartway_cli:dartway check`
fails on it (`forbiddenRequestRead`). Every screen that did chose its own answer to "failed" —
nothing, an empty list, a spinner that never stops. `DwReadBuilder` answers once:

```dart
DwReadBuilder(
  dw.request(GetInvoice(invoiceId: invoiceId)),
  placeholder: placeholderInvoice,   // stand-in data: loading is a skeleton of the real widget over it
  onRefused: {
    DwCoreRefusal.notFound: (context, _) => AppText.body(context.l10n.invoiceNotFound),
  },
  builder: (context, invoice) => InvoiceDetails(invoice: invoice),
)
```

- **Loading** is `builder` over `placeholder` as a skeleton. Leave the placeholder out where drawing
  over stand-in data would itself mislead (a card with someone else's details for a moment); the
  app's loading view shows instead.
- **Failed** is the app's view, configured once in `lib/core/` as
  `DwFlutterConfig.readLoadingBuilder` / `readFailedBuilder` (the kit's `AppProgressIndicator` and
  `LoadFailedMessage`); its retry is the read's `refetch()`. Nothing to pass per screen.
- **A refusal that means a screen of its own** — gone, closed, not yours — is an `onRefused` branch,
  keyed by the code (`DwCoreRefusal.notFound`, `<Package>Refusal.x`), never an `if` over the
  error before the builder.
- **Several reads nest**: the inner `DwReadBuilder` stands in the outer one's `builder`, and each
  answers for its own failure. **Never combine reads through `.value ?? fallback` in a widget** — it
  answers the same for loading and for an error.
- **The body comes from a builder; the chrome from `logic/`.** What a screen or a section *is* — its
  body — is a `DwReadBuilder`. What its chrome needs whatever the read answers — a title, whether a
  button is enabled, a badge, whether to leave room for a bar — is a provider in the feature's
  `logic/` answering a **plain value with a fallback** (a `.select` inside it when useful), and the
  widget watches that provider. **A `DwReadBuilder` never stands in an app bar**, and a badge's read
  never gates or skeletonises the page it sits on:

```dart
// logic/invoice_title.dart
final invoiceTitleProvider = Provider.autoDispose.family<String?, int>(
  (ref, invoiceId) => ref.watch(
    dw.request(GetInvoice(invoiceId: invoiceId)).select((invoice) => invoice.value?.number),
  ),
);

// the page
AppBar(title: AppText.title(ref.watch(invoiceTitleProvider(id)) ?? context.l10n.invoice)),
body: DwReadBuilder(dw.request(GetInvoice(invoiceId: id)), builder: …),
```

- **A value derived from reads as an `AsyncValue`** — a `logic/` provider combining two reads, or
  deciding over one — is rendered by `DwReadBuilder.derived(provider, retry: (ref) => …)`: the same
  branches, with the retry naming the reads to ask again.
- **Something that is not a read** — a hook's future, a plugin's stream — is not a `DwReadBuilder`'s
  business; its waiting is still the kit's `AppProgressIndicator`, never Flutter's spinner
  (`forbiddenProgressIndicator`).

## 3. Refreshing

- **Live data needs no refresh.** If a screen is stale after someone else's change, a channel or a
  publication is missing — fix it on the server (`dartway-realtime`), not with a timer or a refetch.
- **Retry and pull-to-refresh:** `ref.read(dw.request(r).notifier).refetch()` (and the same on
  `dw.pages`, `dw.table`, `dw.window` notifiers). **Not `ref.invalidate`**: the client keeps a request
  alive for a moment after its last watcher leaves, so a thrown-away provider reattaches to the same
  failed state instead of asking again.
- **Feeds are `DwPagedListView`:** it asks for the next page as the end of the list comes near —
  the slot past the last row is built lazily and building it calls `loadMore()` — and shows a retry
  in that slot after a failed page. No scroll listener, pixel threshold or "more" button by hand:

```dart
DwPagedListView<FeedPost>(
  request: const ListFeedPosts(),
  placeholder: placeholderPost,
  header: const FeedHeader(),                 // scrolls with the rows
  emptyBuilder: (context) => AppText.body(context.l10n.noPostsYet),
  itemBuilder: (context, post) => FeedPostCard(post: post),
)
```
  A feed that is one part of a page scrolling as a whole is `DwPagedListView.sliver(…)` in the
  page's own `CustomScrollView` — never a `DwPagedListView` inside a `Column` or a `ListView`,
  where its end is always built and it pages to the end at once.
- **Tables:** the page number is a field — paging is watching `ListInvoicesPage(page: next)`. Keep the
  chosen page tied to the filter it was chosen under, so a new filter starts at page 1.

## 4. Commands and actions

A change is a command. **`dw.command` is called in the feature's `logic/` only**, and runs inside
the `dw.action` that the widget owning the button builds — so one feature sends one command one
way, and `widgets/` lays out what it is handed:

```dart
// lib/app/invoices/invoice_card/logic/invoice_card_commands.dart
/// The commands an invoice card sends.
abstract final class InvoiceCardCommands {
  /// Pays [invoice]. The answer carries it paid, and every watched list takes
  /// it before the command completes.
  static Future<DwCallResult<CustomerInvoice>> pay(CustomerInvoice invoice) =>
      dw.command(PayInvoice(invoiceId: invoice.id));
}

// lib/app/invoices/invoice_card/invoice_card.dart
AppButton.primary(
  context.l10n.payInvoice,
  onTap: dw.action(
    (_) => InvoiceCardCommands.pay(invoice),
    label: 'payInvoice',
    confirmation: DwUiConfirmation(context.l10n.confirmPayInvoice),
    onSuccessNotification: context.l10n.invoicePaid,
  ),
),
```

The logic function answers `dw.command`'s result as it is — no `try`, no unwrapping: `dw.action`
reads it. A flow with state of its own (sign-in, a wizard) sends its commands from its notifier in
`logic/`, and the widget wraps the notifier's method the same way:
`dw.action((_) => notifier.verifyCode())`. A command two features send is one more feature — its
button and its `logic/` — not a copy in each.

What `dw.action` does with the `DwCallResult` the callback returns:

- `DwCallOk` → success notification, `followUpIfMountedAction`;
- **refused** → shows `DwFlutterConfig.refusalText(refusal)` as an error notification. Write nothing for it:
  no `try`, no `switch` over the result, no `onErrorNotification` for the refusal case;
- **not authenticated** → signs out, shows nothing;
- **failed / timed out** → `onErrorNotification` if given, and the app's error report.

Declining the confirmation cancels everything. Need the value? `followUpIfMountedAction: (context,
result)`, or inside the callback `final invoice = (await InvoiceCardCommands.pay(i)).valueOrThrow;` —
a non-ok result thrown there is handled the same way.

- **`dw.action(...)` is a `DwUiAction`, not a `VoidCallback`.** Give it to the kit's buttons, or to any
  tappable widget through `DwActionBuilder(action:, builder: (context, onPressed, busy) => …)`, which
  blocks repeated taps and reports `busy`.
- **`dw.action` wraps work, not waiting for a person.** `busy` lasts exactly as long as the callback's
  `Future`: awaiting a sheet, a dialog or a picker inside it spins the button for as long as the sheet
  is open, and makes `pumpAndSettle` never return in a test. Opening a sheet is navigation — do it from
  a plain handler, and wrap in `dw.action` what happens **after** the choice: the save, the send.
- **A command is retried after network failures with the same idempotency key**, so a retried send
  never executes twice. A `DwTimeoutException` means the outcome is unknown; the next tap is a new
  intent.
- **Local state on top of server state is a second source of truth.** "Already paid" is the invoice's
  status in the watched list, not a `Set<int>` the widget accumulates.
- **The action lives in the widget that owns the button** — not a callback handed down from a parent,
  not a screen-wide busy flag.

## 5. Refusal texts

`DwFlutterConfig.refusalText` is required: a refusal is a code with parameters, and the app turns it into
words. The skeleton's `lib/core/` holds the function — a map from every known wire code to its enum
value, and an **exhaustive `switch`** per enum: the project's `<Package>Refusal`, `DwCoreRefusal`,
`DwAuthRefusal`, `DwUploadRefusal`, and a generic sentence for a code none of them knows (a newer
server).

Adding a refusal code to the contract therefore means, in the same change:

1. a string in **every** `lib/l10n/*.arb`, then `flutter gen-l10n`;
2. a case in the refusal text switch — it does not compile until there is one;
3. parameters rendered from `refusal.params` (strings), and `refusal.field` where one code means
   different things per field (`dw.invalid` on `identifier` vs `code`).

In the app's `DwFlutterConfig.onErrorReport`, step over `DwRefusalException` and
`DwNotAuthenticatedException` **by type** — a refusal is an answer, not an incident. Never match
message text.

A rule that lives only on the client throws the same type, and `dw.action` renders it the same way:
`throw DwRefusalException(DwCallRefusal(AcmeRefusal.amountNotPositive, field: 'amountCents'));`.

## 6. Form validation

A command's `validate()` (`DwSelfValidating`, `dartway-contract`) is the rule, and the client runs it
before sending: an invalid command costs no round trip, and `dw.action` shows its first refusal.
The server runs the same code again.

For feedback under a field while typing, wrap the fields in a `Form` and give the submit button
`requireValidation` (on `DwActionBuilder`, and on the kit's buttons that pass it through): the form's
validators run first and the action is cancelled while one fails. A field validator's text comes from
`context.l10n`. Keep the rule itself in the command — a validator may build the command from the
draft and render the refusal whose `field` is its own through the refusal texts, so nothing is written
twice.

Send only what changed: an edit command's `DwFieldPatch` fields are `keep()` for untouched values,
`set(v)` for changed ones and `clear()` for emptied ones.

## 7. Session, live status, incompatibility

- **Who is signed in:** `ref.watch(dw.accountId)` → `int?`. The skeleton's router listens to it, and
  its signed-in gate loads the member's own profile once (the "my profile" request) and hands it to the
  screens below — read it from there rather than watching the profile again in every widget.
- **Sign in** is two commands of the framework: `DwRequestCode(kind:, identifier:)` answers a
  `DwCodeTicket`; `DwVerifyCode(ticketId:, code:, registration:)` answers a `DwAuthSession`, which
  `dw.signIn(session)` adopts and keeps across restarts. The skeleton's auth zone is the worked flow
  (including a sign-up refused until consents are given, then verified again with the same code).
- **Sign out:** `dw.action((_) => dw.signOut())`. The local session ends at once and the router moves
  to the auth zone; there is no state to reset by hand.
- **Live status:** `ref.watch(dw.liveStatus)` → `DwConnectionStatus` (`idle`, `connecting`,
  `connected`, `disconnected`, `incompatible`). Calls work whatever it says; it only tells whether data
  on screen still follows the server — an "offline" hint, never a reason to block a button.
- **Incompatibility:** an app compiled with an older breaking line of the contract than the server's (or a protocol mismatch) sets
  `dw.incompatibility`, and `DwAppRunner` shows `DwFlutterConfig.updateRequiredScreen` over the whole app.

## 8. Chats and logs — `DwWindowListView`

A newest-first sequence opened at an anchor (a chat, an activity log) is a `DwWindowRequest` shown with
`DwWindowListView` — not a reversed `ListView` over `dw.window` written by hand:

```dart
DwWindowListView<InvoiceComment>(
  request: ListInvoiceComments(invoiceId: invoiceId),
  initialAnchor: lastReadCursor,          // request.cursorOf(item), or null for the newest
  controller: listController,             // DwWindowListController: scrollToCursor, jumpToNewest, newerCount
  onVisibleItemsChanged: markSeen,        // debounced; what read tracking needs
  emptyBuilder: (context) => AppText.body(context.l10n.noCommentsYet),
  itemBuilder: (context, row) => CommentBubble(
    comment: row.item,
    groupedWithPrevious: row.older?.authorId == row.item.authorId,
  ),
)
```

It loads older and newer rows as the list scrolls without moving what is on screen, stays at the
newest row when new ones arrive live, and counts what arrived below otherwise. `row.older` /
`row.newer` are the loaded neighbours (date separators, grouping); `row.isHighlighted` marks an item
just scrolled to. Rows are yours; the list ships no design.

## 9. Providers are written by hand

No `riverpod_generator`, no `build_runner`. Most features need no provider at all: a couple of
`DwReadBuilder`s in the widget. Introduce one — in the feature's `logic/`, the one place besides
`core/` that watches a read itself — when state is **derived from several sources** or carries a
rule, so it is computed once and cached rather than reassembled on every build:

```dart
/// Whether the caller may still edit [invoiceId]: a draft of their own.
/// `false` until the invoice is known — it enables a button, it is chrome.
final invoiceEditableProvider = Provider.autoDispose.family<bool, int>(
  (ref, invoiceId) => ref.watch(
    dw
        .request(GetInvoice(invoiceId: invoiceId))
        .select((invoice) => invoice.value?.status == InvoiceStatus.draft),
  ),
);
```

A provider that answers an `AsyncValue` instead — the body of a section derived from reads — is
shown with `DwReadBuilder.derived(provider, retry: (ref) => ref.read(dw.request(r).notifier).refetch())`,
never taken apart in the widget. Pick by what the value is for: chrome answers a plain value with
a fallback, a body answers an `AsyncValue` for a builder.

- **A family key is a value with meaningful equality**: a request, an id, or a record of them
  (`({int invoiceId, bool archived})`). A new object per build as a key is a new provider per build.
- **One provider answers one question** (`invoiceEditableProvider`), not one screen
  (`InvoiceScreenState` with seventeen fields). Derived from a single object → an extension on the
  data object in `lib/shared/`, not a provider.
- **The decision goes into a factory on the state type**, the provider says where the data comes
  from — so the decision is testable without a container, with time passed in rather than read.
- **No shims over the framework**: a repository, a service or a `ref.payInvoice(...)` extension that
  wraps `dw` hides the real API and adds nothing. A feature's `<feature>_commands.dart` is not one:
  each function sends one named command and answers its result untouched, so the feature's changes
  are listed in one file.
- **A provider does not reach into another feature's internals.** When a neighbour needs it, it is
  that feature's public surface, or it belongs in `lib/core/` (`dartway-feature-scaffold`).
- **`ProviderScope` is written by `DwAppRunner` and by tests only.** A nested scope's override is seen
  by widgets and missed by providers reading through `Ref`. A value that differs per subtree travels as
  a family key or a constructor argument.

A hand-written `NotifierProvider` is overridden in a test with `overrideWith(() => fake)` (a subclass
whose `build()` returns a fixed value); a family is overridden as a whole, the argument handed to the
fake through its constructor. The server itself is faked below the core, not by overriding
`dw` providers — `dartway-testing`.

## 10. Local screen state

Two questions, in order:

1. **Does it survive a restart?** No → an ordinary `Notifier` or a hook. Yes → `dw.plugins.prefs` (the
   `dartway_shared_preferences` plugin; its library import brings the `prefs` getter): it gives back a
   provider, so reads stay `ref.watch`.
2. **Does it belong to an entity?** No → `dw.plugins.prefs.provider(key:, defaultValue:)`. Yes → the
   family, declared once as a top-level `final`:

```dart
final invoiceSortProvider = dw.plugins.prefs.providerFamily<String, int>(
  keyFor: (customerId) => 'invoices.$customerId.sort',
  defaultValue: 'createdAt',
);

final sort = ref.watch(invoiceSortProvider(customerId));
ref.read(invoiceSortProvider(customerId).notifier).update('amount');
```

`mappedProviderFamily(keyFor:, mapFrom:, mapTo:)` is the same for enums and custom types. Not a store
over `raw` read in `initState`: that state has no subscribers.

## 11. Notifications

`dw.notify.success / info / warning / error(text)` — never `ScaffoldMessenger` or a `SnackBar`. The
text comes from `context.l10n` (or the app's `appL10n` outside the tree).

## Checklist

- [ ] A screen shows a read through `DwReadBuilder`, a feed through `DwPagedListView`; no
      `.value`/`.when`/`hasError` over `ref.watch(dw.request(…))` outside `logic/` and `core/`; no
      repositories, no `lib/data/`, no copies of server state.
- [ ] A detail page's `dw.notFound` is an `onRefused` branch; no `.value ?? fallback` over reads in
      a widget; chrome (a title, an enabled button, a badge) from a `logic/` provider answering a
      plain value; no spinner outside the kit.
- [ ] No refetch after commands; retries use the notifier's `refetch()`, never `ref.invalidate`.
- [ ] `dw.command` is called in the feature's `logic/` only, inside the `dw.action` of the widget that
      owns the button; no manual refusal handling.
- [ ] A new refusal code has a string in every `.arb` and a case in the refusal texts.
- [ ] Input rules live in the command's `validate()`; forms use `requireValidation`.
- [ ] Sign-in state from `dw.accountId`; sign-out is `dw.signOut()`.
- [ ] A chat or log uses `DwWindowListView`.
- [ ] Providers hand-written, keyed by requests, ids or records, one question each.
- [ ] Notifications through `dw.notify`; persisted screen state through `dw.plugins.prefs`.
