---
name: dartway-access
description: >-
  Who may do what in a DartWay project, and the tests that prove it: the DwAccessRule every handler
  declares (anonymous only for sign-in-like calls, signedIn, check with the call for rules on its
  real parameters), roles as the project's own (a profile row plus a DwCallContext extension cached
  with memo), "someone else's row does not exist" (dw.notFound rather than dw.forbidden), "my" calls
  that carry no account id, channel rules (DwChannelRule) as the second access point and upload
  rules / DwFileStorage.canRead as the third, what a command's publications reveal to its caller,
  personal keys for tools (DwAccountService.issueKey, ctx.sessionKey.kind), revocation, identifiers
  attached by code (the refusal after the right code), and never raw SQL on the framework's tables.
  Use when adding a handler, a role, a channel, an upload purpose or a key-issuing flow, or when
  reviewing whether a call leaks data.
---

# DartWay — access: rules, roles, channels, keys

The server is the only place access is decided. A hidden button, a route guard, a field the app
"never sends" are conveniences; the server's rules are the access. There are exactly three access
points, and each must be as strict as the others:

1. **the call** — the `DwAccessRule` of every handler, then the handler's own ownership checks;
2. **the channel** — the `DwChannelRule` of every channel kind, checked once at subscription;
3. **the file** — the upload rule of every purpose and `DwFileStorage.canRead` for private files.

Related skills: `dartway-server`, `dartway-realtime`, `dartway-uploads`, `dartway-contract`,
`dartway-testing`.

## 1. Every handler declares its rule

`access:` is required on every `DwCallHandler` factory — there is no default, so no handler is open by
omission.

| Rule | Who | For |
|---|---|---|
| `DwAccessRule.anonymous` | anyone, with or without a session | calls that must work before sign-in: a public landing read, a sign-up-like flow of the project's own. The framework's sign-in commands are built in — you do not declare them |
| `DwAccessRule.signedIn` | any signed-in account | "my" calls, and anything every member may do — the handler still checks ownership |
| `DwAccessRule.check<C>((ctx, call) async => …)` | a signed-in account for which the check is true; otherwise `dw.forbidden` | roles, and rules on the call's real parameters |

Order on the server: the sign-in requirement (anonymous caller → `unauthenticated`, `401`), then
`validate()`, then the check, then the handler. The check runs in the handler's context — inside the
transaction of a transactional command — and after validation, so it may trust the fields' shape.

`C` is the call class the check is written for; a check typed for one class on a handler of another
fails the server's startup. A role rule shared by many handlers is typed for every call:

```dart
/// Access rules of the app, in the words handlers read.
abstract final class AppAccess {
  static final DwAccessRule manager = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isManager,
  );

  /// Reading a customer's invoices: managers, or the account manager of that
  /// customer.
  static final DwAccessRule customerInvoices =
      DwAccessRule.check<ListCustomerInvoices>((ctx, request) async {
        if (await ctx.isManager) return true;
        final customer = await ctx.db.customers.findById(request.customerId);
        return customer?.accountManagerProfileId == (await ctx.callerProfile).id;
      });
}
```

## 2. Roles are the project's

The framework knows that an account signed in, not who that person is to the project. A role is a
column of the project's profile row, and the context extension turns it into words handlers read,
cached per call:

```dart
extension CallerContext on DwCallContext {
  Future<MemberProfileRow> get callerProfile => memo(#callerProfile, () async {
    final accountId = requireAccountId;
    final profile = await db.memberProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    return profile ?? (throw StateError('Account $accountId has no profile'));
  });

  Future<bool> get isManager async =>
      (await callerProfile).role == MemberRole.manager;
}
```

The profile row is created with the account, in `DwAuthConfig.onAccountCreated`
(`dartway-server`), so "a signed-in account without a profile" is a broken invariant, not a case
to handle. The skeleton ships this extension with an admin role, and an `AppAccess`-style class of
rules beside it.

**A role change is guarded like any other data**, and two locks are worth copying from the skeleton:

