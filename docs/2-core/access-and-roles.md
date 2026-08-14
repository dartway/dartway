# Who is allowed to read and write what?

Authorisation in DartWay is not scattered through endpoints, guards and UI checks. It sits in four
places inside a model's CRUD config, and there is no fifth: a model is reachable only if it is
registered, callable only by a signed-in caller unless it says otherwise, readable only through its
`accessFilter`, and writable only through `allowSave` / `allowDelete`.

That concentration is the point. "Who can see other people's bookings?" is answered by opening one
file, not by auditing an endpoint layer and hoping no handler forgot a check.

## Gate 1 — registration

A model with no `DwCrudConfig` in `crudConfigurations` is not served at all. Every operation answers
`DwApiResponse.notConfigured`. The same holds slot by slot: no `getListConfig`, no list; no
`saveConfig`, no writes; no `deleteConfig`, no deletion.

Nothing is exposed by adding a table, and nothing has to be remembered to keep it that way. Access
is granted, never revoked.

## Gate 2 — authentication, `allowAnonymous`

Every config carries `allowAnonymous`, and it defaults to `false`. A caller with no session is
rejected before the config runs — before the filter is built, before the database is touched — and
gets `DwApiResponse.notAuthenticated`.

That response is deliberately not `forbidden`. "You are not signed in" and "you may not do this" ask
different things of the client: the first sends the user to the login screen, the second does not.

Public data says so in one word:

```dart
final clubServiceListConfig = DwGetModelListConfig<ClubService>(
  allowAnonymous: true,                 // a catalog shown before the login screen
  accessFilter: (session) async => null,
);
```

The gate is per config rather than on the endpoint because one CRUD endpoint serves every model.
Serverpod's `requireLogin` is all-or-nothing for a whole endpoint, so switching it on would have
taken the public catalog down together with the private order list.

The framework's own sign-in path is the clearest case for the exception. `dwAuthRequestConfig` and
`dwAuthVerificationConfig` are `allowAnonymous: true`: requesting a code and submitting it are how a
caller gets a session in the first place, so requiring one would mean "sign in to sign in". What
protects them is not authentication but a rate limit per identifier, a lock so parallel attempts
cannot each pass it, and a bounded number of guesses before the request is burned. That is the shape
of a correct exception — open the door, then say what stands behind it.

