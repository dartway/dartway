# Who is allowed to read and change what?

The framework knows one thing about a caller: the account a session key signed in, or none. Who that
account is to the project — a member, a coach, an admin — is the project's, and the framework gives it
three places to decide with it: the access rule of every handler, the rule of every channel kind, and
the rule of every upload purpose.

## The access rule is required on every handler

```dart
DwCallHandler.single<GetAdminCounters, AdminCounters>(
  access: AppAccess.admin,
  handle: (ctx, request) => AdminPublications.countCounters(ctx.db),
),
```

(`example/dartway_example_server/lib/src/admin/admin_handlers.dart`)

`access` has no default, so a handler cannot be open by omission. There are four rules:

| Rule | Who passes |
|---|---|
| `DwAccessRule.anonymous` | Anyone, including a caller without a session |
| `DwAccessRule.signedIn` | Any signed-in account |
| `DwAccessRule.check<C>((ctx, call) async => …)` | A signed-in account for which the check answers `true`; otherwise `dw.forbidden` |
| `DwAccessRule.resource<C, R>(load: …, allows: …)` | A signed-in account that may reach the row the call names: `load` reads it, `allows` decides on it, and the handler gets it as `ctx.accessed<R>()`. Absent and not theirs are the same `dw.notFound`; with `visible:`, a row the caller may see but not act on is `dw.forbidden` |

**A `check` rule requires sign-in first.** An anonymous caller never reaches the check: the call is
answered `unauthenticated` (401), and the app goes to sign-in instead of showing "forbidden".

**The check receives the call**, typed as `C`, for rules on its real parameters — staff viewing a
client's bookings, an owner editing their own post. A rule written for one call class and given to a
handler of another fails the server's startup; a rule meant for any call is typed
`DwServerCall<Object?>`. The check runs in the handler's context — inside the transaction of a
transactional command — so a row it reads is the row the handler sees.