- **nobody changes their own role** — refuse it with a project refusal code (the skeleton's
  `ownRoleLocked`): an admin demoting themselves locks the panel's only way back;
- **the first admin is declared per environment**, not granted by a default: the skeleton's
  `APP_BOOTSTRAP_ADMIN` names an identifier made admin on every start (through
  `server.accounts.ensure`). A default admin identifier in a template would hand every project that
  forgot it to whoever receives that identifier's codes.

A role taken away also closes what it opened: `ctx.revoke(channel, accountId)` for every channel
the role could subscribe to (`dartway-realtime`).

## 3. Someone else's row does not exist

A rule answers **whether the caller may make this call at all**. Whether the row the call names is
theirs is the handler's check, and its answer is `dw.notFound`, not `dw.forbidden`:

```dart
final row = await ctx.db.invoices.findById(command.invoiceId, lock: DwRowLock.forUpdate);
// Someone else's invoice does not exist for the caller.
if (row == null || row.ownerProfileId != (await ctx.callerProfile).id) {
  ctx.refuse(DwCoreRefusal.notFound);
}
```

In a single-request handler, return `null` — the framework refuses `dw.notFound`.

Why: `forbidden` for someone else's id and `notFound` for a free id tell a caller which ids exist —
typing ids one by one enumerates other people's data. `dw.forbidden` is right when the caller may
know the row exists and may not do this to it (a member of a board editing a message they did not
write).

## 4. "My" calls carry no account id

A request or command about the caller's own data names nothing about the caller: the handler reads
`ctx.callerProfile` / `ctx.requireAccountId`. A field holding "my" id is a field anyone can change
to someone else's, and the handler that trusts it serves them. The same goes for every value the
server decides — owner, author, timestamps, status (`dartway-contract`).

When a staff screen really does act on someone else's data, that is a different call with its own
rule (`ListCustomerInvoices` with `AppAccess.customerInvoices`), never the "my" call with an optional
id.

## 5. Channels are the second access point

Everything published to a channel is readable by every subscriber, and nothing re-checks the objects.
So `canSubscribe` of a kind must admit **only people allowed to read every object any command
publishes there** — as strict as the strictest handler of a request on that channel:

- a caller channel: `DwChannelRule.ofCaller(kind)` — a connection subscribes to its own account's
  key only (another key is `dw.forbidden`);
- a role channel: `DwChannelRule.single(kind, canSubscribe: (ctx) => ctx.isManager)`;
- a group channel: `DwChannelRule.keyed<int>(kind, parseKey: int.parse, canSubscribe: (ctx, id) …)`
  checks membership of that group;
- **a subscription is checked once**: a command that removes someone's right revokes it
  (`ctx.revoke`).

**What a command publishes is readable by its caller.** The response of a command carries its
publications — those on channels the caller's live connection is subscribed to, and every
publication when the call names no live connection (a client can simply leave the header out). A
member's command must not publish an object only managers may read; recompute such a figure in a
manager's read, or publish it from a job.

## 6. Files are the third

An upload purpose's rule decides who may upload (`canUpload`), how large and of which types, and
whether the file is public (served by URL to anyone holding it) or private. A private file is read
only through a short link after `DwFileStorage(canRead: …)` says yes for that caller and that file.
And a file id in a command is a number anyone can type: a command that attaches a file checks it is
the caller's own finished upload of the right purpose (`ctx.files.requireOwned`). Details —
`dartway-uploads`.

## 7. Keys, revocation and tools

Every session is a key of an account. Keys do not expire; they are revoked.

- **The app's key** is made by a sign-in (`DwSessionKeyKind.app`), labelled with the app build.
- **A personal key for a tool** (a script, an agent, an integration) is made by
  `ctx.accounts.issueKey(accountId, label: '…')` (`DwSessionKeyKind.personal`). It answers
  `(key: DwSessionKeyInfo, token: String)`; **the token exists only in that answer** — the database
  keeps its hash — so hand it over once, in the command's result (a data object of your own that
  carries it). The framework does not store that command's successful outcome for idempotency, so
  the token never sits in the outcome table.
