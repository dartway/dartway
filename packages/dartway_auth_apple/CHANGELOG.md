## 0.2.0

- **Breaking:** `dw.signInWithApple()` (the `DwAppleSignInCall` extension) is replaced by
  `DwAppleSignIn.signInCommand({registration, introduce, scopes, webAuthenticationOptions})`, which
  runs the Apple flow and answers the `DwSignInWithProvider` it makes — raw nonce, authorization code
  and introduced name included — without sending it. The app sends it with `dw.command` and calls
  `dw.signIn` on success, as with a code; a sign-up the project refuses (`consentsRequired`) is
  finished by sending `withRegistration(...)` of the same command, so the name Apple tells only once
  is not lost to a second run (dartway/dartway#374, D-137). Migration note
  `2026-10-09-provider-sign-in-command.md`.
- No longer depends on `dartway_core_flutter`.

## 0.1.0

- First version: the app's half of Sign in with Apple (D-074, D-076). See
  `docs/4-server/auth-identity.md`.
