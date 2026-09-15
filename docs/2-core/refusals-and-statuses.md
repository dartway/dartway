# What can a call answer besides success?

Every request and command ends in one of four results, and the type says so:

| Result | Means |
|---|---|
| `DwCallOk<R>` | Success, with the `value` |
| `DwCallRefused<R>` | An answer for the user: a `DwCallRefusal`, a code and never a sentence |
| `DwNotAuthenticated<R>` | The call needs a signed-in caller, or its key was revoked |
| `DwCallFailed<R>` | The server failed; `incidentId` is what the operator finds it by |

A `switch` over it is exhaustive, so a caller cannot forget the refusal or the failure. In the
Flutter app a watched request carries the same outcomes as typed errors of its `AsyncValue`
(`DwRefusalException`, `DwNotAuthenticatedException`, `DwFailedException`) — see
[../3-flutter/data-layer.md](../3-flutter/data-layer.md).

**A refusal and a failure are different things, and the difference is who acts.** A refusal is the
system working: no spots left, not allowed, a field is empty. The user reads it and does something
else; nobody is alerted. A failure is the system broken: an exception, a query that did not run. The
user can only retry; the operator is alerted. Shipping a failure as a refusal hides an incident;
shipping a refusal as a failure pages someone about a full class.

## A refusal is a code with parameters

```dart
DwCallRefusal(
  ExampleRefusal.messageTooLong,
  field: 'text',
  params: {'max': ChatMessage.maxTextLength},
)
```

- **`code`** — the project's enum value name (`messageTooLong`), or a framework code under `dw.`.
- **`params`** — values the text needs. Strings on the wire: the constructor turns every value into
  its string and drops `null` values, so `{'max': 4000}` arrives as `{'max': '4000'}`.
- **`field`** — the input field a validation refusal points at, so a form marks the right one.

The project declares its codes as one enum in its shared package
(`example/dartway_example_shared/lib/src/example_refusal.dart`):

```dart
enum ExampleRefusal with DwRefusalCodes {
  titleRequired,
  noSpotsLeft,
  alreadyBooked,
  // ...
}
```

**No text crosses the wire.** The server does not know the user's language, and a sentence built on
the server cannot be fixed without a server release. The app renders every code — its own and the
framework's — through `DwConfig.refusalText`: see
[../3-flutter/actions-and-refusal-texts.md](../3-flutter/actions-and-refusal-texts.md).

## The framework's codes

`DwCoreRefusal` — the codes every project can meet:

| Code | When |
|---|---|
| `dw.forbidden` | An access check said no (`DwAccessRule.check`, a channel rule, an upload rule) |
| `dw.notFound` | A single request's handler returned `null`; or the thing exists but the caller may not know it does |
| `dw.conflict` | The state changed under the caller: a unique key, a stale version, an idempotency key reused for another command |
| `dw.invalid` | The input is not acceptable; `field` names it (a table page below 1, a malformed channel key) |
| `dw.unknownChannel` | A subscription to a channel kind the server has no rule for |
| `dw.tooManyRequests` | Asked too often. Built with `DwCallRefusal.tooManyRequests(duration)`: `retryAfter` holds whole seconds, at least one, read back with `refusal.retryAfter`; the HTTP answer carries `Retry-After` |
| `dw.codeExpired` | A one-time code can no longer be verified — unknown ticket, used, expired or out of attempts; `field` is `code`. The user needs a new code, not another try |
| `dw.updateRequired` | The app build is below the server's `minAppBuild` |
| `dw.protocolUnsupported` | The client speaks another `Dw-Protocol` |

The last two are **incompatibilities** (`DwCoreRefusal.incompatibilities`), not rules: they answer
`incompatible` with 426, and the app replaces itself with the update-required screen
([wire-and-versions.md](wire-and-versions.md)). A handler refusing with one is answered the same way.

Two more enums share the `dw.` namespace, kept separate so a project switching exhaustively over
`DwCoreRefusal` keeps compiling when they grow:

- `DwAuthRefusal.identifierTaken` (`dw.identifierTaken`) — a confirmed identifier belongs to another
  account ([../4-server/auth-identity.md](../4-server/auth-identity.md));
- `DwUploadRefusal` — `dw.uploadPurposeUnknown`, `dw.uploadTooLarge`, `dw.uploadTypeRejected`,
  `dw.uploadMissing`, `dw.uploadMismatch`, `dw.uploadExpired`, `dw.fileNotOwned`
  ([../4-server/uploads.md](../4-server/uploads.md)).

## Refusing on the server

A handler refuses with `ctx.refuse`, which never returns
(`example/dartway_example_server/lib/src/handlers/booking_handlers.dart`):

```dart
if (session.bookedCount >= session.capacity) {
  ctx.refuse(ExampleRefusal.noSpotsLeft);
}
```

`ctx.refuse(code, params: …, field: …)` throws `DwRefusalException`; a helper that has no context
may throw `DwRefusalException(DwCallRefusal(...))` itself, and the framework answers it the same
way. Permission checks, business rules and validation are one mechanism: a `validate()` refusal,
an access check that says no and a `ctx.refuse` all arrive as `DwCallRefused`. A refusal in a
transactional command rolls its transaction back, and the refused outcome is stored for the
idempotency key ([commands-and-idempotency.md](commands-and-idempotency.md)).

Refuse `dw.notFound`, not `dw.forbidden`, for someone else's object when the caller must not learn
that it exists — `CancelBooking` answers a stranger's booking id exactly as a missing one.

## A failure carries an incident id and nothing else

Any other exception in a handler or an access check becomes `DwCallFailed`: the response holds a
fresh incident id, the exception and stack go to the server log and the alert sinks under that id. A
channel rule that throws is answered the same way on the socket — a failed subscription with an
incident id, never a refusal ([../4-server/alerts.md](../4-server/alerts.md)). No message, no type,
no stack crosses the wire: they describe the server's insides to whoever sends a call.

A call the protocol does not allow is a failure too, but the client's: a body that does not decode, a
wrong method, a missing or forbidden header, a page parameter the kind does not take (400), or a path
naming no request or command (404). These are logged with an incident id and never alerted. **Only a
`5xx` alerts; refusals never do.**

## HTTP statuses

The status is a function of the body (`dwHttpStatusFor`), declared once in the shared package, so the
server writes and the client checks the same mapping:

| Response | Status |
|---|---|
| ok | 200 |
| refused `dw.forbidden` | 403 |
| refused `dw.notFound` | 404 |
| refused `dw.conflict` | 409 |
| refused `dw.tooManyRequests` | 429, with `Retry-After` |
| refused, any other code | 422 |
| unauthenticated | 401 |
| failed: internal | 500 |
| failed: malformed call | 400 |
| failed: unknown call | 404 |
| incompatible | 426 |

The client rejects a response whose status disagrees with its body: that answer came from a proxy's
error page or a misrouted request, not from a DartWay server of this protocol. Statuses exist for
logs, monitoring and proxies; the app switches on the result, not the number. The body shapes are in
[wire-and-versions.md](wire-and-versions.md).

## Not authenticated is not a refusal

`DwNotAuthenticated` means "sign in", not "no": a call whose access rule needs an account and has
none, or any call carrying a token that is unknown or revoked. The client ends the session that call
carried and every watched request is asked again as the new caller, instead of showing an error
([access-and-roles.md](access-and-roles.md)).
