---
title: "DwAuthConfig.accountDeletion is required: say who may delete an account"
affects:
  dartway_core_server: "0.21.0-dev.3"
---

## Who is affected

Every project: `DwAuthConfig` has a new required parameter, and the server package does not compile
until it is passed.

## What to change

If members delete their own account from the app — what an app store asks of an app people sign up
in — keep today's behaviour:

    DwAuthConfig(
    + accountDeletion: DwAccountDeletion.byMember,
      normalize: ...,

If they do not, and the project refuses `DwDeleteMyAccount` from `onAccountDeleting` to switch it off,
say so directly and take the refusal out of the hook:

    DwAuthConfig(
    + accountDeletion: DwAccountDeletion.byOperator,
      ...
    - onAccountDeleting: (ctx, accountId) async =>
    -     ctx.refuse(AppRefusal.accountDeletionUnavailable),

The refusal in the hook also refused `ctx.accounts.deleteAccount` from the project's own admin
commands; with `byOperator` those work, and `DwDeleteMyAccount` is answered `dw.forbidden`. A refusal
code the project added only for this can go too, with its text in the app.

Keep the hook itself if it deletes or tombstones rows: the server still refuses to start while rows
cascade off `dw_account` and no `onAccountDeleting` says what happens to them, whoever deletes.
