# Changelog

## 0.1.0

- First public release of the DartWay core Serverpod module: generic
  model-driven CRUD (getOne/getList/save/delete/subscribe) configured per
  model via `DwCrudConfig` (access filters, allowSave/validateSave hooks,
  transactional before/after steps), passwordless phone auth on the app's
  own user model, S3/MinIO cloud storage helpers and Telegram alerts.
- **Security: `DwUploadEndpoint` now requires login.** It previously accepted
  uploads from anyone. Apps that relied on anonymous uploads must sign the user
  in first — this is a deliberate behaviour break.
- **Auth hardening**, configurable on `DwAuthConfig` and secure by default:
  verification codes expire (`verificationCodeLifetime`, 10 min), guessing is
  capped per request (`maxVerificationAttempts`, 5 — after which the request is
  burned), and opening requests is rate-limited per identifier
  (`maxAuthRequestsPerIdentifier` / `authRequestRateLimitWindow`, 5 per 10 min).
  New `DwAuthFailReason` values `tooManyAttempts`, `codeExpired` and
  `rateLimited` tell the client which limit it hit — **exhaustive switches over
  `DwAuthFailReason` in app code must handle them**.
- Every auth limit is now enforced **at the database level**, not by
  read-then-write in Dart. Under Postgres' default READ COMMITTED isolation the
  latter is racy, and not academically so — the integration tests measure it:
  twenty parallel guesses bought **ten** evaluated attempts against a limit of
  five, and a "single-use" access token signed the caller in **twice**. Firing
  the requests concurrently simply took the brute-force protection off.
  Verification attempts and per-identifier rate limiting now take
  transaction-scoped advisory locks, and the access token is claimed with a
  conditional `UPDATE ... WHERE status = 'verified'`, so a second redemption
  matches no rows. See `DwAuthConcurrency`.
- The locks are **non-blocking on purpose**. A lock that waits holds a pooled
  database connection while it queues, so an attacker hammering one identifier
  could exhaust the connection pool — trading a race for a denial of service.
  Failing to take the lock means a request for that identifier is already in
  flight, which for a rate limit is not an error but the answer, and the caller
  gets `rateLimited`.
- Access tokens are single-use: redeeming one moves its auth request to
  `completed`, and the write now commits with the sign-in it authorizes rather
  than outside the enclosing transaction.
- `DwAuthConfig.verifyExternalCredential`: validate an external provider's
  credential (Apple identity token, …) and let DartWay register on first sign-in
  or log the user in. External means a credential issued by a third party —
  Google, Apple, Telegram — while `email` and `phone` remain DartWay's own
  identifier + verification-code flows and never take that path. Leaving the
  callback unset rejects every external provider: an unconfigured provider is a
  closed door, not an open one.
- `DwCloudStorage` honours `useSSL` and `port` from its config instead of
  hardcoding HTTPS and ignoring the port.