- **Tell a tool from the app by the server's record**, never by something the client sends:
  `ctx.sessionKey?.kind == DwSessionKeyKind.personal`. Refuse what a tool must not do, or allow only
  to tools what only tools may do.
- **Revoke**: `ctx.accounts.revokeKey(keyId, accountId: callerAccountId)` — pass `accountId` whenever
  the key id came from the client, or anyone could revoke anyone's key; `revokeKeys(accountId)` signs
  an account out everywhere; `listKeys(accountId)` for a "your sessions" screen. Revocation takes
  effect at once in the server that commits it — connections on the key lose their subscriptions.

All of it goes through `DwAccountService` (`ctx.accounts`, `server.accounts`,
`DwAccountService(db, auth)`). **Never raw SQL on `dw_account`, `dw_identity`, `dw_auth_key` or any
`dw_*` table**: the service holds the locks sign-in takes, runs `onIdentifierChanged`, and revokes
live sessions; SQL does none of that.

## 8. Identifiers attached by code

Attaching a second phone or e-mail, or changing one, is built in: `DwRequestIdentifierCode(kind,
identifier)` then `DwConfirmIdentifier(ticketId:, code:, replace:)`. An identifier that belongs to
another account is refused **only after the right code** (`DwAuthRefusal.identifierTaken`, field
`code`): the request answers the same for a free and a taken identifier.

**Do not add a project check that answers earlier** ("this phone is already taken" before the code is
sent). It turns the call into an account-existence oracle for any signed-in user. Mirror or publish
the change in `DwAuthConfig.onIdentifierChanged`, which runs in the changing transaction.

## 9. Tests that prove access

Access that is not tested is a hope. In `__SERVER_PKG__/test/` (real server, real clients,
`dartway test`), **one refused call per rule**:

```dart
Matcher refusedWith(DwRefusalCode code) => isA<DwCallRefused<Object?>>()
    .having((result) => result.refusal.code, 'refusal code', code.code);
```

Write each case as the call a hostile client would make (`member`, `anonymous` are `DwAppClient`s
from `DwTestServer.connectClient`, the first signed in):

```dart
// anonymous → not authenticated
expect(await anonymous.fetch(const ListMyInvoices()), isA<DwNotAuthenticated<Object?>>());

// a member calling a manager's read → forbidden
expect(await member.fetch(const ListInvoicesPage()), refusedWith(DwCoreRefusal.forbidden));

// someone else's id → not found, and nothing changed
expect(
  await member.command(PayInvoice(invoiceId: othersInvoiceId)),
  refusedWith(DwCoreRefusal.notFound),
);

// a foreign caller channel → refused at subscription
final socket = await server.openLive();
await socket.authenticate(memberToken);
expect(
  (await socket.subscribe('invoices:$otherAccountId') as DwSubscriptionRefusedMessage)
      .refusal
      ?.isCode(DwCoreRefusal.forbidden),
  isTrue,
);
```

Plus, where they apply: a demoted role loses its channel (the client gets the channel's `closed`
frame) and its calls; an admin cannot change their own role; a personal key is refused what tools
must not do; a key id of another account is not revoked. The skeleton's server tests hold the
harness (`refusedWith`, signed-in members, a promoted admin) — `dartway-testing`.

## Checklist

- [ ] Every handler's rule is the narrowest that works; `anonymous` only where sign-in cannot exist yet.
- [ ] Role rules read the cached profile through the context extension.
- [ ] Handlers check ownership of every row an id names; someone else's is `dw.notFound`.
- [ ] "My" calls carry no account or profile id; no command carries what the server decides.
- [ ] Each channel kind's `canSubscribe` is as strict as every request on it; lost rights are revoked.
- [ ] A command publishes nothing its caller may not read.
- [ ] File ids from the client are checked with `ctx.files.requireOwned`; private files have `canRead`.
- [ ] Keys: token returned once; `revokeKey` with the caller's `accountId`; tools told apart by
      `ctx.sessionKey?.kind`.
- [ ] No SQL on `dw_*`; no early "identifier taken" check.
- [ ] One refused call per rule in the server tests.
