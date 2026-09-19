---
name: dartway-contract
description: >-
  The shared package (__SHARED_PKG__) of a DartWay project — the contract the server and the app
  both compile: data objects (DwDataObject, an int or String id), requests (DwSingleRequest,
  DwMaybeRequest, DwListRequest, DwPageRequest, DwTableRequest, DwWindowRequest and their named
  constructors) with channels, commands (DwActionCommand<R>, one result value), DwFieldPatch for
  clearable fields, defaults on the wire, DwSelfValidating, the project's refusal enum
  (DwRefusalCodes), channel kinds (DwChannelKind), upload purposes (DwUploadPurpose), naming
  (two words, Get…/List…, verb+object), and generation (`dartway generate`, `*.dw.dart`,
  lib/generated/ — never edited). Also what a DTO change costs installed app builds and when to
  raise minAppBuild. Use when adding or changing a data object, a request, a command, a refusal
  code, a channel kind or an upload purpose, or when choosing which request kind a screen needs.
---

# DartWay — the contract (`__SHARED_PKG__`)

Everything the app and the server exchange is declared in `__SHARED_PKG__`, in pure Dart, and
nowhere else. Both sides compile the same classes: the server decodes what the app encoded with the
same generated codec, and a rule written here (`validate()`, `matches`) runs identically on both.
A rule written twice — once in a handler, once in a widget — drifts silently, because each copy
passes its own tests.

**Allowed:** `dartway_core_shared` and pure Dart. **Not allowed:** Flutter, a database, IO, anything
from `__SERVER_PKG__` or `__FLUTTER_PKG__`. The public library `lib/__SHARED_PKG__.dart` exports
`package:dartway_core_shared/dartway_core_shared.dart`, `generated/dw_protocol.dart` and every
`src/` file.

Related skills: `dartway-server` (the handler of every call declared here), `dartway-realtime`
(channels, `matches`, `sort`, update actions), `dartway-access` (who may call), `dartway-data-layer`
(how the app watches and sends these), `dartway-uploads`, `dartway-testing`.

In the samples below `AppChannel` and `AppRefusal` stand for the project's own
`<Project>Channel` and `<Project>Refusal`; the domain (`CustomerInvoice`) is invented.

## 1. Three kinds of DTO, nothing else

| Kind | Extends | Is |
|---|---|---|
| Data object | `DwDataObject` | what the server returns and publishes; has an `id` (`int` or `String`) that updates merge by |
| Request | one of the six `DwDataRequest` kinds | a read: no side effects, its fields are its parameters |
| Command | `DwActionCommand<R>` | a change: its fields are its input, `R` its answer |

A project never extends `DwWireObject` or `DwServerCall` directly. Rows (`…Row`) are server-only and
never appear here — the handler maps a row to a data object explicitly (`dartway-server`).

The shape every DTO file has:

```dart
import 'package:dartway_core_shared/dartway_core_shared.dart';

import 'app_channel.dart';
import 'app_refusal.dart';

part 'invoices.dw.dart';

enum InvoiceStatus { draft, sent, paid }

/// An invoice as its owner sees it.
final class CustomerInvoice extends DwDataObject with _$CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    required this.customerName,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.note,
  });

  @override
  final int id;
  final String customerName;
  final int amountCents;
  final InvoiceStatus status;
  final DateTime createdAt;
  final String? note;
}
```

The rules the generator enforces (it refuses the file with a message otherwise):

- `part '<file>.dw.dart';` exactly once, and `with _$ClassName` on every DTO class;
- the class `extends` its kind (not `implements` or `with`) and has no type parameters;
- every serialised field is `final` and set by a **named** constructor parameter of the same name
  (a field with an initializer stays off the wire); declare the class `final` with a `const`
  constructor, as the skeleton does — requests are compared and cached as values;
- field types: `int`, `double`, `String`, `bool`, `DateTime` (UTC microseconds on the wire),
  `Duration`, `Uint8List`, an enum (by name), another concrete DTO class, `List<T>`,
  `Map<String, T>`, `DwFieldPatch<T>`, or a nullable one of these;
