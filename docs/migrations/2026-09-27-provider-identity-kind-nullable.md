---
title: A provider identity is a first-class DwIdentityInfo; kind is now nullable, provider joins it
affects:
  dartway_core_shared: "0.21.0-dev.8"
  dartway_core_server: "0.21.0-dev.8"
---

## Who is affected

Every project reading `DwIdentityInfo.kind` or `DwIdentifierChange.kind` without a null check —
directly, or through a switch that does not cover `null`. Before this version, a provider identity
(`google`, `apple`, from `dartway_auth_providers_server`) made every reader of `dw_identity` throw
`ArgumentError` (dartway/dartway#355), so in practice this affects any project that also lists,
moves or removes identities and offers Google or Apple sign-in.

## What to change

`DwIdentityInfo.kind` and `DwIdentifierChange.kind` are `DwIdentifierKind?` now; both types gained
`provider: String?`, set instead of `kind` for a provider identity — exactly one of the two is ever
set. `DwIdentityInfo.kindName` answers `provider ?? kind!.name`, the one thing both forms share (a
lock key, a `dw_identity.kind` value).

    - final kind = identity.kind.name;
    + final kind = identity.kindName;

    - switch (change.kind) {
    -   case DwIdentifierKind.phone: ...
    -   case DwIdentifierKind.email: ...
    - }
    + switch ((change.kind, change.provider)) {
    +   case (DwIdentifierKind.phone, _): ...
    +   case (DwIdentifierKind.email, _): ...
    +   case (_, final provider?): ... // a Google or Apple identity
    +   case (null, null): throw StateError('neither kind nor provider set');
    + }

A place that only ever sees code identifiers (a phone/e-mail settings screen, say) can instead
filter provider identities out and keep reading `kind` non-null:

    for (final identity in identities)
      if (identity.kind case final kind?) ...

`DwIdentifierChangeCause` gained `linked`: a provider identity's first sign-in matched an existing
account by e-mail (below) rather than a confirmed code — handle it the same way your `moved` and
`removed` cases decide what to do, or leave it to the default case if you only mirror `confirmed`.

The wire shape of `DwIdentityInfo` gained a new, additional form (`provider` instead of `kind`) —
recorded as a new shape, not a protocol bump: the framework's own built-in command that answers one,
`DwConfirmIdentifier`, only ever attaches a code identifier, so no installed app meets this shape
from the framework itself. A project that hands its own `DwIdentityInfo` list to the wire (an admin
command built on `ctx.accounts.listIdentities`, say) decides for itself whether an old build of its
own app needs to keep up — the framework's protocol version does not move for it.

## New, opt-in: `DwAuthConfig.linkByVerifiedEmail`

Nothing to change unless you want it. Off by default, on it attaches a provider identity's first
sign-in to an existing account when the token's e-mail is verified and matches one already there,
instead of making a second account — see `docs/4-server/auth-identity.md`.

## How to check

`dart analyze` on the project's server and Flutter packages: a `kind.name` or an exhaustive `switch`
over `DwIdentifierKind` that does not account for `null` is now a compile error, which is the point.
