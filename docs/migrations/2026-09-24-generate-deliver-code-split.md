---
title: "DwAuthConfig.fixedCode is gone: generateCode picks the code, deliverCode always runs"
affects:
  dartway_core_server: "0.21.0-dev.2"
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
profile. Both known users of `fixedCode` outside this repository do more than that, and **this note
does not know their exact bodies** — it names the shape of what each does differently, not a body
to copy. Whatever the real branches and their order are, the rule is the same one the simple case
above already follows: **`fixed` is the entire original `fixedCode` body, unchanged, priority order
included.** This note's job is to move it, not to improve it — do not reorder branches while moving
them, even where a different order looks more natural once it is in front of you.

- **Studio** (`studio_auth.dart`) hands out a fixed code to **any** identifier while the server
  runs in development — not only accounts that already have one on their profile. Its `fixedCode`
  is set conditionally — `null` itself outside development, not a function that returns `null` —
  so `fixed` stays a nullable closure too, and both hooks call it accordingly:

        generateCode: fixed,   // already nullable — no change needed here
        deliverCode: (ctx, kind, identifier, code, accountId) async {
          if (await fixed?.call(ctx, kind, identifier, accountId) != null) return;
          await sendSms(identifier, code);
        },

  `fixed?.call(...)` on a `null` closure evaluates to `null` before the `await`, not a call —
  `await null` is `null` in Dart, so the guard reads correctly either way. Assigning a nullable
  `fixed` straight to `generateCode` needs no `?`: the field is declared nullable already.

- **U90** (`auth.dart`) reads a profile's own `testVerificationCode` **first** — that check has
  priority over the stand-wide code, not the other way around — and only falls back to a fixed
  code for identifiers without one, while the stand is not production, plus a **store reviewer's**
  account specifically in production. Moving this mechanically means keeping the profile check
  first in `fixed`, exactly where it already is; swapping the two checks' order — profile first
  vs. stand-wide first — changes which code a reviewer's own account is answered whenever both
  would otherwise apply, and that is not a change this note asks for.

For either shape, the same warning applies: if `deliverCode`'s guard ends up narrower than `fixed`
actually is — dropping a branch, or simplifying `fixed?.call(...)` to a bare `fixed(...)` where
`fixed` can truly be `null` — the branch it drops keeps working exactly as before for
`generateCode` (still hands out the fixed code), but `deliverCode` no longer recognises that case
as "already handled" and falls through to the real sender. **A server that used to hand a case the
same code, sent nowhere, starts sending it for real** — an SMS or an e-mail to whatever address or
number was typed in — the first time someone hits that exact case. Nothing about this fails
loudly: the sign-in still works, the code on screen still matches, and the only sign anything
changed is a message that should not exist arriving somewhere real.

## One more thing, if `deliverCode` reads the database

`deliverCode` now runs **after** the ticket's transaction has committed, not inside it (so an HTTP
call to a provider does not hold a pooled connection, or the identifier's advisory lock, for as
long as that call takes). `ctx.db` inside `deliverCode` is a fresh connection, not the one the
ticket was written on, and it no longer shares a transaction with whatever `generateCode` did —
mostly invisible, since both still see the same committed data, except that a lookup done in both
(the profile check in `fixed`, above) now runs twice against the database instead of once inside
one transaction. `ctx.memo`, already shown above, is the fix, and is enough: it survives across the
whole call, transaction boundary included.

## One more thing: a failed delivery still counts against the limit

The ticket is written, and already counted against `maxRequestsPerWindow` and `resendDelay`,
**before** `deliverCode` runs — not after it succeeds. If `deliverCode` throws or refuses, the
ticket it would have refused before existing is already real: the call still fails (an incident for
a bare exception, a refusal for `ctx.refuse`), but the next attempt for that identifier meets the
same `resendDelay`/window refusal an ordinary resend would, rather than being free to retry at
once. A test that asserted "a failed delivery leaves no ticket, and an immediate resend succeeds"
now asserts the opposite: the ticket exists, and an immediate resend is refused until the delay (or
the window) passes.

A repeat of the *same command* with the same idempotency key is a different question from a resend,
and is unaffected by anything above: it replays the original ticket rather than running `deliverCode`
a second time, whether the repeat arrives while delivery is still in flight or long after — the
framework records that outcome in the ticket's own transaction now, precisely so a duplicate send
never meets a resend-delay refusal for a ticket its own earlier attempt already created.

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