- a data object declares `@override final int id;` (or `String`), or an `id` getter — a single
  object with a fixed identity uses a getter (`String get id => 'invoice-totals';`).

`==`, `hashCode`, `toString`, `toJson`, the decoder and `copyWith` are generated. Rebuild an
existing value with `copyWith`, never by listing its fields in the constructor: a field added later
silently takes its default in every place that rebuilt by hand.

## 2. Naming

Every public class name has two or more words (`Dw` is not a word).

| What | Shape | Such as |
|---|---|---|
| Data object | two-word noun | `CustomerInvoice`, `InvoiceTotals` — never `Invoice` |
| Read | `Get…` (one object), `List…` (many) | `GetInvoice`, `ListMyInvoices`, `ListOverdueInvoices` |
| Change | verb + object | `CreateInvoice`, `PayInvoice`, `CancelInvoice` |
| Caller-scoped call | `My` in the name, no account id in the fields | `ListMyInvoices`, `UpdateMyProfile` |
| Channel kinds | `<Project>Channel` enum `with DwChannelKind` | |
| Refusal codes | `<Project>Refusal` enum `with DwRefusalCodes` | |
| Upload purposes | `<Project>Upload` enum `with DwUploadPurpose` | |

**The class name is the wire name** — the call path is `POST /dw/<ClassName>` and updates are grouped
by it. Renaming a DTO class is a wire change (section 9).

## 3. Choosing the request kind

Decide by the shape of what the screen shows, not by the table behind it:

| The screen shows | Kind | Declared as | Server handler |
|---|---|---|---|
| one object that must exist — a detail page by id, "my profile" | `DwSingleRequest<T>` | `const GetInvoice({required this.invoiceId})` | `single`: return `null` → the framework refuses `dw.notFound` |
| one object that may be absent — "my open draft, if any" | `DwMaybeRequest<T>` | must override `bool matches(T item)` | `maybe`: `null` is an answer |
| a whole list, small enough to send at once | `DwListRequest<T>` | `super()` | `list` |
| a list whose membership only the server decides | `DwListRequest<T>` | `super.updateOnly()` | `list` |
| a derived list the client cannot compute (a ranking, an aggregate) | `DwListRequest<T>` | `super.refetchOnUpdate()` | `list` |
| an endless feed with "load more" | `DwPageRequest<T>` | `super(pageSize: 20, maxPageSize: 100)` | `page` |
| numbered pages with a total — an admin table | `DwTableRequest<T>` | `page`/`pageSize` **fields**, `super(maxPageSize: 100)` | `table`: `rows` + `count` |
| a long newest-first sequence opened at an anchor — a chat, a log | `DwWindowRequest<T, S, I>` | `super(pageSize: 40)`, `positionOf` | `window` |

The named constructors choose what an update does (`dartway-realtime`): the default of the list
kinds is `matches ? upsert : remove`; `.updateOnly()` replaces what is there and never inserts;
`.refetchOnUpdate()` asks again on any update.

Page size is a **constant of the class** for page and window requests (the client cannot ask the
server for everything); for a table it is a field, because page 2 and page 3 are different states.
The order a page, table or window handler reads in must be total (`createdAt, id`), or pages skip
and repeat rows.

```dart
/// The caller's invoices, newest first, live on the caller's own channel.
final class ListMyInvoices extends DwListRequest<CustomerInvoice>
    with _$ListMyInvoices {
  const ListMyInvoices();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(AppChannel.invoices),
  ];

  @override
  int Function(CustomerInvoice a, CustomerInvoice b) get sort =>
      (a, b) => b.createdAt.compareTo(a.createdAt);
}

/// One numbered page of every invoice, filtered by status. Managers only.
final class ListInvoicesPage extends DwTableRequest<CustomerInvoice>
    with _$ListInvoicesPage {
  const ListInvoicesPage({this.page = 1, this.pageSize = 20, this.status})
    : super(maxPageSize: 100);

  @override
  final int page;

  @override
  final int pageSize;

  final InvoiceStatus? status;

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel(AppChannel.billing),
  ];

  /// The server's filter, on one object: a row that leaves it leaves the page.
  @override
  bool matches(CustomerInvoice item) => status == null || item.status == status;
}
```

