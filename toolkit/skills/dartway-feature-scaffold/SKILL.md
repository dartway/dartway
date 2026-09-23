---
name: dartway-feature-scaffold
description: >-
  Step-by-step playbook for building a DartWay feature end to end: (1) the contract in
  __SHARED_PKG__ — data object, requests with channels, commands with DwSelfValidating, refusal
  codes; (2) the server in __SERVER_PKG__ — row class, `dart run dartway_cli:dartway generate`, a reviewed migration
  draft, one handler per call with its access rule, rows mapped to data objects in batch, publishing
  what a command changed; (3) the Flutter feature in __FLUTTER_PKG__ — a folder with one public file
  declaring its DwFeatureSpec, widgets/ and logic/, ref.watch(dw.request(...)),
  dw.action((_) => dw.command(...)), texts in l10n including refusal texts; (4) tests and checks.
  Also the Flutter feature law: what a feature, a group and a building block are, isolation (import
  the public file only), where logic lives, and that a feature must be constructible from its address
  (identifiers and data objects), never from lists and callbacks its parent assembled. Use when
  adding functionality, a screen, a flow, or a new kind of data.
---

# DartWay — building a feature, end to end

A DartWay feature runs through all three packages: the **contract** both sides compile, the
**server** that answers it, and the **Flutter feature** that shows it. Build them in that order —
the contract first, because the server and the app are both written against it, and a screen built
before its request exists is built against a guess.

Related skills, one per layer: `dartway-contract`, `dartway-server`, `dartway-access`,
`dartway-realtime`, `dartway-migrations`, `dartway-uploads`, `dartway-data-layer`,
`dartway-navigation`, `dartway-ui-kit`, `dartway-clean-code`, `dartway-testing`, `dartway-finish`.

> **If the feature already exists, read its public file first.** Its `DwFeatureSpec` is the current
> description of the behaviour, and `knownIssues` says what is already known to be wrong. The server's
> rules are in the doc comments of its handlers and of the contract classes. Change the behaviour and
> fix those descriptions in the same diff — a feature's description lives in its code.

The worked reference is in the skeleton `dartway create` gave the project: the admin members table
and the user card run through all three packages — a table request and a single request with their
channel, a role-changing command with a refusal, the handlers with an admin rule, publications to the
member's own channel and the admin channel, and two admin features on top.

## Step 1 — the contract (`__SHARED_PKG__/lib/src/`)

Decide what the screen shows and what the user changes, then declare it (`dartway-contract`):

1. **The data object** the screen shows — a two-word noun with an `id`
   (`CustomerInvoice`). It is what the user sees, not the table: fields the screen needs, resolved
   names instead of foreign keys where the screen shows names.
2. **The requests** — the kind chosen by the screen's shape (single, maybe, list, page, table,
   window); every parameter that changes the answer a field; "my" requests without an account id;
   `channels` so the screen follows changes (`dartway-realtime`); `matches`/`sort` where the kind
   inserts.
3. **The commands** — verb+object; only the user's input and the ids acted on, never the owner,
   timestamps or a status the server moves; `DwFieldPatch` for clearable fields;
   `implements DwSelfValidating` for input rules.
4. **Refusal codes** in the project's refusal enum, each with a doc comment saying when it happens.
5. Export the new file from `lib/__SHARED_PKG__.dart`, run `dart run dartway_cli:dartway generate`, and extend the shared
   contract test (round trip, `validate()`, `onUpdate`).

If the change alters a DTO that installed app builds already use, check the table in
`dartway-contract` ("a DTO change is a contract change between app builds") before going on.

## Step 2 — the server (`__SERVER_PKG__/lib/src/`)

Details in `dartway-server`; the order:

1. **Row class** (`InvoiceRow extends DwTableRow`, `@DwSqlTable`, foreign keys, indexes for the
   queries the handlers will make). Nullable only when the domain allows absence.
2. **`dart run dartway_cli:dartway generate`** — writes the row part and `lib/generated/dw_schema.dart`
   (`db.invoices`).
