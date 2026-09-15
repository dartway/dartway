# Auth and identity: who owns accounts, and what does a project decide?

**The framework owns accounts, identities, session keys and code tickets** (D-007). It knows that
someone signed in, with which phone number or e-mail address, and with which key. What that person
is to the project — a profile, a role, consents — is the project's, in its own tables, referencing
the account id.

This split is why a project writes no sign-in code: it states what an identifier looks like, how a
code reaches a person, and what happens when an account is created. Everything between — tickets,
rate limits, attempts, locks, tokens, revocation — is built in and the same in every project.

## The pieces

| Table | What it holds |
|---|---|
| `dw_account` | an id and a creation time — the framework's whole idea of a person |
| `dw_identity` | identifiers an account signs in with: kind (`phone`, `email`), normalized value, `verified_at`. Unique across accounts |
| `dw_auth_key` | session keys: the SHA-256 of the token, kind (`app`, `personal`), label, last use, revocation |
| `dw_code_ticket` | one row per code sent: the SHA-256 of the code, attempts, expiry, purpose (`signIn`, `attach`) |

A project's profile row carries `accountId` as a foreign key to `dw_account` and is created in the
same transaction as the account (`onAccountCreated`), so an account without a profile cannot exist.

## `DwAuthConfig`

```dart
DwAuthConfig({
  required String? Function(DwIdentifierKind kind, String raw) normalize,
  required Future<void> Function(
    DwCallContext ctx, DwIdentifierKind kind, String identifier, String code,
  ) deliverCode,
  Future<String?> Function(
    DwCallContext ctx, DwIdentifierKind kind, String identifier, int? accountId,
  )? fixedCode,
  Future<void> Function(
    DwCallContext ctx, int accountId, DwIdentifierKind kind, String identifier,
    DwAccountOrigin origin,
  )? onAccountCreated,
  Future<void> Function(DwCallContext ctx, DwIdentifierChange change)? onIdentifierChanged,
  int codeLength = 6,
  Duration codeLifetime = const Duration(minutes: 10),
  int maxAttempts = 5,
  int maxRequestsPerWindow = 5,
  Duration requestWindow = const Duration(minutes: 10),
  Duration resendDelay = const Duration(seconds: 60),
  Duration keyTouchInterval = const Duration(minutes: 10),
})
```

| Field | What it decides |
|---|---|
| `normalize` | The canonical form of an identifier (`79991234567`, a lower-cased e-mail), or `null` when `raw` is not a valid one of that kind — answered `dw.invalid` on field `identifier`. Every lookup, lock and rate limit reads the normalized value, so `Ivan@` and `ivan@` cannot become two accounts or two rate-limit buckets. The app should normalize with the same function; the skeleton shares `AuthIdentifier.normalize` from its shared package. |
| `deliverCode` | Sends the code. Runs inside the transaction that records the ticket: when it throws, no ticket exists and the request does not count against the limit. `ctx.accountId` is `null` for a sign-in and the caller's account for an identifier being attached — the place to word the two messages differently. Never log the code. |
| `fixedCode` | A code accepted instead of a delivered one, for store reviewers, demo personas and end-to-end tests; `accountId` is the account the identifier belongs to, or `null`. Returning a code skips delivery. |
| `onAccountCreated` | Runs in the transaction that creates an account: the place to insert the profile. Refusing here refuses the sign-in, nothing is created, and the code stays usable. `origin` says who created the account (below). |
| `onIdentifierChanged` | Runs in the transaction that changes an existing account's identifiers, once per account and identifier affected, after the change: the place to mirror an identifier into project rows, or to publish. Throwing undoes the change. Not called for the identity an account is created with, nor when a sign-in re-verifies an identifier the account already has. |
| `codeLength` | Digits in a delivered code, 4 to 12. |
| `codeLifetime` | How long a ticket accepts its code. |
| `maxAttempts` | Wrong codes per ticket before it is dead. |
| `maxRequestsPerWindow`, `requestWindow` | Code requests per identifier in the window, counted across sign-in and attach. |
| `resendDelay` | Minimum time between two requests for one identifier; announced as `DwCodeTicket.resendAfter` and enforced. |
| `keyTouchInterval` | A key's `last_used_at` is written at most once per interval, not on every call. |

