---
name: dartway-access
description: >-
  Who may do what in a DartWay project: the DwAccessRule of every handler (anonymous, signedIn,
  check, resource — owned, through a parent, by membership), roles as the project's own, someone
  else's row answering dw.notFound, channel rules and file rules as the second and third access
  points, what a command's publications reveal, personal keys and revocation, identifiers attached
  by code, and the tests that prove each rule. Use when adding a handler, a role, a channel, an
  upload purpose or a key-issuing flow, or when reviewing whether a call leaks data.
---

# DartWay — access (`dartway-access`)

The server is the only place access is decided; a hidden button or a route guard is a convenience.
Three access points, each as strict as the others: **the call** (§1–3), **the channel** (§4), **the
file** (`dartway-uploads`).

## 1. Every handler declares its rule

`access:` is required on every handler factory; there is no default.

| Rule | Who | For |
|---|---|---|
| `DwAccessRule.anonymous` | anyone | what must work before sign-in; say why in the handler's comment |
| `DwAccessRule.signedIn` | any signed-in account | "my" calls, and what every member may do |
| `DwAccessRule.check<C>((ctx, call) async => …)` | signed in and the check holds, else `dw.forbidden` | roles; rules on the call's parameters |
| `DwAccessRule.resource<C, R>(load:, allows:, visible:)` | signed in and may reach the row the call names, else `dw.notFound` | whose row it is; the handler reads it as `ctx.accessed<R>()` |

Order: sign-in (`401`), `validate()`, the rule, the handler — the rule runs inside a transactional
command's transaction. A rule shared by many handlers is typed for every call:
`DwAccessRule.check<DwServerCall<Object?>>((ctx, _) => ctx.isAdmin)` — the skeleton's `ProfileAccess.admin`
in `__SERVER_PKG__/lib/src/profile/profile_access.dart`, beside the `ProfileCallContext` extension that
makes the role a word handlers read.

## 2. Roles are the project's

A role is a column of the profile row, created with the account (`dartway-server`, §8). Guard a role
change like any data: **nobody changes their own role** (a project refusal code — the skeleton's
`ownRoleLocked`), and **the first admin is declared per environment** (`DW_ADMIN_IDENTIFIER`), never a
default. A role taken away closes what it opened: `ctx.revoke` on its channels (`dartway-realtime`).

## 3. Someone else's row does not exist

Whether the row a call names is the caller's is answered **once, in `DwAccessRule.resource`**, and the
answer is `dw.notFound` — `forbidden` for a foreign id and `notFound` for a free one would let a caller
enumerate ids. An owner comparison written in a handler body or a helper is `inlineOwnershipCheck`
(a warning). `allows` carries the whole permission, role included — and a rule resting on a role checks
it in `load` too, answering `null` before taking any lock; `visible` only turns the refusal into
`dw.forbidden` for someone allowed to see the row. A `DwAccessRule.check` that reads an id from the
call without asking whose it is, is this rule written the wrong way.

```dart
// Owned by the caller; locked, since the rule runs in the command's transaction.
access: DwAccessRule.resource<PayInvoice, InvoiceRow>(
  load: (ctx, command) =>
      ctx.db.invoices.findById(command.invoiceId, lock: DwRowLock.forUpdate),
  allows: (ctx, command, invoice) async =>
      invoice.ownerProfileId == (await ctx.profile).id,
),
handle: (ctx, command) async {
  final invoice = ctx.accessed<InvoiceRow>();
  // …
},
```

- **Owned through a parent:** `load` returns the row and the parent as a record,
  `DwAccessRule.resource<RenameLesson, (LessonRow, CourseRow)>`; the handler reads
  `ctx.accessed<(LessonRow, CourseRow)>()`.
- **Membership of a parent:** one function returns the caller's membership or `null` —
  `ctx.membershipOf(teamId)`, a context extension in the parent feature's `_access.dart` — and is the
  only definition of "a member". Every resource rule, the parent's channel rule and `canRead` for its
  files call it; another feature imports that file. A rule for many calls on one kind of row is a
  function returning the rule, in the same file.
- **Visible but not yours to change** (a note on the team's board): `load` answers `null` outside the
  team before taking any lock, `allows` compares the author, `visible: (…) => true`.
- **The caller's rows as a list** is `signedIn` and a `where` naming the caller; a list under a parent
  takes the parent's membership rule.

"My" calls name nothing about the caller (`dartway-contract` §2). A staff screen acting on someone
else's data is a different call with its own rule, never the "my" call with an optional id.

## 4. Channels are the second access point

A kind's `canSubscribe` admits only accounts allowed to read every object published there, answered
for any caller — the rule and why: `dartway-realtime` §1–2.

## 5. Keys, revocation, identifiers

- Every session is a key; keys do not expire, they are revoked. A sign-in makes an app key; a tool gets
  `ctx.accounts.issueKey(accountId, label: …)` → `(key:, token:)` — **the token exists only in that
  answer**, returned once in the command's result.
- Tell a tool from the app by the server's record, `ctx.sessionKey?.kind == DwSessionKeyKind.personal`,
  never by something the client sends — and refuse there what a tool may not do.
- `revokeKey(keyId, accountId: callerAccountId)` — always with the account when the id came from the
  client; `revokeKeys(accountId)` signs out everywhere; `listKeys` for a sessions screen.
- A second phone or e-mail is `DwRequestIdentifierCode` then `DwConfirmIdentifier`; a taken identifier
  is refused only after the right code (`DwAuthRefusal.identifierTaken`). **Never check "taken"
  earlier** — that is an account-existence oracle.
- All of it through `DwAccountService` (`dartway-server` §8), which holds the locks sign-in takes and
  closes live sessions.

## 6. Tests that prove access

In the server's acceptance tests (`dartway-testing`), **one refused call per rule**, written as the call a
hostile client makes — anonymous → `DwNotAuthenticated`; a member on an admin read → `dw.forbidden`;
someone else's id → `dw.notFound` and nothing changed; a foreign caller channel → refused at
subscription. Where they apply: a demoted role loses its channel and calls, an admin cannot change their
own role, a personal key is refused what tools may not do, a key id of another account is not
revoked. The skeleton's
`__SERVER_PKG__/test/src/admin/admin_acceptance_test.dart` and its harness (`refusedWith`) are the
pattern.