3. **Migration draft:** from `__SERVER_PKG__`, `dart run bin/migrate.dart create <snake_name>`. It
   writes a draft into `lib/src/migrations/` and registers it. **Review it before applying** — from
   then on it is an ordinary migration and yours: a new non-null column on a table with rows needs a
   default or a backfill, a rename is not a drop and an add (`dartway-migrations`).
4. **Handlers — one per request and command**, each with its access rule (`dartway-access`):
   ownership checked in the handler, someone else's row answering `dw.notFound`; commands locking the
   row they change (`DwRowLock.forUpdate`); refusals with `ctx.refuse`.
5. **Rows → data objects in batch** — one mapping function per area, relations loaded with
   `findByIds` once per relation; every handler and every publication goes through it.
6. **Publish what a command changed** to every channel that shows it, after commit
   (`ctx.publish`); deletions as `DwDeletedObject.of<T>(id, ctx.protocol)`; add the channel rule when
   the kind is new (`dartway-realtime`).
7. Register the handler list, channel rules and jobs in the server library.

## Step 3 — the Flutter feature (`__FLUTTER_PKG__`)

### Where it goes

A feature lives in a **zone**, and the zones are four folders at the top of `lib/`: `app/` (the app
itself), `admin/` (the admin panel), `auth/` (signing in), `common/` (features more than one zone draws
on). The rest of the top level is closed too: `core/`, `shared/`, `ui_kit/`, `l10n/`, plus `main.dart`
and `__FLUTTER_APP_FILE__`. There is no `data/` (the data layer is `dw.request` and `dw.command` over
the contract) and no `domain/` (the rules live in the contract and the handlers). `dart run dartway_cli:dartway check`
reports anything else as `invalidTopLevelLayout` — a zone name used lower down included: `app/admin/`
is not the admin panel, it is a group that has quietly left every check written for zones.

```
lib/app/<feature>/
  <feature>_page.dart        // the only public file — a widget
  widgets/                   // the feature's building blocks
    <feature>_row.dart
  logic/                     // optional: providers, enums, helpers of this feature only
    <feature>_filter.dart
```

- **The public file** is the only file imported from outside, at any nesting depth, and it is a
  widget: a page, or a widget that carries its own way of being shown.
- **`widgets/`** holds blocks only — what lays out what it was handed.
- **`logic/`** holds what only this feature uses.
- Cross-feature helpers (an extension on a data object, a formatter) → `lib/shared/`. Styles →
  `ui_kit.dart` only. Imports: relative inside the feature and to a sibling feature, `package:` for
  everything further away (`dartway-clean-code`).

### Feature, group, building block

A folder **without** root-level `.dart` files is a **group**: it only groups features, encapsulates
nothing and does not affect visibility — the router may import `app/billing/invoice/invoice_page.dart`
because `invoice` is a feature and `billing` a group. The moment a feature gains a second public
entity (a screen plus an embeddable block, a three-screen flow, a card both of them draw), it becomes a
group of features, each with its one public file. **Behaviour two features share is one more feature.**

| | Where | Described by |
|---|---|---|
| **Feature** — it reads a data object and **decides** something by it: shows different things in different states, picks a label, hides a button, opens a dialog, sends a command | a zone | `DwFeatureSpec` |
| **Building block** — it **arranges what it was handed**: a row, an inset, a form field, a badge | `lib/shared/` | a doc comment |
| **Layer** — presentation, wiring, localisation | `ui_kit/`, `core/`, `l10n/` | — |

The criterion is read off the file: **does this widget decide anything by the data, or lay out what it
was given?** Decides → a feature, however small (a card in a list, one row of work). Lays out → a block.
A file in `widgets/` that switches over a data object, picks a label from a state or fires an action is
a feature standing in the wrong place — move it up beside its neighbours and give it a spec. **Split
small**: every feature brings its own `behaviors` and `knownIssues`, so the finer the cut, the denser the
description.

**Not a feature:** state several features watch and app-wide registries → `lib/core/`; a helper with no
story → `lib/shared/`. A folder in a zone whose public file is not a widget is `notAFeature` (error);
the tell is that you cannot write `purpose` and `behaviors` for it without restating the type name.