A `DwWindowRequest` names one row's place in the sequence, and both sides use it — the server builds
and checks cursors with it, the client places live inserts with it:

```dart
@override
DwWindowPosition<DateTime, int> positionOf(InvoiceEvent item) =>
    (sortValue: item.happenedAt, id: item.id);
```

`S` is `int`, `String` or `DateTime`; `I` is `int` or `String`.

## 4. A request's fields are its complete filter

A request is a value: the client caches its state under the request itself (equality is generated
from the fields) and keeps it live. So:

- **everything that changes the answer is a field.** A status filter, a search string, a page, a
  date. "Today" is a `DateTime day` field the widget fills in — not `DateTime.now()` in the handler,
  which would answer differently for two equal requests;
- **the caller is not a field.** "My" requests carry no account or profile id: the handler reads the
  caller from its context, and the client already keeps state per signed-in account. A field holding
  the caller's own id is a field anyone can change to someone else's (`dartway-access`);
- `channels`, `matches`, `sort` and `positionOf` are pure functions of the item and the fields.
  `DateTime.now()` or a global inside them is a bug.

## 5. Commands: input only, and one answer

A command carries **what the user decided**: the ids of the things it acts on and the values typed
in. It never carries what the server decides — the owner, the caller's id, timestamps, a status
the server moves, a price the server computes, a storage key. The handler derives those from its
context; a field for them is an invitation to forge them.

The answer `R` is **one value** (D-006): a data object, a JSON primitive (`int`, `double`, `num`,
`String`, `bool`), or nothing (`DwActionCommand<void>`; a nullable `R` may answer `null`). A
collection is wrapped in a data object; `dartway generate` refuses any other `R`. Usually the answer is the object the command changed; the
other objects it changed reach the screens through publications (`dartway-realtime`), not through
the answer.

Every command travels with an idempotency key the client generates once per intent: a retry after a
lost answer gets the stored outcome, not a second execution. Nothing to declare for that.

### `DwFieldPatch` — a field that can be cleared

A plain nullable field cannot tell "leave it" from "clear it". An edit command uses:

| Field | Meaning |
|---|---|
| `final String? firstName;` (default `null`) | `null` keeps; the value cannot be cleared |
| `final DwFieldPatch<String> note;` with `this.note = const DwFieldPatch.keep()` | keep / `DwFieldPatch.set(v)` / `DwFieldPatch.clear()` |

The inner type is non-nullable (`DwFieldPatch<String>`, not `DwFieldPatch<String?>`), and a patch
field is never itself nullable. On the wire a kept field is absent, a set one carries its value, a
cleared one an explicit `null`. The server passes it straight to the row's generated `copyWith`,
whose nullable parameters take a `DwFieldPatch` too.

```dart
/// Edits a draft invoice. A field left as it is is kept.
final class EditInvoice extends DwActionCommand<CustomerInvoice>
    with _$EditInvoice
    implements DwSelfValidating {
  const EditInvoice({
    required this.invoiceId,
    this.amountCents,
    this.note = const DwFieldPatch.keep(),
  });

  final int invoiceId;
  final int? amountCents;
  final DwFieldPatch<String> note;

  @override
  List<DwCallRefusal> validate() => [
    if (amountCents case final amount? when amount <= 0)
      DwCallRefusal(AppRefusal.amountNotPositive, field: 'amountCents'),
  ];
}
```

## 6. Defaults on the wire

A field with a constructor default may be absent on the wire: the decoder applies the default, and
the encoder omits a value equal to it (D-041). A required field without a default must be present,
or the call is malformed (`400`). Choose defaults deliberately — they are also what makes adding a
field safe for app builds already installed (section 9).

## 7. Validation — `DwSelfValidating`

A request or command whose input can be wrong `implements DwSelfValidating` and returns **every**
problem from `validate()`:

- the **client** runs it before sending — the first refusal is the answer at once and nothing is
  sent;
