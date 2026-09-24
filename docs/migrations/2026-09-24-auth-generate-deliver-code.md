---
title: "DwAuthConfig.fixedCode is gone: generateCode picks the code, deliverCode always runs"
affects:
  dartway_core_server: "0.21.0-dev.1"
---

## Who is affected

Every project that sets `DwAuthConfig.fixedCode` — a store reviewer's or a test account's code —
or that passes `deliverCode` a 4-argument function. `fixedCode` no longer exists; `deliverCode` is
now called on every request, with a fifth argument, and returning a code from a hook no longer
skips it (issue #310).

## What to change

1. **What `fixedCode` decided moves into `generateCode`**, a new hook of the same shape that
   returns a code rather than `String?`:

       - fixedCode: (ctx, kind, identifier, accountId) async {
       -   if (accountId == null) return null;
       -   final profile = await ctx.db.userProfiles.findFirst(
       -     where: (t) => t.accountId.equals(accountId),
       -   );
       -   return profile?.testVerificationCode;
       - },
       + generateCode: (ctx, kind, identifier, accountId) async =>
       +     await _testCode(ctx, accountId) ?? dwRandomCode(6),

   `dwRandomCode(length)` is the framework's own default generator, now exported for this: a
   project that wants it for most requests and something else for a few no longer writes its own.
   Leaving `generateCode` unset keeps today's behaviour exactly — `codeLength` random digits.

2. **`deliverCode` takes a fifth parameter, `int? accountId`** (the account `identifier` already
   belongs to, the same value `generateCode` was asked with — not the caller attaching it, which is
   still `ctx.accountId`), and **is now called for every code**, including one `generateCode`
   returned. A project whose fixed code must not be sent decides that inside `deliverCode` itself:

       deliverCode: (ctx, kind, identifier, code, accountId) async {
       +  if (await _testCode(ctx, accountId) != null) return;
          await sendSms(identifier, code);
       },

   A project whose fixed code was never meant to be sent anywhere needs exactly this one guard.
   A project that wants its fixed code sent too — the reason for this change — now can, by not
   adding the guard for that case.

## How to check

`dart analyze` — the old signatures no longer compile, on either hook. If a fixed code (a store
reviewer's, a test account's) went to no delivery before, run its sign-in once and confirm nothing
appears in your delivery channel (SMS, e-mail, log) for it.
