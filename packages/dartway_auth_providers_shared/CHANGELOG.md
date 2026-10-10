## 0.1.1

- `DwSignInWithProvider.withRegistration(more)`: the same sign-in — provider, token, nonce,
  authorization code — with `more` merged into its registration, later keys winning. It is how an app
  finishes a provider sign-up its project refused until the terms are accepted
  (dartway/dartway#374, D-137).

## 0.1.0

- First version: the contract of signing in with Google and Apple (D-074). See
  `docs/4-server/auth-identity.md`.