- the **server** runs it again before the access check and the handler — a client is never trusted
  to have checked.

`validate()` reads the DTO's fields and nothing else: no IO, no clock, no database. A rule that
needs data ("the invoice is already paid") is a refusal in the handler (`ctx.refuse`,
`dartway-server`). Point at the input with `field:`; put the numbers a text needs in `params`
(they travel as strings).

A table request's page and page size below 1 are refused by the framework (`checkPage`) without any
code.

## 8. Refusal codes, channel kinds, upload purposes

```dart
/// Why the server refuses. Codes only: the app renders each through its
/// refusal texts, and a code added here needs a text there.
enum AppRefusal with DwRefusalCodes {
  /// An invoice that is paid cannot be edited or paid again.
  invoiceAlreadyPaid,

  /// An amount is a positive number of cents.
  amountNotPositive,
}

/// The app's live channels. The server declares who may subscribe to each.
enum AppChannel with DwChannelKind {
  /// One member's own invoices: a caller channel. Its owner only.
  invoices,

  /// Everything the billing screens show. Managers only.
  billing,
}

/// What an uploaded file is for. The server declares one rule per purpose.
enum AppUpload with DwUploadPurpose {
  invoiceScan;

  /// Read by the server's rule and by the app's picker alike.
  static const int invoiceScanMaxBytes = 10 * 1024 * 1024;
}
```

