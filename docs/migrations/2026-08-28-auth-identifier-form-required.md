---
title: "DwAuthConfig.normalizeIdentifier is required — state the identifier form"
affects:
  dartway_serverpod_core_server: "0.12.0"
---

## Who is affected

Every project with a `DwAuthConfig`. The parameter is required, so the project does not compile
until it is answered.

It shipped one release earlier with a default that changed nothing — which meant the defect it
exists to close stayed open in exactly the projects that never noticed it: `Ivan@acme.com` and
`ivan@acme.com` were matched byte for byte, so the second spelling found no profile, resolved as a
registration, and put the person into an empty second account. Nothing failed and nothing was
logged.

## What to change

One line at the `DwAuthConfig` call site, in the server package:

    DwAuthConfig(
      passwords: passwords,
    + normalizeIdentifier: DwIdentifierForm.folded,
      ...
    )

- `DwIdentifierForm.folded` — trims and case-folds. What an email address wants, and what a phone
  number does not object to. This is what `template/` and `example/` state.
- `DwIdentifierForm.asTyped` — byte for byte, today's behaviour.
- Your own function, if the identifier has a rule of its own. **It must be idempotent** —
  `f(f(x)) == f(x)` — because it is applied more than once: at the edge when the auth request
  arrives, and again inside `DwCore.getUserProfileByIdentifier`.

## Which one to choose, on a database that already has users

**This is a data question before it is a code one.** Switching to `folded` over live data means
rows stored in another form stop being found — silently, as "no such user". Ask the database
first:

```sql
SELECT lower("userIdentifier"), count(*), array_agg("userIdentifier")
FROM user_profile
GROUP BY 1 HAVING count(DISTINCT "userIdentifier") > 1;
```

(the table and column are whatever this project stores the identifier in.)

- **No rows** — nothing is stored in mixed forms. `folded` is safe, and closes the duplicate-account
  defect for good.
- **Rows come back** — those accounts are the defect, already happened. Choose `asTyped` to keep
  today's behaviour, merge the duplicates deliberately, and switch to `folded` afterwards. Do not
  fold first and find out.

`dw.normalizeAuthIdentifier` exposes the same rule to the project's own seeds and admin tools, so
anything writing identifiers outside the auth flow can apply it too.

## How to check

`dart analyze` in the server package — a missing `normalizeIdentifier` is a compile error, so
there is no half-migrated state. Then sign in with an identifier typed in a different case than the
one stored and confirm it lands on the same account.
