---
title: "Whose row it is moves from handler bodies into DwAccessRule.resource"
affects:
  dartway_core_server: "0.21.0-dev.11"
  dartway_cli: "0.17.0"
---

## Who is affected

A project whose handlers check ownership after the rule: `signedIn` or a role rule, then
`if (row.ownerProfileId != me) refuse(notFound)` in the body or in a private `_requireOwn…` helper.
Nothing fails — `dart run dartway_cli:dartway check` now warns on each such site
(`inlineOwnershipCheck`) — but every copy of the check is a place for the answers to drift apart.
The class of bug this ends: one membership ("is the caller in this conversation") defined in
several places, one of which forgot the block check. The recipe is below; the reference is
[Access and roles](../2-core/access-and-roles.md#whose-row-is-it-one-rule-per-shape).

## What to change

**1. An inline owner check becomes the rule.** The row read and the comparison move into
`DwAccessRule.resource`; the handler takes the row from `ctx.accessed`:

    - access: DwAccessRule.signedIn,
    - handle: (ctx, command) async {
    -   final task = await ctx.db.tasks.findById(command.taskId, lock: DwRowLock.forUpdate);
    -   if (task == null || task.userProfileId != (await ctx.profile).id) {
    -     ctx.refuse(DwCoreRefusal.notFound);
    -   }
    + access: DwAccessRule.resource<CompleteTask, TaskRow>(
    +   load: (ctx, command) =>
    +       ctx.db.tasks.findById(command.taskId, lock: DwRowLock.forUpdate),
    +   allows: (ctx, command, task) async =>
    +       task.userProfileId == (await ctx.profile).id,
    + ),
    + handle: (ctx, command) async {
    +   final task = ctx.accessed<TaskRow>();

A handler under a role rule moves the role into `allows` as well: **`allows` carries the whole
permission**, and `load` answers `null` for a caller without the role before it locks anything
(`await ctx.isStaff ? … : null`).

**2. A shared `_requireOwn…` helper becomes a rule function.** Where several handlers called one
helper, one function in `AppAccess` returns the rule, and each handler names it:

    - Future<TaskRow> _requireOwnTask(int taskId) async { … refuse(DwCoreRefusal.notFound); … }
    + static DwAccessRule ownTask<C extends DwServerCall<Object?>>(int Function(C call) taskId) =>
    +     DwAccessRule.resource<C, TaskRow>(
    +       load: (ctx, call) => ctx.db.tasks.findById(taskId(call), lock: DwRowLock.forUpdate),
    +       allows: (ctx, call, task) async => task.userProfileId == (await ctx.profile).id,
    +     );

**3. Locks move into `load`, in the order the handler took them.** A helper that locked the parent
before the child (a day's plan before its entry, so two writers never wait on each other) keeps
that order inside `load`, which now returns both as a record:

    load: (ctx, command) async {
      final entry = await ctx.db.entries.findById(command.entryId);
      if (entry == null || entry.userProfileId != (await ctx.profile).id) return null;
      final plan = await ctx.db.plans.findById(entry.planId, lock: DwRowLock.forUpdate);
      final locked = await ctx.db.entries.findById(entry.id!, lock: DwRowLock.forUpdate);
      return plan == null || locked == null ? null : (locked, plan);
    },
    allows: (ctx, command, found) => true, // decided above, before any lock

**4. One membership function.** Whatever defines "a member" (active, accepted, not blocked) goes
into one function in the context extension that returns the caller's membership or `null` —
`ctx.membershipOf(conversationId)`. Every resource rule's `load`, the conversation's
`DwChannelRule.keyed` `canSubscribe` and `DwFileStorage.canRead` for its attachments call it; delete
every other query that answers the same question.

**5. A message in a conversation is `(message, membership)`, with `visible`.** Editing or deleting
someone else's message in a conversation the caller reads is `dw.forbidden`, not `dw.notFound`:

    access: DwAccessRule.resource<EditMessage, (MessageRow, ConversationMemberRow)>(
      load: (ctx, command) async {
        final seen = await ctx.db.messages.findById(command.messageId);
        if (seen == null) return null;
        final membership = await ctx.membershipOf(seen.conversationId);
        if (membership == null) return null;
        final message = await ctx.db.messages.findById(
          command.messageId,
          lock: DwRowLock.forUpdate,
        );
        return message == null ? null : (message, membership);
      },
      allows: (ctx, command, found) => found.$1.senderProfileId == found.$2.profileId,
      visible: (ctx, command, found) => true,
    ),

`visible` is not a gate: it only turns a refusal `allows` already made into `dw.forbidden`.

**6. Lists stay as they are.** A list of the caller's rows is `signedIn` with the caller in the
query's `where`; a list inside a conversation takes the membership rule of step 4.

## How to check

`dart run dartway_cli:dartway check` reports no `inlineOwnershipCheck`, and the server suite has one
refused call per rule: someone else's id and a missing id both `dw.notFound`, a visible row that is
not the caller's `dw.forbidden`, a caller who lost the role refused.
