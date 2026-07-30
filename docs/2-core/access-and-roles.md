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
  final userProfileId = await session.currentUserProfileId;
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
      await session.isUser(saveContext.currentModel.id ?? -1),
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

What the framework does provide on `Session`: `currentUserProfileId` — the **profile** id, resolved
from the authenticated user, which is the id your foreign keys point at — and `isUser(profileId)`.
Serverpod scopes are not used: `dwAuthenticationHandler` authenticates with an empty scope set, so
scope annotations on endpoints would gate nothing.

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
  — a verification code, an internal hash — is `scope=serverOnly`, which keeps it out of the
  generated client class entirely ([models.md](models.md#scopes-fields-the-client-must-never-see)).
