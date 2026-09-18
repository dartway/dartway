# dartway_auth_providers_server

Sign in with Google and Apple on a DartWay server: `DwSignInProvidersModule` in
`DwAppServer(modules:)`.

- `DwSignInWithProvider` verified against the keys the provider publishes — signature (RS256 for
  Google, ES256 for Apple), issuer, expiry, the nonce, and the app's client ids, **a list**, because
  Android, iOS and the web each have their own;
- the keys fetched once and held for as long as the provider says, fetched again when a token names
  a key id the held set does not have — which is what a rotation looks like from here;
- the account of the provider's subject signed in, created the first time through
  `DwAuthConfig.onExternalAccountCreated`, with the claims the provider signed (`dw.email` and its
  like) beside what the app sent;
- a provider that cannot be reached told apart from a token that does not hold up: the app may try
  again rather than ask the person to;
- for Apple, the one-time authorization code exchanged for a refresh token and kept, so that deleting
  an account revokes the person's tokens with Apple — through a job, so the deletion never waits on
  Apple and never fails because Apple is down.

The providers are independent — a project declares the ones it offers, and one it does not declare
is a door its server does not have.

Documentation: `docs/4-server/auth-identity.md`.
