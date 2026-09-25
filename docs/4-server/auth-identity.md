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
| `dw_identity` | identifiers an account signs in with: kind (`phone`, `email`, or a provider's name — `google`, `apple`), normalized value or the provider's subject id, `verified_at`. Unique across accounts |
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
    int? accountId,
  ) deliverCode,
  required DwAccountDeletion accountDeletion,
  Future<String?> Function(
    DwCallContext ctx, DwIdentifierKind kind, String identifier, int? accountId,
  )? generateCode,
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
| `deliverCode` | Sends `code`. Called **always**, after the ticket's own transaction has committed — whatever `code` is, generated or returned by `generateCode` — so deciding not to send (a store reviewer's or a test account's fixed code, most often) is this hook's own choice, not something withholding the call decides for it. Runs **outside** the transaction that records the ticket, on a fresh pooled `ctx.db`: the ticket is written, and already counted against the limit, before delivery is attempted, so a `deliverCode` that throws (an incident) or refuses no longer undoes it — the caller sees the failure and the next attempt waits out `resendDelay`, the same as any resend. This is deliberate: `deliverCode` is commonly an HTTP call to a provider, and running it under the identifier's advisory lock, inside the ticket's transaction, held a pooled connection (and that lock) for as long as the provider took to answer — a handful of slow sign-ins could exhaust the pool for the whole server. `ctx.memo` is how it avoids a second lookup of whatever `generateCode` already read, since the two no longer share one transaction's cache. `accountId` is the account `identifier` already belongs to, or `null` — the same value `generateCode` was asked with. Never log the code. |
| `accountDeletion` | Who may delete an account, and required because either default is wrong for somebody: `byMember` answers `DwDeleteMyAccount` (an app store asks it of any app people sign up in); `byOperator` refuses it `dw.forbidden`, and only server code deletes, with `ctx.accounts.deleteAccount`. |
| `generateCode` | The code this request gets, inside the ticket's transaction. `null` — whether `generateCode` is unset, or returns it for this call — draws `codeLength` random digits (`dwRandomCode`, exported for reuse); a project returns one of its own for a fixed code — a store reviewer, a test account, a default code out of its own settings — and `deliverCode` decides, independently, whether that code goes anywhere (issue #310: the two used to be coupled — a fixed code skipped `deliverCode` outright, so a fixed code that also had to be sent could not be expressed). |
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

The skeleton's `AppAuth.createProfile` (`template/dartway_starter_server/lib/src/core/auth.dart`) shows why the
difference matters:

