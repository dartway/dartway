## 1. Three kinds of DTO, in the file of their server feature

| Kind | Extends | Is |
|---|---|---|
| Data object | `DwDataObject` | what the server returns and publishes; an `int` or `String` `id` updates merge by |
| Request | one of the six request kinds ([request kinds](requests.md)) | a read: no side effects, its fields are its parameters |
| Command | `DwActionCommand<R>` | a change: its fields are the input, `R` the answer |

**`lib/src/` mirrors the server's features** (`invalidSharedLayout`): the DTOs of the server feature
`invoices/` are `lib/src/invoices.dart`, a DTO goes where its handler is, and a rule both sides apply
goes with the feature that owns it. Grown past the file limits (`fileLong`/`fileTooLong`, as in the
app), it becomes a flat `lib/src/invoices/` of parts `invoices_<part>.dart`, each a data object with
the calls that answer it — never a layer name. Beside the features: only `acme_channel.dart`,
`acme_refusal.dart`, `acme_upload.dart`, `acme_protocol.dart` and `acme_push_category.dart`. A new
`src/` file is exported from `lib/acme_shared.dart`.

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
field types `int`, `double`, `String`, `bool`, `DateTime` (UTC), `DwCalendarDay` (canonical `YYYY-MM-DD`), `Duration`, `Uint8List`, an enum, a
DTO, `List`, `Map<String, T>`, `DwFieldPatch<T>`, or nullable. A single object with a fixed identity
uses an `id` getter (`String get id => 'invoice-totals';`).

**Names** follow law 5 (`contractNameInvalid`); a caller-scoped call says `My` (`ListMyInvoices`). **The class name is the wire name** (`POST /dw/<ClassName>`): renaming one is a
wire change ([compatibility](generation.md)).

## 2. A request's fields are its complete filter

A request is a value: the client caches and shares its live state under the request itself.

- Everything that changes the answer is a field — a filter, a search string, a page, a date. "Today" is
  a `DateTime day` field the widget fills, never `ctx.now` or `ctx.callerLocalTime` in the handler,
  which would answer two equal requests differently.
- **"My" calls carry no account or profile id**: the handler reads the caller from its context, and the
  client keeps state per signed-in account. A field holding "my" id is a field anyone can change to
  someone else's.
- `channels`, `matches`, `sort`, `positionOf` and an overridden `onUpdate` are pure functions of the
  item and the fields — no clock, no global.
