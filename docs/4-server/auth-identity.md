# The auth identifier: when are two typings the same person?

A DartWay user is found by one string — `UserProfile.userIdentifier`, whatever
the app decided that is: a phone number, an email address, an external id. Every
sign-in matches on it, and the match decides something bigger than it looks: an
identifier that matches nothing is not an error, it is a **registration**.

That is the whole subject of this page.

## The failure

An email address is typed by a person, twice: once when they register, and again
every time they come back. Nothing keeps the two typings identical — a phone
capitalises the first letter, a password manager pastes a trailing space, a
person simply types `Ivan@acme.com` on Tuesday and `ivan@acme.com` on Friday.

Matched byte for byte, Friday's address finds nothing. Nothing is broken, so
nothing complains:

1. the lookup honestly reports that no profile carries this identifier;
2. the flow honestly resolves the request as a registration;
3. the person gets a **second account** — empty, in no team, owning nothing;
4. no error is raised anywhere, because every step did what it was asked.

They notice days later, when their data is "gone". Support sees two rows that
look like two different people. This is the expensive shape of bug: silent,
delayed, and indistinguishable from the user's own mistake.

The same split runs deeper than the account. The per-identifier lock and the
rate-limit bucket are keyed on the same string, so two spellings are also **two
rate-limit buckets** — an attacker gets the limit once per spelling.

## The rule is yours to state, and stating it is not optional

DartWay does not fold case on its own, and that is deliberate. The identifier is
not declared to be an email address; an app may legitimately use one where case
is significant. So the framework refuses to guess.

**`normalizeIdentifier` is a required parameter.** It shipped with a default
that changed nothing, and a default that changes nothing is how a defect stays
open everywhere: the projects that most needed the rule were exactly the ones
that would not remember to declare it. A question the framework cannot answer is
not one it may answer quietly — the compiler asks it once, per project.

Two named answers, so the choice reads at the call site:

```dart
DwCore.init<UserProfile>(
  // ...
  dwAuthConfig: DwAuthConfig(
    passwords: passwords,
    // Trim and case-fold — what an email address wants, and what a phone
    // number does not object to. This is what `dartway create` gives you.
    normalizeIdentifier: DwIdentifierForm.folded,
  ),
);
```

`DwIdentifierForm.asTyped` is the other one: byte for byte, for an identifier
where case is significant — and the only choice that cannot break identifiers
already stored in mixed forms. A rule of your own is fine too; it only has to be
idempotent, because DartWay applies it more than once.

**A new project starts on `folded`.** The skeleton states it, so the day a
project moves from phone numbers to email addresses nobody has to remember that
`Ivan@` and `ivan@` were two people.

Declared once, that rule is applied by DartWay everywhere the identifier decides
*who* someone is:

| Where | What it stops |
|---|---|
| the auth request, the moment it arrives | the lookup, the lock and the bucket all read this one field afterwards |
| the profile a registration writes | the row is stored in the form the next sign-in will look for |
| `dw.getUserProfileByIdentifier` | a lookup the app makes itself |

**Stating it in the framework rather than on the client is the point.** An app
can normalize on the sign-in screen, and that works — until a second client, a
seed script, an admin tool or an environment-provisioned first administrator
writes one row that skipped the rule. Then there are two copies of the rule with
nothing checking that they agree, and the disagreement surfaces weeks later as a
duplicate account.

Your own code paths reach the same rule through `dw.normalizeAuthIdentifier`:

```dart
final identifier = dw.normalizeAuthIdentifier(invitation.email);
```

## The rule must be idempotent

DartWay applies it at more than one point on purpose, so `f(f(x))` has to equal
`f(x)`. `trim().toLowerCase()` is idempotent. Anything that appends, wraps or
counts is not.

## Turning it on over live data is a migration

`normalizeIdentifier` changes how identifiers are **matched and written from now
on**. It does not touch rows that are already stored.

So an existing row written as `Ivan@acme.com` stops being found the moment the
rule lowercases the incoming address — and it fails the way this page opened
with: as a registration, not as an error. Switching the rule on over a live
database therefore means bringing the stored identifiers to the same form in the
same release:

```sql
UPDATE user_profile SET "userIdentifier" = lower(trim("userIdentifier"));
```

Run that and you will find out whether your table already holds two rows for one
person. It probably does — there is no unique index on `userIdentifier`, so
nothing has been stopping it. Merge them before you add the constraint, not
after.

A new project has none of this to worry about: declare the rule in
`DwAuthConfig` on day one and the question never arises. `dartway create` ships
`template/` with it already declared.
