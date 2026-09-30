---
name: dartway-contract
description: >-
  The shared package (__SHARED_PKG__), the contract both sides compile: data objects, the six request
  kinds and how to choose one, commands (DwActionCommand<R>), DwFieldPatch, settings objects,
  defaults on the wire, DwSelfValidating, the refusal / channel / upload enums, where a DTO lives,
  generation, and what a DTO change costs installed app builds (the contract's breaking line). Use
  when adding or changing a DTO, a refusal code, a channel kind or an upload purpose.
---

# DartWay — the contract (`__SHARED_PKG__`)

Pure Dart: `dartway_core_shared` and nothing from Flutter, IO, a database or the other two packages.
A rule written here (`validate()`, `matches`) runs identically on both sides; written twice, once per
side, it drifts. Samples use the package `acme_shared`, so its enums are `AcmeChannel`, `AcmeRefusal`,
`AcmeUpload`.

## 1. Three kinds of DTO, in the file of their server feature

| Kind | Extends | Is |
|---|---|---|
| Data object | `DwDataObject` | what the server returns and publishes; an `int` or `String` `id` updates merge by |
| Request | one of the six request kinds (§3) | a read: no side effects, its fields are its parameters |
| Command | `DwActionCommand<R>` | a change: its fields are the input, `R` the answer |

**`lib/src/` mirrors the server's features** (`invalidSharedLayout`): the DTOs of the server feature
`invoices/` are `lib/src/invoices.dart`, a DTO goes where its handler is, and a rule both sides apply
goes with the feature that owns it. Grown past the file limits (`fileLong`/`fileTooLong`, as in the
app), it becomes a flat `lib/src/invoices/` of parts `invoices_<part>.dart`, each a data object with
the calls that answer it — never a layer name. Beside the features: only `acme_channel.dart`,
`acme_refusal.dart`, `acme_upload.dart`, `acme_protocol.dart` and `acme_push_category.dart`.

```dart
import 'package:dartway_core_shared/dartway_core_shared.dart';

part 'invoices.dw.dart';

/// An invoice as its owner sees it.
final class CustomerInvoice extends DwDataObject with _$CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    required this.customerName,
    required this.amountCents,
    this.note,
  });

  @override
  final int id;
  final String customerName;
  final int amountCents;
  final String? note;
}
```

The generator refuses anything else, naming the reason: one `part '<file>.dw.dart'`, `with _$Class`,
the class `extends` its kind and has no type parameters, every serialised field `final` and set by a
named constructor parameter of the same name (declare the class `final` with a `const` constructor);
field types `int`, `double`, `String`, `bool`, `DateTime` (UTC), `Duration`, `Uint8List`, an enum, a
DTO, `List`, `Map<String, T>`, `DwFieldPatch<T>`, or nullable. A single object with a fixed identity
uses an `id` getter (`String get id => 'invoice-totals';`).

**Names** follow law 5 (`contractNameInvalid`); a caller-scoped call says `My` and carries no account id
(`ListMyInvoices`). **The class name is the wire name** (`POST /dw/<ClassName>`): renaming one is a
wire change (§8).

## 2. A request's fields are its complete filter

A request is a value: the client caches and shares its live state under the request itself.

- Everything that changes the answer is a field — a filter, a search string, a page, a date. "Today" is
  a `DateTime day` field the widget fills, not `ctx.now` in the handler.
- The caller is never a field: the handler reads it from the context (`dartway-access`).
- `channels`, `matches`, `sort`, `positionOf` and an overridden `onUpdate` are pure functions of the
  item and the fields — no clock, no global.

## 3. Choosing the request kind — by the shape of the screen

| The screen shows | Kind | Declared as | Handler (`dartway-server`) |
|---|---|---|---|
| one object that must exist | `DwSingleRequest<T>` | `const GetInvoice({required this.invoiceId})` | `single`; `null` → `dw.notFound` |
| one object that may be absent | `DwMaybeRequest<T>` | overrides `matches` | `maybe`; `null` is an answer |
| a small whole list | `DwListRequest<T>` | `super()` | `list` |
| a list only the server can filter (a ranking) | `DwListRequest<T>` | `super.updateOnly()` | `list` |
| a derived list (an aggregate) | `DwListRequest<T>` | `super.refetchOnUpdate()` | `list` |
| an endless feed | `DwPageRequest<T>` | `super(pageSize: 20, maxPageSize: 100)` | `page` |
| numbered pages with a total | `DwTableRequest<T>` | `page`/`pageSize` fields, `super(maxPageSize: 100)` | `table` |
| a newest-first sequence at an anchor — a chat, a log | `DwWindowRequest<T, S, I>` | `super(pageSize: 40)`, `positionOf` | `window` |

What an update does to each kind is `dartway-realtime`. The order a page, table or window handler reads
in is total (`createdAt, id`). A window names a row's place for both sides:
`DwWindowPosition<DateTime, int> positionOf(InvoiceEvent item) => (sortValue: item.happenedAt, id: item.id);`
(`S` is `int`, `String` or `DateTime`; `I` is `int` or `String`).

```dart
/// The caller's invoices, newest first, live on the caller's own channel.
final class ListMyInvoices extends DwListRequest<CustomerInvoice>
    with _$ListMyInvoices {
  const ListMyInvoices();

  @override
  List<DwLiveChannel> get channels => const [
    DwLiveChannel.ofCaller(AcmeChannel.invoices),
  ];

  @override
  int Function(CustomerInvoice a, CustomerInvoice b) get sort =>
      (a, b) => b.id.compareTo(a.id);
}
```

## 4. Commands: the user's input, one answer

A command carries the ids it acts on and what the user typed — **never what the server decides**: the
owner, the caller's id, timestamps, a status the server moves, a computed price, a storage key, the
caller's UTC offset (`ctx.callerUtcOffset`). The answer `R` is one value — a data object, a JSON
primitive, or `void`; a collection is wrapped in a data object (the generator refuses others). Other
objects the command changed reach screens by publication, not in the answer. Idempotency keys are the
client's; nothing to declare.

**`DwFieldPatch<T>` — a field that can be cleared.** A plain nullable field cannot tell "keep" from
"clear": an edit command declares `final DwFieldPatch<String> note;` defaulting to
`const DwFieldPatch.keep()` (inner type non-nullable, the field never nullable). It is read through its
helpers (`fieldPatchMatched` fails matching its variants):

| Need | Write |
|---|---|
| an existing row | `row.copyWith(note: command.note)` |
| a value for a constructor | `command.note.apply(null)` — kept means the default |
| a typed text: trimmed, blank clears | `command.note.trimmedOrCleared` |
| a check on a new value only | `if (command.photoFileId.newValue case final id?) …` |
| its state; another type | `isSet`, `isCleared`, `isKept`; `command.photoFileId.map(…)` |

**Validation** — a request or command whose input can be wrong `implements DwSelfValidating` and returns
every problem from `validate()`, reading only its fields (no IO, no clock). The client runs it before
sending, the server again before the access check. A rule that needs data is a refusal in the handler.

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
      DwCallRefusal(AcmeRefusal.amountNotPositive, field: 'amountCents'),
  ];
}
```

**Defaults on the wire:** a field with a constructor default may be absent — the decoder applies it,
the encoder omits a value equal to it; a required field without one must be present (`400`).

## 5. A settings object

One data object with a default for every field and a fixed `id`; read with a `DwSingleRequest`,
changed by a command whose fields keep when absent — `null` for a non-nullable setting, a
`DwFieldPatch` for a nullable one. `null` means none, never `''`. The server side: `dartway-server`.
The skeleton's `__SHARED_PKG__/lib/src/settings.dart` is the sample.

## 6. Refusal codes, channel kinds, upload purposes

```dart
/// Why the server refuses. Each code needs a text in the app's refusal texts.
enum AcmeRefusal with DwRefusalCodes {
  /// An invoice that is paid cannot be edited or paid again.
  invoiceAlreadyPaid,
}