- **A refusal is a code with parameters, never a sentence.** The wire code is the enum value's name
  (the framework's own are `dw.*`: `DwCoreRefusal`, `DwAuthRefusal`, `DwUploadRefusal`). Texts live in
  the app — `dartway-data-layer`. Before adding a code, check whether `DwCoreRefusal.notFound`,
  `forbidden`, `conflict` or `invalid` with a `field` already says it.
- Doc-comment every code with when it happens and what the user can do — that comment is what the
  person writing its text reads.
- A channel kind's name must not contain `:`. Its access rule lives on the server
  (`dartway-realtime`); a kind without one refuses every subscription.
- Limits both sides read (max bytes, content types) sit on the purpose enum as constants. The rule
  itself is the server's — `dartway-uploads`.

## 9. A DTO change is a contract change between app builds

The web app ships with the server, but an installed mobile build keeps calling the server it was
built against — for weeks. The framework's own wire format is guarded by the protocol version and
is not the project's concern; **the project's DTOs are**. What an old build does with a change:

| Change | Old installed build |
|---|---|
| add an optional field with a default (or nullable) to a request or command | keeps working — it omits the field, the server decodes the default |
| add a field to a data object | keeps working — it ignores the key |
| add a new request or command | keeps working — it never calls it |
| add a **required** field without a default to a request or command | its calls fail as malformed (`400`) |
| rename or remove a field of a data object the old build reads | the answer does not decode on the old build |
| add a value to an enum carried in a data object | the old build reads an object holding it as "this app is out of date" and shows its update screen — no call fails, no list breaks; an open enum (below) reads it as `unknown` |
| publish a new data object type on a channel old builds already listen to | the update does not decode: the old build reports a protocol error and reads that channel's requests again, every time |
| rename or remove a request or command class | its calls answer "unknown call" (`404`) |
| rename a refusal code | the old build shows its generic refusal text |

**Prefer the additive change:** a new optional field, a new call beside the old one, the old handler
kept until no supported build uses it. When a breaking change is unavoidable, raise the server's
minimum build to the first build that speaks the new contract: `DwServerSettings.minAppBuild`. A
call whose `Dw-App-Version` build is lower is answered `426` with `dw.updateRequired`, and the app
shows its update-required screen instead of failing call by call. The value is read when the server
starts — the skeleton's `bin/server.dart` takes it from `DW_MIN_APP_BUILD` — so raising it takes a
restart, not a release. The build is the `+N` of the app's version in `__FLUTTER_PKG__/pubspec.yaml`.

Say which kind of change it is in the commit and the pull request; a breaking one names the
`minAppBuild` it needs.

### Open enums — rare, by declaration

Every enum is strict: a name the build does not know is not a value to guess, it means the app is
older than the data, and the client switches to the update screen by itself. That is what keeps an
exhaustive `switch` over an enum honest.

Mark an enum `with DwOpenEnum` — with a value named `unknown` — only when a value is **for display
alone** and an unknown one can be shown neutrally or left out without anyone acting on it wrongly:
the kind of an entry in an activity feed, the icon of a notification. **Never** when behaviour
depends on the value: a status that decides what may happen next, a role, a permission, a kind of
payment. Every reader turns an unknown name into `unknown` (the screen must handle it: hide the
row, show a neutral label); `unknown` can never be written to a **row**, so nothing stored is
overwritten with it, and it does travel on the wire as itself — an older server answering from a
row it cannot read sends `unknown` instead of failing the answer. `dartway generate` refuses an open enum without `unknown`.

**An open enum in a command is the case those two halves create together**, and the framework
answers it rather than leaving it to you: a build that read `unknown` off the wire and sends it
back in a command is older than the data it is writing, so the call is answered
`dw.updateRequired` — the update screen — and nothing is stored. Not an incident and not the
caller's mistake: no alert reaches the operator, and no "internal server error" reaches the user.
Prefer not to put an open enum in a command at all: it is a display value, and a command that
carries one is asking an app to write back something it could not read.

## 10. Generation

After any change to a DTO file (and to a row class on the server), from the project root:

```bash
dartway generate          # writes every *.dw.dart and lib/generated/ in both packages
dartway generate --check  # exits non-zero when anything is out of date; CI runs it
```

**`dartway` here means the CLI this project pins**, which is `dart run dartway_cli:dartway <command>`
— the project carries it as a dev dependency at the version of the framework it pins. A globally
activated `dartway` may be older than the project and write the wrong files or lack the command
outright; it refuses rather than guessing, and names the invocation above.

It writes, in `__SHARED_PKG__`, the `*.dw.dart` parts and `lib/generated/dw_protocol.dart` — the
protocol registry `<project>Protocol` that the server and `DwFlutterCore` are built with; in
`__SERVER_PKG__`, the row parts and `lib/generated/dw_schema.dart`. **Never edit `*.dw.dart` or
`lib/generated/` by hand**, and commit them with the source change: a stale codec is the wire, so a
field its part does not know compiles, starts, and travels without that field. `dartway check`
reports drift as `generatedCodeStale`, an error.

The generator runs from the server package's dev dependency (`dartway_generator`), so it always
matches the framework the project builds against. A refused declaration is printed with the file
and the reason — fix the declaration, never the output.

## 11. Test the contract where it lives

`__SHARED_PKG__/test/` (plain `dart test`, no services) holds the checks that need no server:

- every new DTO round-trips: `<project>Protocol.decodeNamed(dto.dwTypeName, dto.toJson())` equals
  `dto`;
- `validate()` answers the codes and fields you expect, and nothing for good input;
- `matches`, `sort`, `onUpdate` answer what the screen needs
  (`request.onUpdate(object)` → `DwUpdateAction.upsert` / `remove`);
- a caller channel resolves per account: `request.channels.single.resolvedFor(42).wireName`.

The skeleton's shared package ships such a test; extend it rather than starting another.

## Checklist

- [ ] Names: two words; `Get…`/`List…`; verb+object; `My…` without an account id.
- [ ] Request kind chosen by the table in section 3; `matches` on a maybe request; total order
      for page/table/window.
- [ ] Every parameter that changes a request's answer is a field; nothing impure in `channels`,
      `matches`, `sort`, `positionOf`.
- [ ] A command carries no owner, caller id, timestamp, server status or storage key.
- [ ] Clearable edit fields are `DwFieldPatch<T>` defaulting to `keep()`.
- [ ] `validate()` covers input rules, reads fields only; data rules stay in the handler.
- [ ] New refusal codes documented; the app has a text for each.
- [ ] The change is additive for installed builds, or `minAppBuild` is named.
- [ ] `dartway generate` run and its output committed; `dartway generate --check` passes.
- [ ] The shared contract test covers the new DTOs.