```dart
switch (origin) {
  case DwSignInOrigin(:final registration):
    if (!await AppAuth.isSignUpEnabled(ctx.db)) {
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
the same transaction (`example/dartway_example_server/lib/src/core/example_auth.dart`).

## Built-in commands

Registered by the framework in every server; a project may not register handlers for them.

| Command | Access | Result | What it does |
|---|---|---|---|
| `DwRequestCode(kind, identifier)` | anonymous | `DwCodeTicket` | normalizes, applies the limits, creates a ticket and delivers the code. `DwIdentifierKind.of(identifier)` is the framework's one rule for the kind — an `@` makes it an e-mail, anything else a phone; it sorts and does not validate, `normalize` does |
| `DwVerifyCode(ticketId, code, registration)` | anonymous | `DwAuthSession` | checks the code; creates the account when the identifier has none; makes an `app` session key |
| `DwSignOut()` | signed in | none | revokes the caller's session key |
| `DwDeleteMyAccount()` | signed in | none | deletes the caller's account when `accountDeletion` is `byMember`, refuses `dw.forbidden` otherwise — see below |
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

**Deleting an account.** App stores require it inside the app from any app that lets people sign
up (App Store Review Guideline 5.1.1(v)), whatever the sign-in method. `DwDeleteMyAccount` (with `accountDeletion: DwAccountDeletion.byMember`) — or
`ctx.accounts.deleteAccount(accountId)` for an administrator's command, whichever the setting — runs in one transaction:
`DwAuthConfig.onAccountDeleting(ctx, accountId)` first, where the project deletes or anonymises its
own rows (a row referencing `dw_account` without `ON DELETE CASCADE` must go there, or the deletion
fails; refusing keeps the account); then the code tickets addressed to the account's identifiers (a ticket carries the phone or the
e-mail and outlives the sign-in it served) and the recorded outcomes of its commands, the account's
stored files (their objects leave the storage once it commits), every session key revoked (its live
sessions close), and the account with its identities, keys and push devices. Analytics keep their events without the
account. On the client, `dw.deleteAccount()` sends it and ends the session once the server
confirms; the skeleton's profile page has the button, with a confirmation.

**The server refuses to start when it would delete project rows nobody decided about.** At startup
it reads its own foreign keys and follows every `ON DELETE CASCADE` from `dw_account` — through as
many hops as there are, because the row that hurts is usually not the one naming the account but the
one hanging off it. If any of them belong to the project and `onAccountDeleting` is not set, the
server does not start and names them. When the hook is set, the same list is logged on every start —
and in both cases each table comes **with the path that reaches it**:

```
dw_account → user_profile
dw_account → user_profile → team_invitation
```

The shape is the point. A table hanging straight off the account holds that person's own rows; one
reached through their profile is where somebody else's turn up — an invitation addressed to a team
rather than to whoever wrote it — and a flat list of names hides exactly that. It also settles a
question nobody should have to argue: a reviewer and an author once disagreed about how two of these
tables were connected, and the author's answer was wrong. A path cannot be read two ways.

This exists because it happened. `DwDeleteMyAccount` is part of every server, so a project that had
pointed its own rows at `dw_account` with a cascade — the obvious way to write that foreign key —
made them deletable by the person they are about the moment its framework pin moved. Nothing in the
project changed, nothing failed to compile, no test went red, and a stand lost every survey answer
behind its profiles on the first deletion. The three ways out are the hook itself (delete or
tombstone), a refusal inside it (`ctx.refuse(...)`) while the project has not decided — honest and
reversible — or an empty hook with a comment saying those rows are meant to go. A project where
members do not delete themselves at all says so with `accountDeletion: DwAccountDeletion.byOperator`
rather than a refusal in the hook: the refusal also stopped the operator's own deletions.

The message names the fact and not the conclusion: these tables go, not "you forgot to tell
somebody". Who has to be told is the project's own — an admin channel here, a webhook there — and a
framework that guessed would be wrong in half of them within a year. It does say what is available,
because that is the next question: **the hook runs inside the deleting transaction**, so
`ctx.publish` and `ctx.jobs` work from it, and whatever must be told about the person leaving is told
in the same transaction or not at all. The example publishes its tombstone and its admin counters
from exactly there.

**What the project deletes, and what it keeps.** The hook answers one question per kind of row:
*is this about that person alone, or does someone else hold on to it?* A person's own drafts,
settings and files go with them. What other people read — a message in a chat, a post, a review, an
order a colleague is fulfilling — cannot go without taking somebody else's history with it. Those
rows keep pointing at the profile, and the profile becomes a **tombstone**: the row stays, its
`account_id` is nulled (declare the column nullable with `ON DELETE SET NULL`), a `deleted_at` is
stamped, and every personal field — name, phone, photo, anything the person wrote about themselves —
is cleared in the hook. Its data objects carry a flag (`isDeleted`) and the screens name it: "member
who left". Nothing of the person is left in the framework's tables either way; what is left is an
author with no one behind it.

What this is not: hiding the account behind a flag and keeping the name and the phone number. That
is the shortcut every system is tempted by, and it is a deletion the person was not offered and the
law does not recognise. Whichever route a project takes, the app says which one **before** it asks
to confirm — "your account and your data are deleted; your messages stay, signed by a member who
left" is honest, "everything will be deleted" while the profile survives is not.

`example/` carries the tombstone end to end — the hook, the migration, the flag on the data objects,
the acceptance test that another member's chat keeps its messages after their author leaves. The
template deletes the profile outright, which is right while nothing else points at it, and says in
`auth.dart` when that stops being true.

On the client, the app sends these commands like any other and keeps the answered session with
`dw.signIn(session)` ([Flutter core](../3-flutter/flutter-core.md)).

## Signing in with Google and Apple

`dartway_auth_providers_server` is the other door into the same accounts: the app gets a token from
the provider's own SDK, sends it with `DwSignInWithProvider`, and the server signs in the account of
the subject that token proves.

```dart
// appProtocol is the project's own (generated entries, include: DwWireProtocol.core,
// contractVersion from the generator) — the providers' DTOs go on top of it, keeping
// its contract version:
final protocol = DwWireProtocol(
  dwAuthProvidersProtocolEntries,
  include: appProtocol,
);

