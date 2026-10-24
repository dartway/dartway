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