How long a resolved token is trusted without a query is a server setting, not an auth one
(`tokenCacheSize`, `tokenCacheTtl` in [`DwServerSettings`](app-server.md#dwserversettings)).

### `DwAccountOrigin`

`onAccountCreated` receives either:

- `DwSignInOrigin(registration)` — a sign-in by code to an identifier without an account;
  `registration` is the map the client sent with `DwVerifyCode` (name, consents), empty when it sent
  none;
- `DwToolOrigin()` — `DwAccountService.ensure`: a seed, an admin bootstrap, an import. It has
  accepted nothing on anyone's behalf.

The skeleton's `createProfile` (`template/dartway_starter_server/lib/src/auth.dart`) shows why the
difference matters:

```dart
switch (origin) {
  case DwSignInOrigin(:final registration):
    if (!await isSignUpEnabled(ctx.db)) {
      ctx.refuse(DartwayStarterRefusal.signUpClosed, field: 'identifier');
    }
    if (registration[RegistrationKeys.terms] != 'true') {
      ctx.refuse(DartwayStarterRefusal.consentsRequired, field: 'consents');
    }
    return ctx.db.userProfiles.insert(
      UserProfileRow(
        accountId: accountId,
        firstName: registration[RegistrationKeys.firstName]?.trim() ?? '',
        agreedForMarketing:
            registration[RegistrationKeys.marketing] == 'true',
        termsAcceptedAt: now,
        createdAt: now,
      ),
    );
  case DwToolOrigin():
    return ctx.db.userProfiles.insert(
      UserProfileRow(accountId: accountId, createdAt: now),
    );
}
```

A sign-up without the terms accepted is refused `consentsRequired`, nothing is created, and the app
asks for consent and verifies the same code again. An account made by the bootstrap accepted no
terms: its `termsAcceptedAt` stays empty.

### `DwIdentifierChange`

`onIdentifierChanged` receives `accountId`, `kind`, `cause` (`DwIdentifierChangeCause.confirmed`,
`moved` or `removed`), `previous` and `current`. An attached identifier has no `previous`, a removed
one no `current`, a replaced one both. A move is two changes: removed from the account it left,
attached to the one it joined.

The framework publishes nothing about identifiers. The skeleton republishes the profile, which
shows identifiers read from the framework; the example mirrors the phone into its profile row in
the same transaction (`example/dartway_example_server/lib/src/example_auth.dart`).

## Built-in commands

Registered by the framework in every server; a project may not register handlers for them.

| Command | Access | Result | What it does |
|---|---|---|---|
| `DwRequestCode(kind, identifier)` | anonymous | `DwCodeTicket` | normalizes, applies the limits, creates a ticket and delivers the code |
| `DwVerifyCode(ticketId, code, registration)` | anonymous | `DwAuthSession` | checks the code; creates the account when the identifier has none; makes an `app` session key |
| `DwSignOut()` | signed in | none | revokes the caller's session key |
| `DwRequestIdentifierCode(kind, identifier)` | signed in | `DwCodeTicket` | a code to an identifier the caller wants to attach, or change theirs to |
| `DwConfirmIdentifier(ticketId, code, replace)` | signed in | `DwIdentityInfo` | attaches the identifier or, with `replace`, puts it in place of the caller's identifiers of that kind |

**A code request answers the same whether the identifier belongs to an account or not.** Otherwise
the command would tell anyone which phone numbers are registered. `DwAuthSession.isNewAccount` is
told only to whoever received the code.

Refusals:

- `dw.invalid` on `identifier` — `normalize` rejected it;
- `dw.tooManyRequests` with `retryAfter` — the window's limit or the resend delay (`429` with a
  `Retry-After` header);
- `dw.invalid` on `code`, with `attemptsLeft` — a wrong code; the attempt is committed even though
  the answer is a refusal;
- `dw.codeExpired` on `code` — unknown, used, expired or out of attempts: the user needs a new code,
  not another try;
- `dw.identifierTaken` (`DwAuthRefusal.identifierTaken`) on `code` — `DwConfirmIdentifier` with a
  right code for an identifier of another account. Refused only after the right code (D-045), so
  requesting a code reveals nothing; the ticket is used up.

A ticket is confirmed only by the command of its purpose: a sign-in ticket reads as expired to
`DwConfirmIdentifier`, an attach ticket as expired to `DwVerifyCode`, and a ticket of another
account as expired too — guessing at someone else's ticket learns nothing and burns none of its
attempts.

An account may hold several identifiers of one kind. With `replace`, the oldest identity of the
kind takes the new value (its id stays) and the others of the kind are removed.

On the client, the app sends these commands like any other and keeps the answered session with
`dw.signIn(session)` ([Flutter core](../3-flutter/flutter-core.md)).

## Session keys

Every token the server accepts is a session key of an account. A token is 256 random bits, shown
once — in `DwAuthSession.token` or the answer of `DwAccountService.issueKey` — and stored only as
its SHA-256: a leaked table signs nobody in.

- **Kind.** `DwSessionKeyKind.app` is made by a sign-in: an installation of the app.
  `DwSessionKeyKind.personal` is made on purpose by `issueKey`, for a tool (an MCP client, a
  script). The kind is the server's record, so a handler can tell a tool from the app without
  trusting anything the client sends.
- **Label.** For people choosing which key to revoke. An app key's label is what the app said about
  itself — its `Dw-App-Version` and user agent — cleaned and cut to 200 characters
  (`DwSessionKeyInfo.maxLabelLength`). A personal key's label is required. A label comes from the
  client and describes; it never identifies.
- **No expiry** (D-021). Mobile apps expect to stay signed in, and expiry without refresh tokens
  signs people out at random. A key lives until it is revoked.
- **Revocation is immediate in the process that commits it** (D-044): the token cache forgets the
  key, and every live connection authenticated with it loses its subscriptions. Another process —
  or a running server, when `DwAccountService` over a bare database wrote the revocation — notices
  within `DwServerSettings.tokenCacheTtl`, one minute by default.
- Revoked keys stay listed until the framework's hourly cleanup removes them, a day after
  revocation.

`ctx.sessionKey` is the `DwSessionKeyInfo` of the key that authenticated the call — `id`,
`accountId`, `kind`, `label`, `createdAt`, `lastUsedAt` (lagging by up to `keyTouchInterval`),
`revokedAt`. It is set on calls, on channel subscription checks and on routes declared with
`DwRouteAuth.optional` or `DwRouteAuth.required` ([routes](routes.md)); it is `null` for an
anonymous call and in jobs.

## `DwAccountService`

Everything a project needs from the framework's tables beyond sign-in: seeding, bootstrapping an
admin, personal keys, merging accounts, an admin's search box, ending someone's sessions.

Three ways to get one, by where the code runs:

- `ctx.accounts` in a handler, job or route — writes join the call's transaction, and revoked
  sessions close after it commits;
- `server.accounts` next to a running server — a startup bootstrap
  ([app server](app-server.md#work-after-start-serveraccounts-and-serverdb));
- `DwAccountService(db, auth)` over a bare database, where no server runs in the process — a seed
  script (`template/dartway_starter_server/bin/seed_dev.dart`). Its hooks get a context whose
  `publish`, `revoke` and `jobs` throw rather than drop what they are given (D-022).

| Method | Returns | Notes |
|---|---|---|
| `ensure(kind, rawIdentifier)` | `DwEnsuredAccount` (`accountId`, `created`) | The account of an identifier, created with `onAccountCreated(…, DwToolOrigin())` when it has none; its identity is not verified, since no code proved it. Takes the lock sign-in takes, so a sign-in racing it makes one account. An identifier `normalize` rejects throws `ArgumentError`: a bootstrap with a mistyped admin must not start quietly without one. |
| `find(kind, rawIdentifier)` | `int?` | the account, or `null` |
| `listIdentities(accountId)` | `List<DwIdentityInfo>` | oldest first |
| `listIdentitiesOf(accountIds)` | `Map<int, List<DwIdentityInfo>>` | one query for a list of profiles; every account asked for is a key |
| `accountsMatching(fragment, {kinds})` | `Set<int>` | case-insensitive substring of stored (normalized) identifiers; `%`, `_` and `\` match themselves; an empty fragment throws |
| `moveIdentities(fromAccountId, toAccountId, {kinds})` | `List<DwIdentityInfo>` | a merge, in one transaction under the per-identifier locks; `onIdentifierChanged` runs for both accounts. Revokes nothing |
| `removeIdentities(accountId, {kinds})` | `List<DwIdentityInfo>` | a removed identifier is free: a later sign-in with it makes a new account. Revokes nothing |
| `issueKey(accountId, {label, kind})` | `DwIssuedKey` (`key`, `token`) | a personal key unless `kind` says otherwise. The token exists only in this answer |
| `listKeys(accountId)` | `List<DwSessionKeyInfo>` | newest first, revoked ones included until cleanup |
| `revokeKey(keyId, {accountId})` | `bool` | whether a live key was revoked. Pass the caller's account when the key id came from a client, so nobody revokes a key that is not theirs |
| `revokeKeys(accountId)` | — | every key of the account, app and personal |

**A command that issues a key never stores its successful outcome** (D-043). The outcome table
would otherwise hold the bearer token for a week. A retried send runs again and makes a second key;
the first, whose token nobody received, can be listed and revoked.

`revokeKey` and `revokeKeys` throw `StateError` in a request: revoking is a change, made by a
command.

## No SQL on framework tables

A project never queries or writes `dw_account`, `dw_identity`, `dw_auth_key` or `dw_code_ticket`
(D-049). Every read and write a project needs is a method above, and the framework keeps its
invariants — per-identifier locks taken in a fixed order, verification times, hooks, immediate
revocation — only on its own paths. A project row may reference `dw_account` by foreign key; that
is all.

## Related

- [Access and roles](../2-core/access-and-roles.md) — who may call what, once signed in.
- [Channels and realtime](../2-core/channels-and-realtime.md) — every subscription requires sign-in.
- [Testing](../5-tooling/testing.md) — signing test callers in.
