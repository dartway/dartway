## 0.1.1

- Reads a first-of-its-kind provider identity against `DwAuthConfig.linkByVerifiedEmail`, taking the
  token's verified e-mail straight off its own claims and handing it to
  `DwAccountService.signInWithExternalIdentity` as `verifiedEmail:` — no change to this package's own
  public API. See `dartway_core_server`'s changelog and `docs/4-server/auth-identity.md`
  (dartway/dartway#356).

## 0.1.0

- First version: Sign in with Google and Apple on DartWay 1.0 (D-074), with Apple's refresh token
  kept and revoked when an account is deleted (D-076). See `docs/4-server/auth-identity.md`.