Realtime subscriptions are gated too, but not by this flag: a channel carries no model, so there is
no config to read `allowAnonymous` from, and "is there a session" would not have been the right
question anyway — channel names are guessable by a signed-in stranger just as easily. Channels are
declared separately and answer "may *this* caller listen to *this* channel". See
[Realtime](realtime.md#declaring-a-channel).

## Gate 3 — `accessFilter`, a `WHERE` clause and not a check

Both read configs take one, and it is a **required** parameter — you cannot construct a read config
without stating the rule:

```dart
final Future<Expression?> Function(Session session)? accessFilter;
```

It returns an SQL expression that narrows the query, which is what makes it composable: the
framework ANDs it onto whatever the client sent.

```dart
Future<Expression<dynamic>?> _bookingAccessFilter(Session session) async {
  if (await session.isStaffMember) {
    return null;                       // staff see everything
  }
  final userProfileId = session.signedInUserProfileId;
  return SessionBooking.t.clientProfileId.equals(userProfileId ?? -1);
}
```

Deny-all is an expression too:

```dart
/// Staff and admin see everything; clients see nothing.
Future<Expression<dynamic>?> staffOnlyAccessFilter(Session session) async =>
    await session.isStaffMember ? null : Constant.bool(false);
```

That one line is what hides the staff chat in `example/` from every client — not a hidden tab, not a
missing route. The tab is hidden too, but only so the UI is not confusing; the data was never
reachable.

Because the filter is SQL rather than a post-fetch check, it also governs `getCount`, pagination and
ordering for free: a client asking for page 40 of a list it may not see gets an empty page, not a
slice of someone else's rows. Client-supplied filters can only narrow further — they are ANDed, so
no filter widens what the access rule allows.

## What `null` actually grants

`null` means "no narrowing" — every row the caller is allowed to ask for. It says nothing about who
the caller is; that is Gate 2's job, and by default that gate is shut.

So `accessFilter: (session) async => null` on its own now reads as "every signed-in user sees every
row". To publish rows to the world you have to add `allowAnonymous: true` next to it, and that is
the line a reviewer looks for.

Until 0.3.0 there was no such line, and `null` did publish the table: the CRUD endpoint required no
session, so the filter was the only gate and an absent filter was no gate at all. If you are
upgrading, walk every config whose filter can return `null` and decide, one by one, which ones were
public on purpose. Nothing will fail to compile — the change is in behaviour, not in types.

## Gate 4 — writes

```dart
saveConfig: DwSaveConfig<UserProfile>(
  allowSave: (session, saveContext) async =>
      await session.isClubAdmin ||
      session.isUser(saveContext.currentModel.id ?? -1),
  // ...
),
deleteConfig: DwDeleteConfig<ClubService>(
  allowDelete: (session, model) => session.isClubAdmin,
),
```

`allowSave` is a required parameter — a model with a save config always has a write rule, and the
only way to have no rule is to have no save config. Anything other than `true` produces
`DwApiResponse.forbidden()` (`Not enough permissions`).

`allowDelete` is nominally optional, but a `DwDeleteConfig` without it answers `notConfigured` — the
permissive default does not exist.

Note what `allowSave` receives: the whole `DwSaveContext`, including `initialModel`. Ownership
checks are therefore about the row being written, not about a route — and a client that edits an id
in a request body is checked against the row it actually named.

## Roles are your app's, not the framework's

The framework knows about a user profile table and an authenticated user. It ships no role enum, no
permission matrix and no `@RequiresRole`. Roles are a field on your own model:

```yaml
role: UserRole, default=client   # client / staff / admin
```

and the vocabulary the configs read is an extension your app writes over it:

```dart
extension DwSessionExtension on Session {
  Future<UserProfile?> get currentUserProfile => dw.currentUserProfile(this);

  Future<bool> get isStaffMember async {
    final role = (await currentUserProfile)?.role;
    return role == UserRole.staff || role == UserRole.admin;
  }

  Future<bool> get isClubAdmin async =>
      (await currentUserProfile)?.role == UserRole.admin;
}
```

What the framework does provide on `Session` is two synchronous members:

- **`signedInUserProfileId`** — the **profile** id the caller presented a token for, which is the id
  your foreign keys point at. Free: Serverpod resolves authentication when the session is created
  and caches it, so this reads a field. It says the token is valid, not that the profile row still
  exists — see [Ending a session](#ending-a-session).
- **`isUser(profileId)`** — the same comparison, with a **non-nullable** parameter. That is the whole
  reason it exists: written by hand as `model.ownerId == session.signedInUserProfileId` over a
  nullable column, an anonymous caller reads `null == null` and is let in.

When you need the profile itself and not its id, `dw.currentUserProfile(session)` reads the row — and
being a database call, it is the one you should not put in a hot path. It has two siblings for the
cases where the caller is not the subject: `dw.getUserProfile(session, userProfileId)` and
`dw.getUserProfileByIdentifier(session, identifier)`.

All three take an optional `transaction`, and **inside a CRUD save hook it has to be passed**:
`dw.currentUserProfile(session, transaction: saveContext.transaction)`. Without it the read leaves
the transaction it is running in — which production tolerates and the test suite does not. The
failure mode is written up in [CRUD configs](crud-configs.md).

Serverpod scopes are not used: `dwAuthenticationHandler` authenticates with an empty scope set, so
scope annotations on endpoints would gate nothing.

## Ending a session

An auth key has no expiry, and nothing deletes it on its own. A token therefore works until somebody
takes it away, which is a thing the server has to do on purpose:

```dart
await dw.auth!.revokeAuthKeys(session, userProfileId: profile.id!);
```

Call it wherever an account stops being allowed to act — deletion, a ban, a deactivation, "sign out
everywhere", a changed phone number. The framework cannot know about those events.

Deleting the row is enough for ordinary calls: `dwAuthenticationHandler` reads the key from the
database on every request, so there is no signed token that outlives its revocation. It is not enough
for a connection already open — a websocket resolves its authentication once, when it opens — which
is why `revokeAuthKeys` also broadcasts Serverpod's revocation message.

Every realtime subscription that user holds ends on that message: the stream closes with a
`DwChannelClosed(reason: authenticationRevoked)`, the client does not reconnect, and the local
session ends — a banned user lands on the sign-in screen rather than watching a screen that quietly
stopped updating. The framework listens for the broadcast itself rather than leaving it to Serverpod,
which acts on it only for endpoints declaring `requireLogin` or scopes; the one CRUD endpoint serving
public and private models alike can declare neither.

Because forgetting the call costs a token that works forever, register the sweeper next to your other
jobs; it deletes keys whose profile no longer exists:

```dart
await DwRecurringJobs.startAll(pod, [DwOrphanedAuthKeyCleanup()]);
```

It is a net, not a substitute. A banned user still has a profile row, so only the explicit call ends
that session.

Keeping roles in the app is what lets a project have `coach`, `owner` and `accountant` without the
framework knowing, and what stops a two-role framework abstraction from being wrong for every third
project.

## Rules about the row itself

Privilege escalation is a write rule, and it compares two versions of the same row:

```dart
validateSave: (session, saveContext) async {
  final roleChanged =
      saveContext.initialModel?.role != saveContext.currentModel.role;
  if (roleChanged && !await session.isClubAdmin) {
    return 'Only the admin can change user roles';
  }
  return null;
},
```

Without this, "a user may save their own profile" quietly means "a user may make themselves admin" —
the ownership check passes, because it really is their own row.

`allowSave` and `validateSave` read `initialModel` from *before* the transaction. When a rule
depends on the row's own current state — a role, a consent flag, a balance, a cancellation marker —
set `lockInitialModelForUpdate: true` on the save config: on updates the row is re-read under
`FOR UPDATE` inside the transaction and both hooks are re-evaluated against what was actually
committed. Rules about *other* rows (seats left, stock) belong in `beforeSaveTransaction` instead —
see [crud-configs.md](crud-configs.md#saving-one-lifecycle-for-insert-and-update).

## Where the guarantee stops

Four places where the config is not the whole answer, and all four are ordinary sources of leaks:

- **Broadcast channels.** `accessFilter` governs the API, not the socket. Everything a save touched
  reaches every subscriber of the channels `broadcastTo` returns, including users who could never
  have fetched those rows. Scope the channel to the audience, or send to one user with
  `session.sendUpdatesToUser` — [realtime.md](realtime.md).
- **Custom endpoints.** A bespoke endpoint is outside all three gates: it enforces what you write in
  it, and nothing more. That is the main reason to keep them rare.
- **The client.** Role helpers on the Flutter side and navigation zone guards shape the UI; they
  decide what is worth showing, never what is allowed. Anything they hide must be unreachable
  server-side as well, or it is only hidden from honest users.
- **Field-level secrets.** `accessFilter` selects rows, not columns. A column no client may ever see
  — a verification code, an internal hash — is `scope=serverOnly`: it is kept out of the generated
  client class, never put on the wire, and not blanked when that client saves the row back
  ([models.md](models.md#scopes-fields-the-client-must-never-see)).
