---
title: "DwAuthConfig.fixedCode is gone: generateCode picks the code, deliverCode always runs"
affects:
  dartway_core_server: "0.21.0-dev.1"
---

## Who is affected

Every project that sets `DwAuthConfig.fixedCode`, or that passes `deliverCode` a 4-argument
function. `fixedCode` no longer exists; `deliverCode` is now called on every request, with a fifth
argument, and returning a code from a hook no longer skips it (issue #310).

**Read the whole note before editing**, particularly if `fixedCode` ever returned a code for more
than a named test account — a store's reviewer, or *anything* signing in while some `DW_*` flag is
on. The mechanical move below changes what such a project sends, not just what it compiles to; the
warning after it says exactly what breaks and why.

## What to change, mechanically

The old `fixedCode` closure becomes a plain function — call it `fixed`, or keep whatever name it
already had if it was factored out — with the exact same body and the exact same `String?` return:

    - fixedCode: (ctx, kind, identifier, accountId) async {
    -   if (accountId == null) return null;
    -   final profile = await ctx.db.userProfiles.findFirst(
    -     where: (t) => t.accountId.equals(accountId),
    -   );
    -   return profile?.testVerificationCode;
    - },
    + Future<String?> fixed(
    +   DwCallContext ctx,
    +   DwIdentifierKind kind,
    +   String identifier,
    +   int? accountId,
    + ) async {
    +   if (accountId == null) return null;
    +   final profile = await ctx.db.userProfiles.findFirst(
    +     where: (t) => t.accountId.equals(accountId),
    +   );
    +   return profile?.testVerificationCode;
    + }

Wire it into both hooks, unchanged in body:

    DwAuthConfig(
      ...
    + generateCode: fixed,   // null → the framework's own default (codeLength random digits)
      deliverCode: (ctx, kind, identifier, code, accountId) async {
    +   if (await fixed(ctx, kind, identifier, accountId) != null) return;
        await sendSms(identifier, code);
      },
    )

That is the whole move: `generateCode: fixed` reuses the function directly — its signature already
matches, because `fixedCode` and `generateCode` ask the same four things. `null` from `fixed`
now means "let the framework generate one" the same way it always meant "no fixed code" before;
leaving `generateCode` unset does the same thing for a project that never had a `fixedCode` at all.
`deliverCode`'s new first line is **the same condition as `fixed`'s own**, evaluated again — not a
simplification of it, not "was this call's `accountId` non-null", the actual call to `fixed`,
because that is the only way the guard stays correct when `fixed` is ever *not* pure
`accountId == null` (see the warning below). `ctx.memo` keyed on the account id turns the repeated
call back into one query, if that matters to you:

    Future<String?> fixed(
      DwCallContext ctx,
      DwIdentifierKind kind,
      String identifier,
      int? accountId,
    ) => ctx.memo(#fixedSignInCode, () async {
      if (accountId == null) return null;
      final profile = await ctx.db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(accountId),
      );
      return profile?.testVerificationCode;
    });

## Read this if `fixedCode` ever returned a code for more than one named account

The example above is the simple case — a code that exists only on a signed-in account's own
profile. Both known users of `fixedCode` outside this repository do more than that:

- **Studio** (`studio_auth.dart`) hands out a fixed code to **any** identifier while the server
  runs in development — not only accounts that already have one on their profile.
- **U90** (`auth.dart`) does the same in development, and separately gives a fixed code to a
  **store reviewer's** account in production, by identifier rather than by an existing profile
  field.

For a `fixedCode` shaped like that, the mechanical move above is still correct **only if the new
`fixed` function is the whole original body, dev branch included** — not the part that happens to
read a profile. Copy the environment check across too:

    Future<String?> fixed(
      DwCallContext ctx,
      DwIdentifierKind kind,
      String identifier,
      int? accountId,
    ) async {
      if (isDevelopment) return '000000';           // every identifier, in dev
      if (accountId == null) return null;
      final profile = await ctx.db.userProfiles.findFirst(
        where: (t) => t.accountId.equals(accountId),
      );
      return profile?.testVerificationCode;
    }

If `deliverCode`'s guard is narrowed to only the profile lookup — dropping the `isDevelopment`
line — the dev branch keeps working exactly as before for `generateCode` (still hands out
`000000`), but `deliverCode` no longer recognises that case as "already handled" and falls through
to the real sender. **A development server that used to hand every sign-in the same code, sent
nowhere, starts sending real SMS or e-mail to whatever address or number is typed in**, the first
time someone tries it. Nothing about this fails loudly: the sign-in still works, the code the
tester sees on screen (`000000`) still matches, and the only sign anything changed is a message
that should not exist arriving somewhere real.

## One more thing, if `deliverCode` reads the database

`deliverCode` now runs **after** the ticket's transaction has committed, not inside it (so an HTTP
call to a provider does not hold a pooled connection, or the identifier's advisory lock, for as
long as that call takes). `ctx.db` inside `deliverCode` is a fresh connection, not the one the
ticket was written on, and it no longer shares a transaction with whatever `generateCode` did —
mostly invisible, since both still see the same committed data, except that a lookup done in both
(the profile check in `fixed`, above) now runs twice against the database instead of once inside
one transaction. `ctx.memo`, already shown above, is the fix, and is enough: it survives across the
whole call, transaction boundary included.

## How to check

`dart analyze` — the old signatures no longer compile, on either hook.

For the simple case: if a fixed code (a test account's, say) went to no delivery before, sign in
to that account once and confirm nothing appears in your delivery channel (SMS, e-mail, log) for
it.

**For a `fixedCode` that ever covered more than one named account — check this even if you are
confident you moved the whole condition**: in development (or whatever mode gave out the wide
code), request a sign-in code for an identifier that has **never** signed in before — one with no
account and no profile at all. Confirm it is answered the fixed code (`generateCode` still applies)
**and** that nothing reaches your real delivery channel for it (`deliverCode`'s guard still
recognises the case). If a real SMS or e-mail goes out for that identifier, the guard in
`deliverCode` is narrower than `fixed` was, and needs the missing branch back.
