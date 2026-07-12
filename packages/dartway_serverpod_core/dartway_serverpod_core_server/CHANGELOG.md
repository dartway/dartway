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
  latter is racy: parallel guesses each read the same attempt count, all pass
  the check and all get to try — which would have left the brute-force limit
  bypassable by simply firing the attempts concurrently. Verification attempts
  now take a row lock on the auth request, request rate limiting takes a
  transaction-scoped advisory lock on the identifier, and the access token is
  claimed with a conditional `UPDATE` so a second redemption of the same token
  matches no rows. See `DwAuthConcurrency`.
- Access tokens are single-use: redeeming one moves its auth request to
  `completed`, and the write now commits with the sign-in it authorizes rather
  than outside the enclosing transaction.
- `DwAuthConfig.verifyExternalCredential`: validate an external provider's
  credential (Apple identity token, …) on a non-email `DwAuthRequest`; DartWay
  then registers on first sign-in or logs the user in. Leaving it unset rejects
  every non-email provider — an unconfigured provider is a closed door.
- `DwCloudStorage` honours `useSSL` and `port` from its config instead of
  hardcoding HTTPS and ignoring the port.