### Where a feature's logic lives — bottom up

1. **In the widget** — the default. A couple of `ref.watch(dw.request(...))` calls, local state in
   hooks, a `.where` over a list already loaded.
2. **A provider plus a decision on the state type** — when state is derived from several sources or
   carries a rule. The provider says where the data comes from, a factory on the state type decides
   what follows (time passed in, not read). Written by hand (`dartway-data-layer`).
3. **A `Notifier`** — when the feature owns mutable state: a draft, a multi-select, a step-by-step
   flow. First check it does not duplicate what the server already holds: a command's result is in
   the watched requests without any local copy.

State used by two features is a feature whose public surface is a provider: the provider in the root
file, the state class and the notifier in `logic/`. State only one feature uses may keep notifier and
provider in one file — provider first.

### Build it

1. **Navigation** — the entry and exit points; a route if needed (`dartway-navigation`).
2. **The public widget**, `implements DwFeatureWidget` with its `DwFeatureSpec` (below). Without it
   `dart run dartway_cli:dartway check` warns `featureSpecMissing`.
3. **Reads:** `ref.watch(dw.request(...))` (or `dw.pages` / `dw.table` / `dw.window`), with the section
   it exists for rendering its error — the skeleton's shared section extension (`dartway-data-layer`).
4. **Changes:** `dw.action((_) => dw.command(...))` on the button, in the widget that owns it; a
   refusal is shown by itself.
5. **Texts:** every user-visible string in **every** `lib/l10n/*.arb`, then `flutter gen-l10n`; widgets
   read `context.l10n`. **Each new refusal code gets its text** and its case in the app's refusal
   texts in `lib/core/` — the exhaustive switch does not compile until it has one.
6. **Showing a feature that is not a route** — a sheet or a dialog publishes itself as a static method
   on its own widget, taking `BuildContext` first:

```dart
class InvoiceEditSheet extends ConsumerWidget implements DwFeatureWidget {
  const InvoiceEditSheet({super.key, required this.invoiceId});

  static Future<void> show(BuildContext context, {required int invoiceId}) =>
      context.showAppBottomSheet(child: InvoiceEditSheet(invoiceId: invoiceId));

  final int invoiceId;
  // …
}
```

Not an `extension on BuildContext` (`context.showInvoiceEdit()`): that splits the feature into two
public entities, hides the widget, and leaves the spec nowhere to live.

### A feature is constructible from its address

**The test, one attempt:** write the call. Can the widget be constructed in the router, in a
`showDialog`, in a `ListView.builder` — with nothing in hand but identifiers and data objects?

- yes → a feature; it reads the rest itself;
- no → it is part of its parent's layout; fold it back, or take the assembled data out of its
  constructor.

A constructor that requires a `Function`, a `Map` or a `List` of something the parent computed is the
shape to look for. A list of data objects is not automatically wrong (a card list takes its items); a
list the parent had to compute is.

### Example

```dart
// lib/app/invoices/my_invoices/my_invoices_page.dart
class MyInvoicesPage extends ConsumerWidget implements DwFeatureWidget {
  const MyInvoicesPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'invoices/my-invoices',
    title: 'My invoices',
    purpose: 'A member sees what they owe and pays it.',
    behaviors: [
      'Invoices are listed newest first.',
      'Paying an invoice marks it paid at once, on every device of the member.',
      'A paid invoice has no pay button.',
    ],
    requirements: [
      'A member sees only their own invoices — decided by the server, which '
          'reads the caller, not by this screen.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final request = dw.request(const ListMyInvoices());

    return Scaffold(
      body: ref.watch(request).dwBuildAsync(
        loadingWidget: const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _) => LoadFailedMessage(
          onRetry: dw.action((_) => ref.read(request.notifier).refetch()),
        ),
        childBuilder: (invoices) => invoices.isEmpty
            ? AppText.body(l10n.noInvoicesYet)
            : ListView(
                children: [
                  for (final invoice in invoices) InvoiceCard(invoice: invoice),
                ],
              ),
      ),
    );
  }
}
```

