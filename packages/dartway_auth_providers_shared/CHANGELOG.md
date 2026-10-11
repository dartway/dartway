## 0.3.0-dev.0

- Dependency carets follow DartWay 0.22 and its satellites on their next
  development lines; public dependency types follow those releases (#530).

## 0.2.0

- Targets DartWay 0.21 (`dartway_core_shared` `^0.21.0`). `DwSignInWithProvider` extends that
  package's `DwActionCommand`, so the caret moves this package a minor.

- `DwSignInWithProvider.withRegistration(more)`: the same sign-in — provider, token, nonce,
  authorization code — with `more` merged into its registration, later keys winning. It is how an app
  finishes a provider sign-up its project refused until the terms are accepted
  (dartway/dartway#374, D-137).

## 0.1.0

- First version: the contract of signing in with Google and Apple (D-074). See
  `docs/4-server/auth-identity.md`.