/// The app's live channels; the server declares who may subscribe to each.
enum AcmeChannel with DwChannelKind { invoices, billing }

/// What an uploaded file is for; the server declares one rule per purpose.
enum AcmeUpload with DwUploadPurpose {
  invoiceScan;

  static const int invoiceScanMaxBytes = 10 * 1024 * 1024;
}
```

- A refusal is a code with parameters (`field:`, `params:` as strings), never a sentence. Check first
  whether `DwCoreRefusal.notFound`, `forbidden`, `conflict` or `invalid` with a `field` already says it.
  Doc-comment every code: when it happens, what the user can do. Its text: `dartway-data-layer`.
- A channel kind's name has no `:`. Its rule: `dartway-realtime`.
- Limits both sides read sit on the purpose enum as constants. The rule: `dartway-uploads`.

## 7. Generation

After any DTO (or row class) change: `dart run dartway_cli:dartway generate` from `__FLUTTER_PKG__`,
commit the output with the change. It writes `*.dw.dart` and `lib/generated/dw_protocol.dart` here, row
parts and `lib/generated/dw_schema.dart` in the server. Never edit them; a refused declaration is fixed
in the declaration.

## 8. A DTO change reaches installed app builds

An installed build keeps calling with the contract it was built with, for weeks.

| Change | An old build |
|---|---|
| an optional field with a default on a request/command; a field on a data object; a new call | keeps working |
| a required field without a default on a request/command | its calls fail `400` |
| a data-object field renamed or removed | its answers do not decode |
| a value added to an enum in a data object | shows its update screen (an open enum reads `unknown`) |
| a new data object type on a channel old builds listen to | refetches that channel's requests on every update |
| a request/command renamed or removed | `404` |
| a refusal code renamed | its generic refusal text |

Prefer the additive change. When a breaking one is unavoidable, **raise the breaking line of
`__SHARED_PKG__/pubspec.yaml`'s `version:`** in the same change — the minor below 1.0, the major after —
and regenerate: an app of an older line is then answered `426` and shows its update screen instead of
failing call by call. Say which kind of change it is in the commit.

**Open enums** — `with DwOpenEnum` and a value `unknown` — only for display values an unknown one can be
shown neutrally for (a feed entry's kind), never for anything behaviour depends on (a status, a role).
`unknown` is never stored in a row; a command carrying it back is answered `dw.updateRequired`, so keep
open enums out of commands.

Contract tests (round trip, `validate()`, `onUpdate`, channels): `dartway-testing`.