`InvoiceCard` decides by the invoice (a pay button only while it is unpaid) — so it is a feature of
its own (`lib/app/invoices/invoice_card/invoice_card.dart`), constructible from the invoice alone, and
it sends `PayInvoice` from its own button. `AppText` and `LoadFailedMessage` stand for the project's kit
and shared widgets; in a real screen the skeleton's section extension replaces the manual
`dwBuildAsync` call.

## The feature spec — `DwFeatureSpec`

A feature describes itself **in its own file**, and that is its only description: no registry, no
separate doc. A description apart from the code drifts on the first edit, silently. Error reports,
Studio and the agent read this one.

- **`id`** — `<feature-folder>/<meaningful-name>`. A contract: Studio, feedback and tickets refer to
  it. The folder moves, the id stays; a new name is a new id, never a rename in place.
- **`title`** — what the feature is called out loud.
- **`purpose`** — why the user needs it. Optional and often unnecessary: a card serves its screen.
- **`behaviors`** — what the feature observably does, one statement per item, **each verifiable by
  looking at the running app**.
- **`requirements`** — what it must honour, imposed from outside (who may see it, what the server
  enforces). Phrased as an observable action → it belongs in `behaviors`.
- **`implementationNotes`** — what the code cannot say about itself: why it is done this way, a trap
  not visible from outside. Test: would it still be worth reading after a rewrite? "The list is not
  paged — a member has dozens of invoices, not thousands" survives; "the list comes from
  `dw.request(ListMyInvoices())`" is a map of the code and starts lying at the next edit.
- **`knownIssues`** — what is **wrong** and worth picking up, one sentence with its cost. If fixing it
  makes the entry disappear, it is a known issue; if it stays as an explanation, it is a note. Record
  a finding in the feature you noticed it in, when you notice it.

**Write the spec from what the code does, not from what was intended.** Phrasing verifiable
statements is how undeclared behaviour surfaces.

## Step 4 — tests and checks

Tests (`dartway-testing`), by layer:

- **shared** (`dart test` in `__SHARED_PKG__`): round trip of the new DTOs, `validate()`, `onUpdate`
  of the new requests;
- **server** (`dart run dartway_cli:dartway test`): each handler's behaviour on real clients and a real database; **one
  refused call per access rule** (`dartway-access`); a second client hearing what a command published
  (`dartway-realtime`);
- **Flutter** (`flutter test` in `__FLUTTER_PKG__`): a widget test of the feature over the fake server
  — its reads answered, its command recorded, a publication applied — with the skeleton's test app
  harness.

Checks, all green before `dartway-finish`:

```bash
cd __FLUTTER_PKG__
dart run dartway_cli:dartway generate --check              # generated code matches its sources
dart run bin/migrate.dart check       # in __SERVER_PKG__, against the local database: migrations match the rows
dart run dartway_cli:dartway test                          # server tests with a throwaway Postgres and storage
flutter test                          # in __FLUTTER_PKG__
dart run dartway_cli:dartway check                         # layout, features, UI kit, l10n, generated code, migrations
```

Then run `dartway-finish`: it audits the diff against the cleanliness contract, reconciles the
`DwFeatureSpec` and the handlers' doc comments with the new behaviour, and checks the tests.

## Checklist

- [ ] Contract: data object, requests (kind, fields, channels), commands (input only, `validate()`),
      refusal codes; `dart run dartway_cli:dartway generate`; shared test extended.
- [ ] Server: row class, generated, migration drafted **and reviewed**; one handler per call with an
      access rule; batch mapping; every change published; channel rule for a new kind.
- [ ] Flutter: one public widget with a `DwFeatureSpec`; blocks in `widgets/`; constructible from its
      address; reads with an error branch; changes through `dw.action`; texts and refusal texts in
      every `.arb`.
- [ ] Tests at each layer, including refused calls and a live update.
- [ ] `dart run dartway_cli:dartway generate --check`, `migrate check`, `dart run dartway_cli:dartway test`, `flutter test`, `dart run dartway_cli:dartway check` pass.
