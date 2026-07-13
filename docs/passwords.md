# Passwords & migrating users from another backend

DartWay hashes passwords with **bcrypt** and needs no configuration to do it.
This page is about the other case: you already have users, their passwords were
hashed by a system you are leaving, and they must keep logging in with the
password they have always used.

## The problem, stated honestly

A password hash is one-way. You can copy the `users` table out of your old
backend, but you cannot copy the passwords *back into a different algorithm* —
that is the whole point of hashing. So a migration has exactly two bad options
and one good one:

- **Force a password reset for everyone.** Correct, and it costs you a
  percentage of your users forever. People do not reset passwords; they leave.
- **Keep the old algorithm and never move off it.** Now your security floor is
  whatever a system you no longer run decided in 2017.
- **Read the old hash, and rewrite it the moment you can.** The plaintext
  password exists exactly once — while the user types it. That is the only
  window in which a hash can be migrated, so the migration has to happen at
  login, one user at a time.

DartWay implements the third one.

## How it works

Two roles, and the types say which is which:

| Type | Can read a hash | Can write a hash |
|---|---|---|
| `DwPasswordVerifier` | ✅ | ❌ |
| `DwPasswordHasher` | ✅ | ✅ |

`DwAuthConfig.passwordHasher` is the **one format DartWay writes** — bcrypt by
default. `DwAuthConfig.legacyPasswordVerifiers` lists formats it can only
*read*: the hashes you brought with you.

On a password sign-in DartWay tries the active hasher first. If the stored hash
is not in its format, each legacy verifier that recognises the format gets to
check the password. When one of them says yes, the user is signed in **and the
hash is immediately rewritten with the active hasher**. Every migrated user
walks the legacy path exactly once; after that they are indistinguishable from a
user who registered yesterday.

A hash that no verifier recognises fails the sign-in — and is logged as the
misconfiguration it is, because answering "wrong password" to every migrated
user would be the most expensive silence in your product.

## Wiring it

Implement the old algorithm. Only you know what your old system did — that code
belongs to your app, not to the framework.

```dart
class LegacySha256Verifier extends DwPasswordVerifier {
  const LegacySha256Verifier();

  // A shape check, not a security decision: it only picks who reads the hash.
  @override
  bool matches(String storedHash) => storedHash.startsWith('sha256\$');

  @override
  Future<bool> verify(String password, String storedHash) async =>
      'sha256\$${sha256.convert(utf8.encode(password))}' == storedHash;
}
```

Register it:

```dart
DwCore.init<UserProfile>(
  // ...
  dwAuthConfig: DwAuthConfig(
    passwords: passwords,
    legacyPasswordVerifiers: const [LegacySha256Verifier()],
  ),
);
```

Import the old hashes as they are — `setUserPassword` takes a hash you cannot
reverse:

```dart
await dw.auth!.setUserPassword(
  session,
  userId: userId,
  newPasswordHash: rowFromTheOldDatabase.passwordHash,
);
```

That is the whole migration. Users log in with their old passwords; their hashes
become bcrypt as they do.

## When it is over

Watch the `Upgraded a legacy password hash` log lines dry up. When the tail is
small enough, drop the verifier from the config and force a reset for whoever
never came back — those are exactly the accounts where a reset costs you nothing.

Keeping a legacy verifier around forever has one real cost beyond the code: a
legacy algorithm is usually far faster than bcrypt, so a not-yet-upgraded user
answers measurably sooner than a migrated one. That leaks *who has not logged in
since the migration* — not their password, but it is a fact you are giving away
for free.

## Don't do this

**Do not swap bcrypt for a fast digest** to make login snappier. SHA-256 is fast
by design, and "fast to hash" means "fast to attack offline". The slowness of
bcrypt is the feature you are paying for.

**Do not put your current algorithm in `legacyPasswordVerifiers`.** Verifiers
are read-only: nothing would ever write that format, and every login would
"upgrade" a hash that was already fine.
