# Advisory locks

Some server rules have no row to lock. "Only one verification code in flight per
phone number", "don't create the same push campaign twice", "don't send and
delete an account at the same time" — the rows being guarded either don't exist
yet or span several tables. Under Postgres' default `READ COMMITTED` isolation,
checking state and then writing it is racy: fire the requests together and each
one reads the same pre-state, all pass the check, all proceed.

`dw.advisoryLock` makes the decisive step atomic in the database, keyed on a
`(namespace, key)` pair instead of a row.

```dart
final locked = await dw.advisoryLock.tryLock(
  session,
  namespace: DwAdvisoryLockNamespace.myFeature,
  key: userProfileId, // an int, or a String (hashed for you)
  transaction: transaction,
);

if (!locked) {
  // someone else holds this key right now — refuse rather than race
  return;
}
// ... the guarded work, safe from a concurrent copy of itself ...
```

## Non-blocking on purpose

`tryLock` returns `false` instead of waiting. That is deliberate: a lock that
queues would hold a pooled database connection while it waits, so anyone
hammering one key could exhaust the pool and take the server down — trading a
race for a denial of service. Failing to take the lock is not an error, it is
the answer: someone else is already handling this key, so this caller should
back off (rate-limited, "too fast", skip).

## Transaction-scoped

The lock lives for the length of the transaction and is released automatically
at commit or rollback — it can never leak. A transaction is therefore required:
a transaction-scoped advisory lock taken outside one is released immediately, so
the guard would quietly buy nothing. Passing a `null` transaction throws rather
than lock nothing silently.

## Namespaces

Two unrelated features that both lock on "user 42" must not block each other, so
every key is scoped by a namespace. The framework reserves the low numbers in
`DwAdvisoryLockNamespace` for its own subsystems; pick your own numbers well
clear of that range:

```dart
abstract final class AppAdvisoryLock {
  static const int inviteRedemption = 1001;
  static const int walletTransfer = 1002;
}
```

`key` may be an `int` (used directly) or a `String` (hashed to a 32-bit key with
Postgres `hashtext`), so you can lock on an id or on a composite string like
`'invite:$inviteId:$userId'`.
