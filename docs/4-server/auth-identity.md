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

## When one account has two identifiers

Everything above assumes one account is reached by one string. Some products are
not shaped that way: sign in by phone **or** by email, with both belonging to
the same person. Matching a single column cannot express that, and the failure
is the one this page opened with, arriving by a different road — the second
channel matches nothing, so it registers a second account.

`DwAuthConfig.findUserProfileByIdentifier` hands the lookup to the app:

```dart
DwAuthConfig(
  passwords: passwords,
  normalizeIdentifier: DwIdentifierForm.folded,
  findUserProfileByIdentifier: (session, identifier, {transaction}) =>
      UserProfile.db.findFirstRow(
        session,
        where: (t) => t.phone.equals(identifier) | t.email.equals(identifier),
        transaction: transaction,
      ),
);
```

The identifier arrives already normalized, so the rule is still stated once —
do not apply it again inside the query. With this set, the `userIdentifier`
column is never read and is no longer required to exist: an app answering the
question itself has no use for a column nothing consults.

**What you take on with it.** The framework can no longer see the shape of the
lookup, so three things stop being its problem and become yours, and none of
them raises an error when it is wrong:

| What | What it costs to skip |
|---|---|
| a unique index on **every** column the query searches | two accounts claim one address, and `findFirstRow` resolves to whichever row the database hands back first |
| the query reaches the account by every value that can **create** one | a channel written at registration but missing from the query is a door in with no way back — the person registers again on their second visit |
| the query carries its own `include:` | relations the app expects loaded arrive null; the core applies its own include only to the lookup it performs itself |

The second row is the one that bites, because it looks like it works. A
registration writes the identifier into whichever column matches the provider —
so if the query searches `email` but a phone registration wrote only `phone`,
the account exists and cannot be found. **Write and read the same set of
columns.**

## Acquiring the second identifier

**Being able to sign in by two values is not the same as having two values.** A
person who registered by phone has an empty `email` column until something puts
one there, and until then the email door is shut for them specifically.

`DwAuthRequestType.changeIdentifier` is that something, and it is the sign-in
flow run backwards. A **signed-in** caller names a new phone number or address;
DartWay sends a code to it and verifies it exactly as it would a sign-in; the
app then writes it wherever it keeps it:

```dart
DwAuthConfig(
  // ...
  attachVerifiedIdentifier:
      (session, {required userProfile, required verifiedRequest}) =>
          UserProfile.db.updateRow(
            session,
            verifiedRequest.authProvider == DwAuthProvider.email
                ? userProfile.copyWith(email: verifiedRequest.userIdentifier)
                : userProfile.copyWith(phone: verifiedRequest.userIdentifier),
          ),
);
```

Return the profile as it now stands: it travels back to the caller, so the
screen that asked shows the new value without a second read.

**The two inversions are the whole of it**, and both are the opposite of a
sign-in:

- **the identifier must be free.** Finding an account is the failure here
  (`userAlreadyExists`), not the happy path. Two people cannot hold one address,
  because the sign-in lookup would then resolve them arbitrarily;
- **the account is read from the session, never from the request.** `userId`
  arrives on a model the client sends. Taken at its word, it would let anyone
  write their address onto anyone's profile — so it is overwritten with the
  caller's own id before anything else looks at it.

**Unset, the flow is refused before a code is sent**, not after. An identifier
verified and then dropped on the floor is the worst of the three outcomes: the
person watched the code arrive, typed it, was told nothing went wrong, and their
address did not change.

What DartWay checks before calling you: the caller is signed in, the identifier
is normalized, nobody else holds it, and the code came back correct. What it
cannot check is whether *your* rules allow this person that identifier — a
corporate domain, a blocked number, a plan that permits one channel. That check
belongs in the callback, before the write.

And one trap worth naming twice: **writing a column the sign-in query does not
search** leaves the owner a door they cannot come back through. The pair has to
agree.

### Still not implemented

`addAuthProvider` and `removeAuthProvider` remain `UnimplementedError`. They are
a different subject — linking and unlinking an **external** credential (Apple,
Google, Telegram), where there is no code to send and the provider's token is
the proof.