**A `resource` rule is "is this mine" said once**: the rule reads the row, and the handler receives
it rather than reading it again. Which shape of ownership takes which form is below, in
[Whose row is it](#whose-row-is-it-one-rule-per-shape).

A call runs its steps in this order:

1. a token that is unknown or revoked — `unauthenticated` (401), whatever the rule: a client holding a
   dead token must learn it on any call;
2. a rule other than `anonymous` and no account — `unauthenticated` (401);
3. validation — `DwSelfValidating.validate()`, and `checkPage()` of a table request — refused (422);
4. the `check` — `dw.forbidden` (403) when it answers `false`, or the `resource` — `dw.notFound` (404) when it is absent or not allowed, `dw.forbidden` when not allowed but `visible`; an exception in either is a failure (500);
5. the handler.

Sign-in comes before validation, so an anonymous caller is told to sign in rather than which field is
wrong. Validation comes before the check because it is pure while a check may query, and a check
written against the call's fields should not run on fields that are invalid.

**A registered call without a handler stops the server from starting**, and so do two handlers for one
call and a handler for a class the protocol does not register: `DwStartupException` lists every
problem. A missing handler is found at deploy, not by the first user to press the button.

## Roles are the project's

A role is a column of the project's profile row, and the project names it in its own words with an
extension on the context (`example/dartway_example_server/lib/src/core/call_context.dart`):

```dart
extension AppCallContext on DwCallContext {
  /// The caller's profile, read once per call.
  Future<UserProfileRow> get profile => memo(#profile, () async {
    final accountId = requireAccountId;
    final profile = await db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    // Created in the same transaction as the account: absence is a broken
    // invariant, not a state a caller can be in.
    return profile ?? (throw StateError('Account $accountId has no profile'));
  });

  Future<bool> get isStaff async => (await profile).role != UserRole.client;

  Future<bool> get isAdmin async => (await profile).role == UserRole.admin;
}

/// Access rules of the example, in the words handlers read.
abstract final class AppAccess {
  static final DwAccessRule staff = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isStaff,
  );

  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );
}
```

`memo` runs its function at most once per call: the access check, the handler and every helper ask
`ctx.profile`, and one query answers them all. The skeleton `dartway create` gives a project has the
same shape in its server package's `lib/src/core/call_context.dart`, with an `admin` rule.

The framework ships no roles because every project's are different — a club has coaches, a shop has
sellers — and a role enum in the framework would be a second one beside the project's. What it
guarantees is the part each project would otherwise get wrong on its own: no handler is open by
accident.

## Whose row is it: one rule per shape

Ownership is decided in the access rule, never in the handler's body after `signedIn`: an inline
check is written a little differently every time, and one project that did so answered one question
— "is the caller in this chat" — four different ways. `dart run dartway_cli:dartway check` warns on the
inline form (`inlineOwnershipCheck`). Each shape below has one form.

**A row the caller owns** — a field of the row names the caller's profile. `load` reads the row,
`allows` compares the field:

```dart
DwCallHandler.command<CancelBooking, SessionBooking>(
  access: DwAccessRule.resource<CancelBooking, SessionBookingRow>(
    // Locked: the rule runs inside the command's transaction.
    load: (ctx, command) => ctx.db.sessionBookings.findById(
      command.bookingId,
      lock: DwRowLock.forUpdate,
    ),
    allows: (ctx, command, booking) async =>
        booking.clientProfileId == (await ctx.profile).id,
  ),
  handle: (ctx, command) async {
    final booking = ctx.accessed<SessionBookingRow>();
    // …
  },
),
```

(`example/dartway_example_server/lib/src/bookings/bookings_handlers.dart`)

A command that writes the row locks it in `load` (`lock: DwRowLock.forUpdate`). `ctx.accessed<R>()`
in a handler whose rule loaded something else throws — that is a bug in the declaration, not a
refusal.

**A row owned through its parent** — a lesson is the teacher's because its course is. `load` reads
the row and the parent that decides, and hands both over as a record, so the handler reads neither
again:

```dart
DwCallHandler.command<RenameLesson, Lesson>(
  access: DwAccessRule.resource<RenameLesson, (LessonRow, CourseRow)>(
    load: (ctx, command) async {
      final lesson = await ctx.db.lessons.findById(
        command.lessonId,
        lock: DwRowLock.forUpdate,
      );
      if (lesson == null) return null;
      final course = await ctx.db.courses.findById(lesson.courseId);
      return course == null ? null : (lesson, course);
    },
    allows: (ctx, command, found) async =>
        found.$2.teacherProfileId == (await ctx.profile).id,
  ),
  handle: (ctx, command) async {
    final (lesson, course) = ctx.accessed<(LessonRow, CourseRow)>();
    // …
  },
),
```

**Membership of a parent** — the caller is in the conversation, the project, the circle the call
names. The row that proves it is the caller's membership, so that is what `load` reads, and the
rule is written **once**, as a function next to the project's other rules; every handler of that
parent names it:

```dart
abstract final class AppAccess {
  /// A member of the conversation the call names; the handler reads the
  /// membership as `ctx.accessed<ConversationMemberRow>()`.
  static DwAccessRule conversationMember<C extends DwServerCall<Object?>>(
    int Function(C call) conversationId,
  ) => DwAccessRule.resource<C, ConversationMemberRow>(
    load: (ctx, call) async => ctx.db.conversationMembers.findFirst(
      where: (t) =>
          t.conversationId.equals(conversationId(call)) &
          t.profileId.equals((await ctx.profile).id!),
    ),
    allows: (ctx, call, membership) => membership.isActive,
  );
}

DwCallHandler.command<LeaveConversation, void>(
  access: AppAccess.conversationMember<LeaveConversation>(
    (command) => command.conversationId,
  ),
  handle: (ctx, command) async {
    final membership = ctx.accessed<ConversationMemberRow>();
    // …
  },
),
```

A row inside the parent — a message of that conversation — is the second shape over the third:
`load` reads the message and the caller's membership of its conversation, as a record.

**A row the caller may see but not change** — a message someone else wrote, in a chat the caller
reads. `visible` answers whether the caller may know it exists; when `allows` refuses and `visible`
agrees, the answer is `dw.forbidden`, otherwise still `dw.notFound`:

```dart
DwCallHandler.command<EditChatMessage, ChatMessage>(
  access: DwAccessRule.resource<EditChatMessage, ChatMessageRow>(
    load: (ctx, command) => ctx._liveMessage(command.messageId, lock: true),
    allows: (ctx, command, row) async =>
        row.authorProfileId == (await ctx.profile).id,
    visible: (ctx, command, row) => ctx.isStaff,
  ),
  handle: (ctx, command) async {
    final row = ctx.accessed<ChatMessageRow>();
    // …
  },
),
```

(`example/dartway_example_server/lib/src/chat/chat_handlers.dart`)

**The caller's rows, as a list** — there is no row to check, so there is no rule beyond `signedIn`:
the query names the caller in its `where`, and the request names nothing about them (next
section). A list under a parent — the messages of a conversation — takes the parent's membership
rule and filters by the parent's id.

```dart
DwCallHandler.list<ListMyBookings, SessionBooking>(
  access: DwAccessRule.signedIn,
  handle: (ctx, request) async {
    final me = await ctx.profile;
    final rows = await ctx.db.sessionBookings.find(
      where: (t) => t.clientProfileId.equals(me.id!),
    );
    // …
  },
),
```

## "My" requests carry no account id

`ListMyBookings` has no `accountId` field. Its handler reads the caller's bookings, and its channel is
`DwLiveChannel.ofCaller(DartwayExampleChannel.bookings)`. A request that took the account as a field would be
a request anyone could send with someone else's id, and every handler would have to remember to
compare it with the caller. Commands follow the same rule: the input never carries the owner
([commands-and-idempotency.md](commands-and-idempotency.md)).

A handler that must not reveal whether someone else's object exists refuses `dw.notFound` for it, not
`dw.forbidden` ([refusals-and-statuses.md](refusals-and-statuses.md)).

## Client state is scoped by account

The client keeps each request's state per account. When the signed-in account changes — sign-in,
sign-out, a key the server rejected — every watched request is released and asked again as the new
caller, and caller channels resolve for the new account. The next user of a device never sees the
previous user's data, and updates computed for the previous session are not applied.

## Channels: the second access point

A channel rule decides who may subscribe to a kind — once per subscription, for signed-in connections
only ([channels-and-realtime.md](channels-and-realtime.md)). Two consequences for access:

- everything published to a channel must be readable by every subscriber of it: the channel's rule,
  not the request's, guards what is published;
- a command that takes access away revokes the subscriptions that access opened (`ctx.revoke`),
  because nothing checks again.

A handler's rule and the rule of the channels its request declares should say the same thing. When
they disagree, a user either reads a list they cannot follow, or is refused a subscription the screen
needed — silently, since the read itself succeeded.

## Uploads: the third access point

Each upload purpose has a `DwUploadRule` whose `canUpload(ctx)` decides who may upload, and private
files are read through the `canRead` hook of `DwFileStorage`. See
[../4-server/uploads.md](../4-server/uploads.md).

## Sessions and keys

A session key is what an account signs in with. Keys do not expire; they are revoked — by sign-out, by
the server, or when a key issued for a tool is withdrawn. A revoked key answers `unauthenticated` on
the next call and loses its live subscriptions. `ctx.sessionKey` tells an app's key from a personal
key made for a tool. Sign-in, identifiers and keys are in
[../4-server/auth-identity.md](../4-server/auth-identity.md).