DwAppServer(
  protocol: protocol,
  modules: [
    DwSignInProvidersModule([
      DwGoogleSignIn(clientIds: [androidClientId, iosClientId, webClientId]),
      DwAppleSignIn(clientIds: ['com.club.app']),
    ]),
  ],
  auth: DwAuthConfig(
    ...,
    onExternalAccountCreated: (ctx, accountId, provider, subject, data) =>
        AppAuth.createProfile(ctx, accountId, data),
  ),
);
```

`dartway_auth_providers_shared` carries the command and the refusals — it is what the app depends
on; `dartway_auth_providers_server` verifies. They are separate packages from the core on purpose:
a server that offers no provider does not register the command at all, and a command with no
handler is a server that refuses to start.

**The providers are independent.** A project declares the ones it offers; a token of a provider it
did not declare is refused with `dw.forbidden`, as every door this server does not have is. There is
no configuration that accepts "any provider": a provider is its issuer, its key set and its client
ids together.

**What is checked, and all of it is checked.** The token is three base64url parts; a key the
provider publishes, of the id the header names and of the algorithm that key itself declares — never
the algorithm the token claims — verifies the signature; the issuer is the provider's; the audience
is one of **this app's client ids**; it has not expired (two minutes of clock skew) and is not dated
into the future; the nonce is the one the app used, either as the app made it or as its SHA-256
(Apple's flow hashes it); and it names a subject. A token is never half accepted.

**The client ids are a list because Android, iOS and the web each have their own.** A server
configured with one of them turns away the users of the other platforms, and the refusal says
nothing they can act on — this is the mistake the shape of the API is there to prevent.

**Keys rotate, so nothing is pinned.** The set is fetched on the first sign-in and held for as long
as the provider's `Cache-Control` says (an hour when it says nothing, a day at most). A token naming
a key id the held set does not have is what a rotation looks like, so the set is fetched again — at
most once a minute, which is what keeps a stream of made-up key ids from becoming a stream of
requests to the provider. A fetch that fails while a set is held keeps the held one.

**Two refusals, and the difference matters to the app.** `dw.providerCredentialRejected` (field
`idToken`) means the token did not hold up — ask the provider for another one. Which check failed is
written to the server's log and not to the answer: it is a hint to whoever is trying tokens.
`dw.providerUnreachable` (field `provider`) means the provider could not be asked for its keys and
none are held — nothing is wrong with the token, and the app may simply try again.

**What the provider told about the person reaches `onExternalAccountCreated`** in the registration
map, under keys the server reserves: `dw.email`, `dw.emailVerified`, `dw.name`, `dw.givenName`,
`dw.familyName`, `dw.picture`, `dw.realUser` (`DwProviderClaim`). They are the server's words: what
the app sent under the `dw.` prefix is dropped first, so a project reading `dw.email` reads an
e-mail a provider signed. Apple tells the name **only at the very first authorization** and never in
the token, so an app that wants it sends it in `DwSignInWithProvider.registration` of that sign-in —
or it is gone for good.

The identity is stored like any other: `dw_identity`, kind `google` or `apple`, value the provider's
subject id. Nothing of the token is kept. An account can therefore hold a phone, an e-mail and a
provider identity at once, and `DwAccountService.accountOfExternalIdentity` answers who a subject is.

**Deleting an account tells Apple.** Sign in with Apple requires that an app revoke the person's
tokens when they delete their account, and the only thing that can do it is a refresh token, which
exists for one moment: the app sends Apple's one-time `authorizationCode` with the sign-in, and the
server exchanges it. Give `DwAppleSignIn` a `signingKey` — the `.p8` file Apple hands out once, its
key id and the team id — and the module does the rest:

```dart
DwAppleSignIn(
  clientIds: ['com.club.app'],
  signingKey: DwAppleSigningKey(
    teamId: 'ABCDE12345',
    keyId: 'XYZ9876543',
    privateKeyPem: applePrivateKey,   // from the secret store, never the repo
  ),
),
```

The key signs a **client secret** — a short-lived JWT, half an hour — for every call to Apple; it is
minted per call and stored nowhere. The refresh token is kept in `dw_provider_token`, which no
handler reads and nothing leaves the server with. Deleting the account hands it to the
`dw.auth_providers.revoke` job and deletes the row: **the deletion never waits on Apple and never
fails because Apple is down**, and the job retries until Apple answers. A sign-in without a code, or
a server without a signing key, signs the person in and says in the log that the revocation will
have nothing to work with; an exchange Apple refuses does not refuse the sign-in, which the identity
token already proved.

**The app's half is two packages, one per provider**, so a project takes what it offers:
`dartway_auth_google` (`dw.signInWithGoogle()`) and `dartway_auth_apple` (`dw.signInWithApple()`).
Each makes the nonce, gets the token from the provider's SDK, sends the command and signs the
answered session in; what the provider told about the person is handed to an `introduce` callback
whose answer joins `registration`, so the project names its own fields and neither package knows
them. Apple's package also carries the `authorizationCode`; Google's nonce is fixed by
`DwGoogleAuth.initialize`, because the Google SDK takes it there rather than per sign-in.

**What a project still owes the stores.** Offering Google or Apple sign-in brings App Store
guideline 4.8 into play — an app whose main account uses a third-party sign-in must also offer one
that asks no more than name and e-mail and lets the person hide theirs; sign-in by code to a phone
or an e-mail is not affected.

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
- `ctx.accounts` in a **startup step** — the first administrator, in the step's transaction
  ([app server](app-server.md#startup-steps));
- `server.accounts` next to a running server;
- `DwAccountService(db, auth)` over a bare database, where no server runs in the process. Its hooks
  get a context whose `publish`, `revoke` and `jobs` throw rather than drop what they are given
  (D-022). The skeleton's seed does **not** use this: it starts the project's own server on port
  `0` and works in a real context, so the accounts it creates are created by the project's real
  `DwAuthConfig` rather than by a second copy of it.

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
